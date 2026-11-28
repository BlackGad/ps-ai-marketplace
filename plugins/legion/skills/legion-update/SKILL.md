---
name: legion-update
description: Use when the owner asks about legion updates or wants to update legion, or the session notice says a newer legion is available; never in member mode.
---

# Update legion

Never use this skill in member mode. It does not need repository setup or an overseer lease. A session notice only offers an update; it does not authorize one.

Speak to the owner in plain words. Show a command only when they ask for it or must run it themselves.

1. Run a fresh check, even after a session notice, using [commands.md](references/commands.md).
2. Tell the owner the installed and available versions. If no newer version is available, say so and stop. If the check fails, explain that the versions could not be confirmed; use the fallback in the reference without claiming a version you could not read.
3. Ask whether they want to update legion. If they decline, stop. On Windows, give the owner the terminal instructions in the reference and end the update work in this session. On macOS and Linux, run the update after the owner's yes.
4. Check the result in the terminal, or use the reference to check the log if the update was scheduled. After a successful update, tell the owner to run `legion` in the repository to load the new skills and reopen the last conversation. If the update fails, explain what failed and what remains to be done.
