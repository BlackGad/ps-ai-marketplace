Captured on Windows on 2026-11-19 using the installer's closed-stdin subprocess adapter:

- `claude plugin list --json`
- `claude plugin marketplace list --json`
- `codex plugin marketplace list` and `--json`
- `copilot plugin marketplace list` and `--json`

These are the legion entries and relevant text headers extracted from the real output. User names and home paths are neutralised. JSON field names, values describing installation state, and the Codex JSON envelope are preserved. All captures exited 0 with empty stderr.

Codex's text ROOT is a checkout; its JSON `marketplaceSource.source` matches the read-only `config.toml` marketplace entry. Copilot's JSON `source` retains the `GitHub: ` prefix. Claude's user plugin has `enabled: true` and `projectEnabled: false`.
