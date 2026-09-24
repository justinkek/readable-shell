## Whole-word variable names

Name every shell variable with the whole word - `encoded` not `enc`, `command` not `cmd`, whether it is assigned bare, with `local`, with `export` or with `declare`. {held-to} A hook refuses an assignment whose name is a shortening it knows, counting only what is newly added. It has no escape hatch: rename the variable and retry.
