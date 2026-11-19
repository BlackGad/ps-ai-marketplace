# Repository scripts

| Script | When | What it does | Arguments | Output |
| --- | --- | --- | --- | --- |
| `check-task.ps1` | after each task | Release build, analyzers, suites of changed projects | `-Base <commit>` | pass/fail table; log in `.legion/temp/` |

Replace the example with actual repo scripts. Name `check-task` as the gate in workflow.
