#!/usr/bin/env bash

# What both hooks read: which rules hold, against what, and for which shells,
# and the two scans that find shell breaking them.

. "$(dirname "${BASH_SOURCE[0]}")/payload.sh"
. "$(dirname "${BASH_SOURCE[0]}")/settings.sh"

# A shell is known by the family whose assignment syntax it shares. Bourne is
# sh, bash, zsh, ksh, dash, ash and mksh, and it is the only family so far.
known_shells="bourne"

# A file is written in a Bourne shell when its name says so, or when its first
# line runs one.
bourne_file_names='(^|/)([^/]*\.(sh|bash|zsh|ksh|dash|ash|mksh)|\.?(bashrc|bash_profile|bash_login|bash_logout|zshrc|zprofile|zshenv|zlogin|zlogout|profile|kshrc|mkshrc))$'
bourne_opening_line='^#![[:space:]]*[^[:space:]]*/(env[[:space:]]+(-[^[:space:]]+[[:space:]]+)*)?(sh|bash|zsh|ksh|dash|ash|mksh)([[:space:]]|$)'

# Whether RULES holds the rule named: names or options.
rule_holds() {
  case "$(setting_value RULES)" in
    both | "$1") return 0 ;;
  esac
  return 1
}

# Whether SCOPE holds what is named: files or commands.
scope_holds() {
  case "$(setting_value SCOPE)" in
    both | "$1") return 0 ;;
  esac
  return 1
}

# The shells SHELLS names that this plugin knows, or detect.
shells_chosen() {
  local shell chosen=""
  for shell in $(setting_value SHELLS); do
    [ "$shell" = "detect" ] && { printf 'detect'; return 0; }
    case " $known_shells " in
      *" $shell "*) chosen="$chosen $shell" ;;
    esac
  done
  printf '%s' "${chosen# }"
}

# Whether a file written in this shell is held to the rules. A project that
# detects takes every shell it holds, so a file in any known shell is held.
shell_held_in_files() {
  local chosen
  scope_holds files || return 1
  chosen="$(shells_chosen)"
  [ "$chosen" = "detect" ] && chosen="$known_shells"
  case " $chosen " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

# The shell a file is written in, or nothing. The file on disk has the last
# word on its first line; a file not yet written is read from what is going
# into it.
shell_of_file() {
  local path="$1" body="$2" opening
  if printf '%s\n' "$path" | grep --quiet --extended-regexp "$bourne_file_names"; then
    printf 'bourne'
    return 0
  fi
  if [ -f "$path" ]; then
    opening="$(head -n 1 "$path" 2>/dev/null)"
  else
    opening="$(printf '%s\n' "$body" | head -n 1)"
  fi
  if printf '%s\n' "$opening" | grep --quiet --extended-regexp "$bourne_opening_line"; then
    printf 'bourne'
  fi
}

# The shells a project's files are written in, one to a line. Names are read
# first, since they cost nothing; a file with no extension is opened to read
# its first line, up to a few hundred of them.
project_shells() {
  local directory="$1" listed unnamed
  if git -C "$directory" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    listed="$(git -C "$directory" ls-files --cached --others --exclude-standard 2>/dev/null)"
  else
    listed="$(cd "$directory" 2>/dev/null && find . -maxdepth 4 -type f \
      -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null)"
  fi
  if printf '%s\n' "$listed" | grep --quiet --extended-regexp "$bourne_file_names"; then
    printf 'bourne\n'
    return 0
  fi
  while IFS= read -r unnamed; do
    [ -n "$unnamed" ] && [ -f "$directory/$unnamed" ] || continue
    if head -n 1 "$directory/$unnamed" 2>/dev/null \
      | grep --quiet --extended-regexp "$bourne_opening_line"; then
      printf 'bourne\n'
      return 0
    fi
  done < <(printf '%s\n' "$listed" | grep --invert-match --extended-regexp '\.[A-Za-z0-9]+$' | head -n 300)
}

# The shortened names refused, one to a line.
abbreviations() {
  local word allowed
  allowed=" $(setting_value ABBREVIATIONS_ALLOWED) "
  for word in $(setting_value ABBREVIATIONS) $(setting_value ABBREVIATIONS_ADDED); do
    case "$allowed" in
      *" $word "*) continue ;;
    esac
    printf '%s\n' "$word"
  done
}

# Every short option on a command that takes long ones, as `option: command -x`.
# Quoted text is data rather than a command, so it is taken out first.
scan_options() {
  local text="$1" unquoted segment head_word token held_commands allowed_options
  held_commands=" $(setting_value COMMANDS) $(setting_value COMMANDS_ADDED) "
  allowed_options=" $(setting_value SHORT_OPTIONS_ALLOWED) "
  unquoted="$(printf '%s\n' "$text" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")"

  while IFS= read -r segment; do
    [ -n "$segment" ] || continue
    # Unquoted on purpose: the segment is split into its words.
    # shellcheck disable=SC2086
    set -- $segment
    while [ $# -gt 0 ]; do
      case "$1" in
        if | while | until | then | do | done | elif | else | fi | '!' | time | sudo | nohup | exec | command) shift ;;
        *) break ;;
      esac
    done
    [ $# -gt 0 ] || continue
    head_word="${1##*/}"
    case "$held_commands" in
      *" $head_word "*) ;;
      *) continue ;;
    esac
    shift
    for token in "$@"; do
      case "$token" in
        -[A-Za-z] | -[A-Za-z][A-Za-z]*) ;;
        *) continue ;;
      esac
      case "$allowed_options" in
        *" $head_word:$token "*) continue ;;
      esac
      printf 'option: %s %s\n' "$head_word" "$token"
    done
  done <<< "$(printf '%s\n' "$unquoted" | tr '|;&' '\n\n\n')"
}

# Every shortened name assigned, as `name: enc`, in the syntax of the shell named.
scan_names() {
  local text="$1" shell="$2" unquoted
  case "$shell" in
    bourne)
      unquoted="$(printf '%s\n' "$text" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")"
      printf '%s\n' "$unquoted" \
        | grep --only-matching --extended-regexp '(^|[[:space:]]|local[[:space:]]+|export[[:space:]]+|declare[[:space:]]+)[A-Za-z_][A-Za-z0-9_]*=' \
        | grep --only-matching --extended-regexp '[A-Za-z_][A-Za-z0-9_]*=' \
        | tr -d '=' \
        | grep --line-regexp --fixed-strings --file=<(abbreviations) \
        | sed 's/^/name: /'
      ;;
  esac
}

# Every breach in the text, for the rules that hold.
scan() {
  local text="$1" shell="$2"
  [ -n "$text" ] || return 0
  if rule_holds options; then scan_options "$text"; fi
  if rule_holds names; then scan_names "$text" "$shell"; fi
}
