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

# Whether RULES holds the rule named: names, options, functions, constants or
# early-exits. Before 0.6.0 RULES was a choice whose both meant every rule
# there was, so both still means every rule.
rule_holds() {
  local held
  held=" $(setting_value RULES) "
  case "$held" in
    *" both "*) return 0 ;;
    *" $1 "*) return 0 ;;
  esac
  return 1
}

# The layout breaches read on standard input whose rule RULES holds.
layout_held() {
  local line
  while IFS= read -r line; do
    case "$line" in
      "pipeline: "*) rule_holds functions || continue ;;
      "early exit: "*) rule_holds early-exits || continue ;;
    esac
    printf '%s\n' "$line"
  done
}

# Whether SCOPE holds what is named: files or commands.
scope_holds() {
  case "$(setting_value SCOPE)" in
    both | "$1") return 0 ;;
  esac
  return 1
}

# The shells SHELLS names that this plugin knows, or detect for every one.
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

# The rules for the shell named, as a session is told them the first time it
# writes shell the rules hold. A file has a layout as well; a one-off command
# has none, so it is told the option and name rules alone.
rules_text() {
  local shell="$1" for_a_file="$2" rules="$PLUGIN_ROOT/rules" held_to first=1 layout
  if scope_holds files && scope_holds commands; then
    held_to="It applies to shell written into a file and to a one-off command alike."
  elif scope_holds files; then
    held_to="It applies to shell written into a file; a one-off command is not held to it."
  else
    held_to="It applies to a one-off command you run; shell written into a file is not held to it."
  fi
  if rule_holds options && [ -f "$rules/options.md" ]; then
    sed "s|{held-to}|$held_to|" "$rules/options.md"
    first=""
  fi
  if rule_holds names && [ -f "$rules/names-$shell.md" ]; then
    [ -n "$first" ] || printf '\n'
    sed "s|{held-to}|$held_to|" "$rules/names-$shell.md"
    first=""
  fi
  [ -n "$for_a_file" ] || return 0
  for layout in functions constants early-exits; do
    rule_holds "$layout" || continue
    layout="$rules/files-$layout.md"
    [ -f "$layout" ] || continue
    [ -n "$first" ] || printf '\n'
    cat "$layout"
    first=""
  done
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

# Every breach of the two layout rules a pattern can decide, in a whole shell
# file: a pipeline of more than three stages outside a function, as
# `pipeline: <the pipeline>`, and a script or function whose last statement is
# an if of more than one line with no else, as `early exit: <function>`.
# Quoted text, comments and here-documents are data, so they are taken out
# first.
layout_program="$(cat <<'AWK'
function trim(text) { sub(/^[ \t]+/, "", text); sub(/[ \t]+$/, "", text); return text }

# The line with quoted text and comments taken out. A command substitution
# inside double quotes is code again, so the quoting is kept as a stack, and
# it runs across lines, so the stack is kept from one line to the next.
function unquoted(line,    out, position, character, rest) {
  out = ""
  for (position = 1; position <= length(line); position++) {
    character = substr(line, position, 1)
    if (quoting[depth] == "single") {
      if (character == "'") { depth--; out = out "…" }
      continue
    }
    if (quoting[depth] == "escaped") {
      if (character == "\\") { position++; continue }
      if (character == "'") { depth--; out = out "…" }
      continue
    }
    if (quoting[depth] == "double") {
      if (character == "\\") { position++; continue }
      if (character == "\"") { depth--; out = out "…"; continue }
      if (substr(line, position, 2) == "$(") { quoting[++depth] = "code"; parens[depth] = 0; position++; out = out "(" }
      continue
    }
    if (character == "\\") { out = out substr(line, position, 2); position++; continue }
    if (character == "'") { quoting[++depth] = (substr(line, position - 1, 1) == "$") ? "escaped" : "single"; continue }
    if (character == "\"") { quoting[++depth] = "double"; continue }
    if (depth > 0 && character == "(") parens[depth]++
    if (depth > 0 && character == ")") {
      if (parens[depth] == 0) { depth--; out = out ")"; continue }
      parens[depth]--
    }
    if (character == "#" && (position == 1 || substr(line, position - 1, 1) ~ /[ \t;]/)) break
    if (character == "<" && substr(line, position, 2) == "<<" && substr(line, position + 2, 1) != "<") {
      rest = substr(line, position + 2)
      strip_tabs = (substr(rest, 1, 1) == "-")
      sub(/^-/, "", rest)
      sub(/^[ \t]*/, "", rest)
      gsub(/['"\\]/, "", rest)
      match(rest, /^[A-Za-z0-9_]+/)
      if (RSTART > 0) document_end = substr(rest, 1, RLENGTH)
    }
    out = out character
  }
  return out
}

# The most stages in any one pipeline of the text. A pipeline inside
# parentheses is a pipeline of its own, so its bars are counted apart.
function longest_pipeline(text,    position, character, level, group, groups, bars, longest) {
  level = 0
  groups = 1
  group[0] = 1
  bars[1] = 0
  longest = 0
  for (position = 1; position <= length(text); position++) {
    character = substr(text, position, 1)
    if (character == "(") { group[++level] = ++groups; bars[groups] = 0 }
    else if (character == ")" && level > 0) level--
    else if (character == "|" && ++bars[group[level]] > longest) longest = bars[group[level]]
  }
  return longest + 1
}

function begin_frame(name) {
  frames++
  frame_name[frames] = name
  frame_braces[frames] = -1
  frame_blocks[frames] = 0
  frame_last[frames] = ""
  frame_else[frames] = 0
  frame_if_lines[frames] = 0
}

function end_frame() {
  if (frame_last[frames] == "if" && !frame_else[frames] && frame_if_lines[frames] > 1)
    print "early exit: " frame_name[frames]
  frames--
}

function inside_a_function() { return frames > 1 && frame_braces[frames] >= 0 }

# A statement starting at the top of the current function or script.
function statement(kind) {
  if (frame_blocks[frames] != 0) return
  frame_last[frames] = kind
  frame_else[frames] = 0
  frame_if_lines[frames] = 0
  if (kind == "if") opened_an_if = 1
}

function command(text,    word) {
  text = trim(text)
  while (text != "") {
    word = text
    sub(/[ \t].*/, "", word)
    if (word == "then" || word == "do" || word == "!" || word == "time") {
      text = trim(substr(text, length(word) + 1))
      continue
    }
    if (word == "else" || word == "elif") {
      if (frame_blocks[frames] == 1 && frame_last[frames] == "if") frame_else[frames] = 1
      if (word == "elif") return
      text = trim(substr(text, length(word) + 1))
      continue
    }
    break
  }
  if (text == "") return
  if (word == "if") { statement("if"); frame_blocks[frames]++; blocks[++block_depth] = "if"; return }
  if (word == "case") { statement("other"); frame_blocks[frames]++; blocks[++block_depth] = "case"; return }
  if (word == "while" || word == "until" || word == "for" || word == "select") {
    statement("other"); frame_blocks[frames]++; blocks[++block_depth] = "loop"; return
  }
  if (word == "fi" || word == "esac" || word == "done") {
    if (frame_blocks[frames] > 0) frame_blocks[frames]--
    if (block_depth > 0) block_depth--
    return
  }
  if (word == "{") {
    braces++
    if (frames > 1 && frame_braces[frames] < 0) { frame_braces[frames] = braces; return }
    statement("other")
    return
  }
  if (word == "}") {
    if (frames > 1 && frame_braces[frames] == braces) end_frame()
    braces--
    return
  }
  statement("other")
}

function logical_line(line,    piece_text, header, name, pieces, piece_count, piece, stages, stage_count, stage, parts, part_count, part) {
  opened_an_if = 0
  gsub(/[0-9]*>&[0-9-]*|&>|\|&/, " ", line)
  header = line
  if (match(header, /^[ \t]*function[ \t]+[^ \t(){}]+([ \t]*\(\))?|^[ \t]*[A-Za-z_][A-Za-z0-9_:.-]*[ \t]*\(\)/)) {
    name = substr(header, RSTART, RLENGTH)
    sub(/^[ \t]*(function[ \t]+)?/, "", name)
    sub(/[ \t]*\(\)$/, "", name)
    line = substr(line, RSTART + RLENGTH)
    begin_frame(name)
  }
  piece_count = split(line, pieces, /;;|;|&&|\|\||&/)
  for (piece = 1; piece <= piece_count; piece++) {
    # A case pattern's bars separate words, not stages.
    sub(/^[ \t]*case[ \t]+[^ \t]+[ \t]+in[ \t]+\(?[^()]*\)/, "case … in ", pieces[piece])
    if (block_depth > 0 && blocks[block_depth] == "case")
      sub(/^[ \t]*\(?[^()]*\)/, "", pieces[piece])
    stage_count = split(pieces[piece], stages, /\|/)
    for (stage = 1; stage <= stage_count; stage++) {
      part_count = split(stages[stage], parts, /[()`]/)
      for (part = 1; part <= part_count; part++) command(parts[part])
    }
    if (longest_pipeline(pieces[piece]) > 3 && !inside_a_function()) {
      piece_text = trim(pieces[piece])
      gsub(/[ \t]+/, " ", piece_text)
      print "pipeline: " substr(piece_text, 1, 60)
    }
  }
  if (frame_last[frames] == "if" && frame_blocks[frames] > 0 && !opened_an_if) frame_if_lines[frames]++
}

BEGIN { depth = 0; quoting[0] = "code"; frames = 0; begin_frame("the script"); braces = 0; block_depth = 0 }

{
  if (in_document != "") {
    check = $0
    if (in_document_tabs) sub(/^\t+/, "", check)
    if (check == in_document) in_document = ""
    next
  }
  document_end = ""
  cleaned = unquoted($0)
  if (document_end != "") { in_document = document_end; in_document_tabs = strip_tabs }
  pending = pending cleaned
  if (depth > 0) { sub(/\\[ \t]*$/, "", pending); pending = pending " "; next }
  if (pending ~ /(\\|\||&&)[ \t]*$/) { sub(/\\[ \t]*$/, " ", pending); pending = pending " "; next }
  logical_line(pending)
  pending = ""
}

END {
  if (pending != "") logical_line(pending)
  while (frames > 1) frames--
  end_frame()
}
AWK
)"

scan_layout() {
  [ -n "$1" ] || return 0
  printf '%s\n' "$1" | awk "$layout_program"
}

# What a file holds once a change lands: a write is the whole file, and an
# edit is replaced into what the file holds now. A change whose removed text
# the file does not hold, such as a patch's scattered lines, gives nothing.
file_after_change() {
  local kind="$1" path="$2" added="$3" removed="$4" before
  if [ "$kind" = "write" ]; then
    printf '%s' "$added"
    return 0
  fi
  [ "$kind" = "edit" ] && [ -n "$removed" ] && [ -f "$path" ] || return 1
  before="$(cat "$path")"
  case "$before" in
    *"$removed"*) ;;
    *) return 1 ;;
  esac
  printf '%s%s%s' "${before%%"$removed"*}" "$added" "${before#*"$removed"}"
}
