#!/usr/bin/env bash
# Simulator benchmark.
#
#   bench.sh                      pick worktree + version with fzf
#   bench.sh castle-climb         pick version only
#   bench.sh castle-climb castle_climb_1.5
#
# Runs 16M spins @ 8 threads and 48M spins @ 24 threads, then reports the
# hottest methods and allocation sites from a JFR recording of the 48M run.
#
#   -n / --no-profile   skip JFR
#   -k / --keep         leave the server running when done
set -uo pipefail

PROTO_ROOT=${PROTO_ROOT:-/home/irakli/work/prototypes}
PORT=${PORT:-8080}
HEAP=${HEAP:-12g}
RTP=${RTP:-96}
BET_TYPE=${BET_TYPE:-Normal}
WORK=$(mktemp -d /tmp/bench.XXXXXX)

PROFILE=1
KEEP=0
ARGS=()
for a in "$@"; do
  case "$a" in
    -n|--no-profile) PROFILE=0 ;;
    -k|--keep)       KEEP=1 ;;
    -h|--help)       sed -n '2,12p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *)               ARGS+=("$a") ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

c_dim=$'\033[2m'; c_b=$'\033[1m'; c_g=$'\033[32m'; c_y=$'\033[33m'; c_r=$'\033[31m'; c_0=$'\033[0m'
say()  { printf '%s\n' "$*"; }
info() { printf '%s==>%s %s\n' "$c_b" "$c_0" "$*"; }
warn() { printf '%s!%s %s\n' "$c_y" "$c_0" "$*"; }
die()  { printf '%serror:%s %s\n' "$c_r" "$c_0" "$*" >&2; exit 1; }

SERVER_PID=""
cleanup() {
  if [[ -n $SERVER_PID ]] && (( ! KEEP )); then kill -9 "$SERVER_PID" 2>/dev/null; fi
  rm -rf "$WORK"
}
trap cleanup EXIT

command -v fzf >/dev/null || die "fzf not found"

# ---------------------------------------------------------------- worktree ---
if [[ ${1:-} ]]; then
  WT=$1
  [[ -d $WT ]] || WT=$PROTO_ROOT/$1
  [[ -d $WT ]] || die "no such worktree: $1"
else
  # git worktree list, not ls: the bare repo's objects/refs/logs are not worktrees
  WT=$(git -C "$PROTO_ROOT" worktree list --porcelain 2>/dev/null \
        | awk '/^worktree /{print substr($0,10)}' \
        | grep -v "^$PROTO_ROOT\$" \
        | sort \
        | fzf --prompt='worktree > ' --height=45% --reverse \
              --preview="git -C {} log --oneline -8 2>/dev/null; echo; git -C {} status --short 2>/dev/null | head -12" \
              --preview-window=right:55%)
  [[ $WT ]] || exit 130
fi
cd "$WT" || die "cannot cd $WT"
WT_NAME=$(basename "$WT")
BRANCH=$(git -C "$WT" rev-parse --abbrev-ref HEAD 2>/dev/null)

[[ -f mvnw ]] || die "$WT_NAME has no mvnw (not a prototypes worktree?)"

# ------------------------------------------------------------------- build ---
info "building ${c_b}$WT_NAME${c_0} ${c_dim}($BRANCH)${c_0}"
if ! ./mvnw -o package -DskipTests -q > "$WORK/build.log" 2>&1; then
  say; sed -n '/ERROR/,$p' "$WORK/build.log" | head -25
  die "build failed - full log: $WORK/build.log"
fi

# ------------------------------------------------------------------ server ---
if ss -lptn "sport = :$PORT" 2>/dev/null | grep -q ":$PORT"; then
  warn "port $PORT busy - killing existing jetty"
  pkill -9 -f "jetty:run" 2>/dev/null
  for _ in $(seq 20); do ss -lptn "sport = :$PORT" 2>/dev/null | grep -q ":$PORT" || break; sleep 1; done
fi

JFR=$WORK/run.jfr
JFR_OPTS=""
(( PROFILE )) && JFR_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints"

info "starting jetty ${c_dim}(heap $HEAP)${c_0}"
MAVEN_OPTS="-Xmx$HEAP -Xms$HEAP $JFR_OPTS" \
  nohup ./mvnw -o -pl game -am jetty:run > "$WORK/jetty.log" 2>&1 &
SERVER_PID=$!

for _ in $(seq 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/game/api/getFiles" 2>/dev/null)
  [[ $code == 200 ]] && break
  kill -0 "$SERVER_PID" 2>/dev/null || { tail -20 "$WORK/jetty.log"; die "server died on startup"; }
  sleep 1
done
[[ ${code:-} == 200 ]] || { tail -20 "$WORK/jetty.log"; die "server did not come up on :$PORT"; }

# The JVM that serves requests is a child of the mvn launcher.
JVM_PID=$(pgrep -f "jetty:run" | tail -1)

# ----------------------------------------------------------------- version ---
VERSIONS=$(curl -s "http://localhost:$PORT/game/api/getFiles" | tr -d '[]"' | tr ',' '\n' | sed '/^$/d')
[[ $VERSIONS ]] || die "no versions from getFiles (PROTO_FILES_DIR=${PROTO_FILES_DIR:-unset})"

if [[ ${2:-} ]]; then
  VERSION=$2
  grep -qx "$VERSION" <<<"$VERSIONS" || die "unknown version: $VERSION"
else
  # pre-fill the query with this worktree's name (castle-climb -> castle_climb) so the
  # matching version floats to the top; no --select-1, the list stays visible
  GUESS=${WT_NAME//-/_}
  VERSION=$(fzf --prompt='version > ' --height=45% --reverse \
                --query="$GUESS" --bind=change:top <<<"$VERSIONS")
  [[ $VERSION ]] || exit 130
fi

SIM="http://localhost:$PORT/game/api/simulate?version=$VERSION&report=false&fake_reels=false&RTP=$RTP&minRTP=$RTP&maxRTP=$RTP&betType=$BET_TYPE"

# a fresh cookie jar per request: the servlet drops the sim from the session
# after each response, and reusing a stale jar returns instantly with garbage.
run_sim() {
  local count=$1 threads=$2 jar=$WORK/jar.$RANDOM
  local out
  out=$(curl -s -c "$jar" -b "$jar" -o /dev/null -w '%{http_code} %{time_total}' \
             "$SIM&count=$count&threads=$threads")
  rm -f "$jar"

  local code=${out%% *} secs=${out##* }
  # A dead server or a stale session returns instantly; without these guards the
  # script reports absurd rates (340 billion spins/s) as if they were real.
  [[ $code == 200 ]] || die "simulate returned HTTP $code (server log: $WORK/jetty.log)"
  awk -v t="$secs" 'BEGIN{exit !(t > 0.5)}' \
    || die "simulate returned in ${secs}s - server died or session was stale"
  printf '%s' "$secs"
}

# Group thousands ourselves rather than relying on %'d: that needs a locale with a
# thousands separator, and LC_ALL=C (which we want for predictable decimal parsing)
# defines none, so %'d would silently print ungrouped.
fmt_rate() {
  awk -v n="$1" 'BEGIN{
    n = sprintf("%.0f", n)
    neg = (substr(n,1,1) == "-"); if (neg) n = substr(n,2)
    out = ""
    while (length(n) > 3) {
      out = "," substr(n, length(n)-2) out
      n = substr(n, 1, length(n)-3)
    }
    print (neg ? "-" : "") n out
  }'
}

# ------------------------------------------------------------------- warmup ---
# throughput is bimodal until C2 settles; without this the first results are ~30% low
info "warming up ${c_dim}(JIT)${c_0}"
for _ in 1 2 3; do run_sim 6000000 24 >/dev/null || exit 1; done

say
printf '%s%s%s  %s|%s  %s  %s|%s  RTP %s\n' \
  "$c_b" "$WT_NAME" "$c_0" "$c_dim" "$c_0" "$VERSION" "$c_dim" "$c_0" "$RTP"
printf '%s%s%s\n' "$c_dim" "$(printf '─%.0s' {1..58})" "$c_0"

# ------------------------------------------------------------------- 16M/8 ---
t=$(run_sim 16000000 8) || exit 1
r=$(awk -v c=16000000 -v t="$t" 'BEGIN{print c/t}')
printf '  %-22s %8.2fs   %s%12s%s spins/s\n' "16M spins / 8 thr" "$t" "$c_g" "$(fmt_rate "$r")" "$c_0"

# ------------------------------------------------------------------ 48M/24 ---
if (( PROFILE )) && [[ -n $JVM_PID ]]; then
  jcmd "$JVM_PID" JFR.start name=bench settings=profile filename="$JFR" >/dev/null 2>&1
fi

t=$(run_sim 48000000 24) || exit 1
r=$(awk -v c=48000000 -v t="$t" 'BEGIN{print c/t}')
printf '  %-22s %8.2fs   %s%12s%s spins/s\n' "48M spins / 24 thr" "$t" "$c_g" "$(fmt_rate "$r")" "$c_0"

if (( PROFILE )) && [[ -n $JVM_PID ]]; then
  jcmd "$JVM_PID" JFR.dump name=bench filename="$JFR" >/dev/null 2>&1
  jcmd "$JVM_PID" JFR.stop name=bench >/dev/null 2>&1
fi

# machine context - a loaded box or a downclocked CPU invalidates the comparison
mhz=$(awk '/cpu MHz/{s+=$4;n++} END{if(n)printf "%.0f",s/n}' /proc/cpuinfo)
load=$(awk '{print $1}' /proc/loadavg)
printf '%s  %s─ %s MHz, load %s%s\n' "$c_dim" "$(printf '─%.0s' {1..24})" "$mhz" "$load" "$c_0"

# ---------------------------------------------------------------- hotpaths ---
if (( PROFILE )) && [[ -s $JFR ]]; then
  # Collapse each leaf frame to Class.method before counting, so overloads
  # (e.g. the two String.split signatures) aggregate into one row instead of
  # showing up as separate near-identical entries.
  shorten() {
    sed 's/ line:.*//; s/^[[:space:]]*//; s/([^)]*)//g' \
      | awk -F. 'NF>1{print $(NF-1)"."$NF; next} {print}' \
      | sed '/^$/d'
  }

  # leaf frame of each sample = where CPU time is actually spent
  cpu=$(jfr print --events ExecutionSample "$JFR" 2>/dev/null \
        | grep -A1 'stackTrace = \[' | grep -vE 'stackTrace|^--' | shorten)
  total=$(wc -l <<<"$cpu")

  if (( total > 0 )); then
    say; printf '%sTop 5 CPU%s %s(%s samples)%s\n' "$c_b" "$c_0" "$c_dim" "$total" "$c_0"
    sort <<<"$cpu" | uniq -c | sort -rn | head -5 | while read -r n sym; do
      printf '  %5.1f%%  %s\n' "$(awk -v n="$n" -v t="$total" 'BEGIN{print n*100/t}')" "$sym"
    done
  fi

  alloc=$(jfr print --events ObjectAllocationSample "$JFR" 2>/dev/null \
          | grep -A1 'stackTrace = \[' | grep -vE 'stackTrace|^--' | shorten)
  atotal=$(wc -l <<<"$alloc")

  if (( atotal > 0 )); then
    say; printf '%sTop 5 allocation%s %s(%s samples)%s\n' "$c_b" "$c_0" "$c_dim" "$atotal" "$c_0"
    sort <<<"$alloc" | uniq -c | sort -rn | head -5 | while read -r n sym; do
      printf '  %5.1f%%  %s\n' "$(awk -v n="$n" -v t="$atotal" 'BEGIN{print n*100/t}')" "$sym"
    done
  fi

  gc=$(jfr print --events GarbageCollection "$JFR" 2>/dev/null | grep -c 'name = ')
  full=$(jfr print --events GarbageCollection "$JFR" 2>/dev/null | grep -c 'G1Full')
  say; printf '%sGC%s  %s collections, %s full\n' "$c_b" "$c_0" "$gc" "$full"
fi

say
if (( KEEP )); then
  info "server left running on :$PORT ${c_dim}(pid $JVM_PID)${c_0}"
  SERVER_PID=""
fi
