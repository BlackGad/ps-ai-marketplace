# Personalisation fields

Read both `~/.agents/configuration/ps-ai-personalisation.json` and `~/.agents/configuration/ps-ai-notes.md` before applying another ps-ai skill. For tool operations, read `skills/ps-ai-<agent.tool>/SKILL.md` using the selected account's `agent.tool`; stop if it is missing. Account IDs are unique lowercase hyphenated names and must not shadow commands on PATH. Account operations belong to the selected tool's `references/accounts.md`.

After every JSON change, validate:

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind personalisation -Path <home>/.agents/configuration/ps-ai-personalisation.json
```

Use [create.md](create.md) for fixture or alternate-home handling. Keep commands internal unless the owner asks for them or must run them themselves.

`<plugin>/schemas/personalisation.schema.json` is authoritative. Set `$schema` to that local path for editor help. Examples are illustrative; use owner answers.

| Field | Meaning and example |
| --- | --- |
| `$schema` | Editor schema location, e.g. `<plugin>/schemas/personalisation.schema.json`. |
| `schemaVersion` | Format version: `1`. |
| `communication` | Language, questions, channels: `{"language":"simple-english","questions":"one-at-a-time","channels":{}}`. |
| `communication.language` | Preferred language/style: `simple-english`. |
| `communication.questions` | Question cadence: `one-at-a-time`. |
| `communication.channels` | Named channel map; `{}` means none. |
| `channels.<name>.kind` | Transport: `telegram`. |
| `channels.<name>.target` | Nonsecret destination: `123456789`. |
| `channels.<name>.format` | Message format: `markdownv2`. |
| `channels.<name>.tone` | Tone: `business`. |
| `channels.<name>.launch` | Flags by tool: `{"<tool-id>":["<channel-argument>","<channel-value>"]}`. |
| `agents` | CLI accounts; `[]` before registration. |
| `agents[].id` | Unique lowercase hyphenated id: `agent-a`. |
| `agents[].tool` | Tool descriptor id: `<tool-id>`; use its tool skill. |
| `agents[].command` | Executable or wrapper: `~/.agents/bin/agent-a`. |
| `agents[].configDir` | Account folder or `default`: `~/.agents/accounts/agent-a`. |
| `agents[].roles` | `overseer`, `legion`, `reviewer`, `mechanical`: `["legion","reviewer"]`. |
| `agents[].care` | Optional `high`: spend carefully, on overseer work. |
| `agents[].cost` | Optional `paid`: ask before use. |
| `agents[].models` | Optional per-role model: `{"legion":"preferred-model"}`; keys are the four roles. |
| `agents[].launch.args` | Account launch flags: `["<argument>"]`. |
| `routing` | Preferred account ids by job. |
| `routing.implement` | Implementation order: `["agent-a"]`. |
| `routing.review` | Reviewer order: `["agent-b"]`. |
| `routing.mechanical` | Mechanical order: `[]`. |
| `routing.neverModels` | Excluded model names: `["model-to-avoid"]`. |
| `routing.rules` | Personal routing notes: `["reserve strongest model for milestone review"]`. |
| `knowledge.backend` | `llm-wiki` or `none`. |
| `knowledge.hub` | Wiki folder if enabled: `~/.agents/knowledge`. |
| `projects` | Settings keyed by repo id, not path: `{"my-project":{"label":"project","notify":[]}}`. |
| `projects.<id>.label` | Neutral wiki label, never a client name. |
| `projects.<id>.notify` | Channel names from `communication.channels`: `[]`. |
| `projects.<id>.launch` | Project launch flags by tool: `{"<tool-id>":["<argument>"]}`. |
| `projects.<id>.routing` | Optional override using the routing keys above. |
| `default.notify` | Channels for unregistered projects: `[]`. |

Do not guess model names. Routing entries must refer to defined account IDs; the validator checks this and the schema.

## Foundry provider

`agents[].provider` is optional. Without it, the agent uses its subscription. A Foundry agent has one endpoint and at least one selected deployment:

```json
{
  "kind": "foundry",
  "endpoint": "https://<resource>.cognitiveservices.azure.com",
  "default": "deployment-a",
  "deployments": [
    { "name": "deployment-a", "model": "deployment-a" },
    { "name": "deployment-b", "model": "deployment-b" }
  ]
}
```

| Provider field | Rule |
| --- | --- |
| `kind` | Required. Only `foundry` is supported. |
| `endpoint` | Required. HTTPS scheme and host only. The account script trims pasted paths and trailing slashes. |
| `default` | Required. Must match a selected deployment name. |
| `deployments` | Required, nonempty array. Each `name` is required and unique. |
| `deployments[].model` | Optional model name. Discovery fills it when known; updates retain a known value if discovery has none. |
| `deployments[].alias` | Optional; accepted values come from the selected tool descriptor. Each alias can occur once. |

No other provider or deployment fields are accepted. The selected tool descriptor and its accounts reference own discovery filters, alias support, provider limitations, and launch behavior.

Use the matching tool skill's `references/accounts.md` for add or "update models for <id>". First run `ps-ai-account.ps1 -Action add -Tool <tool-id> -Id <id> -Provider foundry -Endpoint <url> -List` or `ps-ai-account.ps1 -Action models -Id <id> -List`. Present `new`, `gone`, and `kept`, then ask which deployments, default, and any supported aliases to save. Wait for the owner's answer before running without `-List`. The write uses `-Deployments`, `-Default`, and optional `-Aliases`; `models` replaces the complete deployment list. Validate personalisation after writing. Never put a token or key in this block.
