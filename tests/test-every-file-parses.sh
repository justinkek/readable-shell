#!/usr/bin/env bash

# A hook that does not parse exits clean having checked nothing, so every hook
# and library file an install copies is parsed by /bin/bash, which is 3.2 on a
# Mac. A here-document inside a command substitution is refused outright: bash
# 3.2 scans it for backquotes as code, and a newer bash parses it without
# complaint, so a run on Linux would never see it fail.

. "$(dirname "$0")/built.sh"

pass=0
fail=0

report() {
  local label="$1" found="$2"
  if [ -z "$found" ]; then
    printf "  PASS  %s\n" "$label"
    pass=$((pass + 1))
  else
    printf "  FAIL  %s\n%s\n" "$label" "$found"
    fail=$((fail + 1))
  fi
}

files() { find "$BUILT_HOOKS" "$(dirname "$0")/../hooks" -name '*.sh' -type f | sort; }

printf "Test group: every hook and library file parses\n"

unparsed=""
while IFS= read -r file; do
  said="$(/bin/bash -n "$file" 2>&1)" || unparsed="${unparsed}    ${file}: ${said}
"
done < <(files)
report "every file parses under $(/bin/bash -c 'printf %s "$BASH_VERSION"')" "$unparsed"

report "no here-document sits inside a command substitution" \
  "$(files | xargs grep --line-number --extended-regexp '\$\([[:space:]]*cat[[:space:]]*<<' 2>/dev/null)"

printf "\n%d passed, %d failed\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
