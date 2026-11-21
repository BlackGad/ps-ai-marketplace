# Legion report

Write this report to the `{REPORT_FILE}` named by the overseer's task prompt, even when stopping for a question. Keep a heading even when its answer is "None". Give evidence, not only a PASS label.

```markdown
## Summary

- Scope completed or stop reason; files changed.

## Tests added

- Test name and behavior it proves; failing result before implementation and passing result after.

## Checks run

| Command | Result |
| --- | --- |
| `<exact command>` | PASS/FAIL and decisive output |

## Commits

- `<hash>` — `<subject>`; or "None — stopped before commit".

## Open questions

- The precise scope, API, or plan question; or "None".
```

Never include credentials, token contents, or sensitive logs. The overseer reviews this report and updates the handoff.
