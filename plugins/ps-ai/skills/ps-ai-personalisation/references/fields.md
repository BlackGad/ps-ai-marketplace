# Personalisation fields

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
| `channels.<name>.launch` | Flags by tool: `{"claude":["--channels","plugin:telegram@claude-plugins-official"]}`. |
| `agents` | CLI accounts; `[]` before registration. |
| `agents[].id` | Unique lowercase hyphenated id: `codex-a`. |
| `agents[].tool` | `claude`, `codex`, or `copilot`. |
| `agents[].command` | Executable or wrapper: `~/bin/codex-a`. |
| `agents[].configDir` | Account folder or `default`: `~/.codex`. |
| `agents[].roles` | `overseer`, `legion`, `reviewer`, `mechanical`: `["legion","reviewer"]`. |
| `agents[].care` | Optional `high`: spend carefully, on overseer work. |
| `agents[].cost` | Optional `paid`: ask before use. |
| `agents[].models` | Optional per-role model: `{"legion":"preferred-model"}`; keys are the four roles. |
| `agents[].launch.args` | Account launch flags: `["--verbose"]`. |
| `routing` | Preferred account ids by job. |
| `routing.implement` | Implementation order: `["codex-a"]`. |
| `routing.review` | Reviewer order: `["claude-b"]`. |
| `routing.mechanical` | Mechanical order: `[]`. |
| `routing.neverModels` | Excluded model names: `["model-to-avoid"]`. |
| `routing.rules` | Personal routing notes: `["reserve strongest model for milestone review"]`. |
| `knowledge.backend` | `llm-wiki` or `none`. |
| `knowledge.hub` | Wiki folder if enabled: `~/.agents/knowledge`. |
| `projects` | Settings keyed by repo id, not path: `{"my-project":{"label":"project","notify":[]}}`. |
| `projects.<id>.label` | Neutral wiki label, never a client name. |
| `projects.<id>.notify` | Channel names from `communication.channels`: `[]`. |
| `projects.<id>.launch` | Project launch flags by tool: `{"claude":["--verbose"]}`. |
| `projects.<id>.routing` | Optional override using the routing keys above. |
| `default.notify` | Channels for unregistered projects: `[]`. |

Do not guess model names. Routing entries must refer to defined account IDs; the validator checks this and the schema.

## Foundry provider

`agents[].provider` is optional. Without it, the agent uses its subscription. A Foundry agent has one endpoint and at least one selected deployment:

```json
{
  "kind": "foundry",
  "endpoint": "https://<resource>.cognitiveservices.azure.com",
  "default": "claude-opus-x",
  "deployments": [
    { "name": "claude-opus-x", "model": "claude-opus-x", "alias": "opus" },
    { "name": "claude-sonnet-x", "model": "claude-sonnet-x", "alias": "sonnet" }
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
| `deployments[].alias` | Optional, Claude agents only: `opus`, `sonnet`, `haiku`, or `fable`. Each alias can occur once. |

No other provider or deployment fields are accepted. Discovery filters model names to `claude` for Claude and Copilot, or `gpt` for Codex. Copilot GPT is out of scope; Codex is **not yet proven against Foundry**. Copilot stores `default` but its runner does not select that model at launch.

Use the matching tool skill's `references/accounts.md` for add or "update models for <id>". First run `ps-ai-account.ps1 -Action add -Tool <tool> -Id <id> -Provider foundry -Endpoint <url> -List` or `ps-ai-account.ps1 -Action models -Id <id> -List`. Present `new`, `gone`, and `kept`, then ask which deployments, default, and any Claude aliases to save. Wait for the owner's answer before running without `-List`. The write uses `-Deployments`, `-Default`, and optional `-Aliases`; `models` replaces the complete deployment list. Validate personalisation after writing. Never put a token or key in this block.
