#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: fork.sh [branch] [-B <base-ref>] [-n <session-name>] [--background]

Fork the current Claude Code session into a new Supacode worktree.
  branch        new branch name (default: <current-branch>_fork)
  -B, --base    base ref for the new worktree (default: current HEAD)
  -n, --name    display name for the forked Claude session
  --background  create the worktree/tab without stealing focus
USAGE
  exit 2
}

shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

BRANCH="" BASE="" NAME="" BG=()
while [ $# -gt 0 ]; do
  case "$1" in
    -B|--base) BASE="$2"; shift 2 ;;
    -n|--name) NAME="$2"; shift 2 ;;
    --background) BG=(--background); shift ;;
    -h|--help) usage ;;
    -*) usage ;;
    *) [ -z "$BRANCH" ] || usage; BRANCH="$1"; shift ;;
  esac
done

command -v supacode >/dev/null 2>&1 || {
  echo "error: supacode CLI not found; run this inside a Supacode terminal" >&2
  exit 1
}
[ -n "${SUPACODE_REPO_ID:-}" ] || {
  echo "error: SUPACODE_REPO_ID is unset; run this inside a Supacode terminal" >&2
  exit 1
}

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
if [ -n "${CLAUDE_PID:-}" ] && [ -r "$CFG/sessions/$CLAUDE_PID.json" ]; then
  SID=$(sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p' "$CFG/sessions/$CLAUDE_PID.json" | head -n 1)
fi
[ -n "$SID" ] || SID="${CLAUDE_CODE_SESSION_ID:-}"
[ -n "$SID" ] || {
  echo "error: could not resolve the current Claude session id (run from inside a Claude Code session)" >&2
  exit 1
}

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

WT_ID=$(supacode repo worktree-new -r "$SUPACODE_REPO_ID" \
  --branch "$BRANCH" --base "$BASE" --no-upstream ${BG[@]+"${BG[@]}"})
[ -n "$WT_ID" ] || {
  echo "error: supacode repo worktree-new returned no worktree id" >&2
  exit 1
}
WT_PATH=$(printf '%b' "${WT_ID//%/\\x}")

CMD="claude --resume $SID --fork-session"
[ -z "$NAME" ] || CMD="$CMD --name $(shq "$NAME")"
TITLE="claude fork${NAME:+: $NAME}"

TAB_ID=$(supacode tab new -w "$WT_ID" -i "$CMD" --title "$TITLE" ${BG[@]+"${BG[@]}"})

echo "forked session: $SID"
echo "worktree:       $WT_PATH"
echo "branch:         $BRANCH (base $BASE)"
echo "tab:            $TAB_ID"
echo "command:        $CMD"
