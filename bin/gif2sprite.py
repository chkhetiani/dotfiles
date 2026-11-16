#!/usr/bin/env python3
"""
gif2sprites.py: GIF -> transparent frames -> cropped -> scaled -> packed spritesheet (PixiJS JSON).

Steps (each one asks what it needs):
  1. extract frames        (ImageMagick)
  2. remove background     (rembg)
  3. find a common crop    (ImageMagick, alpha union)
  4. crop + scale          (ImageMagick)
  5. pack a spritesheet    (TexturePacker CLI if installed, else built-in packer)

Requirements:
  ImageMagick (magick or convert), rembg:  pip install "rembg[cpu,cli]"
  Built-in packer only:                    pip install pillow rectpack
"""
import json
import math
import re
import shutil
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------- helpers

def ask(prompt, default=None, cast=str):
    suffix = f" [{default}]" if default is not None else ""
    while True:
        raw = input(f"{prompt}{suffix}: ").strip()
        if raw == "" and default is not None:
            return default
        try:
            return cast(raw)
        except ValueError:
            print("  Please enter a valid value.")


def yes(prompt, default=True):
    d = "Y/n" if default else "y/N"
    while True:
        raw = input(f"{prompt} [{d}]: ").strip().lower()
        if raw == "":
            return default
        if raw in ("y", "yes"):
            return True
        if raw in ("n", "no"):
            return False


def run(cmd, **kw):
    cmd = [str(c) for c in cmd]
    r = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if r.returncode != 0:
        print(f"\nCommand failed: {' '.join(cmd[:6])} ...")
        print(r.stderr.strip() or r.stdout.strip())
        sys.exit(1)
    return r.stdout


def run_live(cmd):
    cmd = [str(c) for c in cmd]
    if subprocess.run(cmd).returncode != 0:
        print(f"\nCommand failed: {' '.join(cmd[:6])} ...")
        sys.exit(1)


def step(n, title):
    print(f"\n=== Step {n}: {title} ===")


def pngs(folder):
    return sorted(Path(folder).glob("*.png"))


def reuse_or_clear(folder, label):
    """If folder has PNGs, ask whether to reuse. Returns True to reuse."""
    folder = Path(folder)
    if folder.exists() and pngs(folder):
        if yes(f"{folder}/ already has {len(pngs(folder))} files. Reuse them and skip this step?", True):
            return True
        shutil.rmtree(folder)
    folder.mkdir(parents=True, exist_ok=True)
    return False


# ---------------------------------------------------------------- tooling

if shutil.which("magick"):
    CONVERT, MOGRIFY, IDENTIFY = ["magick"], ["magick", "mogrify"], ["magick", "identify"]
elif shutil.which("convert") and shutil.which("mogrify"):
    CONVERT, MOGRIFY, IDENTIFY = ["convert"], ["mogrify"], ["identify"]
else:
    sys.exit("ImageMagick not found. Install it first (e.g. brew install imagemagick).")

REMBG = shutil.which("rembg")
TEXTUREPACKER = shutil.which("TexturePacker")

# ---------------------------------------------------------------- built-in packer

def pack_builtin(files, out_png, out_json, size, rotate, pad, border, extrude, anim_name):
    try:
        from PIL import Image
        from rectpack import newPacker, MaxRectsBssf, PackingBin, PackingMode
    except ImportError:
        sys.exit('Built-in packer needs:  pip install pillow rectpack')

    items = []
    for f in files:
        im = Image.open(f).convert("RGBA")
        bb = im.getchannel("A").getbbox() or (0, 0, 1, 1)
        items.append((f.name, im.crop(bb), bb, im.size))

    usable = size - 2 * border
    packer = newPacker(mode=PackingMode.Offline, bin_algo=PackingBin.BFF,
                       pack_algo=MaxRectsBssf, rotation=rotate)
    packer.add_bin(usable, usable, count=1)
    for i, (_, tr, _, _) in enumerate(items):
        packer.add_rect(tr.width + 2 * extrude + pad, tr.height + 2 * extrude + pad, rid=i)
    packer.pack()
    placed = packer.rect_list()
    if len(placed) < len(items):
        return False, None

    sheet = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    frames, names, max_x, max_y = {}, [], 0, 0
    for _, x, y, w, h, rid in placed:
        name, tr, bb, src = items[rid]
        rotated = (w - 2 * extrude - pad, h - 2 * extrude - pad) != tr.size
        tile = tr.rotate(-90, expand=True) if rotated else tr  # clockwise, like TexturePacker
        tw, th = tile.size
        px, py = x + border, y + border
        ex = extrude
        if ex:
            padded = Image.new("RGBA", (tw + 2 * ex, th + 2 * ex))
            padded.paste(tile, (ex, ex))
            padded.paste(tile.crop((0, 0, 1, th)).resize((ex, th)), (0, ex))
            padded.paste(tile.crop((tw - 1, 0, tw, th)).resize((ex, th)), (tw + ex, ex))
            padded.paste(padded.crop((0, ex, tw + 2 * ex, ex + 1)).resize((tw + 2 * ex, ex)), (0, 0))
            padded.paste(padded.crop((0, ex + th - 1, tw + 2 * ex, ex + th)).resize((tw + 2 * ex, ex)), (0, th + ex))
            sheet.paste(padded, (px, py))
        else:
            sheet.paste(tile, (px, py))
        fx, fy = px + ex, py + ex
        max_x, max_y = max(max_x, px + tw + 2 * ex), max(max_y, py + th + 2 * ex)
        frames[name] = {
            "frame": {"x": fx, "y": fy, "w": tr.width, "h": tr.height},  # unrotated size, as TexturePacker writes it
            "rotated": rotated,
            "trimmed": True,
            "spriteSourceSize": {"x": bb[0], "y": bb[1], "w": tr.width, "h": tr.height},
            "sourceSize": {"w": src[0], "h": src[1]},
        }
    names = sorted(frames)
    sw, sh = max_x + border, max_y + border
    sheet = sheet.crop((0, 0, sw, sh))
    sheet.save(out_png, optimize=True)
    data = {
        "frames": {n: frames[n] for n in names},
        "animations": {anim_name: names},
        "meta": {"app": "gif2sprites.py", "version": "1.0", "image": Path(out_png).name,
                 "format": "RGBA8888", "size": {"w": sw, "h": sh}, "scale": "1"},
    }
    Path(out_json).write_text(json.dumps(data, indent=1))
    return True, (sw, sh)


# ---------------------------------------------------------------- main

def main():
    print("GIF -> sprite sheet\n")

    gif = Path(ask("Path to GIF").strip("'\"")).expanduser()
    if not gif.is_file():
        sys.exit(f"File not found: {gif}")
    name = ask("Output name", gif.stem)
    work = Path(ask("Working folder", f"{name}_work"))
    work.mkdir(parents=True, exist_ok=True)

    delay = int(run(IDENTIFY + ["-format", "%T\n", gif]).splitlines()[0] or 4)
    gif_fps = round(100 / delay, 2) if delay else 25
    print(f"GIF frame delay {delay}/100 s -> {gif_fps} fps")

    # --- 1. extract
    step(1, "Extract frames")
    frames_dir = work / "frames"
    if not reuse_or_clear(frames_dir, "frames"):
        run(CONVERT + [gif, "-coalesce", frames_dir / "f_%04d.png"])
    n = len(pngs(frames_dir))
    print(f"{n} frames extracted.")

    # --- 2. background removal
    step(2, "Remove background")
    out_dir = work / "out"
    if yes("Remove the background? (say no if the GIF is already transparent)", True):
        if not REMBG:
            sys.exit('rembg not found. Install it:  pip install "rembg[cpu,cli]"')
        if not reuse_or_clear(out_dir, "cutouts"):
            print("Models: isnet-general-use (good default), birefnet-general (better edges, slower),")
            print("        u2net, isnet-anime (for drawn art)")
            model = ask("Model", "isnet-general-use")
            print("Running rembg. The first run downloads the model; CPU takes a few minutes.")
            run_live([REMBG, "p", "-m", model, frames_dir, out_dir])
    else:
        shutil.rmtree(out_dir, ignore_errors=True)
        shutil.copytree(frames_dir, out_dir)
    cut = pngs(out_dir)
    if len(cut) != n:
        sys.exit(f"Expected {n} cutouts, found {len(cut)}.")

    # --- 3. crop box
    step(3, "Find the crop box")
    thr = ask("Ignore alpha below this percent (removes faint leftover pixels)", 5, float)
    box = run(CONVERT + cut + ["-alpha", "extract", "-evaluate-sequence", "max",
                                "-threshold", f"{thr}%", "-format", "%@", "info:"]).strip()
    m = re.match(r"(\d+)x(\d+)\+(\d+)\+(\d+)", box)
    if not m:
        sys.exit(f"Could not read crop box: {box!r}")
    cw, ch, cx, cy = map(int, m.groups())
    print(f"Content spans {cw}x{ch} at x={cx}, y={cy} in all frames.")
    if not yes("Use this crop box?", True):
        cw = ask("Width", cw, int); ch = ask("Height", ch, int)
        cx = ask("X offset", cx, int); cy = ask("Y offset", cy, int)

    # --- 4. crop + scale
    step(4, "Crop and scale")
    size = ask("Sheet size (square, px): 1024 / 2048 / 4096", 2048, int)
    suggested = max(1, int(100 * math.sqrt(0.65 * size * size / (n * cw * ch))))
    suggested = min(suggested, 100)
    print(f"Frame is {cw}x{ch}. To fit {n} frames on one {size}px sheet, about {suggested}% is a good start")
    print("(trimming transparent edges usually saves a lot, so it may fit slightly larger).")

    pad = ask("Padding between frames (px)", 2, int)
    border = ask("Padding around the sheet edge (px)", 2, int)
    extrude = ask("Extrude edge pixels (stops bleeding when scaled)", 1, int)
    rotate = yes("Allow rotation of frames? (smaller sheet; PixiJS v7 handles it)", False)

    use_tp = False
    if TEXTUREPACKER:
        use_tp = yes("TexturePacker CLI found. Use it? (no = built-in packer)", True)
    else:
        print("TexturePacker CLI not found, using the built-in packer.")

    cropped_dir = work / "cropped"
    if cropped_dir.exists():
        shutil.rmtree(cropped_dir)
    cropped_dir.mkdir()
    run(MOGRIFY + ["-path", cropped_dir, "-crop", f"{cw}x{ch}+{cx}+{cy}", "+repage"] + cut)

    while True:
        scale = ask("Scale (percent)", suggested, float)
        small_dir = work / "small"
        if small_dir.exists():
            shutil.rmtree(small_dir)
        small_dir.mkdir()
        if scale >= 100:
            for f in pngs(cropped_dir):
                shutil.copy(f, small_dir / f.name)
        else:
            run(MOGRIFY + ["-path", small_dir, "-filter", "Lanczos", "-resize", f"{scale}%"] + pngs(cropped_dir))
        fw, fh = int(round(cw * scale / 100)), int(round(ch * scale / 100))
        print(f"Frames are now about {fw}x{fh}.")

        # --- 5. pack
        step(5, "Pack the sheet")
        out_png = work / f"{name}.png"
        out_json = work / f"{name}.json"
        if use_tp:
            cmd = [TEXTUREPACKER, "--format", "json-array", "--data", out_json, "--sheet", out_png,
                   "--max-size", size, "--size-constraints", "AnySize", "--algorithm", "MaxRects",
                   "--trim-mode", "Trim", "--shape-padding", pad, "--border-padding", border,
                   "--extrude", extrude]
            if not rotate:
                cmd.append("--disable-rotation")
            cmd.append(small_dir)
            r = subprocess.run([str(c) for c in cmd], capture_output=True, text=True)
            ok = r.returncode == 0 and out_png.exists()
            if not ok:
                print((r.stderr or r.stdout).strip()[-600:])
            dims = None
        else:
            ok, dims = pack_builtin(pngs(small_dir), out_png, out_json, size, rotate,
                                    pad, border, extrude, name)
        if ok:
            break
        print(f"\nThe frames did not fit on one {size}px sheet at {scale}%.")
        if not yes("Try a smaller scale?", True):
            sys.exit("Stopped. Intermediate files are in " + str(work))
        suggested = max(1, int(scale * 0.85))

    print("\nDone.")
    print(f"  Sheet:  {out_png}")
    print(f"  Data:   {out_json}")
    print(f"  Speed:  {gif_fps} fps  (PixiJS v7: animationSpeed = {gif_fps} / 60)")
    print(f"  Frames: {n}, loop length {n / gif_fps:.2f} s")
    print(f"\nIntermediate folders in {work}/ can be deleted once you are happy.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nCancelled.")
