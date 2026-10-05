The adapter hands every tool call to the guard before it runs: the first write
to a shell file is refused once with the rules, and a write that breaks them
after that is refused. An edit making several replacements in
one call is checked like any other.

Verified at 0.1.1 on a real session: `git --version -q` and a write of `enc=1`
to `probe.sh` were refused with the guard's reason, and the same write to
`probe.md` ran.
