# File a reusable lesson

Write the general problem, the cause or decision with its reason, the solution, and when to use it again. Tag it with the neutral knowledge label in repository workflow, never a client name. File after a hard problem and during milestone close-out.

Before and after writing, check:

- [ ] No client names or identifying project names.
- [ ] No source code or proprietary snippets.
- [ ] No hosts, domains, URLs, IP addresses, or physical/email addresses that identify a client.
- [ ] No secrets, credentials, tokens, or credential file contents.
- [ ] The project tag is only the neutral `label`.

Replace specifics with roles such as “the service” or “the readiness signal.” If removing specifics destroys the lesson, drop it. A behavior-changing lesson also belongs in `~/.legion/configuration/notes.md`.

After the note passes the checks, commit it in the hub: the one named in `~/.config/llm-wiki/config.json` (`hub_path`, then legacy `resolved_path`), or `~/.legion/knowledge` when no pointer is saved, as [consult.md](consult.md) says. Commit only if the hub is its own git repository, meaning `git -C <hub> rev-parse --show-toplevel` prints the hub itself; otherwise skip the commit and say so. Stage by path only the files this filing changed (the note, its indexes, the log) with `git -C <hub> add -- <paths>`, never `git add -A`, then `git -C <hub> commit -m "file: <note title>"`.
