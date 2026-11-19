# Copilot CLI limits

Follow [owner notes](../../ps-ai-personalisation/references/fields.md) before account, model or channel choices.
Copilot CLI 1.0.109 has no limit percentage readout in this workflow. Run a short prompt on the selected account:

```sh
<command> -p "ping" -s < /dev/null
```

Close stdin for scripted launches. A quota error from this ping means the selected account is out. A successful ping only shows it can answer now; report percentages and reset times as unknown. A network or authentication failure is not proof of quota exhaustion. Never use one account's ping result for another.

## Foundry agent

When `provider.kind` is `foundry`, use this check instead of the subscription ping above:

```powershell
az account get-access-token --resource https://cognitiveservices.azure.com -o none
```

Exit 0 means Azure can issue a token. Foundry has no subscription window to report; deployment access and capacity still need a real response. A failed token check is not subscription exhaustion. Do not print or save the token. Add and launch try interactive `az login` once after a failure. A new token check does not refresh a running Copilot agent's fixed token. Follow its expiry notice and restart with `<id> --resume`.
