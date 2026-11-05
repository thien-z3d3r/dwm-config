#!/usr/bin/env bash
read -r cpu a b c previdle rest < /proc/stat
prevtotal=$((a+b+c+previdle))
sleep 0.5
read -r cpu a b c idle rest < /proc/stat
total=$((a+b+c+idle))
diff_total=$((total-prevtotal))
diff_idle=$((idle-previdle))
if [ "$diff_total" -gt 0 ]; then
    cpu=$((100 * (diff_total - diff_idle) / diff_total))
else
    cpu=0
fi
echo "󰅡 ${cpu}%"
