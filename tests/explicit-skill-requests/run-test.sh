#!/usr/bin/env bash
# Test explicit skill requests (user names a skill directly)
# Usage: ./run-test.sh <skill-name> <prompt-file>
#
# Tests whether Claude invokes a skill when the user explicitly requests it by name
# (without using the plugin namespace prefix)
#
# --setting-sources project excludes ~/.claude, so personal skills of the same name are
# not loaded and the plugin's own hooks and CLAUDE.md are the only ones in play. HOME is
# left alone: authentication depends on it and there is nothing to seed.

set -e

SKILL_NAME="$1"
PROMPT_FILE="$2"
# 3 is too low. use-systematic-debugging names no actual bug, so the model spends the
# budget exploring before it can invoke anything: measured, it ends on error_max_turns at
# num_turns 4 with nothing fired. At 8 the skill fired in 3 of 3 runs.
MAX_TURNS="${3:-8}"

if [ -z "$SKILL_NAME" ] || [ -z "$PROMPT_FILE" ]; then
    echo "Usage: $0 <skill-name> <prompt-file> [max-turns]"
    echo "Example: $0 executing-plans ./prompts/executing-plans-please.txt"
    exit 1
fi

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the superpowers plugin root (two levels up)
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TIMESTAMP=$(date +%s)
OUTPUT_DIR="${TMPDIR:-/tmp}/superpowers-tests/${TIMESTAMP}-$$/explicit-skill-requests/${SKILL_NAME}"
mkdir -p "$OUTPUT_DIR"

TIMEOUT_BIN=$(command -v gtimeout || command -v timeout || true)

# Read prompt from file
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Explicit Skill Request Test ==="
echo "Skill: $SKILL_NAME"
echo "Prompt file: $PROMPT_FILE"
echo "Max turns: $MAX_TURNS"
echo "Output dir: $OUTPUT_DIR"
echo ""

# Copy prompt for reference
cp "$PROMPT_FILE" "$OUTPUT_DIR/prompt.txt"

# Create a minimal project directory for the test.
# The agent sees its cwd. Any "superpowers" or skill name in that path cues the skill
# call the test is trying to measure, so the workspace lives outside OUTPUT_DIR.
PROJECT_DIR="${TMPDIR:-/tmp}/ws-${TIMESTAMP}-$$"
mkdir -p "$PROJECT_DIR/docs/superpowers/plans"

# Create a dummy plan file for mid-conversation tests
cat > "$PROJECT_DIR/docs/superpowers/plans/auth-system.md" << 'EOF'
# Auth System Implementation Plan

## Task 1: Add User Model
Create user model with email and password fields.

## Task 2: Add Auth Routes
Create login and register endpoints.

## Task 3: Add JWT Middleware
Protect routes with JWT validation.
EOF

# Run Claude with isolated environment
LOG_FILE="$OUTPUT_DIR/claude-output.json"
cd "$PROJECT_DIR"

echo "Plugin dir: $PLUGIN_DIR"
echo "Running claude -p with explicit skill request..."
echo "Prompt: $PROMPT"
echo ""

${TIMEOUT_BIN:+$TIMEOUT_BIN 300} claude -p "$PROMPT" \
    --plugin-dir "$PLUGIN_DIR" \
    --setting-sources project \
    --dangerously-skip-permissions \
    --max-turns "$MAX_TURNS" \
    --output-format stream-json \
    --verbose \
    > "$LOG_FILE" 2>&1 || true

echo ""
echo "=== Results ==="

if grep -q '"subtype":"error_max_turns"' "$LOG_FILE"; then
    echo "NOTE: run ended on error_max_turns at --max-turns $MAX_TURNS."
    echo "      A FAIL below may be a turn-budget artifact, not behavior."
fi

# If a bare skill name is registered, --setting-sources project did not take and the
# measurement is meaningless. Note the leading quote: "superpowers:brainstorming" has a
# colon before the name and does not match this pattern.
if grep -m1 '"subtype":"init"' "$LOG_FILE" | grep -q "\"${SKILL_NAME}\""; then
    echo "HARNESS ERROR: bare '${SKILL_NAME}' is registered — personal skills are in play." >&2
    echo "  --setting-sources project did not take effect. Aborting." >&2
    exit 2
fi

# Only a superpowers:-prefixed invocation counts. An unprefixed match would be a
# personal ~/.claude/skills copy of the same name answering instead of this plugin.
SKILL_PATTERN='"skill":"superpowers:'"${SKILL_NAME}"'"'
if grep -q '"name":"Skill"' "$LOG_FILE" && grep -qE "$SKILL_PATTERN" "$LOG_FILE"; then
    echo "PASS: Skill '$SKILL_NAME' was triggered"
    TRIGGERED=true
else
    echo "FAIL: Skill '$SKILL_NAME' was NOT triggered"
    TRIGGERED=false
fi

# Show what skills WERE triggered
echo ""
echo "Skills triggered in this run:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"

# Check if Claude took action BEFORE invoking the skill (the failure mode)
echo ""
echo "Checking for premature action..."

# Look for tool invocations before the Skill invocation
# This detects the failure mode where Claude starts doing work without loading the skill
FIRST_SKILL_LINE=$(grep -n '"name":"Skill"' "$LOG_FILE" | head -1 | cut -d: -f1)
if [ -n "$FIRST_SKILL_LINE" ]; then
    # Check if any non-Skill, non-system tools were invoked before the first Skill invocation
    # Filter out task tracking tools (planning is ok) and other non-action tools
    PREMATURE_TOOLS=$(head -n "$FIRST_SKILL_LINE" "$LOG_FILE" | \
        grep '"type":"tool_use"' | \
        grep -v '"name":"Skill"' | \
        grep -vE '"name":"(TodoWrite|TaskCreate|TaskUpdate|TaskList|TaskGet)"' || true)
    if [ -n "$PREMATURE_TOOLS" ]; then
        echo "WARNING: Tools invoked BEFORE Skill tool:"
        echo "$PREMATURE_TOOLS" | head -5
        echo ""
        echo "This indicates Claude started working before loading the requested skill."
    else
        echo "OK: No premature tool invocations detected"
    fi
else
    echo "WARNING: No Skill invocation found at all"
fi

# Show first assistant message
echo ""
echo "First assistant response (truncated):"
grep '"type":"assistant"' "$LOG_FILE" | head -1 | jq -r '.message.content[0].text // .message.content' 2>/dev/null | head -c 500 || echo "  (could not extract)"

echo ""
echo "Full log: $LOG_FILE"
echo "Timestamp: $TIMESTAMP"

if [ "$TRIGGERED" = "true" ]; then
    exit 0
else
    exit 1
fi
