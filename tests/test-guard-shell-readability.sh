#!/usr/bin/env bash

. "$(dirname "$0")/built.sh"

HOOK="$BUILT_HOOKS/guard-shell-readability.sh"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH" ${BUILT_ROOT:+"$BUILT_ROOT"}' EXIT

# Every run reads a home and a project of its own, so no setting on this
# machine reaches a test.
PERSON="$SCRATCH/person"
PROJECT="$SCRATCH/project"
mkdir -p "$PERSON" "$PROJECT"

pass=0
fail=0

# Most groups hold both files and commands to the rules, so each says what it
# checks; the default, files alone, has a group of its own at the end.
guarded() {
  (
    for key in $(env | sed -n 's/^\(READABLE_SHELL_[A-Z_]*\)=.*/\1/p'); do unset "$key"; done
    cd "$PROJECT" && env HOME="$PERSON" READABLE_SHELL_SCOPE=both "$@" bash "$HOOK" 2>/dev/null
  )
}

guarded_by_default() {
  (
    for key in $(env | sed -n 's/^\(READABLE_SHELL_[A-Z_]*\)=.*/\1/p'); do unset "$key"; done
    cd "$PROJECT" && env HOME="$PERSON" "$@" bash "$HOOK" 2>/dev/null
  )
}

run_bash() {
  local command="$1"
  shift
  jq --null-input --compact-output --arg command "$command" \
    '{tool_name:"Bash",tool_input:{command:$command}}' | guarded "$@"
}

run_write() {
  local path="$1" content="$2"
  shift 2
  jq --null-input --compact-output --arg path "$path" --arg content "$content" \
    '{tool_name:"Write",tool_input:{file_path:$path,content:$content}}' | guarded "$@"
}

run_edit() {
  local path="$1" old="$2" new="$3"
  shift 3
  jq --null-input --compact-output --arg path "$path" --arg old "$old" --arg new "$new" \
    '{tool_name:"Edit",tool_input:{file_path:$path,old_string:$old,new_string:$new}}' | guarded "$@"
}

assert_denies() {
  local label="$1" output="$2"
  if printf '%s' "$output" | grep --quiet --fixed-strings '"permissionDecision":"deny"'; then
    printf "  PASS  %s\n" "$label"
    pass=$((pass + 1))
  else
    printf "  FAIL  %s - expected a deny, got '%s'\n" "$label" "$output"
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

printf "Test group: short-form options are denied\n"

assert_denies "clustered option on curl" \
  "$(run_bash 'curl -sS https://example.dev')"
assert_denies "the jq options from the review" \
  "$(run_bash 'jq -rn --arg c "$cursor" @uri')"
assert_denies "single-letter option on git" \
  "$(run_bash 'git commit -m "a message"')"
assert_denies "short option inside a written script" \
  "$(run_write /tmp/probe.sh '#!/usr/bin/env bash
gh pr view -q .url')"

printf "\nTest group: shortened variable names are denied\n"

assert_denies "the assignment from the review" \
  "$(run_write /tmp/probe.sh '#!/usr/bin/env bash
enc=$(printf %s "$cursor")')"
assert_denies "a local declaration" \
  "$(run_write /tmp/probe.sh '#!/usr/bin/env bash
readable() { local cmd=$1; printf "%s" "$cmd"; }')"
assert_denies "an assignment in a one-off command" \
  "$(run_bash 'tmp=/tmp/out')"

printf "\nTest group: shell with no long form must never be denied\n"

assert_silent "wc rejects a long option outright" \
  "$(run_bash 'wc -l /tmp/probe.sh')"
assert_silent "sed rejects a long option outright" \
  "$(run_bash 'sed -n 1p /tmp/probe.sh')"
assert_silent "tr rejects a long option outright" \
  "$(run_bash 'printf a | tr -d a')"
assert_silent "cut rejects a long option outright" \
  "$(run_bash 'cut -c1 /tmp/probe.sh')"
assert_silent "ls rejects a long option outright" \
  "$(run_bash 'ls -la /tmp')"
assert_silent "comm rejects a long option outright" \
  "$(run_bash 'comm -23 /tmp/one /tmp/two')"
assert_silent "basename rejects a long option outright" \
  "$(run_bash 'basename -s .sh /tmp/probe.sh')"
assert_silent "a test operator is not an option" \
  "$(run_write /tmp/probe.sh '#!/usr/bin/env bash
if [ -n "$value" ]; then printf "%s" "$value"; fi')"
assert_silent "a builtin option is not a command option" \
  "$(run_write /tmp/probe.sh '#!/usr/bin/env bash
set -f
export -f readable')"
assert_silent "git -C has no long form" \
  "$(run_bash 'git -C /tmp/repo status')"

printf "\nTest group: readable shell stays silent\n"

assert_silent "long-form options throughout" \
  "$(run_bash 'git commit --message "a message"')"
assert_silent "whole-word variable names" \
  "$(run_write /tmp/probe.sh '#!/usr/bin/env bash
encoded=$(printf %s "$cursor")')"
assert_silent "a short option quoted as data, not run" \
  "$(run_bash 'printf "%s" "curl -sS"')"

printf "\nTest group: out of scope stays silent\n"

assert_silent "a non-shell file" \
  "$(run_write /tmp/probe.ts 'const enc = 1;')"
assert_silent "a markdown file documenting a short option" \
  "$(run_write /tmp/probe.md 'Run `curl -sS` to fetch it.')"
assert_silent "a tool that carries no shell" \
  "$(jq --null-input --compact-output '{tool_name:"Read",tool_input:{file_path:"/tmp/probe.sh"}}' | guarded)"
assert_silent "an edit that removes the offence" \
  "$(run_edit /tmp/probe.sh 'enc=1' 'encoded=1')"
assert_silent "a fish script, whose opening line only holds the letters sh" \
  "$(run_write "$SCRATCH/probe" '#!/usr/bin/env fish
curl -sS https://example.dev')"

printf "\nTest group: only what the edit adds counts\n"

assert_silent "an existing offence carried past unchanged" \
  "$(run_edit /tmp/probe.sh 'jq -nc "{}"
value=1' 'jq -nc "{}"
value=2')"
assert_silent "an existing short name re-indented, not added" \
  "$(run_edit /tmp/probe.sh 'cmd=$1' '  cmd=$1')"
assert_denies "a second offence added beside an existing one" \
  "$(run_edit /tmp/probe.sh 'jq -nc "{}"' 'jq -nc "{}"
git commit -m "a message"')"

printf "\nTest group: every Bourne shell file is held, by name or by opening line\n"

for named in probe.ksh probe.dash probe.mksh probe.ash probe.zsh .bashrc .zshrc .profile; do
  assert_denies "$named is held" "$(run_write "$SCRATCH/$named" 'enc=1')"
done

printf '#!/bin/ksh\n' > "$SCRATCH/unnamed-ksh"
assert_denies "an edit to a file with no extension whose first line runs ksh" \
  "$(run_edit "$SCRATCH/unnamed-ksh" 'value=1' 'enc=1')"
assert_denies "a new file whose first line runs dash" \
  "$(run_write "$SCRATCH/unnamed-dash" '#!/usr/bin/env dash
enc=1')"

printf "\nTest group: the lists are the project's to change\n"

assert_silent "a name taken off the list" \
  "$(run_bash 'ctx=1' READABLE_SHELL_ABBREVIATIONS_ALLOWED='ctx')"
assert_denies "and the rest of the list still holds" \
  "$(run_bash 'enc=1' READABLE_SHELL_ABBREVIATIONS_ALLOWED='ctx')"
assert_denies "a name added to the list" \
  "$(run_bash 'btn=1' READABLE_SHELL_ABBREVIATIONS_ADDED='btn err')"
assert_silent "a list replaced whole" \
  "$(run_bash 'enc=1' READABLE_SHELL_ABBREVIATIONS='btn')"
assert_denies "a command added to the list" \
  "$(run_bash 'terraform plan -out plan.bin' READABLE_SHELL_COMMANDS_ADDED='terraform')"
assert_silent "a command the list does not hold" \
  "$(run_bash 'terraform plan -out plan.bin')"
assert_silent "a short option allowed" \
  "$(run_bash 'git commit -m "a message"' READABLE_SHELL_SHORT_OPTIONS_ALLOWED='git:-m')"

printf "\nTest group: the rules and the scope can each be narrowed\n"

assert_silent "options alone lets a short name through" \
  "$(run_bash 'enc=1' READABLE_SHELL_RULES=options)"
assert_denies "and still refuses a short option" \
  "$(run_bash 'git commit -m "a message"' READABLE_SHELL_RULES=options)"
assert_silent "names alone lets a short option through" \
  "$(run_bash 'git commit -m "a message"' READABLE_SHELL_RULES=names)"
assert_silent "files alone lets a command through" \
  "$(run_bash 'enc=1' READABLE_SHELL_SCOPE=files)"
assert_denies "and still refuses a file" \
  "$(run_write /tmp/probe.sh 'enc=1' READABLE_SHELL_SCOPE=files)"
assert_silent "commands alone lets a file through" \
  "$(run_write /tmp/probe.sh 'enc=1' READABLE_SHELL_SCOPE=commands)"
assert_denies "and still refuses a command" \
  "$(run_bash 'enc=1' READABLE_SHELL_SCOPE=commands)"
assert_silent "a shells list naming none it knows holds no file" \
  "$(run_write /tmp/probe.sh 'enc=1' READABLE_SHELL_SHELLS=fish)"
assert_denies "and one naming bourne holds a Bourne file" \
  "$(run_write /tmp/probe.sh 'enc=1' READABLE_SHELL_SHELLS=bourne)"

printf "\nTest group: a project's own settings are read from where it runs\n"

mkdir -p "$PROJECT/.readable-shell"
printf 'READABLE_SHELL_ABBREVIATIONS_ALLOWED = req res\n' > "$PROJECT/.readable-shell/settings"
assert_silent "a name the project allows" "$(run_bash 'req=1')"
assert_denies "and one it does not" "$(run_bash 'enc=1')"

elsewhere="$SCRATCH/elsewhere"
mkdir -p "$elsewhere"
outside="$(jq --null-input --compact-output --arg cwd "$elsewhere" \
  '{tool_name:"Bash",cwd:$cwd,tool_input:{command:"req=1"}}' | guarded)"
assert_denies "the project the payload names wins over the directory it ran in" "$outside"
rm -rf "$PROJECT/.readable-shell"

printf "\nTest group: the refusal names the setting that would allow an option\n"

refusal="$(run_bash 'git commit -m "a message"')"
printf '%s' "$refusal" | grep --quiet --fixed-strings 'READABLE_SHELL_SHORT_OPTIONS_ALLOWED'
if [ "$?" = "0" ]; then
  printf "  PASS  the refusal names READABLE_SHELL_SHORT_OPTIONS_ALLOWED\n"
  pass=$((pass + 1))
else
  printf "  FAIL  the refusal names READABLE_SHELL_SHORT_OPTIONS_ALLOWED - got '%s'\n" "$refusal"
  fail=$((fail + 1))
fi

printf "\nTest group: a Codex patch is held to the same rules, file by file\n"

run_patch() {
  local patch="$1"
  shift
  jq --null-input --compact-output --arg patch "$patch" \
    '{tool_name:"apply_patch",tool_input:{command:$patch}}' | HOOK="$CODEX_HOOKS/guard-shell-readability.sh" guarded "$@"
}

assert_denies "a shell file added with a shortened name" \
  "$(run_patch $'*** Begin Patch\n*** Add File: bin/run.sh\n+enc=1\n*** End Patch')"
assert_denies "a shell file changed to hold a short option" \
  "$(run_patch $'*** Begin Patch\n*** Update File: bin/run.sh\n@@\n-git commit --message x\n+git commit -m x\n*** End Patch')"
assert_silent "a markdown file in the same patch shape" \
  "$(run_patch $'*** Begin Patch\n*** Add File: notes.md\n+Run `curl -sS` to fetch it.\n*** End Patch')"
assert_silent "an existing short name carried past unchanged" \
  "$(run_patch $'*** Begin Patch\n*** Update File: bin/run.sh\n@@\n-cmd=1\n+  cmd=1\n*** End Patch')"

both="$(run_patch $'*** Begin Patch\n*** Add File: one.sh\n+enc=1\n*** Add File: notes.md\n+tmp=1\n*** Add File: two.bash\n+curl -sS x\n*** End Patch')"
reason="$(printf '%s' "$both" | jq --raw-output '.hookSpecificOutput.permissionDecisionReason')"
case "$reason" in
  *one.sh*two.bash*)
    case "$reason" in
      *notes.md*) printf "  FAIL  a patch touching three files names only the two shell files - it named notes.md\n"; fail=$((fail + 1)) ;;
      *) printf "  PASS  a patch touching three files names only the two shell files\n"; pass=$((pass + 1)) ;;
    esac
    ;;
  *) printf "  FAIL  a patch touching three files names only the two shell files - got '%s'\n" "$reason"; fail=$((fail + 1)) ;;
esac

assert_denies "a Codex command is held as well" \
  "$(jq --null-input --compact-output '{tool_name:"Bash",tool_input:{command:"curl -sS x"}}' \
    | HOOK="$CODEX_HOOKS/guard-shell-readability.sh" guarded)"

printf "\nTest group: by default an agent's commands are left alone, and files are held\n"

assert_silent "a short option in a command" \
  "$(jq --null-input --compact-output '{tool_name:"Bash",tool_input:{command:"git commit -m x"}}' | guarded_by_default)"
assert_silent "a shortened name in a command" \
  "$(jq --null-input --compact-output '{tool_name:"Bash",tool_input:{command:"enc=1"}}' | guarded_by_default)"
assert_denies "a shortened name written into a shell file" \
  "$(jq --null-input --compact-output '{tool_name:"Write",tool_input:{file_path:"/tmp/probe.sh",content:"enc=1"}}' | guarded_by_default)"

printf "\n%d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
