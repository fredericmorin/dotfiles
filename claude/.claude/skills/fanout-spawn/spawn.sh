#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: spawn.sh <plan.md> [--only 1,3] [-B <base-ref>] [--fork] [--background] [--dry-run]

Spawn one Supacode worktree + Claude session per sidecar prompt of a fan-out plan.
  plan.md       the plan file; sidecars are <plan-stem>_group_<N>_*.md next to it
  --only        comma-separated group numbers to spawn (default: all)
  -B, --base    base ref for the worktrees (default: current HEAD)
  --fork        fork the current Claude session into each worktree instead of a fresh one
  --background  create worktrees/tabs without stealing focus
  --dry-run     print what would be spawned and exit
USAGE
  exit 2
}

PLAN="" ONLY="" BASE="" FORK=0 DRY=0 BG=()
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="$2"; shift 2 ;;
    -B|--base) BASE="$2"; shift 2 ;;
    --fork) FORK=1; shift ;;
    --background) BG=(--background); shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) usage ;;
    -*) usage ;;
    *) [ -z "$PLAN" ] || usage; PLAN="$1"; shift ;;
  esac
done
[ -n "$PLAN" ] && [ -f "$PLAN" ] || usage

if [ "$DRY" -eq 0 ]; then
  command -v supacode >/dev/null 2>&1 || {
    echo "error: supacode CLI not found; run this inside a Supacode terminal" >&2
    exit 1
  }
  [ -n "${SUPACODE_REPO_ID:-}" ] || {
    echo "error: SUPACODE_REPO_ID is unset; run this inside a Supacode terminal" >&2
    exit 1
  }
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

PLAN_ABS=$(cd "$(dirname "$PLAN")" && pwd)/$(basename "$PLAN")
PLAN_DIR=$(dirname "$PLAN_ABS")
STEM=$(basename "$PLAN_ABS" .md)
REPO_ROOT=$(git rev-parse --show-toplevel)
[ -n "$BASE" ] || BASE=$(git rev-parse HEAD)
BASE_SHA=$(git rev-parse --verify "$BASE^{commit}")

SID=""
if [ "$FORK" -eq 1 ]; then
  CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  if [ -n "${CLAUDE_PID:-}" ] && [ -r "$CFG/sessions/$CLAUDE_PID.json" ]; then
    SID=$(sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p' "$CFG/sessions/$CLAUDE_PID.json" | head -n 1)
  fi
  [ -n "$SID" ] || SID="${CLAUDE_CODE_SESSION_ID:-}"
  [ -n "$SID" ] || { echo "error: --fork needs a Claude session id (run inside Claude Code)" >&2; exit 1; }
fi

rel() { case "$1" in "$REPO_ROOT"/*) echo "${1#"$REPO_ROOT"/}" ;; *) echo "" ;; esac; }
committed() { [ -n "$1" ] && git cat-file -e "$BASE_SHA:$1" 2>/dev/null; }
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

PLAN_REL=$(rel "$PLAN_ABS")
PROMPT_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fanout-spawn/$STEM"
mkdir -p "$PROMPT_DIR"

SIDECARS=()
for f in "$PLAN_DIR/${STEM}"_group_*.md; do [ -f "$f" ] && SIDECARS+=("$f"); done
[ "${#SIDECARS[@]}" -gt 0 ] || { echo "error: no sidecars matching ${STEM}_group_*.md in $PLAN_DIR" >&2; exit 1; }

wanted() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

printf '%-6s %-40s %-12s %s\n' GROUP BRANCH ACTION SIDECAR
FAILED=0
for SC in "${SIDECARS[@]}"; do
  NAME=$(basename "$SC" .md)
  NUM=$(printf '%s' "$NAME" | sed -n 's/.*_group_\([0-9][0-9]*\).*/\1/p')
  wanted "$NUM" || continue
  BRANCH=$(sed -n 's/^Branch: *`\([^`]*\)`.*/\1/p' "$SC" | head -n 1)
  [ -n "$BRANCH" ] || BRANCH="${STEM}_group_${NUM}"
  TITLE=$(sed -n '1s/^# *//p' "$SC")
  if ! grep -q '^## Prompt' "$SC"; then
    printf '%-6s %-40s %-12s %s\n' "$NUM" "$BRANCH" "SKIP" "$SC (no '## Prompt' heading)"
    FAILED=1; continue
  fi
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    printf '%-6s %-40s %-12s %s\n' "$NUM" "$BRANCH" "SKIP" "$SC (branch exists)"
    FAILED=1; continue
  fi

  SC_REL=$(rel "$SC")
  PROMPT_FILE="$PROMPT_DIR/$BRANCH.md"
  {
    echo "You are working one unit of a fan-out plan, on branch \`$BRANCH\` in its own git worktree."
    echo "Unit: $TITLE"
    if committed "$PLAN_REL" && committed "$SC_REL"; then
      echo "Plan: \`$PLAN_REL\`. This unit's sidecar: \`$SC_REL\`."
    else
      echo "The plan files are not committed on this branch's base, so read them from the source checkout:"
      echo "Plan: \`$PLAN_ABS\`. This unit's sidecar: \`$SC\`."
    fi
    echo
    echo "Follow the prompt below. When the work is done and verified, open the MR with the commit-and-open-mr skill."
    echo
    echo "---"
    echo
    sed -n '/^## Prompt/,$p' "$SC" | sed '1d'
  } > "$PROMPT_FILE"

  if [ "$FORK" -eq 1 ]; then
    CMD="claude --resume $SID --fork-session -n $(shq "$BRANCH") \"\$(cat $(shq "$PROMPT_FILE"))\""
  else
    CMD="claude -n $(shq "$BRANCH") \"\$(cat $(shq "$PROMPT_FILE"))\""
  fi

  if [ "$DRY" -eq 1 ]; then
    printf '%-6s %-40s %-12s %s\n' "$NUM" "$BRANCH" "DRY-RUN" "$SC"
    continue
  fi

  if ! WT_ID=$(supacode repo worktree-new -r "$SUPACODE_REPO_ID" \
      --branch "$BRANCH" --base "$BASE_SHA" --no-upstream ${BG[@]+"${BG[@]}"}) || [ -z "$WT_ID" ]; then
    printf '%-6s %-40s %-12s %s\n' "$NUM" "$BRANCH" "FAILED" "worktree-new failed"
    FAILED=1; continue
  fi
  WT_PATH=$(printf '%b' "${WT_ID//%/\\x}")
  if ! TAB_ID=$(supacode tab new -w "$WT_ID" -i "$CMD" --title "claude: $BRANCH" ${BG[@]+"${BG[@]}"}); then
    printf '%-6s %-40s %-12s %s\n' "$NUM" "$BRANCH" "FAILED" "tab new failed in $WT_PATH"
    FAILED=1; continue
  fi
  printf '%-6s %-40s %-12s %s\n' "$NUM" "$BRANCH" "SPAWNED" "$WT_PATH (tab $TAB_ID)"
done

echo
echo "base: $BASE_SHA${SID:+  (forked from session $SID)}"
echo "prompts: $PROMPT_DIR"
exit $FAILED
