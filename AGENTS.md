# Working in this repository

(audience: agents)

The rules this plugin gives a session are not this file. They are the files in
`rules/`: `options.md` for long-form options, one `names-<shell>.md` per shell
family for whole-word variable names, and `files-*.md` for how a shell file is
laid out. A session is given them once, in the refusal of the first shell it
writes that the rules hold, by `rules_text` in `hooks/readable-shell-lib.sh`,
with `{held-to}` filled in to say what they apply to. A session that never
writes shell is never told them. To see what a session gets:

    printf '{"session_id":"look","tool_name":"Write","tool_input":{"file_path":"a.sh","content":"x=1"}}' \
      | env HOME="$(mktemp -d)" bash distributions/claude/hooks/guard-shell-readability.sh

This file is what a session working *on* the plugin reads.

This plugin is built by the ai-plugin-sdk. `./build` calls it: the SDK is a
checkout at `../ai-plugin-sdk`, or wherever `AI_PLUGIN_SDK` names.

## What it is and is not

Every variable name is a whole word, refused at edit time with no escape hatch. Every option is written in its long form where the command takes one that works on both Linux and macOS, noted at edit time and never refused. It is a legibility guard. It checks nothing shellcheck checks, and nothing it refuses is a bug.

Which commands take portable long forms is not kept as a list: there are too many, and they differ between Linux and macOS. The agent judges each one from the note. The one list kept is of commands that take none, `COMMANDS_QUIET`, and a command missing from it costs a needless note rather than a wrong refusal.

## Layout rules

`rules/files-functions.md`, `rules/files-constants.md` and `rules/files-early-exits.md` say how a shell file is laid out: named functions, named constants and early exits. They are shown with the first shell file a session writes, and never for a command, which has no layout.

Each rule is split into what a pattern decides and what needs the code's meaning. The guard refuses the first half; the second half is for an AI review, which does not exist yet.

| Rule | Refused by the guard | Left to an AI review |
| --- | --- | --- |
| whole-word names | a name on the abbreviation list | a whole word that says nothing, like `data` |
| long options | nothing; a short option on a command not left quiet is noted | whether the command takes a portable long form |
| named functions | a pipeline of more than three stages outside a function | logic written twice |
| named constants | nothing | a number or path that carries meaning |
| early exits | a script or function whose last statement is an `if` of more than one line with no `else` | nothing |

A layout rule is about the whole file, so `scan_layout` reads the file as the change leaves it: a write is the whole file, and an edit is replaced into the file on disk. A change that cannot be placed in the file, such as a Codex patch's scattered lines, is not checked for layout. Only a breach the file did not already hold is refused.

The plan, in order:

| Check | During dev | In review |
| --- | --- | --- |
| what a pattern decides | this guard, at the write | `readable-shell check` in CI, not built yet |
| what needs meaning | an AI review when the agent stops, not built yet | an AI review of the pull request, not built yet |

The edit hook only sees writes from an agent with this plugin, so CI is what holds a change made any other way.

## Two paths, kept apart

| Path | What it is about | Setting |
| --- | --- | --- |
| a write or an edit to a shell file, whichever tool made it | the project's own code, which varies per project | `SCOPE=files` |
| `Bash` tool calls | how an agent behaves, the same in every project | `SCOPE=commands` |

`SCOPE` defaults to `files`. A committed file is read for years; a command an agent runs is read once, if at all, and refusing it costs retries and, where a platform lacks a long form, a command that fails.

The guard reads the tool call through the SDK's `tool_entries`, and `plugin.json` asks for the `bash`, `write`, `edit` and `multi_edit` kinds, so it names no client's tools: a Claude `Edit` and a Codex patch arrive as the same entries.

A command an agent runs is Bourne shell whatever the project holds, so the
command path always scans it as Bourne.

## Shells

A shell is known by its family, since the rule that differs between shells is
the assignment syntax. `known_shells` in `hooks/readable-shell-lib.sh` lists the
families there are, and Bourne is the only one so far.

| Part | Shared across shells | Per shell |
| --- | --- | --- |
| long-option rule and its quiet list | all of it | nothing |
| abbreviation list | all of it | nothing |
| assignment pattern | nothing | `scan_names`, one arm per family |
| file names and opening lines | nothing | one pattern each |
| printed name rule | nothing | `rules/names-<family>.md` |

Adding a family is one arm in `scan_names`, one in `shell_of_file`, a word in
`known_shells`, a rules file, and a test group.

## Before you push

    tests/run-tests                                 this plugin's own behaviour
    ../ai-plugin-sdk/tests/run-tests "$PWD"         the SDK's, against this plugin

CI runs both.

## When to raise the version

An install names no ref, so what main points at is what a person gets. A merge
that changes what an install receives - `distributions/`, the marketplace
manifests, `plugin.json` or `package.json` - raises the version in
`plugin.json` and `package.json`. A merge that touches only the README, the
tests or CI raises nothing. CI runs the SDK's `version-changed` on every pull
request to hold this:

    ../ai-plugin-sdk/version-changed "$PWD" origin/main

## Where a change belongs

| Change | File |
| --- | --- |
| a rule a session is told | `rules/` |
| a setting, its kind and its default | `plugin.json` |
| how the lists, the scans and the shells are read | `hooks/readable-shell-lib.sh` |
| what is refused, and what the refusal says | `hooks/guard-shell-readability.sh` |
| which rules a session is shown | `rules_text` in `hooks/readable-shell-lib.sh` |
| what an older version left behind | `hooks/migrations.sh` |
| what works on one client | `clients/<client>/support.md` |
| what an install copies | nothing by hand - `distributions/` is built by `./build` |

`distributions/`, `INSTALL.md` and `COMPATIBILITY.md` are generated and
committed, because an install fetches files from the repository. Run `./build`
after changing anything they are built from; the SDK's tests fail on any
difference.

## Writing

Plain English, no metaphors, and a worked example instead of a description of
one. Every page opens with `(audience: humans)` or `(audience: agents)` under
its heading. `rules/` carries no mark, since a hook prints it into a session and
the mark would go with it.

The plugin's own shell is held to its own rules.
