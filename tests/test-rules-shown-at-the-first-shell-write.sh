#!/usr/bin/env bash

. "$(dirname "$0")/built.sh"

GUARD="$BUILT_HOOKS/guard-shell-readability.sh"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH" ${BUILT_ROOT:+"$BUILT_ROOT"}' EXIT

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

# A tool call in the session named, from a home of its own, with any settings
# after it.
called() {
  local session="$1" tool="$2" input="$3"
  shift 3
  (
    for key in $(env | sed -n 's/^\(READABLE_SHELL_[A-Z_]*\)=.*/\1/p'); do unset "$key"; done
    jq --null-input --compact-output --arg session "$session" --arg tool "$tool" --argjson input "$input" \
      '{session_id:$session,tool_name:$tool,tool_input:$input}' \
      | env HOME="$SCRATCH/person" "$@" bash "$GUARD" 2>/dev/null
  )
}
reason() { jq --raw-output '.hookSpecificOutput.permissionDecisionReason // empty'; }
holds() { printf '%s' "$1" | grep --quiet --fixed-strings "$2"; }

clean_script='{"file_path":"/tmp/probe.sh","content":"encoded=1"}'

printf "Test group: the first shell file a session writes is refused once, with the rules\n"

first="$(called one Write "$clean_script" | reason)"
holds "$first" "This first write is refused so they can be read"
assert "a clean first write is refused" "$?" "it went through and the session never saw the rules"

for heading in "## Long-form options" "## Whole-word variable names" "## Named functions" "## Named constants" "## Early exits"; do
  holds "$first" "$heading"
  assert "the refusal carries $heading" "$?" "it does not"
done

holds "$first" "{held-to}"
[ "$?" = "1" ]
assert "no placeholder reaches a session" "$?" "one did"

[ -z "$(called one Write "$clean_script")" ]
assert "the same write again goes through" "$?" "the rules were shown twice"

[ -n "$(called two Write "$clean_script")" ]
assert "a new session is shown them again" "$?" "it was not"

narrowed="$(called narrowed Write "$clean_script" READABLE_SHELL_RULES='names options' | reason)"
holds "$narrowed" "## Named functions"
[ "$?" = "1" ]
assert "a rule RULES leaves out is not shown" "$?" "Named functions was shown"
holds "$narrowed" "## Whole-word variable names"
assert "and a rule it holds still is" "$?" "Whole-word variable names was not shown"

printf "\nTest group: a breach in the first write is named alongside the rules\n"

breach="$(called three Write '{"file_path":"/tmp/probe.sh","content":"enc=1"}' | reason)"
holds "$breach" "shortened variable name(s): enc"
assert "the refusal names the breach" "$?" "it said '$breach'"

printf "\nTest group: a session that writes no shell is told nothing\n"

[ -z "$(called four Write '{"file_path":"/tmp/notes.md","content":"enc=1"}')" ]
assert "a markdown write goes through" "$?" "it was refused"

[ -z "$(called four Bash '{"command":"git commit -m x"}')" ]
assert "a command goes through, since commands are not held by default" "$?" "it was refused"

printf "\nTest group: commands, when held, are shown the rules that apply to them\n"

command_first="$(called five Bash '{"command":"echo hi"}' READABLE_SHELL_SCOPE=both | reason)"
holds "$command_first" "## Long-form options"
assert "a first command is refused with the option rule" "$?" "it said '$command_first'"

holds "$command_first" "## Named functions"
[ "$?" = "1" ]
assert "and not the layout rules, which a command has none of" "$?" "it carried them"

printf "\n%d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
