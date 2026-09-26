#!/usr/bin/env bash

# Refuses a command, or a change to a shell file, that adds a shortened
# variable name or a short-form option. Only what is newly added counts, so a
# change carrying an old breach past unchanged is not refused for it.
#
# The tool call is read through tool_entries, so it is the same on every
# client: a Claude Edit and a Codex patch both arrive as entries naming a
# file, what was added and what was removed.

set -f
payload="$(cat)"

command -v jq >/dev/null 2>&1 || exit 0

. "$(dirname "$0")/lib/readable-shell-lib.sh"
. "$(dirname "$0")/lib/tool.sh"
. "$(dirname "$0")/lib/permission.sh"

settings_from_project "$(hook_field "$payload" cwd)"

field() { jq --raw-output ".$1" <<< "$entry"; }

refusals=""
while IFS= read -r entry; do
  case "$(field kind)" in
    bash)
      scope_holds commands || continue
      added="$(field command)"
      removed=""
      subject="this command"
      shell="bourne"
      ;;
    write | edit | multi_edit)
      scope_holds files || continue
      file_path="$(field file)"
      added="$(field added)"
      removed="$(field removed)"
      shell="$(shell_of_file "$file_path" "$added")"
      [ -n "$shell" ] || continue
      shell_held_in_files "$shell" || continue
      subject="$file_path"
      ;;
    *) continue ;;
  esac

  [ -n "$added" ] || continue

  offences="$(comm -23 \
    <(scan "$added" "$shell" | sort --unique) \
    <(scan "$removed" "$shell" | sort --unique))"
  [ -n "$offences" ] || continue

  offending_names="$(printf '%s\n' "$offences" | sed -n 's/^name: //p' | tr '\n' ' ' | sed 's/ $//')"
  offending_options="$(printf '%s\n' "$offences" | sed -n 's/^option: //p' | tr '\n' ',' | sed 's/,$//')"

  detail=""
  [ -n "$offending_names" ] && detail="shortened variable name(s): ${offending_names}"
  if [ -n "$offending_options" ]; then
    [ -n "$detail" ] && detail="$detail; "
    detail="${detail}short-form option(s): ${offending_options}"
  fi
  refusals="${refusals:+$refusals; }${subject} - ${detail}"
done < <(tool_entries "$payload")

[ -n "$refusals" ] || exit 0

hook_permission deny "Unreadable shell denied in ${refusals}. Spell every variable name out as the whole word, and write every option in its long form, then retry. There is no escape hatch - do not ask, do not work around this deny. If an option genuinely has no long form on this platform, say which and leave the exception for the user to add to ${PLUGIN_PREFIX}_SHORT_OPTIONS_ALLOWED."
exit 0
