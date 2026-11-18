# Repository scripts

| Script | When | What it does | Arguments | Output |
| --- | --- | --- | --- | --- |
| `check-task.ps1` | after each task | Release build, analyzers, suites of changed projects | `-Base <commit>` | pass/fail table; log in `.agents/temp/` |

Replace the example with actual repo scripts. The `project.json` step name for `check-task.ps1` is `check-task`.
