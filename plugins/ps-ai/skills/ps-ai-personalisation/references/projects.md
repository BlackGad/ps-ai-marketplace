# Project entries

On first overseer takeover, read `id` from `<repo>/.agents/configuration/project.json`. If `projects.<id>` is absent, ask once where to notify, including `none`; add `{ "label": "<neutral-label>", "notify": [] }` with the owner's answer and validate. Do not key by path or add last-seen metadata. A move or clone retains the id.

Use `default.notify` before registration. `notify` names must exist in `communication.channels`. Project `launch.<tool>` and routing overrides are optional owner choices.

Clean up only when asked. Show each candidate id and settings separately, ask confirmation per entry, then remove only confirmed entries. Never remove because a path is missing or an entry is old. Validate each change.
