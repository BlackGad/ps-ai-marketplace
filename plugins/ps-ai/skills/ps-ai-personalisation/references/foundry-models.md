# Foundry model mapping

Only Foundry agents need a model question during setup: “Standard mapping or choose deployments yourself?” Reuse an answer already given. Subscription agents use their CLI defaults.

Discover deployments with `-Action add -Tool <tool> -Id '<id>' -Provider foundry -Endpoint '<endpoint>' -List`, or `-Action models -Id '<id>' -List` for an existing agent. Run these flags through `<plugin>/bin/ps-ai-account.ps1`. Discovery uses Azure CLI; never print or save its token.

For standard mapping:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action add -Tool <tool> -Id '<id>' -Provider foundry -Endpoint '<endpoint>' -Standard
& "<plugin>/bin/ps-ai-account.ps1" -Action models -Id '<id>' -Standard
```

`-Standard` uses discovered deployments. Optional `-Deployments` limits it to selected discovered names. Do not combine it with `-Aliases` or `-Default`. Explicit choices still use the commands in the tool's account guide.

Claude maps `opus`, `sonnet` and `haiku` from separate tokens in the deployment name or model. Split on hyphens, underscores, dots and spaces, ignoring case. Compare numeric tokens left to right to choose the newest. Use numbers from the deployment name, or from the model when the name has none. Missing trailing numbers count as zero. The default is sonnet, else the first mapped alias. Fable is never chosen automatically.

Codex and Copilot save no aliases. They prefer the newest deployment containing the `sol` token, else the newest deployment. Copilot discovery still includes only supported Claude deployments.

A missing match or a tie at the newest version stops before writing files. The message names the unresolved alias and candidates. Ask the owner about that alias only. Keep resolved choices, resolve any further missing aliases one at a time, then save the full selection with explicit flags. If discovery failed, resolve discovery first.
