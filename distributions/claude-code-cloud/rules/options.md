## Long-form options

Where a command takes a long form of an option that works on both Linux and macOS, write it - `git --message` not `git -m`, `jq --raw-output` not `jq -r`. {held-to} Where it takes none, the short one stands: much of the base Unix toolset has no long forms on macOS, and a shell test like `[ -n "$value" ]` never had one. Where such a line's options do not say what it does, call it through a function named for what it does. After each write, a hook notes the short options it newly adds, leaving out the commands it knows take no long forms; it refuses nothing for them.
