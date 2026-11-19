# Interactive overseer launch

Follow [owner notes](../../ps-ai-personalisation/references/fields.md) before account, model or channel choices.

Omit model flags by default. Only when notes name a model, pass it through literal `-Arguments`, as shown below. Replace `<named-model>` with that preference; do not discover models or offer a model list.

```powershell
pwsh -NoProfile -File <plugin>/bin/ps-ai-overseer.ps1 -Account <id> -Tool copilot -Repo <repo> -Arguments @('--model', '<named-model>', '<argument>', 'two words', '')
```

Follow the [shared launcher guide](../../ps-ai-personalisation/references/launcher.md) for arguments, account bindings and relaunches.
