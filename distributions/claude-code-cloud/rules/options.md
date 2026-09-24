## Long-form options

Write every command option in its long form - `git --message` not `git -m`, `jq --raw-output` not `jq -r`. {held-to} Where a tool offers no long form for an option, the short one stands: much of the base Unix toolset has none, and a shell test like `[ -n "$value" ]` never had one. A hook refuses a short option on the commands it knows to have long ones, counting only what is newly added. It has no escape hatch: where an option genuinely has no long form on this platform, say which and leave the exception for the user to add.
