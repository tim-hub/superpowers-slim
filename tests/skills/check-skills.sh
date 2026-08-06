#!/usr/bin/env bash
# Structural gate for the slim skill set. Run from repo root.
set -uo pipefail

SKILLS_DIR="skills"
FAIL=0

fail() { echo "FAIL: $*"; FAIL=1; }

# SKILL.md word ceilings. Raise a ceiling here rather than dropping a step.
budget() {
  case "$1" in
    brainstorming)                  echo 320 ;;
    writing-plans)                  echo 380 ;;
    executing-plans)                echo 200 ;;
    test-driven-development)        echo 270 ;;
    systematic-debugging)           echo 400 ;;
    requesting-code-review)         echo 190 ;;
    receiving-code-review)          echo 330 ;;
    verification-before-completion) echo 230 ;;
    finishing-a-development-branch) echo 470 ;;
    *) echo -1 ;;
  esac
}

DELETED="using-superpowers using-git-worktrees subagent-driven-development dispatching-parallel-agents writing-skills"

EXPECTED=$(printf '%s\n' \
  brainstorming executing-plans finishing-a-development-branch \
  receiving-code-review requesting-code-review systematic-debugging \
  test-driven-development verification-before-completion writing-plans \
  | sort | tr '\n' ' ')
# -not -name '.*' — local tooling leaves untracked dirs like skills/.claude behind,
# and the "$SKILLS_DIR"/*/ glob below already skips them.
ACTUAL=$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -exec basename {} \; \
  | sort | tr '\n' ' ')
[ "$ACTUAL" = "$EXPECTED" ] \
  || fail "skill set mismatch
    expected: $EXPECTED
    actual:   $ACTUAL"

for dir in "$SKILLS_DIR"/*/; do
  name=$(basename "$dir")
  f="${dir}SKILL.md"

  [ -f "$f" ] || { fail "$name: no SKILL.md"; continue; }

  fm=$(awk 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit} inside' "$f")
  keys=$(printf '%s\n' "$fm" | grep -oE '^[a-z_]+:' | tr -d ':' | sort | tr '\n' ' ')
  [ "$keys" = "description name " ] \
    || fail "$name: frontmatter keys are '$keys', expected 'description name '"

  fmlen=$(printf '%s' "$fm" | wc -c | tr -d ' ')
  [ "$fmlen" -le 1024 ] || fail "$name: frontmatter is $fmlen chars, limit 1024"

  grep -qE '^[[:space:]]*@[A-Za-z./]' "$f" \
    && fail "$name: contains an @-link, which force-loads the target"

  for d in $DELETED; do
    if grep -rqF "$d" "$dir"; then
      fail "$name: references deleted skill '$d'"
      grep -rnF "$d" "$dir" | sed 's/^/    /'
    fi
  done

  words=$(wc -w < "$f" | tr -d ' ')
  max=$(budget "$name")
  if [ "$max" -lt 0 ]; then
    fail "$name: no word ceiling defined"
  elif [ "$words" -gt "$max" ]; then
    fail "$name: SKILL.md is $words words, ceiling $max"
  fi
done

[ "$FAIL" -eq 0 ] \
  && echo "PASS: 9 skills, valid frontmatter, no @-links, no dangling references, all within ceiling"
exit "$FAIL"
