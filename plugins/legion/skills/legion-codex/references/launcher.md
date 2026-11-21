# Interactive overseer launch

Follow [owner notes](../../legion-personalisation/references/fields.md) before account, model or channel choices.

Omit model flags by default. When notes name a model or allow a tier, follow [model tiers and Foundry routing](../../legion-overseer/references/task-loop.md#model-tiers) and pass the model through literal `-Arguments`, as shown below. Replace `<named-model>` with that preference; do not discover models or offer a model list for subscription agents.

```powershell
pwsh -NoProfile -File <plugin>/bin/legion-overseer.ps1 -Account <id> -Tool codex -Repo <repo> -Arguments @('--model', '<named-model>', '<argument>', 'two words', '')
```

Follow the [shared launcher guide](../../legion-personalisation/references/launcher.md) for arguments, account bindings and relaunches.
