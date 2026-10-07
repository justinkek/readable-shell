---
name: settings
description: Change readable-shell's settings
---

# readable-shell settings

Settings are stored in `~/.readable-shell/settings` with one `key = value` a line.
Blank lines and lines opening with `#` are ignored, and the last assignment of a key is the one that counts.

| Key | Default | What it does, and what to say when setting it |
| --- | --- | --- |
| `READABLE_SHELL_STOP_NOTE_DIRECTORY` | `~/.readable-shell/state/notes` | where a turn's notes are written |
| `READABLE_SHELL_UPDATE_CHECK` | `on` | asks once a day whether a newer version is out |
| `READABLE_SHELL_UPDATE_CHECK_DAYS` | `1` | days between those asks |
| `READABLE_SHELL_VERSION_SOURCE` | `https://raw.githubusercontent.com/justinkek/readable-shell/main/package.json` | where the update check reads the published version from |
| `READABLE_SHELL_RULES` | `names options functions constants early-exits` | which rules hold, space separated: `names` for whole-word variable names, `options` for long-form options, `functions` for long pipelines in a named function, `constants` for named numbers and paths, `early-exits` for ending early rather than in an if. A rule left out is neither checked nor shown. `both`, from before 0.6.0, still holds every rule |
| `READABLE_SHELL_SCOPE` | `files` | what the rules are held against: `files` for shell written into a file, `commands` for the commands an agent runs, `both` for the two. Say that the files are the project's own and outlive the session, and a command is read once if at all |
| `READABLE_SHELL_SHELLS` | `bourne` | which shells' files are held to the rules, space separated. The shells known are `bourne`: sh, bash, zsh, ksh, dash, ash and mksh. `detect` holds every known shell |
| `READABLE_SHELL_ABBREVIATIONS` | `acc arg args arr attr attrs btn buf cb cfg cmd conf ctx cur curr db decl decls def dep deps desc dest dev dir dirs dist doc docs dst e el elem elems enc env envs err ev evt expr exprs ext exts fn fp func i ident idents idx j len lib mod msg num obj opt opts param params perf pkg pos prev prod prop props proto ref refs rel repo req res ret retval sep src stmt stmts str tbl temp tit tmp util utils val var vars ver` | the shortened variable names refused, space separated. Setting it replaces the whole list |
| `READABLE_SHELL_ABBREVIATIONS_ADDED` | unset, nothing added | shortened names refused on top of the list, such as `btn err resp` |
| `READABLE_SHELL_ABBREVIATIONS_ALLOWED` | unset, nothing allowed | names taken off the list, such as `ctx` for a Go project or `req res` for an Express one |
| `READABLE_SHELL_COMMANDS_QUIET` | `[ [[ test set read export local declare readonly typeset unset shift return exit printf echo cd pwd trap wait eval exec source command type hash ulimit umask alias getopts let awk basename cat chmod chown comm cp cut date df diff dirname du env file find head hostname id kill ln ls mkdir mktemp mv nohup od paste ps python python3 rm rmdir scp sed sleep ssh stat tail tee tmux touch tr uname uniq wc which xargs` | the commands whose short options are never noted, because they take no long form that works on both Linux and macOS, space separated. Setting it replaces the whole list |
| `READABLE_SHELL_COMMANDS_QUIET_ADDED` | unset, nothing added | commands left quiet on top of the list, such as a project's own scripts |

`READABLE_SHELL_HOME` moves the settings file and the state under it together.

A project can hold settings of its own in `.readable-shell/settings` at its root, in
the same shape. The hooks read it before `~/.readable-shell/settings`, and an
environment variable before either. Write there when the user wants a value
for everyone working in the project rather than for themselves, and say that
it is a file to commit.

## Before writing anything

Read the steps below. Where they say no hook runs, write no
file: follow them instead, since nothing would read what you wrote.

## How to update settings

Run this once per key, and edit no file yourself:

```
bash "/opt/readable-shell/distributions/claude-code-cloud/set-setting.sh" <key> <value>
```

It creates the file if it is not there, puts the new value where the old one
was, and leaves the rest of the file as it is, comments included. It writes
nothing and says what the setting takes when the value is one it cannot take,
so pass on what it says rather than trying again.

Where the file already holds a value for the key, say so before running it,
since the hooks read it as the default.

For the project's own file, put `--project <directory>` before the key,
naming the root of the project.

## How to apply settings

The steps below say what reads the file here, and what to do so the session
reads the new copy.

## Inform the user of their settings

Name each key the file sets, and the default above for keys that are unset / empty.

A key another setting has turned off keeps its value and says so in the parenthesis, naming the key and the value that turned it off:

| Key                                        | Value |
| ------------------------------------------ | ----- |
| `READABLE_SHELL_UPDATE_CHECK` | `off` (set) |
| `READABLE_SHELL_UPDATE_CHECK_DAYS` | `1` (set - n.a. because `READABLE_SHELL_UPDATE_CHECK` is set to `off`) |

One pair does this. `READABLE_SHELL_UPDATE_CHECK = off` asks nothing, so `READABLE_SHELL_UPDATE_CHECK_DAYS` throttles nothing.

## What not to do

Do not edit what a hook prints to change a value. The hook rewrites it from
whatever is configured, every time it runs.

Do not export a variable in a shell to make a change stick: it lasts as long as
that shell. An environment variable set on a cloud environment is a different
thing, and the steps below say when it is the right one.

## The steps for this install

The hooks read the file every time they run, so a change takes effect at once,
and the reload skill prints with the new value.

The file is written inside the container, which is rebuilt for every session, so
a setting you want to keep goes in a `READABLE_SHELL_` environment variable on
the cloud environment, see
[the docs](https://code.claude.com/docs/en/cloud-environments#set-environment-variables).

## Note

Rendered from readable-shell 0.9.0. Say that version when asked which one is
installed, and say it is the version this file was built from rather than one
read off disk.

Generated by the ai-plugin-sdk build. Edit the plugin's own sources instead.
