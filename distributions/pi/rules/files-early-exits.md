## Early exits

In a shell file, end a script or a function as soon as a condition rules out the rest - `[ -f "$config" ] || exit 0` - rather than nesting the rest inside an `if`. The main work then sits at the left margin, after every check that guards it.
