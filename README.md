# readable-shell

(audience: humans)

Shell an agent commits should read like the rest of your code. This plugin
refuses a shortened variable name at the moment an agent writes it into a shell
file - `encoded`, not `enc`:

```
Unreadable shell denied in scripts/release.sh - shortened variable name(s): msg.
Spell every variable name out as the whole word, then retry.
```

A short-form option is noted rather than refused. The agent is asked to write
the long form where the command takes one that works on both Linux and macOS -
`git --message`, not `git -m` - and to leave the short one where it takes none:

```
Short-form options added in scripts/release.sh - git -m. Where a command takes
a long form of an option that works on both Linux and macOS, write that instead.
```

It is a legibility guard, not a correctness linter. It checks nothing
shellcheck checks, and shellcheck checks nothing it does, so run both.

Only what an edit adds is counted, so an old file is never refused for what was
already in it. Commands that take no long forms on macOS, such as `sed` and
`ls`, and the shell's own built-ins are left quiet, so `sed -n`, `ls -la` and
`[ -n "$value" ]` raise no note.

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

Every setting can be set for yourself in `~/.readable-shell/settings.json`,
for everyone in a project in `.readable-shell/settings.json` at its root,
committed with it, or for yourself in one project in
`.readable-shell/settings.local.json` beside it. The local file is read first,
then the project's, then your own, and an environment variable before any of
them. A file names a setting without the `READABLE_SHELL_` prefix.

The two lists are set a word at a time: `false` takes a shipped word off,
`true` adds one, and every other shipped word stays. In an Express project,
`.readable-shell/settings.json` might hold:

```json
{
  "ABBREVIATIONS": { "req": false, "res": false },
  "SKIPPED_COMMANDS": { "deploy": true }
}
```

| Setting | Default | What it does |
| --- | --- | --- |
| `READABLE_SHELL_RULES` | all five | which rules hold, from `names options functions constants early-exits`; a rule left out is neither checked nor shown |
| `READABLE_SHELL_SCOPE` | `files` | `files` for shell written into files, `commands` for commands an agent runs, `both` for the two |
| `READABLE_SHELL_SHELLS` | `bourne` | which shells' files are held; `detect` holds every known shell |
| `READABLE_SHELL_ABBREVIATIONS` | 93 words | the shortened names refused, set a word at a time |
| `READABLE_SHELL_ABBREVIATIONS_SHIPPED` | `on` | `off` leaves out the 93 words, so only the ones added are refused |
| `READABLE_SHELL_SKIPPED_COMMANDS` | the built-ins and the classic Unix tools | the commands whose short options are never noted, set a command at a time |
| `READABLE_SHELL_SKIPPED_COMMANDS_SHIPPED` | `on` | `off` leaves out the shipped commands, so only the ones added are skipped |

In an environment variable a list is the same JSON object:
`READABLE_SHELL_ABBREVIATIONS='{"req": false}'`. Settings written before
0.10.0 as `KEY = value` lines are converted once for your own file; a
project's old file is not read, and the settings skill writes it again.

A session is told the rules once, when it first writes a shell file: that
write is refused with the rules in the reason, and the agent redoes it. A
session that writes no shell is told nothing, and the rules it is told follow
the same settings.

## Shells

Files in sh, bash, zsh, ksh, dash, ash and mksh are held, known by their name or
by their first line. The long-option rule is about the command rather than the
shell, so it is written once for every shell; the name rule differs only in how
a shell assigns a variable, and more shells can follow.
