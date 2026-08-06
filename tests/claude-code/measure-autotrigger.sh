#!/usr/bin/env bash
# Measures how often brainstorming autotriggers on a given tree, over N runs.
#
# This reports a rate. It asserts nothing about whether the skill fired: autotriggering is
# a probabilistic model behavior and one sample cannot gate a repository. Only broken
# plumbing is an error.
#
# Usage: ./measure-autotrigger.sh [-n RUNS] [-t MAX_TURNS] [-p PLUGIN_DIR]
#
# MUST run outside a command sandbox. Inside one, a plugin SessionStart hook fails with
# EPERM under ~/.claude and the injection never reaches the model, so the run measures a
# broken hook while reporting the hook as present.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS=1
MAX_TURNS=8
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

while [ $# -gt 0 ]; do
    case "$1" in
        -n) RUNS="$2"; shift 2 ;;
        -t) MAX_TURNS="$2"; shift 2 ;;
        -p) PLUGIN_DIR="$(cd "$2" && pwd)"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [-n RUNS] [-t MAX_TURNS] [-p PLUGIN_DIR]"
            exit 0
            ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

PROMPT="Let's make a react todo list"
TIMESTAMP=$(date +%s)
OUTPUT_DIR="${TMPDIR:-/tmp}/superpowers-tests/${TIMESTAMP}-$$/autotrigger"
mkdir -p "$OUTPUT_DIR"

TIMEOUT_BIN=$(command -v gtimeout || command -v timeout || true)

# A tree that ships hooks/hooks.json must produce a successful hook, or the run measures a
# broken hook rather than a present one.
HOOK_EXPECTED=false
[ -f "$PLUGIN_DIR/hooks/hooks.json" ] && HOOK_EXPECTED=true

fired=0
premature=0
truncated=0
hook_ok=0
polluted=0

for i in $(seq 1 "$RUNS"); do
    # The agent sees its cwd. Any "superpowers", skill name or "test" in that path cues the
    # skill call this script is trying to measure, so the workspace sits outside OUTPUT_DIR.
    WS="${TMPDIR:-/tmp}/ws-${TIMESTAMP}-$$-${i}"
    mkdir -p "$WS"
    LOG="$OUTPUT_DIR/run-${i}.json"

    ( cd "$WS" && ${TIMEOUT_BIN:+$TIMEOUT_BIN 300} claude -p "$PROMPT" \
        --plugin-dir "$PLUGIN_DIR" \
        --setting-sources project \
        --dangerously-skip-permissions \
        --max-turns "$MAX_TURNS" \
        --output-format stream-json \
        --verbose ) > "$LOG" 2>&1 || true

    if [ ! -s "$LOG" ]; then
        echo "HARNESS ERROR: run $i produced no output at $LOG" >&2
        exit 1
    fi

    # "superpowers:brainstorming" has a colon before the name and does not match this.
    if grep -m1 '"subtype":"init"' "$LOG" | grep -q '"brainstorming"'; then
        polluted=$((polluted + 1))
    fi

    if grep -qE '"skill":"superpowers:brainstorming"' "$LOG"; then
        fired=$((fired + 1))
    fi

    first_skill_line=$(grep -n '"name":"Skill"' "$LOG" | head -1 | cut -d: -f1)
    if [ -n "$first_skill_line" ]; then
        if head -n "$first_skill_line" "$LOG" | grep '"type":"tool_use"' \
            | grep -qE '"name":"(Write|Edit|NotebookEdit)"'; then
            premature=$((premature + 1))
        fi
    elif grep '"type":"tool_use"' "$LOG" | grep -qE '"name":"(Write|Edit|NotebookEdit)"'; then
        premature=$((premature + 1))
    fi

    if grep -q '"subtype":"error_max_turns"' "$LOG"; then
        truncated=$((truncated + 1))
    fi

    if [ "$HOOK_EXPECTED" = true ]; then
        if grep -m1 '"subtype":"hook_response"' "$LOG" | grep -q '"outcome":"success"'; then
            hook_ok=$((hook_ok + 1))
        fi
    fi
done

echo "=== $(basename "$PLUGIN_DIR") ==="
echo "runs:       $RUNS"
echo "fired:      $fired/$RUNS"
echo "premature:  $premature/$RUNS"
echo "truncated:  $truncated/$RUNS"
if [ "$HOOK_EXPECTED" = true ]; then
    echo "hook ok:    $hook_ok/$RUNS"
fi
echo "logs:       $OUTPUT_DIR"

if [ "$polluted" -gt 0 ]; then
    echo "HARNESS ERROR: bare 'brainstorming' registered in $polluted of $RUNS runs." >&2
    echo "  --setting-sources project did not take effect; personal skills are in play." >&2
    exit 1
fi

if [ "$HOOK_EXPECTED" = true ] && [ "$hook_ok" -ne "$RUNS" ]; then
    echo "HARNESS ERROR: the plugin hook succeeded in only $hook_ok of $RUNS runs." >&2
    echo "  A present-but-broken hook measures as 'hook present'. Are you inside a sandbox?" >&2
    exit 1
fi

exit 0
