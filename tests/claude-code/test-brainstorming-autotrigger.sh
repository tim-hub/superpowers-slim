#!/usr/bin/env bash
# Upstream's harness acceptance test, made executable.
# Sends exactly "Let's make a react todo list" and asserts brainstorming
# auto-triggers before any file is written.
#
# Usage: ./test-brainstorming-autotrigger.sh [plugin-dir]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${1:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

PROMPT="Let's make a react todo list"
TIMESTAMP=$(date +%s)
OUTPUT_DIR="${TMPDIR:-/tmp}/superpowers-tests/${TIMESTAMP}/autotrigger"
PROJECT_DIR="$OUTPUT_DIR/project"
LOG_FILE="$OUTPUT_DIR/claude-output.json"
mkdir -p "$PROJECT_DIR"

echo "=== Brainstorming Auto-Trigger Test ==="
echo "Plugin dir: $PLUGIN_DIR"
echo "Prompt: $PROMPT"
echo ""

cd "$PROJECT_DIR"
timeout 300 claude -p "$PROMPT" \
    --plugin-dir "$PLUGIN_DIR" \
    --dangerously-skip-permissions \
    --max-turns 3 \
    --output-format stream-json \
    --verbose \
    > "$LOG_FILE" 2>&1 || true

echo "=== Results ==="
echo "Skills triggered:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"
echo ""

TRIGGERED=false
if grep -qE '"skill":"([^"]*:)?brainstorming"' "$LOG_FILE"; then
    echo "PASS: brainstorming was triggered"
    TRIGGERED=true
else
    echo "FAIL: brainstorming was NOT triggered"
fi

# The failure mode that matters: writing code before designing.
echo ""
echo "Checking for file mutation before the Skill call..."
FIRST_SKILL_LINE=$(grep -n '"name":"Skill"' "$LOG_FILE" | head -1 | cut -d: -f1)
if [ -n "$FIRST_SKILL_LINE" ]; then
    PREMATURE=$(head -n "$FIRST_SKILL_LINE" "$LOG_FILE" \
        | grep '"type":"tool_use"' \
        | grep -E '"name":"(Write|Edit|NotebookEdit)"' || true)
    if [ -n "$PREMATURE" ]; then
        echo "FAIL: files were written before any skill was invoked:"
        echo "$PREMATURE" | head -5
        TRIGGERED=false
    else
        echo "OK: no file mutation before the Skill call"
    fi
else
    echo "FAIL: no Skill invocation found at all"
    PREMATURE=$(grep '"type":"tool_use"' "$LOG_FILE" \
        | grep -E '"name":"(Write|Edit|NotebookEdit)"' || true)
    [ -n "$PREMATURE" ] && echo "  and files were written:" && echo "$PREMATURE" | head -5
    TRIGGERED=false
fi

echo ""
echo "Full log: $LOG_FILE"
[ "$TRIGGERED" = "true" ] && exit 0 || exit 1
