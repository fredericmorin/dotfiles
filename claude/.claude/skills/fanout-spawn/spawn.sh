#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: spawn.sh <plan.md> [--step N] [--only 1,3] [-B <base-ref>] [--fork] [--background] [--dry-run]

Spawn one Supacode worktree + Claude session per sidecar prompt of one step of a fan-out plan.
  plan.md       the plan file; sidecars are <plan-stem>_step<N>.md (single unit)
                or <plan-stem>_step<N>_part<M>.md (one part of a parallel group) next to it
  --step        step number to spawn (default: the lowest step with a sidecar whose branch
                does not exist yet); steps are sequential, so spawn one step at a time
  --only        comma-separated part numbers within that step (default: all parts)
  -B, --base    base ref for the worktrees (default: current HEAD; for step > 1 pass the
                ref that already contains the previous step, e.g. origin/master)
  --fork        fork the current Claude session into each worktree instead of a fresh one
  --background  create worktrees/tabs without stealing focus
  --dry-run     print what would be spawned and exit
USAGE
  exit 2
}

PLAN="" STEP="" ONLY="" BASE="" FORK=0 DRY=0 BG=()
while [ $# -gt 0 ]; do
  case "$1" in
    --step) STEP="$2"; shift 2 ;;
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
step_of() { basename "$1" .md | sed -n 's/.*_step\([0-9][0-9]*\)\(_part[0-9][0-9]*\)*$/\1/p'; }
part_of() { basename "$1" .md | sed -n 's/.*_step[0-9][0-9]*_part\([0-9][0-9]*\)$/\1/p'; }
branch_of() {
  local b
  b=$(sed -n 's/^Branch: *`\([^`]*\)`.*/\1/p' "$1" | head -n 1)
  [ -n "$b" ] || b="${STEM}_step$(step_of "$1")$(part_of "$1" | sed 's/^./_part&/')"
  echo "$b"
}

PLAN_REL=$(rel "$PLAN_ABS")
PROMPT_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fanout-spawn/$STEM"
mkdir -p "$PROMPT_DIR"

SIDECARS=()
while IFS= read -r f; do
  [ -n "$f" ] && [ -n "$(step_of "$f")" ] && SIDECARS+=("$f")
done < <(ls "$PLAN_DIR/${STEM}"_step*.md 2>/dev/null | sort -V)
[ "${#SIDECARS[@]}" -gt 0 ] || { echo "error: no sidecars matching ${STEM}_step<N>[_part<M>].md in $PLAN_DIR" >&2; exit 1; }

if [ -z "$STEP" ]; then
  for SC in "${SIDECARS[@]}"; do
    git show-ref --verify --quiet "refs/heads/$(branch_of "$SC")" && continue
    STEP=$(step_of "$SC"); break
  done
  [ -n "$STEP" ] || { echo "error: every sidecar's branch already exists; pass --step N to respawn one" >&2; exit 1; }
fi

wanted() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

echo "step: $STEP"
printf '%-6s %-6s %-40s %-12s %s\n' STEP PART BRANCH ACTION SIDECAR
FAILED=0 SEEN=0
for SC in "${SIDECARS[@]}"; do
  S=$(step_of "$SC"); P=$(part_of "$SC")
  [ "$S" = "$STEP" ] || continue
  wanted "${P:-1}" || continue
  SEEN=1
  BRANCH=$(branch_of "$SC")
  TITLE=$(sed -n '1s/^# *//p' "$SC")
  if ! grep -q '^## Prompt' "$SC"; then
    printf '%-6s %-6s %-40s %-12s %s\n' "$S" "${P:--}" "$BRANCH" "SKIP" "$SC (no '## Prompt' heading)"
    FAILED=1; continue
  fi
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    printf '%-6s %-6s %-40s %-12s %s\n' "$S" "${P:--}" "$BRANCH" "SKIP" "$SC (branch exists)"
    FAILED=1; continue
  fi

  SC_REL=$(rel "$SC")
  PROMPT_FILE="$PROMPT_DIR/$BRANCH.md"
  {
    echo "You are working one unit of a fan-out plan — step $S${P:+, part $P} — on branch \`$BRANCH\` in its own git worktree."
    echo "Unit: $TITLE"
    if committed "$PLAN_REL" && committed "$SC_REL"; then
      echo "Plan: \`$PLAN_REL\`. This unit's sidecar: \`$SC_REL\`."
    else
      echo "The plan files are not committed on this branch's base, so read them from the source checkout:"
      echo "Plan: \`$PLAN_ABS\`. This unit's sidecar: \`$SC\`."
    fi
    if [ -n "$P" ]; then
      echo "Other parts of step $S run in parallel on their own branches; expect mechanical rebase conflicts in the shared files the plan names."
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
    printf '%-6s %-6s %-40s %-12s %s\n' "$S" "${P:--}" "$BRANCH" "DRY-RUN" "$SC"
    continue
  fi

  if ! WT_ID=$(supacode repo worktree-new -r "$SUPACODE_REPO_ID" \
      --branch "$BRANCH" --base "$BASE_SHA" --no-upstream ${BG[@]+"${BG[@]}"}) || [ -z "$WT_ID" ]; then
    printf '%-6s %-6s %-40s %-12s %s\n' "$S" "${P:--}" "$BRANCH" "FAILED" "worktree-new failed"
    FAILED=1; continue
  fi
  WT_PATH=$(printf '%b' "${WT_ID//%/\\x}")
  if ! TAB_ID=$(supacode tab new -w "$WT_ID" -i "$CMD" --title "claude: $BRANCH" ${BG[@]+"${BG[@]}"}); then
    printf '%-6s %-6s %-40s %-12s %s\n' "$S" "${P:--}" "$BRANCH" "FAILED" "tab new failed in $WT_PATH"
    FAILED=1; continue
  fi
  printf '%-6s %-6s %-40s %-12s %s\n' "$S" "${P:--}" "$BRANCH" "SPAWNED" "$WT_PATH (tab $TAB_ID)"
done
[ "$SEEN" -eq 1 ] || { echo "error: no sidecar for step $STEP${ONLY:+ with parts $ONLY}" >&2; exit 1; }

echo
echo "base: $BASE_SHA${SID:+  (forked from session $SID)}"
echo "prompts: $PROMPT_DIR"
exit $FAILED
