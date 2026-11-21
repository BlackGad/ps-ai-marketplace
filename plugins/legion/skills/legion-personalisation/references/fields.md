# Settings fields

Save preferences using the [shared memory rule](../SKILL.md#identity-and-hard-rules). Personal, cross-repository preferences belong in `~/.legion/configuration/notes.md`. Read notes before selecting accounts, dispatching, communicating or knowledge work. Follow stated models, exclusions, account purposes, reviewer and worker order, careful-use choices and paid-use approval. Omit model flags unless notes name a model or allow a tier for the run; follow [model tiers](../../legion-overseer/references/task-loop.md#model-tiers). Discover models only for Foundry agents through [Foundry model mapping](foundry-models.md). Save new owner preferences as plain sentences when stated; ask model questions during setup only for Foundry mapping. Re-read after edits. Current owner instructions win. Scripts never parse notes.

Route channel operations through `skills/legion-<kind>/SKILL.md`; stop if missing. Any chosen session may oversee without channels.

| Field | Operational consumer and purpose |
| --- | --- |
| `$schema` | `Write-LegionPersonalisation` normalizes the stable editor URL; runtime uses the bundled schema. |
| `schemaVersion` | `Invoke-LegionValidation` checks the bundled runtime format. |
| `agents[].id` | Account operations select identity; the launcher derives a canonical wrapper. |
| `agents[].tool` | Tool discovery chooses account, Foundry and launch adapters. |
| `agents[].configDir` | Account wrappers, Foundry adapters and root installer select the account folder. Use a concrete folder, never `default`. |
| `agents[].provider.kind` | Foundry runner selects provider dispatch; only Foundry is implemented. |
| `provider.endpoint` | Foundry adapters connect to the selected HTTPS host. |
| `provider.default` | Foundry adapters select the default deployment. |
| `provider.deployments[].name` | Foundry picker and adapters use wire deployment IDs. |
| `provider.deployments[].model` | The model-mapping adapter maps model IDs. |
| `provider.deployments[].alias` | The alias adapter maps supported aliases. |
| `channels[].id/kind/target/accounts` | `Resolve-LegionChannel` selects the descriptor, destination and eligible accounts; the launcher validates bindings. |

Require `schemaVersion: 1`, `agents` and `channels`. Both arrays may be empty. Accounts require `id/tool/configDir`; provider is optional. Channels require `id/kind/target/accounts`; bindings are nonempty, unique and refer to supported accounts. IDs are lowercase hyphenated names, unique in each array. Descriptors determine supported tools and kinds.

Provider requires `kind/endpoint/default/deployments`; each deployment requires `name`, with optional `model/alias`. Names and aliases are unique, the default must be selected, and aliases must be supported by the tool. Endpoint is an HTTPS host without a path. Never save secrets.

Validate every edit with the bundled schema:

```text

pwsh -NoProfile -File <plugin>/bin/legion-validate.ps1 -Kind personalisation -Path <home>/.legion/configuration/personalisation.json

```

Use the stable editor URL `https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/plugins/legion/schemas/personalisation.schema.json` or omit `$schema`. Unknown fields require setup. Do not invent defaults or copy sample preferences. Use [create.md](create.md) for setup and [notes-template.md](notes-template.md) for headings. Record stated models, exclusions, purposes, careful/paid-use choices, notifications, format, knowledge location and durable lessons. Put unfinished requested work and “Finish my legion setup” under Finish later. Add no consent or status properties. The agent repairs prose references after account/channel changes and reports unresolved wording.

For tool operations read `skills/legion-<agent.tool>/SKILL.md`; stop if missing.

## Account setup

Keep existing account folders, settings, shortcuts and logins. Never read credentials or test sign-in. Only the owner logs in if the CLI asks. Use the matching tool's account guide for commands.

Every new, adopted, registered or Foundry account needs legion installed in its recorded config folder; setup installs it only where the folder has none, and moving versions is the update flow's job. Explain the install and get the owner's yes; reuse approval already given. Expand `~/` against the chosen home. Only `legion-setup.ps1` installs: a missing CLI through `legion-install-tool.ps1`, and legion, only with `-Yes` after the owner's yes. Report setup as incomplete if installation fails or is declined.
