#!/usr/bin/env bash

# Before 0.10.0 settings were `KEY = value` lines, and the lists were changed
# through settings of their own. The migration moves a person's file onto
# settings.json, with those settings turned into items on the lists.

. "$(dirname "$0")/built.sh"

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH" ${BUILT_ROOT:+"$BUILT_ROOT"}' EXIT

pass=0
fail=0

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    printf "  PASS  %s\n" "$label"
    pass=$((pass + 1))
  else
    printf "  FAIL  %s - expected '%s', got '%s'\n" "$label" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

migrated() {
  env READABLE_SHELL_HOME="$SCRATCH/home" \
    bash -c ". \"$BUILT_HOOKS/lib/settings.sh\" && . \"$BUILT_HOOKS/lib/migrations.sh\""
}

held() { jq --compact-output "$1" "$SCRATCH/home/settings.json"; }

printf "Test group: an old settings file is moved onto settings.json\n"

mkdir -p "$SCRATCH/home"
cat > "$SCRATCH/home/settings" <<'OLD'
READABLE_SHELL_SCOPE = both
READABLE_SHELL_ABBREVIATIONS_ADDED = zork
READABLE_SHELL_ABBREVIATIONS_ALLOWED = req res
READABLE_SHELL_COMMANDS_QUIET_ADDED = deploy
OLD
migrated

check "a plain setting comes across as it was" "$(held .SCOPE)" '"both"'
check "words added and allowed become items on the list" "$(held .ABBREVIATIONS)" '{"zork":true,"req":false,"res":false}'
check "and the shipped words are still read" "$(held .ABBREVIATIONS_SHIPPED)" 'null'
check "commands added become items on the skipped list" "$(held .SKIPPED_COMMANDS)" '{"deploy":true}'
check "and the old keys are gone" "$(held '[keys[] | select(test("ADDED|ALLOWED|QUIET"))]')" '[]'

printf "\nTest group: a list set whole keeps meaning what it meant\n"

rm -rf "$SCRATCH/home" && mkdir -p "$SCRATCH/home"
cat > "$SCRATCH/home/settings" <<'OLD'
READABLE_SHELL_ABBREVIATIONS = btn
READABLE_SHELL_COMMANDS_QUIET = ls cd
OLD
migrated

check "a replaced word list leaves out the shipped words" "$(held '[.ABBREVIATIONS, .ABBREVIATIONS_SHIPPED]')" '[{"btn":true},"off"]'
check "and so does a replaced quiet list" "$(held '[.SKIPPED_COMMANDS, .SKIPPED_COMMANDS_SHIPPED]')" '[{"ls":true,"cd":true},"off"]'

printf "\n%d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
