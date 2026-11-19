# Codex CLI limits

Follow [owner notes](../../ps-ai-personalisation/references/fields.md) before account, model or channel choices.
Run a short ping through the selected account's command, from a disposable git repository:

```sh
<command> exec "ping" < /dev/null
```

When launched by a script, close stdin immediately. Read the newest session record under **that account's** `CODEX_HOME/sessions` and find its `rate_limits` event. Report the available window percentages and reset times from the record. Use the account's configured `configDir` or wrapper environment to identify `CODEX_HOME`; never inspect credential files. If no `rate_limits` event appears, report limits as unknown. Only a quota error or a limit event from this account can justify calling it exhausted; never transfer another account's result.

## Foundry agent

Codex is **not yet proven against Foundry**. When `provider.kind` is `foundry`, use this check instead of subscription session limits above:

```powershell
az account get-access-token --resource https://cognitiveservices.azure.com -o none
```

Exit 0 means Azure can issue a token. Foundry has no subscription window to report. This does not prove GPT deployment access or a working Codex session. On failure, show the Azure error; do not declare subscription exhaustion. Do not print or save the token. Add and launch try interactive `az login` once after a failure.
