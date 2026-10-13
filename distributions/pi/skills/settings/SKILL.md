---
name: settings
description: Change readable-shell's settings
---

# readable-shell settings

Settings are stored in `~/.readable-shell/settings.json`, one JSON object whose keys
are the keys below without the `READABLE_SHELL_` they carry in the environment:

```json
{
  "SOME_SWITCH": "off",
  "SOME_LIST": { "an-item": false, "another": true }
}
```

| Key | Default | What it does, and what to say when setting it |
| --- | --- | --- |
| `READABLE_SHELL_STOP_NOTE_DIRECTORY` | `~/.readable-shell/state/notes` | where a turn's notes are written |
| `READABLE_SHELL_UPDATE_CHECK` | `on` | asks once a day whether a newer version is out |
| `READABLE_SHELL_UPDATE_CHECK_DAYS` | `1` | days between those asks |
| `READABLE_SHELL_VERSION_SOURCE` | `https://raw.githubusercontent.com/justinkek/readable-shell/main/package.json` | where the update check reads the published version from |
| `READABLE_SHELL_RULES` | `names options functions constants early-exits` | which rules hold, space separated: `names` for whole-word variable names, `options` for long-form options, `functions` for long pipelines in a named function, `constants` for named numbers and paths, `early-exits` for ending early rather than in an if. A rule left out is neither checked nor shown. `both`, from before 0.6.0, still holds every rule |
| `READABLE_SHELL_SCOPE` | `files` | what the rules are held against: `files` for shell written into a file, `commands` for the commands an agent runs, `both` for the two. Say that the files are the project's own and outlive the session, and a command is read once if at all |
| `READABLE_SHELL_SHELLS` | `bourne` | which shells' files are held to the rules, space separated. The shells known are `bourne`: sh, bash, zsh, ksh, dash, ash and mksh. `detect` holds every known shell |
| `READABLE_SHELL_ABBREVIATIONS` | `acc arg args arr attr attrs btn buf cb cfg cmd conf ctx cur curr db decl decls def dep deps desc dest dev dir dirs dist doc docs dst e el elem elems enc env envs err ev evt expr exprs ext exts fn fp func i ident idents idx j len lib mod msg num obj opt opts param params perf pkg pos prev prod prop props proto ref refs rel repo req res ret retval sep src stmt stmts str tbl temp tit tmp util utils val var vars ver` | the shortened variable names refused. Turn one off with `false` where a project needs it, such as `req` and `res` in an Express project, or add one with `true` |
| `READABLE_SHELL_SKIPPED_COMMANDS` | `[ [[ test set read export local declare readonly typeset unset shift return exit printf echo cd pwd trap wait eval exec source command type hash ulimit umask alias getopts let awk basename cat chmod chown comm cp cut date df diff dirname du env file find head hostname id kill ln ls mkdir mktemp mv nohup od paste ps python python3 rm rmdir scp sed sleep ssh stat tail tee tmux touch tr uname uniq wc which xargs` | the commands whose short options are never noted, because they take no long form that works on both Linux and macOS. Add a project's own scripts with `true`, or turn one off with `false` to have it noted |
| `READABLE_SHELL_ABBREVIATIONS_SHIPPED` | `on` | `off` leaves out the 93 items the plugin ships in `READABLE_SHELL_ABBREVIATIONS`, so only the ones turned on there are used |
| `READABLE_SHELL_SKIPPED_COMMANDS_SHIPPED` | `on` | `off` leaves out the 79 items the plugin ships in `READABLE_SHELL_SKIPPED_COMMANDS`, so only the ones turned on there are used |

`READABLE_SHELL_HOME` moves the settings file and the state under it together.

A list setting ships a list of items. Each file turns an item off with `false`
or adds one with `true`, and keeps every other item the plugin ships, so a new
version's items still arrive. Its `_SHIPPED` switch set to `off` leaves out the
shipped items, so the list is only what is turned on.

A project can hold settings of its own in `.readable-shell/settings.json` at its
root, in the same shape, and a person can hold their own for that project in
`.readable-shell/settings.local.json` beside it. The hooks read the local file
first, then the project's, then `~/.readable-shell/settings.json`, and an environment
variable before any of them; for a list, the first of those to name an item
decides it. Write the project's file when the user wants a value for everyone
working in the project, and say that it is a file to commit. Write the local
one when they want it for themselves in this project alone, and say it is a
file to leave out of git.

An environment variable holds a list as the same JSON object a file holds:
`READABLE_SHELL_<LIST_KEY>='{"an-item": false}'`.

A file that holds a `readable-shell` setting as `key = value` lines is from before
the SDK wrote JSON, and no hook reads it. Offer to write each of its values
again with the steps below, then remove it.

## Before writing anything

Read the steps below. Where they say no hook runs, write no
file: follow them instead, since nothing would read what you wrote.

## How to update settings

Refuse a value the table above does not allow, saying what it takes and writing
nothing; where the file already holds one, say so, since the hooks read it as
the default.

If the file is not there, create it as a JSON object holding the setting.
Else, read the file, replace or add the setting, and write it back.
Leave every other key in the file as it is.

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

The hooks read the file every time they run, so a change takes effect at once.
Whatever this session was given at its start was given with the old value, so
run the reload skill to be given it again with the new one.

## Note

Rendered from readable-shell 0.10.0. Say that version when asked which one is
installed, and say it is the version this file was built from rather than one
read off disk.

Generated by the ai-plugin-sdk build. Edit the plugin's own sources instead.
