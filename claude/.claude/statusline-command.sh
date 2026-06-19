#!/bin/sh
# Claude Code status line — renders the ccstatusline layout:
#   <session-id> | <model> <effort> | <context slider> | <cached> | <branch> <changes>
# To use add this to your ~/.claude/settings.json
#   "statusLine" : {
#     "command" : "sh \/Users\/fred\/flare\/config\/.claude\/statusline-command.sh",
#     "type" : "command"
#   },
input=$(cat)

# --- fields from stdin -------------------------------------------------------
session_id=$(echo "$input" | jq -r '.session_id // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
cached=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Context fill % computed from the REAL window size (e.g. 1M), so the bar never
# assumes a fixed 200k. Falls back to the reported percentage only if the token
# counts or window size are unavailable.
size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
toks=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
if [ -n "$size" ] && [ -n "$toks" ] && [ "$size" -gt 0 ]; then
  used=$(awk -v t="$toks" -v s="$size" 'BEGIN{ p=int(t/s*100+0.5); if(p<0)p=0; if(p>100)p=100; print p }')
else
  used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
  remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
  [ -z "$used" ] && [ -n "$remaining" ] && used=$((100 - remaining))
  [ -z "$used" ] && used=0
fi

# --- ANSI colors (mapping ccstatusline widget colors) ------------------------
reset='\033[0m'
cyan='\033[36m'          # model
gray='\033[90m'          # brightBlack: context bar + separators
brightGreen='\033[92m'   # tokens-cached
magenta='\033[35m'       # git-branch
yellow='\033[33m'        # git-changes

sep="${gray} | ${reset}"

# --- context bar (slider style) ----------------------------------------------
width=10
filled=$(awk -v u="$used" -v w="$width" 'BEGIN{
  f = int(u / 100 * w + 0.5);
  if (f < 0) f = 0; if (f > w - 1) f = w - 1;
  print f
}')
bar=""
i=0
while [ "$i" -lt "$width" ]; do
  if [ "$i" -eq "$filled" ]; then bar="${bar}●"
  elif [ "$i" -lt "$filled" ]; then bar="${bar}━"
  else bar="${bar}─"; fi
  i=$((i + 1))
done

# --- cached tokens (human readable) ------------------------------------------
cached_h=$(awk -v n="$cached" 'BEGIN{
  if (n >= 1000000) { printf "%.1fM", n / 1000000 }
  else if (n >= 1000) { printf "%.1fk", n / 1000 }
  else { printf "%d", n }
}')

# --- git branch + changes ----------------------------------------------------
branch=""
changes=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    sha=$(git -C "$cwd" rev-parse --short=8 HEAD 2>/dev/null)
    [ -n "$sha" ] && branch="$sha"
  fi
  if [ -n "$branch" ]; then
    sums=$( { git -C "$cwd" diff --numstat 2>/dev/null; \
              git -C "$cwd" diff --cached --numstat 2>/dev/null; } \
            | awk '{ if ($1 != "-") a += $1; if ($2 != "-") d += $2 } END { printf "%d %d", a + 0, d + 0 }')
    add=${sums% *}
    del=${sums#* }
    if [ "$add" -gt 0 ] || [ "$del" -gt 0 ]; then
      changes="+${add} -${del}"
    fi
  fi
fi

# --- assemble ----------------------------------------------------------------
sid=$(printf '%s' "$session_id" | cut -c1-8)

out="${sid}"
out="${out}${sep}${cyan}${model}${reset}"
[ -n "$effort" ] && out="${out} ${effort}"
out="${out}${sep}${gray}${bar} ${used}%${reset}"
out="${out}${sep}${brightGreen}cached:${cached_h}${reset}"
if [ -n "$branch" ]; then
  home="$HOME"
  short_cwd=$(echo "$cwd" | sed "s|^$home|~|")
  out="${out}${sep}${gray}${short_cwd}${reset}${magenta}@${branch}${reset}"
  [ -n "$changes" ] && out="${out} ${yellow}${changes}${reset}"
fi

printf "%b\n" "$out"
