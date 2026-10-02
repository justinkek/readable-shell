## Named constants

In a shell file, give a number or a path that carries meaning a name saying what it is, and use the name: `days_logs_are_kept=14`, then `-mtime +"$days_logs_are_kept"`. A number with no meaning of its own, such as the `1` in `head --lines=1`, stays as it is.
