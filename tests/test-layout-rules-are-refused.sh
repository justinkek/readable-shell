#!/usr/bin/env bash

. "$(dirname "$0")/built.sh"

HOOK="$BUILT_HOOKS/guard-shell-readability.sh"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH" ${BUILT_ROOT:+"$BUILT_ROOT"}' EXIT

PERSON="$SCRATCH/person"
PROJECT="$SCRATCH/project"
mkdir -p "$PERSON" "$PROJECT"

# The rules count as shown, so each write is refused for what it breaks alone.
mkdir -p "$PERSON/.readable-shell/state/rules-shown"
: > "$PERSON/.readable-shell/state/rules-shown/unknown"

pass=0
fail=0

guarded() {
  (
    for key in $(env | sed -n 's/^\(READABLE_SHELL_[A-Z_]*\)=.*/\1/p'); do unset "$key"; done
    cd "$PROJECT" && env HOME="$PERSON" "$@" bash "$HOOK" 2>/dev/null
  )
}

run_write() {
  jq --null-input --compact-output --arg path "$1" --arg content "$2" \
    '{tool_name:"Write",tool_input:{file_path:$path,content:$content}}' | guarded
}

run_edit() {
  jq --null-input --compact-output --arg path "$1" --arg old "$2" --arg new "$3" \
    '{tool_name:"Edit",tool_input:{file_path:$path,old_string:$old,new_string:$new}}' | guarded
}

run_bash() {
  jq --null-input --compact-output --arg command "$1" \
    '{tool_name:"Bash",tool_input:{command:$command}}' | guarded READABLE_SHELL_SCOPE=both
}

assert_denies_with() {
  local label="$1" output="$2" expected="$3"
  if printf '%s' "$output" | grep --quiet --fixed-strings '"permissionDecision":"deny"' \
    && printf '%s' "$output" | grep --quiet --fixed-strings -- "$expected"; then
    printf "  PASS  %s\n" "$label"
    pass=$((pass + 1))
  else
    printf "  FAIL  %s - expected a deny naming '%s', got '%s'\n" "$label" "$expected" "$output"
    fail=$((fail + 1))
  fi
}

assert_silent() {
  local label="$1" output="$2"
  if [ -z "$output" ]; then
    printf "  PASS  %s\n" "$label"
    pass=$((pass + 1))
  else
    printf "  FAIL  %s - expected silence, got '%s'\n" "$label" "$output"
    fail=$((fail + 1))
  fi
}

printf "Test group: a pipeline of more than three stages goes in a function\n"

assert_denies_with "four stages at the top of a script" \
  "$(run_write "$SCRATCH/a.sh" 'ls | grep log | sort | tail -1')" \
  'pipeline(s) of more than three stages outside a function: ls | grep log | sort | tail -1'
assert_denies_with "four stages assigned from a substitution, quoted text shown as an ellipsis" \
  "$(run_write "$SCRATCH/a.sh" 'names="$(printf "%s" "$x" | sed "s/a//" | tr "a" "b" | sort)"')" \
  'names=(printf … … | sed … | tr … … | sort)'
assert_silent "three stages" \
  "$(run_write "$SCRATCH/a.sh" 'ls | grep log | sort')"
assert_silent "four stages inside a function" \
  "$(run_write "$SCRATCH/a.sh" 'latest_log() {
  ls | grep log | sort | tail -1
}')"
assert_silent "bars inside quotes" \
  "$(run_write "$SCRATCH/a.sh" 'printf "%s\n" "a | b | c | d"')"
assert_silent "bars between case patterns" \
  "$(run_write "$SCRATCH/a.sh" 'case "$1" in
  start|stop|restart|status) run "$1" ;;
esac')"
assert_silent "or-lists are not stages" \
  "$(run_write "$SCRATCH/a.sh" 'first || second || third || fourth')"
assert_silent "a pipeline inside a substitution is its own pipeline" \
  "$(run_write "$SCRATCH/a.sh" 'value="$(printf x | bash "$(which | head -1)" | head -1)"')"
assert_silent "a here-document is data" \
  "$(run_write "$SCRATCH/a.sh" 'cat <<TEXT
a | b | c | d
TEXT')"
assert_silent "a one-off command has no layout" \
  "$(run_bash 'ls | grep log | sort | tail -1')"

printf "\nTest group: a script or function ends early rather than in an if\n"

assert_denies_with "a script ending in an if with no else" \
  "$(run_write "$SCRATCH/a.sh" 'set -e
if [ -f "$1" ]; then
  first
  second
fi')" \
  'ending in an if with no else: the script'
assert_denies_with "a function ending in an if with no else" \
  "$(run_write "$SCRATCH/a.sh" 'publish() {
  if [ -n "$1" ]; then
    first
    second
  fi
}
publish "$@"')" \
  'ending in an if with no else: publish'
assert_silent "an if with an else" \
  "$(run_write "$SCRATCH/a.sh" 'if [ -f "$1" ]; then
  first
  second
else
  third
fi')"
assert_silent "an early exit" \
  "$(run_write "$SCRATCH/a.sh" '[ -f "$1" ] || exit 0
first
second')"
assert_silent "an if of one statement" \
  "$(run_write "$SCRATCH/a.sh" 'if [ -f "$1" ]; then
  rm "$1"
fi')"
assert_silent "an if with work after it" \
  "$(run_write "$SCRATCH/a.sh" 'if [ -f "$1" ]; then
  first
  second
fi
third')"

printf "\nTest group: an edit is read in the file it lands in\n"

printf 'latest_log() {\n  ls\n}\n' > "$SCRATCH/function.sh"
assert_silent "a pipeline added inside a function the edit does not show" \
  "$(run_edit "$SCRATCH/function.sh" '  ls' '  ls | grep log | sort | tail -1')"

printf 'set -e\nls\n' > "$SCRATCH/top.sh"
assert_denies_with "a pipeline added at the top of a script" \
  "$(run_edit "$SCRATCH/top.sh" 'ls' 'ls | grep log | sort | tail -1')" \
  'pipeline(s) of more than three stages'

printf 'if [ -f x ]; then\n  first\n  second\nfi\n' > "$SCRATCH/carried.sh"
assert_silent "an if already ending the script, edited inside" \
  "$(run_edit "$SCRATCH/carried.sh" '  second' '  second
  third')"

printf '[ -f x ] || exit 0\nfirst\nsecond\n' > "$SCRATCH/exits.sh"
assert_denies_with "an early exit turned into an if" \
  "$(run_edit "$SCRATCH/exits.sh" '[ -f x ] || exit 0
first
second' 'if [ -f x ]; then
  first
  second
fi')" \
  'ending in an if with no else: the script'

printf "\n%d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
