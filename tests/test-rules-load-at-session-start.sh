#!/usr/bin/env bash

. "$(dirname "$0")/built.sh"

REPOSITORY="$(cd "$(dirname "$0")/.." && pwd)"
LOADER="$BUILT_HOOKS/load-rules.sh"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH" ${BUILT_ROOT:+"$BUILT_ROOT"}' EXIT

PERSON="$SCRATCH/person"
mkdir -p "$PERSON"

pass=0
fail=0

assert() {
  local label="$1" outcome="$2" detail="$3"
  if [ "$outcome" = "0" ]; then
    printf "  PASS  %s\n" "$label"
    pass=$((pass + 1))
  else
    printf "  FAIL  %s - %s\n" "$label" "$detail"
    fail=$((fail + 1))
  fi
}

# What a session in the project named is given, with any settings after it.
given_in() {
  local project="$1"
  shift
  (
    for key in $(env | sed -n 's/^\(READABLE_SHELL_[A-Z_]*\)=.*/\1/p'); do unset "$key"; done
    jq --null-input --compact-output --arg cwd "$project" \
      '{hook_event_name:"SessionStart",session_id:"test-load",cwd:$cwd}' \
      | env HOME="$PERSON" READABLE_SHELL_PLAIN=1 READABLE_SHELL_SCOPE=both "$@" bash "$LOADER" 2>/dev/null
  )
}

holds() { printf '%s' "$1" | grep --quiet --fixed-strings "$2"; }

with_shell="$SCRATCH/with-shell"
without_shell="$SCRATCH/without-shell"
unnamed_shell="$SCRATCH/unnamed-shell"
mkdir -p "$with_shell/scripts" "$without_shell/source" "$unnamed_shell/bin"
printf 'value=1\n' > "$with_shell/scripts/run.ksh"
printf 'export const value = 1;\n' > "$without_shell/source/index.ts"
printf '#!/bin/sh\nvalue=1\n' > "$unnamed_shell/bin/run"

printf "Test group: the rules reach a session in a project that holds shell\n"

printed="$(given_in "$with_shell")"
holds "$printed" "## Long-form options"
assert "the option rule is printed" "$?" "it is not"
holds "$printed" "## Whole-word variable names"
assert "and the name rule" "$?" "it is not"
holds "$printed" "to shell written into a file and to a one-off command alike"
assert "and both say what they apply to" "$?" "they do not"
holds "$printed" "{held-to}"
[ "$?" = "1" ]
assert "no placeholder reaches a session" "$?" "one did"

holds "$(given_in "$unnamed_shell")" "to shell written into a file and to a one-off command alike"
assert "a file with no extension is found by its opening line" "$?" "the project read as holding no shell"

printf "\nTest group: a project with no shell is told about commands alone\n"

printed="$(given_in "$without_shell")"
holds "$printed" "It applies to a one-off command you run"
assert "the rules say they apply to commands" "$?" "they say otherwise"
holds "$printed" "written into a file and"
[ "$?" = "1" ]
assert "and not to files it does not have" "$?" "a session pays for a rule it cannot break"

[ -z "$(given_in "$without_shell" READABLE_SHELL_SCOPE=files)" ]
assert "held to files alone, it prints nothing at all" "$?" "it printed rules nothing will enforce"

printf "\nTest group: what is printed follows the settings\n"

printed="$(given_in "$with_shell" READABLE_SHELL_RULES=options)"
holds "$printed" "## Whole-word variable names"
[ "$?" = "1" ]
assert "options alone drops the name rule" "$?" "it printed it"
holds "$printed" "## Long-form options"
assert "and keeps the option rule" "$?" "it dropped it"

printed="$(given_in "$with_shell" READABLE_SHELL_RULES=names)"
holds "$printed" "## Long-form options"
[ "$?" = "1" ]
assert "names alone drops the option rule" "$?" "it printed it"

printed="$(given_in "$with_shell" READABLE_SHELL_SCOPE=commands)"
holds "$printed" "It applies to a one-off command you run"
assert "commands alone says so" "$?" "it says otherwise"

printed="$(given_in "$with_shell" READABLE_SHELL_SCOPE=files)"
holds "$printed" "a one-off command is not held to it"
assert "files alone says so" "$?" "it says otherwise"

printed="$(given_in "$without_shell" READABLE_SHELL_SHELLS=bourne)"
holds "$printed" "to shell written into a file and to a one-off command alike"
assert "a shell named outright is printed whether or not the project holds it" "$?" "it was not"

printf "\nTest group: a session with no project named is given every rule\n"

bare="$(printf '{}' | env HOME="$PERSON" READABLE_SHELL_PLAIN=1 READABLE_SHELL_SCOPE=both bash "$LOADER" 2>/dev/null)"
holds "$bare" "to shell written into a file and to a one-off command alike"
assert "a hand run prints the rules for every known shell" "$?" "it printed '$bare'"

printf "\nTest group: what a session gets is not what a contributor reads\n"

holds "$printed" "Working in this repository"
[ "$?" = "1" ]
assert "the loader does not print AGENTS.md" "$?" "a session is paying for it"
grep --quiet --fixed-strings 'rules/' "$REPOSITORY/AGENTS.md"
assert "and AGENTS.md says where the printed rules live" "$?" "it does not"

printf "\nTest group: how a shell file is laid out reaches a project that holds shell files\n"

for heading in "## Named functions" "## Named constants" "## Early exits"; do
  holds "$(given_in "$with_shell")" "$heading"
  assert "$heading is printed for a project with shell files" "$?" "it is not"

  holds "$(given_in "$with_shell" READABLE_SHELL_SCOPE=commands)" "$heading"
  [ "$?" = "1" ]
  assert "and not when only commands are held, which have no layout" "$?" "it was printed"
done

printf "\nTest group: by default the rules are about files alone\n"

by_default() {
  (
    for key in $(env | sed -n 's/^\(READABLE_SHELL_[A-Z_]*\)=.*/\1/p'); do unset "$key"; done
    jq --null-input --compact-output --arg cwd "$1" '{hook_event_name:"SessionStart",cwd:$cwd}' \
      | env HOME="$PERSON" READABLE_SHELL_PLAIN=1 bash "$LOADER" 2>/dev/null
  )
}

holds "$(by_default "$with_shell")" "a one-off command is not held to it"
assert "a project with shell is told the rules cover its files and not its commands" "$?" "they say otherwise"

[ -z "$(by_default "$without_shell")" ]
assert "a project with no shell is told nothing" "$?" "it pays for rules nothing enforces"

printf "\n%d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
