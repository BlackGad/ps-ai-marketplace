# Settings fields

Preferences belong in `~/.agents/configuration/ps-ai-notes.md`. Read notes before selecting accounts or models, dispatching, communicating or knowledge work. Re-read after edits. Current owner instructions win. Scripts never parse notes.

| Field | Operational consumer and purpose |

| --- | --- |

| `$schema` | `Write-PsAiPersonalisation` normalizes the stable editor URL; runtime uses the bundled schema. |

| `schemaVersion` | `Invoke-PsAiValidation` checks the bundled runtime format. |

| `agents[].id` | Account operations select identity; the launcher derives a canonical wrapper. |

| `agents[].tool` | Tool discovery chooses account, Foundry and launch adapters. |

| `agents[].configDir` | Account wrappers, Foundry adapters and root installer select the account folder. Use a concrete folder, never `default`. |

| `agents[].provider.kind` | Foundry runner selects provider dispatch; only Foundry is implemented. |

| `provider.endpoint` | Foundry adapters connect to the selected HTTPS host. |

| `provider.default` | Foundry adapters select a deployment; The model-mapping adapter still needs its picker. |

| `provider.deployments[].name` | Foundry picker and adapters use wire deployment IDs. |

| `provider.deployments[].model` | The model-mapping adapter adapter maps model IDs. |

| `provider.deployments[].alias` | The alias adapter adapter maps supported aliases. |

| `channels[].id/kind/target/accounts` | `Resolve-PsAiChannel` selects the descriptor, destination and eligible accounts; the launcher validates bindings. |

Require `schemaVersion: 1`, `agents` and `channels`. Both arrays may be empty. Accounts require `id/tool/configDir`; provider is optional. Channels require `id/kind/target/accounts`; bindings are nonempty, unique and refer to supported accounts. IDs are lowercase hyphenated names, unique in each array. Descriptors determine supported tools and kinds.

Provider requires `kind/endpoint/default/deployments`; each deployment requires `name`, with optional `model/alias`. Names and aliases are unique, the default must be selected, and aliases must be supported by the tool. Endpoint is an HTTPS host without a path. Never save secrets.

Validate every edit with the bundled schema:

```text

pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind personalisation -Path <home>/.agents/configuration/ps-ai-personalisation.json

```

Use the stable editor URL `https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/plugins/ps-ai/schemas/personalisation.schema.json` or omit `$schema`. Unknown fields require setup. Do not invent defaults or copy sample preferences. Use [create.md](create.md) for setup and [notes-template.md](notes-template.md) for headings. Record stated models, exclusions, purposes, careful/paid-use choices, notifications, format, knowledge location and durable lessons. Put deferred choices and “Finish my ps-ai setup” under Finish later. Add no consent or status properties. The agent repairs prose references after account/channel changes and reports unresolved wording.

For tool operations read `skills/ps-ai-<agent.tool>/SKILL.md`; stop if missing.
