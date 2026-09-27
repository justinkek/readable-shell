The adapter prints the rules when the first turn of a session starts, and hands
every tool call to the guard before it runs, so a command or a write to a shell
file that breaks the rules is refused. An edit making several replacements in
one call is checked like any other.

Verified at 0.1.1 on a real session: `git --version -q` and a write of `enc=1`
to `probe.sh` were refused with the guard's reason, and the same write to
`probe.md` ran.
