# Create owner configuration

1. Ask one question at a time, in order: communication language and question cadence; channels or none; agents and existing wrappers; account roles/models; routing; knowledge; notes. Use answers already given without re-asking. Ask only for missing choices that block a valid file.
2. Create `<home>/.agents/configuration/ps-ai-personalisation.json` with the schema's required top-level fields: `schemaVersion: 1`, `communication.channels`, `agents`, `routing`, `knowledge.backend`, `projects`, `default`. See [fields.md](fields.md). Empty routing lists and `knowledge.backend: none` are valid while choices remain open. Validate this initial JSON.
3. Register each existing wrapper through the selected tool skill's `references/accounts.md`. The JSON must exist first. Do not replace a wrapper or recreate its login. Account IDs may not shadow a command on PATH; the command and account id may differ. Validate after each registration.
4. Add roles, models, launch arguments, and routing according to owner answers. For new accounts use the matching tool skill and `-Action add`; the owner logs in themselves. Never handle credentials.
5. Create `ps-ai-notes.md` from [notes-template.md](notes-template.md) with stated preferences. Install the launcher shim using [launcher.md](launcher.md) if setup includes it. Re-read files and validate final JSON.

In a temporary owner home, substitute it for every `~` and pass `-HomeRoot <temp home>` to every account or launcher script. `ps-ai-validate.ps1` has no `-HomeRoot`; pass the temp home's full JSON path with `-Path`.
