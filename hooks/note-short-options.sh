#!/usr/bin/env bash

# Notes each short-form option a command, or a change to a shell file, newly
# adds, once the call has gone through. It refuses nothing: whether a command
# takes a long form that works on both Linux and macOS is the agent's to judge,
# so no list of them is kept. Commands that take none are left quiet.
#
# It runs after the call rather than before it because every client hands an
# after-call note to the agent, where Pi drops the one an allowed call carries.

set -f
payload="$(cat)"

command -v jq >/dev/null 2>&1 || exit 0

. "$(dirname "$0")/lib/readable-shell-lib.sh"
. "$(dirname "$0")/lib/tool.sh"
. "$(dirname "$0")/lib/say.sh"

settings_from_project "$(hook_field "$payload" cwd)"
rule_holds options || exit 0

notes=""
while IFS= read -r entry; do
  held_entry "$(hook_field "$payload" cwd)" || continue
  [ -n "$added" ] || continue
  found="$(comm -23 \
    <(scan_options "$added" | sort --unique) \
    <(scan_options "$removed" | sort --unique) \
    | sed 's/^option: //' | tr '\n' ',' | sed 's/,$//')"
  [ -n "$found" ] && notes="${notes:+$notes; }${subject} - ${found}"
done < <(tool_entries "$payload")

[ -n "$notes" ] || exit 0

event="$(hook_event_of "$payload")"
printf '%s' "Short-form options added in ${notes}. Where a command takes a long form of an option that works on both Linux and macOS, write that instead. Where it takes none, the short one stands, and where the line's options do not say what it does, call it through a function named for what it does. A command that takes no long forms at all can be left quiet by the user in ${PLUGIN_PREFIX}_COMMANDS_QUIET_ADDED." \
  | hook_say "${event:-PostToolUse}"
exit 0
