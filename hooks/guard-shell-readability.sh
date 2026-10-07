#!/usr/bin/env bash

# Refuses a command, or a change to a shell file, that adds a shortened
# variable name or a short-form option. A change to a shell file is also
# refused for a pipeline of more than three stages outside a function, and for
# a script or function that ends in an if with no else. Only what is newly
# added counts, so a change carrying an old breach past unchanged is not
# refused for it.
#
# The tool call is read through tool_entries, so it is the same on every
# client: a Claude Edit and a Codex patch both arrive as entries naming a
# file, what was added and what was removed.
#
# The first time a session writes shell the rules hold, the write is refused
# once with the rules themselves, so a session that never writes shell is
# never told them. Not every rule can be checked, so that first write is
# refused even when it already follows them.

set -f
payload="$(cat)"

command -v jq >/dev/null 2>&1 || exit 0

. "$(dirname "$0")/lib/readable-shell-lib.sh"
. "$(dirname "$0")/lib/tool.sh"
. "$(dirname "$0")/lib/permission.sh"
. "$(dirname "$0")/lib/state.sh"

apply_migrations

settings_from_project "$(hook_field "$payload" cwd)"

field() { jq --raw-output ".$1" <<< "$entry"; }

# The offences of one kind, joined by the separator given.
offences_of() {
  printf '%s\n' "$offences" | sed -n "s/^$1: //p" | tr '\n' "$2" | sed "s/$2\$//"
}

# The layout breaches the change adds to the whole file. The rules are about
# the file, so an edit is read in the file it lands in.
layout_offences() {
  local before after
  after="$(file_after_change "$kind" "$file_path" "$added" "$removed")" || return 0
  before=""
  [ -f "$file_path" ] && before="$(cat "$file_path")"
  comm -23 <(scan_layout "$after" | sort --unique) <(scan_layout "$before" | sort --unique) | layout_held
}

refusals=""
first_shell=""
first_for_a_file=""
while IFS= read -r entry; do
  kind="$(field kind)"
  case "$kind" in
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
      case "$file_path" in
        /*) ;;
        *) file_path="$(hook_field "$payload" cwd)/$file_path" ;;
      esac
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

  if [ -z "$first_shell" ]; then
    first_shell="$shell"
    [ "$subject" = "this command" ] || first_for_a_file=1
  fi

  offences="$(comm -23 \
    <(scan "$added" "$shell" | sort --unique) \
    <(scan "$removed" "$shell" | sort --unique))"
  [ "$subject" = "this command" ] || offences="${offences:+$offences
}$(layout_offences)"
  [ -n "$offences" ] || continue

  detail=""
  for part in \
    "name|shortened variable name(s)| " \
    "option|short-form option(s)|," \
    "pipeline|pipeline(s) of more than three stages outside a function|;" \
    "early exit|ending in an if with no else|,"; do
    found="$(offences_of "${part%%|*}" "${part##*|}")"
    [ -n "$found" ] || continue
    part="${part#*|}"
    detail="${detail:+$detail; }${part%|*}: ${found}"
  done
  refusals="${refusals:+$refusals; }${subject} - ${detail}"
done < <(tool_entries "$payload")

# One mark per session, so the rules are shown once however much shell it writes.
session_id="$(hook_field "$payload" session_id | tr -c 'A-Za-z0-9_-' '_')"
if [ -n "$first_shell" ] && ! plugin_mark_once "rules-shown/${session_id:-unknown}"; then
  shown="$(rules_text "$first_shell" "$first_for_a_file")"
  hook_permission deny "readable-shell holds the shell in this session to the rules below. This first write is refused so they can be read; redo it following them.${refusals:+ It also breaks them in ${refusals}.}

$shown"
  exit 0
fi

[ -n "$refusals" ] || exit 0

hook_permission deny "Unreadable shell denied in ${refusals}. Spell every variable name out as the whole word, write every option in its long form, give a pipeline of more than three stages a function named for what it returns, and end a script or function as soon as a condition rules out the rest rather than nesting the rest inside an if, then retry. There is no escape hatch - do not ask, do not work around this deny. If an option genuinely has no long form on this platform, say which and leave the exception for the user to add to ${PLUGIN_PREFIX}_SHORT_OPTIONS_ALLOWED."
exit 0
