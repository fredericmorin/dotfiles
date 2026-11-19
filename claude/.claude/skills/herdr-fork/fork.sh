#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: fork.sh [-b <branch>] [-B <base-ref>] [-n <name>] [--fresh] [-m <model>] [--effort <level>] [-- prompt...]
       fork.sh --args-stdin <<'EOF'
       [options] [-- prompt...]
       EOF

Fork the current Claude Code session (or start a fresh one with --fresh) in a new
worktree of the session's repo: a new Herdr space made by Herdr's worktree dialog,
so the project's projects.json setup runs before Claude starts.
  -b, --branch  new branch for the worktree (default: the --name, else
                <current-branch>_fork; numbered when taken)
  -B, --base    base ref for the new branch (default: origin's default branch, origin/HEAD)
  -n, --name    tab name and Claude session name
  --fresh       start a new Claude session instead of forking this one's history
  -m, --model   model for the new session (passed as claude --model, e.g. opus)
  --effort      effort level for the new session (passed as claude --effort)
  --background  accepted, no effect: Herdr shows each new worktree space
  -- prompt...  free text sent to the new session as its first message;
                any words that are not options are taken as the prompt too
  --args-stdin  read the whole argument string from stdin instead, so shell
                metacharacters in the prompt reach the session verbatim;
                options before the first standalone `--` are split on
                whitespace, everything after it is the prompt
USAGE
  exit 2
}

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

NAME="" PROMPT="" FRESH="" MODEL="" EFFORT="" BRANCH="" BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -b|--branch) BRANCH="$2"; shift 2 ;;
    -B|--base) BASE="$2"; shift 2 ;;
    -n|--name) NAME="$2"; shift 2 ;;
    --fresh) FRESH=1; shift ;;
    -m|--model) MODEL="$2"; shift 2 ;;
    --effort) EFFORT="$2"; shift 2 ;;
    --background) shift ;;
    -h|--help) usage ;;
    --) shift; PROMPT="$*"; break ;;
    -*) usage ;;
    *) PROMPT="$*"; break ;;
  esac
done

command -v herdr-app >/dev/null 2>&1 || { echo "error: herdr-app not found on PATH" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "error: jq not found on PATH" >&2; exit 1; }
[ -n "${HC_TERMINAL_ID:-}" ] || {
  echo "error: HC_TERMINAL_ID is unset; run this inside a Herdr terminal" >&2
  exit 1
}

SPACE=$(hc get "$HC_TERMINAL_ID" --json | jq -r '.labels["herdr.space"] // empty')
[ -n "$SPACE" ] || {
  echo "error: terminal $HC_TERMINAL_ID has no herdr.space label; is it shown in Herdr?" >&2
  exit 1
}

# The session file records the folder Claude started in: the worktree branches from its checkout.
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SID="" FOLDER=""
if [ -n "${CLAUDE_PID:-}" ] && [ -r "$CFG/sessions/$CLAUDE_PID.json" ]; then
  SID=$(jq -r '.sessionId // empty' "$CFG/sessions/$CLAUDE_PID.json")
  FOLDER=$(jq -r '.cwd // empty' "$CFG/sessions/$CLAUDE_PID.json")
fi
[ -n "$SID" ] || SID="${CLAUDE_CODE_SESSION_ID:-}"
[ -n "$FOLDER" ] || FOLDER="$PWD"
[ -n "$FRESH" ] || [ -n "$SID" ] || {
  echo "error: could not resolve the current Claude session id (run from inside a Claude Code session)" >&2
  exit 1
}

CMD=(claude)
[ -n "$FRESH" ] || CMD+=(--resume "$SID" --fork-session)
[ -z "$MODEL" ] || CMD+=(--model "$MODEL")
[ -z "$EFFORT" ] || CMD+=(--effort "$EFFORT")
[ -z "$NAME" ] || CMD+=(--name "$NAME")
# `--` keeps a prompt that starts with "-" from being read as an option.
[ -z "$PROMPT" ] || CMD+=(-- "$PROMPT")

# The worktree dialog has no base option: make the branch at the base, the dialog checks it out.
cd "$FOLDER"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "error: $FOLDER is not inside a git checkout" >&2
  exit 1
}
if [ -z "$BASE" ]; then
  BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || {
    echo "error: origin's default branch isn't known; run: git -C $REPO_ROOT remote set-head origin --auto (or pass -B)" >&2
    exit 1
  }
fi
BASE_SHA=$(git rev-parse --verify "$BASE^{commit}")
if [ -z "$BRANCH" ]; then
  if [ -n "$NAME" ]; then
    BRANCH="$NAME"
  else
    CUR=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CUR" = "HEAD" ]; then BRANCH="fork_$(date +%Y%m%d_%H%M%S)"; else BRANCH="${CUR}_fork"; fi
  fi
  CANDIDATE="$BRANCH" N=2
  while git show-ref --verify --quiet "refs/heads/$CANDIDATE"; do
    CANDIDATE="${BRANCH}${N}"; N=$((N + 1))
  done
  BRANCH="$CANDIDATE"
fi
git check-ref-format --branch "$BRANCH" >/dev/null 2>&1 || { echo "error: '$BRANCH' is not a valid branch name; pass -b <branch>" >&2; exit 1; }
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "error: branch $BRANCH already exists" >&2
  exit 1
fi
git branch --no-track "$BRANCH" "$BASE_SHA" >/dev/null

# herdr-app do can't pass props to a dialog: the worktree-request mod opens my-worktree with these.
REQUEST="$HOME/.cache/herdr/worktree-request.json"
mkdir -p "$(dirname "$REQUEST")"
jq -n --arg space "$SPACE" --arg folder "$REPO_ROOT" --arg branch "$BRANCH" --arg name "$NAME" \
  --argjson argv "$(printf '%s\0' "${CMD[@]}" | jq -Rs 'split("\u0000")[:-1]')" \
  '{created: (now * 1000 | floor), space: $space, folder: $folder, branch: $branch, argv: $argv}
   + (if $name != "" then {tab: $name} else {} end)' > "$REQUEST"
herdr-app do mod.open --name worktree-request >/dev/null

worktree_of() {
  git worktree list --porcelain | awk -v ref="branch refs/heads/$1" '
    /^worktree / { path = substr($0, 10) }
    $0 == ref { print path; exit }'
}
# git worktree add can take a while on a big repo; the dialog shows any error.
WT_PATH=""
for _ in $(seq 300); do
  WT_PATH=$(worktree_of "$BRANCH")
  [ -z "$WT_PATH" ] || break
  sleep 1
done
[ -n "$WT_PATH" ] || {
  echo "error: no checkout of $BRANCH appeared; see Herdr's worktree dialog (branch $BRANCH is left at $BASE_SHA)" >&2
  exit 1
}

if [ -n "$FRESH" ]; then
  echo "session:        fresh"
else
  echo "forked session: $SID"
fi
echo "branch:         $BRANCH (from $BASE, $BASE_SHA)"
echo "worktree:       $WT_PATH (a new space, under the repo's space)"
echo "command:        $(printf '%q ' "${CMD[@]}")"
