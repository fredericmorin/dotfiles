#!/bin/sh
# Claude Code status line — renders the ccstatusline layout:
#   <session-id> | <model> <effort> | <context slider> <cache ttl> | <tokens> <cost> | <branch> <changes>
# To use add this to your ~/.claude/settings.json
#   "statusLine" : {
#     "command" : "sh \/Users\/fred\/flare\/config\/.claude\/statusline-command.sh",
#     "type" : "command"
#   },
#
# Runs every few seconds in every session, so it keeps process count low:
# one jq pass parses and formats all stdin fields, shell builtins do the rest.

# --- fields from stdin (single jq pass) --------------------------------------
eval "$(jq -r '
  def eta($t): ($t - (now | floor)) as $d
    | if $t <= 0 or $d <= 0 then ""
      elif $d >= 86400 then "\($d / 86400 | floor)d\(($d % 86400) / 3600 | floor)h"
      elif $d >= 3600 then "\($d / 3600 | floor)h\(($d % 3600) / 60 | floor | tostring | if length < 2 then "0" + . else . end)m"
      else "\(($d / 60 | floor) + (if $d % 60 > 0 then 1 else 0 end))m" end;
  def limit($w): ($w // {}) as $w
    | [($w.used_percentage // -1 | round), ($w.resets_at // 0 | floor)]
    | [.[0], eta(.[1])];

  (.model.display_name // "" | sub(" \\((?<n>[0-9]*[MK]) context\\)"; " \(.n)")) as $m
  | (if (.model.id // "" | contains("[1m]")) and ($m | contains("1M") | not)
     then "\($m) 1M" else $m end) as $model
  | .context_window as $cw
  | (if ($cw.context_window_size // 0) > 0 and $cw.total_input_tokens != null
     then ($cw.total_input_tokens / $cw.context_window_size * 100 + 0.5 | floor
           | if . < 0 then 0 elif . > 100 then 100 else . end)
     else ($cw.used_percentage
           // (if $cw.remaining_percentage != null then 100 - $cw.remaining_percentage else null end)
           // 0) end) as $used
  | ($used / 100 * 10 + 0.5 | floor | if . < 0 then 0 elif . > 9 then 9 else . end) as $f
  | ([range(10) | if . == $f then "●" elif . < $f then "━" else "─" end] | join("")) as $bar
  | limit(.rate_limits.five_hour) as [$h5p, $h5e]
  | limit(.rate_limits.seven_day) as [$d7p, $d7e]
  | @sh "now=\(now | floor)",
    @sh "sid=\(.session_id // "" | .[0:8])",
    @sh "model=\($model)",
    @sh "effort=\(.effort.level // "")",
    @sh "cwd=\(.cwd // "")",
    @sh "transcript=\(.transcript_path // "")",
    @sh "cache_left=\(.prompt_cache.expires_at // null
                       | if . == null then "" else . - now | floor | if . < 0 then 0 else . end end)",
    @sh "project_dir=\(.workspace.project_dir // .cwd // "")",
    @sh "used=\($used)",
    @sh "bar=\($bar)",
    @sh "cost=\(.cost.total_cost_usd // 0 | . * 100 | round
                 | "\(. / 100 | floor).\(. % 100 | tostring | if length < 2 then "0" + . else . end)")",
    @sh "h5_pct=\($h5p)", @sh "h5_eta=\($h5e)",
    @sh "d7_pct=\($d7p)", @sh "d7_eta=\($d7e)"
')"

# Session new tokens: input + cache writes + output over every API call of
# the main transcript and its subagents. Cache reads are left out: they re-count
# the whole context on every call, so they measure context size, not work. Each
# content block is its own transcript line repeating the usage, so dedupe by
# message id. Whole transcripts are read, so the sum is cached next to the
# transcript and only recomputed when it or a subagent transcript is newer.
tokens=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  tok_cache="${transcript%.jsonl}.statusline-tokens"
  stale=""
  if [ ! -f "$tok_cache" ] || [ "$transcript" -nt "$tok_cache" ]; then
    stale=1
  else
    for f in "${transcript%.jsonl}"/subagents/*.jsonl; do
      [ "$f" -nt "$tok_cache" ] && { stale=1; break; }
    done
  fi
  if [ -n "$stale" ]; then
    set -- "$transcript"
    for f in "${transcript%.jsonl}"/subagents/*.jsonl; do
      [ -f "$f" ] && set -- "$@" "$f"
    done
    tokens=$(grep -h '"usage"' "$@" | jq -rn '
      reduce (inputs | select(.type == "assistant" and .message.usage != null)) as $e
        ({}; .[$e.message.id] = $e.message.usage)
      | [.[] | (.input_tokens // 0) + (.output_tokens // 0)
               + (.cache_creation_input_tokens // 0)]
      | add // 0 | . / 1000 | round | "\(.)k"' 2>/dev/null)
    { printf '%s\n' "$tokens" > "$tok_cache"; } 2>/dev/null
  else
    read -r tokens < "$tok_cache"
  fi
fi

# Sandbox state. Neither stdin nor the hook payloads expose it, so read
# sandbox.enabled from the settings chain the way the CLI merges it: managed
# policy first, then local (what /sandbox writes), project, and user.
set --
for f in \
  "/Library/Application Support/ClaudeCode/managed-settings.json" \
  "${project_dir}/.claude/settings.local.json" \
  "${project_dir}/.claude/settings.json" \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
do
  [ -f "$f" ] && set -- "$@" "$f"
done
sandbox_enabled=""
[ $# -gt 0 ] && sandbox_enabled=$(jq -rn '
  first(inputs | .sandbox.enabled | select(. != null) | tostring) // ""' "$@" 2>/dev/null)
[ -n "$CLAUDE_CODE_FORCE_SANDBOX" ] && sandbox_enabled="true"

# --- ANSI colors (mapping ccstatusline widget colors) ------------------------
esc=$(printf '\033')
reset="${esc}[0m"
cyan="${esc}[36m"          # model
gray="${esc}[90m"          # brightBlack: context bar + separators
brightGreen="${esc}[92m"   # session tokens + cost
green="${esc}[32m"         # sandboxed / rate limit ok
blue="${esc}[34m"          # sandbox state: unsandboxed
magenta="${esc}[35m"       # git-branch
yellow="${esc}[33m"        # git-changes
red="${esc}[31m"           # rate limit high

sep="${gray} | ${reset}"

# --- rate limit windows ------------------------------------------------------
# "18% 2h13m" — percentage used of the window, plus time until it resets.
limit_widget() {  # label, pct, eta -> sets $widget
  widget=""
  [ "$2" -lt 0 ] && return
  if [ "$2" -ge 80 ]; then c="$red"
  elif [ "$2" -ge 50 ]; then c="$yellow"
  else c="$green"; fi
  widget="${c}$1:$2%${reset}${3:+ ${gray}$3${reset}}"
}

# --- git branch + changes ----------------------------------------------------
# The worktree diff stats every tracked file, the costliest part of this
# script, so branch and +/- counts are cached per worktree in
# <gitdir>/statusline-cache as "<epoch> <branch> <add> <del>". The cache is
# reused unless one of these changed since it was written:
#   - the session transcript (Claude is active, so it may be editing files)
#   - <gitdir>/index (stage, commit, checkout, rebase)
#   - <gitdir>/HEAD (branch switch)
# or it is older than 30s (catches edits made outside Claude). Idle sessions
# then run no git at all between expiries. The gitdir is read from .git
# directly (a dir in the main checkout, a "gitdir: <path>" file in a
# worktree), falling back to git when cwd is a subdirectory.
# --no-optional-locks: no index rewrite per refresh; no preload: fewer threads.
branch=""
changes=""
gitdir=""
if [ -n "$cwd" ]; then
  if [ -d "$cwd/.git" ]; then
    gitdir="$cwd/.git"
  elif [ -f "$cwd/.git" ]; then
    read -r _ gitdir < "$cwd/.git"
    case "$gitdir" in /*) ;; *) gitdir="$cwd/$gitdir" ;; esac
  else
    gitdir=$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null)
  fi
fi
if [ -n "$gitdir" ]; then
  cache="$gitdir/statusline-cache"
  ts=0
  if [ -f "$cache" ] && [ ! "$transcript" -nt "$cache" ] \
     && [ ! "$gitdir/index" -nt "$cache" ] && [ ! "$gitdir/HEAD" -nt "$cache" ]; then
    read -r ts branch add del < "$cache"
  fi
  if [ $((now - ${ts:-0})) -ge 30 ]; then
    branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null \
      || git --no-optional-locks -C "$cwd" rev-parse --short=8 HEAD 2>/dev/null)
    add=0
    del=0
    if [ -n "$branch" ]; then
      sums=$( { git --no-optional-locks -c core.preloadIndex=false -C "$cwd" diff --numstat 2>/dev/null; \
                git --no-optional-locks -C "$cwd" diff --cached --numstat 2>/dev/null; } \
              | awk '{ if ($1 != "-") a += $1; if ($2 != "-") d += $2 } END { printf "%d %d", a + 0, d + 0 }')
      add=${sums% *}
      del=${sums#* }
      { printf '%s %s %s %s\n' "$now" "$branch" "$add" "$del" > "$cache"; } 2>/dev/null
    fi
  fi
  if [ -n "$branch" ] && { [ "$add" -gt 0 ] || [ "$del" -gt 0 ]; }; then
    changes="+${add} -${del}"
  fi
fi

# --- assemble ----------------------------------------------------------------
out="${sid}"
out="${out}${sep}${cyan}${model}${reset}"
[ -n "$effort" ] && out="${out} ${effort}"
if [ "$sandbox_enabled" = "true" ]; then
  out="${out}${sep}${green}sandboxed${reset}"
else
  out="${out}${sep}${blue}unsandboxed${reset}"
fi
out="${out}${sep}${gray}${bar} ${used}%${reset}"
if [ -n "$cache_left" ]; then
  if [ "$cache_left" -eq 0 ]; then cc="$red"
  elif [ "$cache_left" -lt 60 ]; then cc="$yellow"
  else cc="$green"; fi
  out="${out} ${cc}$((cache_left / 60)):$(( cache_left % 60 / 10 ))$(( cache_left % 10 ))${reset}"
fi
out="${out}${sep}${brightGreen}${tokens:+${tokens} }\$${cost}${reset}"
limit_widget 5h "$h5_pct" "$h5_eta"
[ -n "$widget" ] && out="${out}${sep}${widget}"
limit_widget 7d "$d7_pct" "$d7_eta"
[ -n "$widget" ] && out="${out}${sep}${widget}"
if [ -n "$branch" ]; then
  case "$cwd" in
    "$HOME"*) short_cwd="~${cwd#"$HOME"}" ;;
    *) short_cwd="$cwd" ;;
  esac
  out="${out}${sep}${gray}${short_cwd}${reset}${magenta}@${branch}${reset}"
  [ -n "$changes" ] && out="${out} ${yellow}${changes}${reset}"
fi

printf '%s\n' "$out"
