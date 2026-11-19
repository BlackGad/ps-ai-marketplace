# Interactive overseer launch

Follow [owner notes](../../ps-ai-personalisation/references/fields.md) before account, model or channel choices.

```powershell
pwsh -NoProfile -File <plugin>/bin/ps-ai-overseer.ps1 -Account <id> -Tool claude -Repo <repo> -Arguments @('--model', '<chosen-model>', '<argument>', 'two words', '')
```

Follow the [shared launcher guide](../../ps-ai-personalisation/references/launcher.md) for arguments, account bindings and relaunches.
