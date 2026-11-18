# Claude Code limits

Ping the selected account's command in print mode with a small model:

```sh
<command> -p --model haiku --output-format stream-json --verbose "ping" < /dev/null
```

In PowerShell 7, start the process with redirected stdin and close stdin immediately; do not let a script runner leave it open. Read the `rate_limit_event` from the stream JSON. Report each available window's used or remaining percentage and reset time as exposed by the event. If no event appears, say the ping gave no limit readout; do not invent percentages or declare exhaustion. Never run this ping on a different account and attribute its windows to the selected one.

## Foundry agent

When `provider.kind` is `foundry`, use this check instead of the subscription ping above:

```powershell
az account get-access-token --resource https://cognitiveservices.azure.com -o none
```

Exit 0 means Azure can issue a token. Foundry has no subscription window to report. Token success does not prove deployment access or capacity. On failure, show the Azure error; do not declare subscription exhaustion. Do not print or save the token. Add, model discovery, and launch try interactive `az login` once after a failed token check.
