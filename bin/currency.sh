#!/usr/bin/env bash

cur=$1

yesterday=$(date -d "yesterday" +%Y-%m-%d)

rate_url="https://nbg.gov.ge/gw/api/ct/monetarypolicy/currencies/ka/json/?currencies=$cur"
rate_yesterday_url="$rate_url&date=$yesterday"

# Fetch the current exchange rates
rate=$(curl -s "$rate_url" | jq '.[0].currencies[0].rate')
rate_yesterday=$(curl -s "$rate_yesterday_url" | jq '.[0].currencies[0].rate')

diff=$(echo "$rate - $rate_yesterday" | bc)

c="↑"
if [ $(echo "$diff > 0" | bc) -eq 1 ]; then
    c="↑"
elif [ $(echo "$diff < 0" | bc) -eq 1 ]; then
    c="↓"
fi

echo $(printf "$c %.4f" "$rate")
