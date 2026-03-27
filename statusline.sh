#!/usr/bin/env bash
# Claude Code status line — Gruvbox Dark theme with Powerline separators
# Segments: cwd | git branch | model | context bar | tokens | claude.ai usage | cost | duration
#
# Requirements: Git Bash (Windows) or any bash (Linux/macOS), grep, sed, awk, curl
# Optional: claude CLI in PATH (for active account detection)
# Icons: Nerd Font Mono (JetBrainsMono Nerd Font Mono recommended)
#
# Config: ~/.claude/claude-usage.conf — see claude-usage.conf.example

input=$(cat)

# ---------------------------------------------------------------------------
# Gruvbox Dark palette — 24-bit ANSI escape helpers
# ---------------------------------------------------------------------------
fg() { local r=$((16#${1:1:2})) g=$((16#${1:3:2})) b=$((16#${1:5:2})); printf '\033[38;2;%d;%d;%dm' $r $g $b; }
bg() { local r=$((16#${1:1:2})) g=$((16#${1:3:2})) b=$((16#${1:5:2})); printf '\033[48;2;%d;%d;%dm' $r $g $b; }
reset=$'\033[0m'

color_fg0='#fbf1c7'
color_bg3='#665c54'
color_blue='#458588'
color_aqua='#689d6a'
color_green='#b8bb26'
color_yellow='#d79921'
color_orange='#d65d0e'
color_red='#cc241d'
color_purple='#b16286'
color_dark='#665c54'

# Icons — explicit UTF-8 hex bytes (avoids Windows file encoding issues on save)
SEP=$'\xee\x82\xb0'           # U+E0B0  Powerline right-arrow
SEP_ROUND_L=$'\xee\x82\xb6'   # U+E0B6  Powerline rounded left cap
SEP_ROUND_R=$'\xee\x82\xb4'   # U+E0B4  Powerline rounded right cap
ICON_FOLDER=$'\xef\x81\xbb'   # U+F07B  folder
ICON_BRANCH=$'\xef\x90\x98'   # U+F418  nf-oct-git_branch
ICON_ROBOT=$'\xf3\xb1\x9c\x99' # U+F1719 robot
ICON_COST=$'\xf3\xb0\x84\x90'  # U+F0110 coin
ICON_CLOCK=$'\xef\x80\x97'     # U+F017  clock
ICON_USAGE=$'\xef\x88\x81'     # U+F201  fa-line-chart
ICON_RESET=$'\xf3\xb0\x9d\xb3' # U+F0773 reset
GAUGE_EMPTY=$'\xf3\xb0\xa1\xb3' # U+F0873 gauge empty  (0–24%)
GAUGE_LOW=$'\xf3\xb0\xa1\xb5'   # U+F0875 gauge low    (25–49%)
GAUGE_HIGH=$'\xee\xb4\xaf'       # U+ED2F  gauge high   (50–74%)
GAUGE_FULL=$'\xf3\xb0\xa1\xb4'  # U+F0874 gauge full   (75–100%)

# ---------------------------------------------------------------------------
# Data extraction — grep/sed only (no jq dependency)
# ---------------------------------------------------------------------------
_str() {
  printf '%s' "$input" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"(\\\\.|[^\"])*\"" \
    | sed 's/^[^:]*:[[:space:]]*"//; s/".*$//; s/\\\\/\\/g' \
    | head -1
}
_num() {
  printf '%s' "$input" \
    | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*-?[0-9]+(\.[0-9]+)?" \
    | sed 's/.*:[[:space:]]*//' \
    | head -1
}

# ---------------------------------------------------------------------------
# Claude.ai usage (5h + 7d limits) — cached 60s
# Requires: ~/.claude/claude-usage.conf with CLAUDE_ORG_ID + CLAUDE_SESSION_KEY
# ---------------------------------------------------------------------------
_claude_usage() {
  local conf="$HOME/.claude/claude-usage.conf"
  local cache="$HOME/.claude/.usage-cache"
  local cache_ts="$HOME/.claude/.usage-cache-ts"

  [ -f "$conf" ] || return 1
  # shellcheck source=/dev/null
  . "$conf"
  [ -z "$CLAUDE_ORG_ID" ] || [ -z "$CLAUDE_SESSION_KEY" ] && return 1

  # Cache check (60s TTL)
  local now expiry=0
  now=$(date +%s 2>/dev/null) || return 1
  [ -f "$cache_ts" ] && expiry=$(cat "$cache_ts" 2>/dev/null)
  if [ "$now" -lt "${expiry:-0}" ] && [ -f "$cache" ]; then
    cat "$cache"
    return 0
  fi

  # Fetch from claude.ai API
  local resp
  resp=$(curl -sf --max-time 5 \
    -H "Cookie: sessionKey=$CLAUDE_SESSION_KEY" \
    -H "Accept: application/json" \
    -H "Cache-Control: no-cache" \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    "https://claude.ai/api/organizations/$CLAUDE_ORG_ID/usage" 2>/dev/null) || return 1

  [ -z "$resp" ] && return 1

  local fh_pct wd_pct fh_block wd_block fh_reset_raw wd_reset_raw fh_epoch wd_epoch
  fh_block=$(printf '%s' "$resp" | grep -oE '"five_hour":[^}]+}')
  wd_block=$(printf '%s' "$resp" | grep -oE '"seven_day":[^}]+}')

  fh_pct=$(printf '%s' "$fh_block" | grep -oE '"utilization"[[:space:]]*:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$')
  wd_pct=$(printf '%s' "$wd_block" | grep -oE '"utilization"[[:space:]]*:[[:space:]]*[0-9]+' | grep -oE '[0-9]+$')

  [ -z "$fh_pct" ] && return 1

  fh_reset_raw=$(printf '%s' "$fh_block" | grep -oE '"resets_at":"[^"]*"' | sed 's/"resets_at":"//;s/"//')
  wd_reset_raw=$(printf '%s' "$wd_block" | grep -oE '"resets_at":"[^"]*"' | sed 's/"resets_at":"//;s/"//')
  fh_epoch=$(date -d "$fh_reset_raw" +%s 2>/dev/null || echo 0)
  wd_epoch=$(date -d "$wd_reset_raw" +%s 2>/dev/null || echo 0)

  local result="$fh_pct ${wd_pct:-0} $fh_epoch $wd_epoch"
  printf '%s' "$result" > "$cache"
  printf '%s' "$((now + 60))" > "$cache_ts"
  printf '%s' "$result"
}

# ---------------------------------------------------------------------------
# Active account email — cached 300s
# Tries `claude auth status`, falls back to CLAUDE_ACTIVE_ACCOUNT in conf
# ---------------------------------------------------------------------------
_active_email() {
  local conf="$HOME/.claude/claude-usage.conf"
  local cache="$HOME/.claude/.auth-email-cache"
  local cache_ts="$HOME/.claude/.auth-email-cache-ts"
  local now expiry=0 email
  now=$(date +%s 2>/dev/null) || return 1
  [ -f "$cache_ts" ] && expiry=$(cat "$cache_ts" 2>/dev/null)
  if [ "$now" -lt "${expiry:-0}" ] && [ -f "$cache" ]; then
    cat "$cache"
    return 0
  fi
  email=$(claude auth status 2>/dev/null | grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' | head -1)
  if [ -z "$email" ] && [ -f "$conf" ]; then
    email=$(grep 'CLAUDE_ACTIVE_ACCOUNT=' "$conf" 2>/dev/null | sed 's/.*=//;s/"//g' | head -1)
  fi
  if [ -n "$email" ]; then
    printf '%s' "$email" > "$cache"
    printf '%s' "$((now + 300))" > "$cache_ts"
    printf '%s' "$email"
  fi
}

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------
cwd=$(_str 'current_dir')
[ -z "$cwd" ] && cwd=$(_str 'cwd')
[ -n "$HOME" ] && cwd="${cwd/#$HOME/\~}"
# Shorten: keep last 2 path components
cwd=$(printf '%s' "$cwd" | sed 's|\\|/|g' | awk -F'/' '{
  n=NF; if ($n=="") n--
  if (n<=2) print $0
  else printf "\xe2\x80\xa6/%s/%s", $(n-1), $n
}')

dir_for_git=$(_str 'current_dir')
[ -z "$dir_for_git" ] && dir_for_git=$(_str 'cwd')
[ -z "$dir_for_git" ] && dir_for_git="."

git_branch=""
command -v git >/dev/null 2>&1 && \
  git_branch=$(git -C "$dir_for_git" --no-optional-locks branch --show-current 2>/dev/null)

model=$(_str 'display_name')
used_pct=$(_num 'used_percentage')
total=$(_num 'context_window_size')
cost_raw=$(_num 'total_cost_usd')
cost_fmt=$(echo "$cost_raw" | awk '{if($1!="") printf "$%.2f",$1}')
duration_ms=$(_num 'total_duration_ms')
duration_fmt=$(echo "$duration_ms" | awk '{
  if ($1=="") { print ""; next }
  s = int($1/1000)
  if (s < 60) { printf "%ds", s }
  else { printf "%dm%ds", int(s/60), s%60 }
}')
api_duration_ms=$(_num 'total_api_duration_ms')
api_duration_fmt=$(echo "$api_duration_ms" | awk '{
  if ($1=="") { print ""; next }
  s = int($1/1000)
  if (s < 60) { printf "%ds", s }
  else { printf "%dm%ds", int(s/60), s%60 }
}')

usage_data=$(_claude_usage)
active_email=$(_active_email)
usage_5h="" usage_7d="" usage_fh_left="" usage_wd_left=""
if [ -n "$usage_data" ]; then
  usage_5h=$(echo "$usage_data" | awk '{print $1}')
  usage_7d=$(echo "$usage_data" | awk '{print $2}')
  fh_epoch=$(echo "$usage_data" | awk '{print $3}')
  wd_epoch=$(echo "$usage_data" | awk '{print $4}')
  _now=$(date +%s 2>/dev/null)
  usage_fh_left=$(awk -v s="$((fh_epoch - _now))" 'BEGIN{
    if(s<=0){print "now";exit}
    h=int(s/3600);m=int((s%3600)/60)
    if(h>0)printf "%dh%02d",h,m; else printf "%dm",m
  }')
  usage_wd_left=$(awk -v s="$((wd_epoch - _now))" 'BEGIN{
    if(s<=0){print "now";exit}
    d=int(s/86400);h=int((s%86400)/3600)
    if(d>0)printf "%dd",d; else printf "%dh",h
  }')
fi

# ---------------------------------------------------------------------------
# Segment 1 — current directory  (fg0 on yellow)
# ---------------------------------------------------------------------------
printf '%s%s%s' "${reset}$(fg "$color_yellow")" "$SEP_ROUND_L" ""
printf '%s%s %s %s ' "$(fg "$color_fg0")" "$(bg "$color_yellow")" "$ICON_FOLDER" "$cwd"

# ---------------------------------------------------------------------------
# Segment 2 — git branch  (fg0 on orange)
# ---------------------------------------------------------------------------
if [ -n "$git_branch" ]; then
  printf '%s%s%s' "$(fg "$color_yellow")" "$(bg "$color_orange")" "$SEP"
  printf '%s%s %s %s ' "$(fg "$color_fg0")" "$(bg "$color_orange")" "$ICON_BRANCH" "$git_branch"
  prev_bg="$color_orange"
else
  prev_bg="$color_yellow"
fi

# ---------------------------------------------------------------------------
# Segment 3 — model name  (fg0 on aqua)
# ---------------------------------------------------------------------------
printf '%s%s%s' "$(fg "$prev_bg")" "$(bg "$color_aqua")" "$SEP"
printf '%s%s %s %s ' "$(fg "$color_fg0")" "$(bg "$color_aqua")" "$ICON_ROBOT" "$model"

# ---------------------------------------------------------------------------
# Segment 4 — context window: gauge icon + tokens + bar + %  (fg0 on blue)
# Appears only after the first API call
# ---------------------------------------------------------------------------
if [ -n "$used_pct" ]; then
  ICON_CHIP=$(echo "$used_pct" | awk -v e="$GAUGE_EMPTY" -v l="$GAUGE_LOW" -v h="$GAUGE_HIGH" -v f="$GAUGE_FULL" \
    '{if ($1<25) print e; else if ($1<50) print l; else if ($1<75) print h; else print f}')

  filled=$(echo "$used_pct" | awk '{v=int($1/10+0.5); if(v<0)v=0; if(v>10)v=10; print v}')
  empty=$((10 - filled))
  filled_str=""; for ((i=0; i<filled; i++)); do filled_str+="█"; done
  empty_str="";  for ((i=0; i<empty;  i++)); do empty_str+="░"; done

  bar_color=$(echo "$used_pct" | awk -v g="$color_green" -v y="$color_yellow" -v o="$color_orange" -v r="$color_red" \
    '{if ($1<25) print g; else if ($1<50) print y; else if ($1<75) print o; else print r}')

  used_tokens=$(echo "$used_pct $total" | awk '{printf "%.0f", $1*$2/100}')
  used_k=$(echo "$used_tokens" | awk '{if($1>=1000) printf "%.0fk",$1/1000; else printf "%d",$1}')
  ctx_pct=$(printf "%.0f%%" "$used_pct")

  printf '%s%s%s' "$(fg "$color_aqua")" "$(bg "$color_blue")" "$SEP"
  printf '%s%s %s %s ' "$(fg "$color_fg0")" "$(bg "$color_blue")" "$ICON_CHIP" "$used_k"
  printf '%s%s[%s' "$(fg "$bar_color")" "$(bg "$color_blue")" "$filled_str"
  printf '%s%s%s]' "$(fg "$color_bg3")" "$(bg "$color_blue")" "$empty_str"
  printf ' %s%s%s ' "$(fg "$color_fg0")" "$(bg "$color_blue")" "$ctx_pct"

  prev_end_bg="$color_blue"
else
  prev_end_bg="$color_aqua"
fi

# ---------------------------------------------------------------------------
# Segment 5 — claude.ai usage 5h/7d  (fg0 on purple)
# Optional: only shown when ~/.claude/claude-usage.conf is configured
# Format: email  icon  5h:XX% (reset) / 7d:XX% (reset)
# ---------------------------------------------------------------------------
last_bg="$prev_end_bg"
if [ -n "$usage_5h" ]; then
  printf '%s%s%s' "$(fg "$prev_end_bg")" "$(bg "$color_purple")" "$SEP"
  if [ -n "$active_email" ]; then
    printf '%s%s %s %s ' "$(fg "$color_fg0")" "$(bg "$color_purple")" "$active_email" "$ICON_USAGE"
  else
    printf '%s%s %s ' "$(fg "$color_fg0")" "$(bg "$color_purple")" "$ICON_USAGE"
  fi
  printf '%s%s5h:%s%%' "$(fg "$color_fg0")" "$(bg "$color_purple")" "$usage_5h"
  [ -n "$usage_fh_left" ] && printf '%s%s (%s %s)' "$(fg "$color_fg0")" "$(bg "$color_purple")" "$ICON_RESET" "$usage_fh_left"
  printf '%s%s / 7d:%s%%' "$(fg "$color_fg0")" "$(bg "$color_purple")" "$usage_7d"
  [ -n "$usage_wd_left" ] && printf '%s%s (%s %s)' "$(fg "$color_fg0")" "$(bg "$color_purple")" "$ICON_RESET" "$usage_wd_left"
  printf '%s%s ' "$(fg "$color_fg0")" "$(bg "$color_purple")"
  last_bg="$color_purple"
fi

# ---------------------------------------------------------------------------
# Segment 6 — cost + duration  (fg0 on dark — fades to background)
# Appears only after the first API call
# ---------------------------------------------------------------------------
if [ -n "$cost_fmt" ]; then
  printf '%s%s%s' "$(fg "$last_bg")" "$(bg "$color_dark")" "$SEP"
  printf '%s%s %s %s ' "$(fg "$color_fg0")" "$(bg "$color_dark")" "$ICON_COST" "$cost_fmt"
  if [ -n "$duration_fmt" ]; then
    if [ -n "$api_duration_fmt" ]; then
      printf '%s%s%s %s / %s ' "$(fg "$color_fg0")" "$(bg "$color_dark")" "$ICON_CLOCK" "$api_duration_fmt" "$duration_fmt"
    else
      printf '%s%s%s %s ' "$(fg "$color_fg0")" "$(bg "$color_dark")" "$ICON_CLOCK" "$duration_fmt"
    fi
  fi
  last_bg="$color_dark"
fi

printf '%s%s%s' "${reset}$(fg "$last_bg")" "$SEP_ROUND_R" "$reset"

printf '\n'
