#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: fork.sh [branch] [-B <base-ref>] [-n <session-name>] [-s] [--fresh] [-r <repo>] [-m <model>] [--effort <level>] [--background] [-- prompt...]
       fork.sh --args-stdin <<'EOF'
       [branch] [options] [-- prompt...]
       EOF

Fork the current Claude Code session (or start a fresh one with --fresh) in a new
Supacode worktree.
  branch        new branch name (default: <current-branch>_fork)
  -B, --base    base ref for the new worktree (default: current HEAD)
  -n, --name    display name for the forked Claude session
  -s, --same    fork into a new tab of the current worktree instead of a new
                worktree (no branch or base allowed)
  --fresh       start a new Claude session instead of forking this one's history
  -r, --repo    create the worktree in another Supacode repo, given as a path
                or a folder name from `supacode repo list` (needs --fresh)
  -m, --model   model for the new session (passed as claude --model, e.g. opus)
  --effort      effort level for the new session (passed as claude --effort, e.g. medium)
  --background  create the worktree/tab without stealing focus
  -- prompt...  free text sent to the forked session as its first message;
                any words after the branch are taken as the prompt too
  --args-stdin  read the whole argument string from stdin instead, so shell
                metacharacters in the prompt (> < | ; & = $ ` quotes) reach
                the fork verbatim; options before the first standalone `--`
                are split on whitespace, everything after it is the prompt
USAGE
  exit 2
}

shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

unquote() {
  local s="$1"
  case "$s" in
    \"*\") s="${s#\"}"; s="${s%\"}" ;;
    \'*\') s="${s#\'}"; s="${s%\'}" ;;
  esac
  printf '%s' "$s"
}

if [ "${1:-}" = "--args-stdin" ]; then
  RAW=" $(cat) "
  ARGV=()
  case "$RAW" in
    *[[:space:]]--[[:space:]]*)
      read -r -d "" -a ARGV <<<"${RAW%%[[:space:]]--[[:space:]]*}" || true
      ARGV+=(-- "$(unquote "$(trim "${RAW#*[[:space:]]--[[:space:]]}")")")
      ;;
    *)
      read -r -d "" -a ARGV <<<"$RAW" || true
      ;;
  esac
  set -- ${ARGV[@]+"${ARGV[@]}"}
fi

BRANCH="" BASE="" NAME="" PROMPT="" SAME="" FRESH="" MODEL="" EFFORT="" REPO="" BG=()
while [ $# -gt 0 ]; do
  case "$1" in
    -B|--base) BASE="$2"; shift 2 ;;
    -n|--name) NAME="$2"; shift 2 ;;
    -s|--same) SAME=1; shift ;;
    --fresh) FRESH=1; shift ;;
    -r|--repo) REPO="$2"; shift 2 ;;
    -m|--model) MODEL="$2"; shift 2 ;;
    --effort) EFFORT="$2"; shift 2 ;;
    --background) BG=(--background); shift ;;
    -h|--help) usage ;;
    --) shift; PROMPT="$*"; break ;;
    -*) usage ;;
    *)
      if [ -z "$BRANCH" ] && [ -z "$SAME" ]; then BRANCH="$1"; shift
      else PROMPT="$*"; break
      fi ;;
  esac
done

[ -z "$SAME" ] || [ -z "$BASE$BRANCH" ] || {
  echo "error: --same forks into the current worktree; drop the branch/--base" >&2
  exit 2
}

# claude --resume finds sessions by project dir, so history can't follow into another repo.
[ -z "$REPO" ] || [ -n "$FRESH" ] || {
  echo "error: --repo needs --fresh; a forked session can't resume in another repo" >&2
  exit 2
}
[ -z "$REPO" ] || [ -z "$SAME" ] || {
  echo "error: --repo and --same can't be combined" >&2
  exit 2
}

command -v supacode >/dev/null 2>&1 || {
  echo "error: supacode CLI not found; run this inside a Supacode terminal" >&2
  exit 1
}

if [ -n "$REPO" ]; then
  # --args-stdin skips shell tilde expansion.
  case "$REPO" in "~"|"~/"*) REPO="$HOME${REPO#\~}" ;; esac
  WANT=""
  if [ -d "$REPO" ]; then WANT="$(cd "$REPO" && pwd -P)/"; fi
  REPO_ID="" REPO_PATH="" MATCHES=()
  while IFS= read -r ID; do
    P=$(printf '%b' "${ID//%/\\x}")
    if [ -n "$WANT" ]; then
      [ "$P" = "$WANT" ] && MATCHES+=("$ID")
    else
      B="${P%/}"; B="${B##*/}"
      [ "$B" = "$REPO" ] && MATCHES+=("$ID")
    fi
  done < <(supacode repo list)
  if [ "${#MATCHES[@]}" -eq 0 ]; then
    echo "error: no Supacode repo matches '$REPO'; add it with: supacode repo open <path>" >&2
    exit 1
  fi
  if [ "${#MATCHES[@]}" -gt 1 ]; then
    echo "error: '$REPO' matches several Supacode repos; pass a path instead:" >&2
    for ID in "${MATCHES[@]}"; do printf '  %b\n' "${ID//%/\\x}" >&2; done
    exit 1
  fi
  REPO_ID="${MATCHES[0]}"
  REPO_PATH=$(printf '%b' "${REPO_ID//%/\\x}")
  cd "$REPO_PATH"
else
  [ -n "${SUPACODE_REPO_ID:-}" ] || {
    echo "error: SUPACODE_REPO_ID is unset; run this inside a Supacode terminal" >&2
    exit 1
  }
  REPO_ID="$SUPACODE_REPO_ID"
fi

# The session's cwd is authoritative: SUPACODE_WORKTREE_ID is set when the tab
# opens and goes stale once Supacode moves the session to another worktree.
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  [ -n "${SUPACODE_WORKTREE_ID:-}" ] && cd "$(printf '%b' "${SUPACODE_WORKTREE_ID//%/\\x}")"
  git rev-parse --show-toplevel >/dev/null 2>&1 || {
    echo "error: not inside a git checkout" >&2
    exit 1
  }
fi

CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SID=""
if [ -z "$FRESH" ] && [ -n "${CLAUDE_PID:-}" ] && [ -r "$CFG/sessions/$CLAUDE_PID.json" ]; then
  SID=$(sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p' "$CFG/sessions/$CLAUDE_PID.json" | head -n 1)
fi
[ -n "$FRESH" ] || [ -n "$SID" ] || SID="${CLAUDE_CODE_SESSION_ID:-}"
[ -n "$FRESH" ] || [ -n "$SID" ] || {
  echo "error: could not resolve the current Claude session id (run from inside a Claude Code session)" >&2
  exit 1
}

if [ -n "$SAME" ]; then
  TOP="$(git rev-parse --show-toplevel)/"
  WT_ID=""
  while IFS= read -r ID; do
    if [ "$(printf '%b' "${ID//%/\\x}")" = "$TOP" ]; then WT_ID="$ID"; break; fi
  done < <(supacode worktree list)
  [ -n "$WT_ID" ] || {
    echo "error: no Supacode worktree matches $TOP" >&2
    exit 1
  }
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
  BASE=$(git rev-parse HEAD)
fi

[ -n "$BASE" ] || BASE=$(git rev-parse HEAD)
if [ -z "$BRANCH" ]; then
  CUR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
  if [ "$CUR" = "HEAD" ]; then
    BRANCH="fork_$(date +%Y%m%d_%H%M%S)"
  else
    BRANCH="${CUR}_fork"
  fi
  CANDIDATE="$BRANCH"; N=2
  while git show-ref --verify --quiet "refs/heads/$CANDIDATE"; do
    CANDIDATE="${BRANCH}${N}"; N=$((N + 1))
  done
  BRANCH="$CANDIDATE"
fi

[ -n "$SAME" ] || WT_ID=$(supacode repo worktree-new -r "$REPO_ID" \
  --branch "$BRANCH" --base "$BASE" --no-upstream ${BG[@]+"${BG[@]}"})
[ -n "$WT_ID" ] || {
  echo "error: supacode repo worktree-new returned no worktree id" >&2
  exit 1
}
WT_PATH=$(printf '%b' "${WT_ID//%/\\x}")

if [ -n "$FRESH" ]; then
  CMD="claude"
else
  CMD="claude --resume $SID --fork-session"
fi
[ -z "$MODEL" ] || CMD="$CMD --model $(shq "$MODEL")"
[ -z "$EFFORT" ] || CMD="$CMD --effort $(shq "$EFFORT")"
[ -z "$NAME" ] || CMD="$CMD --name $(shq "$NAME")"
if [ -n "$PROMPT" ]; then
  PROMPT_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/supacode-fork"
  mkdir -p "$PROMPT_DIR"
  PROMPT_FILE="$PROMPT_DIR/${BRANCH//\//_}_$(date +%Y%m%d_%H%M%S).md"
  printf '%s\n' "$PROMPT" > "$PROMPT_FILE"
  CMD="$CMD \"\$(cat $(shq "$PROMPT_FILE"))\""
fi
if [ -n "$FRESH" ]; then
  TITLE="claude${NAME:+: $NAME}"
else
  TITLE="claude fork${NAME:+: $NAME}"
fi

TAB_ID=$(supacode tab new -w "$WT_ID" -i "$CMD" --title "$TITLE" ${BG[@]+"${BG[@]}"})

if [ -n "$FRESH" ]; then
  echo "session:        fresh"
else
  echo "forked session: $SID"
fi
[ -z "$REPO" ] || echo "repo:           $REPO_PATH"
echo "worktree:       $WT_PATH"
if [ -n "$SAME" ]; then
  echo "branch:         $BRANCH (same worktree)"
else
  echo "branch:         $BRANCH (base $BASE)"
fi
echo "tab:            $TAB_ID"
echo "command:        $CMD"
[ -z "$PROMPT" ] || echo "prompt file:    $PROMPT_FILE"
