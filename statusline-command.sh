#!/bin/sh
# Claude Code statusLine command
# Reads JSON from stdin and outputs a formatted status line.

input=$(cat)

# Pick an ANSI color code based on a usage percentage (green/yellow/red)
pct_color() {
    p=$1
    if [ "$p" -ge 80 ]; then echo "1;31"      # red
    elif [ "$p" -ge 50 ]; then echo "1;33"    # yellow
    else echo "1;32"; fi                        # green
}

# Build a 10-segment bar (█ filled / ░ empty) for a usage percentage.
# Output uses printf escape sequences, meant to be embedded in a printf format.
make_bar() {
    p=$1
    filled=$(( (p + 5) / 10 ))
    [ "$filled" -gt 10 ] && filled=10
    [ "$filled" -lt 0 ] && filled=0
    bar=""
    i=0
    while [ "$i" -lt 10 ]; do
        if [ "$i" -lt "$filled" ]; then
            bar="${bar}\xe2\x96\x88"   # █ full block
        else
            bar="${bar}\xe2\x96\x91"   # ░ light block
        fi
        i=$((i + 1))
    done
    printf "%s" "$bar"
}

# 1. Current working directory (basename)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
if [ -n "$cwd" ]; then
    dir=$(basename "$cwd")
else
    dir=$(basename "$PWD")
fi

# 2. Model display name
model=$(echo "$input" | jq -r '.model.display_name // empty')

# 3. Git branch — skip gracefully when not in a git repo or git is unavailable
branch=""
if [ -n "$cwd" ] && command -v git >/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

# 4. Context used percentage (pre-calculated field)
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# 5. Cumulative session cost (USD)
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# 5b. Rate limit usage — Claude.ai Pro/Max only; absent for API/other plans
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# 6. Weather — cached for 30 min to avoid a network call on every render
weather_cache="${TMPDIR:-/tmp}/cc_weather_cache"
weather=""
if command -v curl >/dev/null 2>&1; then
    if [ -z "$(find "$weather_cache" -mmin -30 2>/dev/null)" ]; then
        # Cache missing or older than 30 min → refresh (quietly, short timeout)
        curl -fs -m 3 "wttr.in/?format=%c%t" 2>/dev/null > "$weather_cache.tmp" \
            && mv "$weather_cache.tmp" "$weather_cache"
    fi
    [ -f "$weather_cache" ] && weather=$(cat "$weather_cache")
fi


# --- Build the output line ---
SEP=" | "

printf "\033[1;36m%s\033[0m" "$dir"

if [ -n "$model" ]; then
    printf "%s\033[1;33m%s\033[0m" "$SEP" "$model"
fi

if [ -n "$branch" ]; then
    printf "%s\033[1;32m\xef\x9c\xa6 %s\033[0m" "$SEP" "$branch"
fi

if [ -n "$used_pct" ]; then
    # Round to integer
    pct=$(printf "%.0f" "$used_pct")
    # Color by usage level: green < 50, yellow 50-79, red >= 80
    if [ "$pct" -ge 80 ]; then
        ctx_color="1;31"   # red
    elif [ "$pct" -ge 50 ]; then
        ctx_color="1;33"   # yellow
    else
        ctx_color="1;32"   # green
    fi
    # 10-segment bar: filled vs empty
    filled=$(( (pct + 5) / 10 ))
    [ "$filled" -gt 10 ] && filled=10
    [ "$filled" -lt 0 ] && filled=0
    bar=""
    i=0
    while [ "$i" -lt 10 ]; do
        if [ "$i" -lt "$filled" ]; then
            bar="${bar}\xe2\x96\x88"   # █ full block
        else
            bar="${bar}\xe2\x96\x91"   # ░ light block
        fi
        i=$((i + 1))
    done
    printf "%sctx \033[${ctx_color}m${bar} %d%%\033[0m" "$SEP" "$pct"
fi

if [ -n "$cost" ]; then
    printf "%s\033[1;32m\xf0\x9f\x92\xb0\$%.2f\033[0m" "$SEP" "$cost"
fi

if [ -n "$five_h" ]; then
    p5=$(printf "%.0f" "$five_h")
    c5=$(pct_color "$p5")
    bar5=$(make_bar "$p5")
    printf "%s5h \033[${c5}m${bar5} %d%%\033[0m" "$SEP" "$p5"
fi

if [ -n "$week_d" ]; then
    p7=$(printf "%.0f" "$week_d")
    c7=$(pct_color "$p7")
    bar7=$(make_bar "$p7")
    printf "%s7d \033[${c7}m${bar7} %d%%\033[0m" "$SEP" "$p7"
fi

if [ -n "$weather" ]; then
    printf "%s\033[1;37m%s\033[0m" "$SEP" "$weather"
fi

printf "\n"
