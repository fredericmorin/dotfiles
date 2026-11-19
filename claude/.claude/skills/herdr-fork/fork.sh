#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: fork.sh [-n <name>] [--fresh] [-m <model>] [--effort <level>] [--background] [-- prompt...]
       fork.sh --args-stdin <<'EOF'
       [options] [-- prompt...]
       EOF

Fork the current Claude Code session (or start a fresh one with --fresh) in a new
Herdr tab of the space this session runs in, in the session's folder.
  -n, --name    tab name and Claude session name
  --fresh       start a new Claude session instead of forking this one's history
  -m, --model   model for the new session (passed as claude --model, e.g. opus)
  --effort      effort level for the new session (passed as claude --effort)
  --background  add the tab without switching to it
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

NAME="" PROMPT="" FRESH="" MODEL="" EFFORT="" BG=""
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--name) NAME="$2"; shift 2 ;;
    --fresh) FRESH=1; shift ;;
    -m|--model) MODEL="$2"; shift 2 ;;
    --effort) EFFORT="$2"; shift 2 ;;
    --background) BG=1; shift ;;
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

# The session file records the folder Claude started in; --resume looks sessions up by it.
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

ARGS=$(jq -n --arg space "$SPACE" --arg folder "$FOLDER" --arg name "$NAME" --arg bg "$BG" \
  --argjson argv "$(printf '%s\0' "${CMD[@]}" | jq -Rs 'split("\u0000")[:-1]')" \
  '{space: $space, folder: $folder, argv: $argv}
   + (if $name != "" then {name: $name} else {} end)
   + (if $bg != "" then {focus: false} else {} end)')

OUT=$(herdr-app do tab.new "$ARGS")

if [ -n "$FRESH" ]; then
  echo "session:        fresh"
else
  echo "forked session: $SID"
fi
echo "space:          $SPACE"
echo "folder:         $FOLDER"
echo "tab:            $(printf '%s' "$OUT" | jq -r '.tab // .')"
echo "terminal:       $(printf '%s' "$OUT" | jq -r '.terminal // empty')"
echo "command:        $(printf '%q ' "${CMD[@]}")"
