The first patch that writes a shell file is refused once with the rules, and a
patch that adds a breach to a shell file after that is refused before it runs. A patch changing
several files is checked file by file, and the refusal names each shell file
it caught.

Codex runs no hook until it has been reviewed, so nothing arrives until `/hooks`
has been opened and the commands trusted.

Verified on Codex that the hook is called for a command and for a patch, and
that a refusal stops the call. Not yet verified with this plugin installed.
