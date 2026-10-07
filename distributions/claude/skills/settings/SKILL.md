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
| `READABLE_SHELL_ABBREVIATIONS` | `acc arg attr cfg cmd ctx curr desc dir dst enc fp idx len msg num opt pos prev req res src str tmp val var` | the shortened variable names refused, space separated. Setting it replaces the whole list |
| `READABLE_SHELL_ABBREVIATIONS_ADDED` | unset, nothing added | shortened names refused on top of the list, such as `btn err resp` |
| `READABLE_SHELL_ABBREVIATIONS_ALLOWED` | unset, nothing allowed | names taken off the list, such as `ctx` for a Go project or `req res` for an Express one |
| `READABLE_SHELL_COMMANDS` | `aws brew curl docker gcloud gh git grep jq kubectl mise node npm npx pip3 python3 rsync sort tar wget` | the commands whose short options are refused, space separated. Setting it replaces the whole list. Say that a command is listed only where every option in use has a long form |
| `READABLE_SHELL_COMMANDS_ADDED` | unset, nothing added | commands held to long options on top of the list, such as `terraform duckdb` |
| `READABLE_SHELL_SHORT_OPTIONS_ALLOWED` | `git:-C tar:-C` | short options that have no long form, each as `command:option`, space separated. Setting it replaces the whole list |

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
bash "${CLAUDE_PLUGIN_ROOT}/set-setting.sh" <key> <value>
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

One install serves several clients. Read the signatures, then follow the
steps under the one that matches.

### Claude Code, on your machine

A plugin directory under `~/.claude/plugins`, and a project directory you can
write to. Everything works, and settings persist.

The hooks read the file every time they run, so a change takes effect at once.
Whatever this session was given at its start was given with the old value, so
run the reload skill to be given it again with the new one.

### ZCode

A plugin cached under `~/.zcode`, and no `~/.claude/plugins`. Everything works
as it does on Claude Code, and settings persist, but the window that installed
it is ZCode's own.

The hooks read the file every time they run, so a change takes effect at once.
Whatever this session was given at its start was given with the old value, so
run the reload skill to be given it again with the new one.

### Claude Chat

Skills under `/mnt/skills/plugins/`, no plugin directory, and no
`~/.readable-shell` written by anything but you. No hook runs, so nothing
reads a settings file, and what a session start hook would print only arrives
when the reload skill prints it.

No hook runs here, so nothing reads the file and none is worth writing.

A setting still holds for this conversation: say what it changes and how,
restate the part it changes with the new value, and follow it from your next
reply. Say that it lasts until this conversation ends.

To keep it, put the text the reload skill prints in a preference or a custom
style with the value already changed. It can be edited before it is pasted in.

### Claude Cowork

A plugin directory under `~/.claude/plugins`, with `~/.readable-shell/state`
written this session. Every hook runs, and the container is discarded when the
session ends.

The hooks read the file every time they run, so a change takes effect at once,
and the reload skill prints with the new value.

The file is written inside the session's container, which is discarded when the
session ends, so say the setting lasts as long as this session does.

## Note

Rendered from readable-shell 0.6.1. Say that version when asked which one is
installed, and say it is the version this file was built from rather than one
read off disk.

Generated by the ai-plugin-sdk build. Edit the plugin's own sources instead.
