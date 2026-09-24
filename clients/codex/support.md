The rules are printed when a session starts, and a command is refused before it
runs. Codex sends its file edits to no hook, so shell written into a file is
asked for by the rules rather than refused.

Codex runs no hook until it has been reviewed, so nothing arrives until `/hooks`
has been opened and the commands trusted.

Not yet verified on a real session.
