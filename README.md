# readable-shell

(audience: humans)

Shell an agent commits should read like the rest of your code. This plugin
refuses two things at the moment an agent writes them into a shell file:

1. A shortened variable name - `encoded`, not `enc`.
2. A short-form option on a command that has a long one - `git --message`, not
   `git -m`.

```
Unreadable shell denied in scripts/release.sh - shortened variable name(s): msg;
short-form option(s): git -m. Spell every variable name out as the whole word,
and write every option in its long form, then retry.
```

It is a legibility guard, not a correctness linter. It checks nothing
shellcheck checks, and shellcheck checks nothing it does, so run both.

Only what an edit adds is counted, so an old file is never refused for what was
already in it. Both lists are kept short on purpose: a command is listed only
where its options have long forms, so `sed -n` and `ls -la` pass, and so does
`[ -n "$value" ]`.

## Installing

See [INSTALL.md](INSTALL.md), and [COMPATIBILITY.md](COMPATIBILITY.md) for what
runs on each client.

The commands an agent runs are left alone by default: a command is read once,
if at all, and a rule that refuses it costs retries. Set `SCOPE` to `both` to
hold them to the rules too.

Three more rules say how a shell file is laid out. The guard refuses the parts
of them a pattern can decide, and the rest are shown to the agent:

| Rule | Refused |
| --- | --- |
| a pipeline of more than three stages, or logic used twice, goes in a named function | a pipeline of more than three stages outside a function |
| a number or path that carries meaning gets a name | nothing |
| a script or function exits early rather than nesting its work in an `if` | a script or function whose last statement is an `if` of more than one line with no `else` |

## Settings

Every setting can be set for yourself in `~/.readable-shell/settings`, or for
everyone in a project in `.readable-shell/settings` at its root, committed with
it. The project's file is read first, and an environment variable before
either.

```
# .readable-shell/settings in a Go project
READABLE_SHELL_ABBREVIATIONS_ALLOWED = ctx
READABLE_SHELL_COMMANDS_ADDED = terraform
```

| Setting | Default | What it does |
| --- | --- | --- |
| `READABLE_SHELL_RULES` | all five | which rules hold, from `names options functions constants early-exits`; a rule left out is neither checked nor shown |
| `READABLE_SHELL_SCOPE` | `files` | `files` for shell written into files, `commands` for commands an agent runs, `both` for the two |
| `READABLE_SHELL_SHELLS` | `bourne` | which shells' files are held; `detect` holds every known shell |
| `READABLE_SHELL_ABBREVIATIONS` | 26 words | the shortened names refused; setting it replaces the list |
| `READABLE_SHELL_ABBREVIATIONS_ADDED` | unset | names refused on top of the list |
| `READABLE_SHELL_ABBREVIATIONS_ALLOWED` | unset | names taken off the list |
| `READABLE_SHELL_COMMANDS` | 20 commands | the commands held to long options; setting it replaces the list |
| `READABLE_SHELL_COMMANDS_ADDED` | unset | commands held on top of the list |
| `READABLE_SHELL_SHORT_OPTIONS_ALLOWED` | `git:-C tar:-C` | short options with no long form, as `command:option` |

A session is told the rules once, when it first writes a shell file: that
write is refused with the rules in the reason, and the agent redoes it. A
session that writes no shell is told nothing, and the rules it is told follow
the same settings.

## Shells

Files in sh, bash, zsh, ksh, dash, ash and mksh are held, known by their name or
by their first line. The long-option rule is about the command rather than the
shell, so it is written once for every shell; the name rule differs only in how
a shell assigns a variable, and more shells can follow.
