#!/usr/bin/env bash

# Refuses a command, or an edit to a shell file, that adds a shortened
# variable name or a short-form option. Only what is newly added counts, so an
# edit carrying an old breach past unchanged is not refused for it.

set -f
payload="$(cat)"

command -v jq >/dev/null 2>&1 || exit 0

. "$(dirname "$0")/lib/readable-shell-lib.sh"

settings_from_project "$(hook_field "$payload" cwd)"

input_field() { printf '%s' "$payload" | jq --raw-output "$1 // empty"; }

case "$(hook_field "$payload" tool_name)" in
  Bash)
    scope_holds commands || exit 0
    added="$(input_field .tool_input.command)"
    removed=""
    subject="this command"
    shell="bourne"
    ;;
  Edit | Write | MultiEdit)
    scope_holds files || exit 0
    file_path="$(input_field .tool_input.file_path)"
    added="$(input_field '.tool_input.new_string // .tool_input.content // ([.tool_input.edits[]?.new_string] | join("\n"))')"
    removed="$(input_field '.tool_input.old_string // ([.tool_input.edits[]?.old_string] | join("\n"))')"
    shell="$(shell_of_file "$file_path" "$added")"
    [ -n "$shell" ] || exit 0
    shell_held_in_files "$shell" || exit 0
    subject="$file_path"
    ;;
  *) exit 0 ;;
esac

[ -n "$added" ] || exit 0

offences="$(comm -23 \
  <(scan "$added" "$shell" | sort --unique) \
  <(scan "$removed" "$shell" | sort --unique))"

[ -n "$offences" ] || exit 0

offending_names="$(printf '%s\n' "$offences" | sed -n 's/^name: //p' | tr '\n' ' ' | sed 's/ $//')"
offending_options="$(printf '%s\n' "$offences" | sed -n 's/^option: //p' | tr '\n' ',' | sed 's/,$//')"

detail=""
[ -n "$offending_names" ] && detail="shortened variable name(s): ${offending_names}"
if [ -n "$offending_options" ]; then
  [ -n "$detail" ] && detail="$detail; "
  detail="${detail}short-form option(s): ${offending_options}"
fi

reason="Unreadable shell denied in ${subject} - ${detail}. Spell every variable name out as the whole word, and write every option in its long form, then retry. There is no escape hatch - do not ask, do not work around this deny. If an option genuinely has no long form on this platform, say which and leave the exception for the user to add to ${PLUGIN_PREFIX}_SHORT_OPTIONS_ALLOWED."

jq --null-input --compact-output --arg reason "$reason" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
exit 0
