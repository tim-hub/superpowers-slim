#!/usr/bin/env bash
# One-time sweep over the four configurations in
# docs/superpowers/specs/2026-08-07-autotrigger-measurement-design.md.
#
# Scaffolding, not a durable tool. measure-autotrigger.sh is the piece worth keeping.
#
# Usage: ./measure-configs.sh [-n RUNS]      (default 15)
#
# MUST run outside a command sandbox: cfg1 ships a SessionStart hook that fails with
# EPERM inside one.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"

RUNS=15
if [ "${1:-}" = "-n" ]; then
    RUNS="$2"
fi

BINDING_MARKER="You MUST use this before any creative work"
NEUTRAL='description: Use when turning an idea, feature request, or vague goal into a design, before writing code'

WT_ROOT="${TMPDIR:-/tmp}/autotrigger-configs-$$"
mkdir -p "$WT_ROOT"

echo "worktrees: $WT_ROOT"
echo "runs per configuration: $RUNS"
echo "measured tree for cfg3/cfg4: $(git -C "$REPO" rev-parse --short HEAD)"
echo ""

git -C "$REPO" worktree add "$WT_ROOT/cfg1-hook-original"   615dc8a >/dev/null
git -C "$REPO" worktree add "$WT_ROOT/cfg2-nohook-original" f49f0d7 >/dev/null
git -C "$REPO" worktree add "$WT_ROOT/cfg3-slim-binding"    HEAD    >/dev/null
git -C "$REPO" worktree add "$WT_ROOT/cfg4-slim-neutral"    HEAD    >/dev/null

# cfg4 is cfg3 with only the description swapped. Nothing else may differ.
SKILL="$WT_ROOT/cfg4-slim-neutral/skills/brainstorming/SKILL.md"
awk -v repl="$NEUTRAL" '!swapped && /^description:/ { print repl; swapped=1; next } { print }' \
    "$SKILL" > "$SKILL.tmp" && mv "$SKILL.tmp" "$SKILL"

if grep -q "$BINDING_MARKER" "$SKILL"; then
    echo "ERROR: cfg4 still carries the binding description" >&2
    exit 1
fi
if ! grep -qF "$NEUTRAL" "$SKILL"; then
    echo "ERROR: cfg4 does not carry the neutral description" >&2
    exit 1
fi

# Guard the premise of the whole matrix: only cfg4's description may differ.
for cfg in cfg1-hook-original cfg2-nohook-original cfg3-slim-binding; do
    if ! grep -q "$BINDING_MARKER" "$WT_ROOT/$cfg/skills/brainstorming/SKILL.md"; then
        echo "ERROR: $cfg does not carry the binding description" >&2
        exit 1
    fi
done

for cfg in cfg1-hook-original cfg2-nohook-original cfg3-slim-binding cfg4-slim-neutral; do
    echo "########## $cfg ##########"
    bash "$SCRIPT_DIR/measure-autotrigger.sh" -n "$RUNS" -p "$WT_ROOT/$cfg" \
        | tee "$WT_ROOT/$cfg.txt"
    status=${PIPESTATUS[0]}
    if [ "$status" -ne 0 ]; then
        echo "ABORTING: $cfg reported a harness failure (exit $status)." >&2
        echo "  Summaries so far are in $WT_ROOT/*.txt" >&2
        exit "$status"
    fi
    echo ""
done

echo "########## summaries ##########"
cat "$WT_ROOT"/*.txt

echo ""
echo "Remove the worktrees when the numbers are recorded:"
for cfg in cfg1-hook-original cfg2-nohook-original cfg3-slim-binding cfg4-slim-neutral; do
    echo "  git -C $REPO worktree remove $WT_ROOT/$cfg --force"
done
