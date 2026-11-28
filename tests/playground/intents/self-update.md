---
covers: plugins/legion/src/legion/cli/*, plugins/legion/src/legion/core/_stop_event.py, plugins/legion/src/legion/services/accounts/*, plugins/legion/src/legion/services/channels/_overseer.py, plugins/legion/src/legion/services/installation/*, plugins/legion/src/legion/services/lifecycle/*
os: linux
budget: 15
---

Goal: bring back a launched overseer automatically after updating Legion to the checkout.

Use a disposable container with no logins or mounted credentials. Install the actual 0.23.1 release as a uv tool. Put a fake Claude CLI on PATH and register a disposable account and Telegram binding. The fake CLI can use `tests/python/legion/fake_cli.py` with `FAKE_OVERSEER_REQUEST` set to the checkout and `FAKE_OVERSEER_UVX=1`. Keep the stock CLIs off PATH so the checkout update reaches only fakes.

1. Set up a scratch repository with a handoff. Start the fake overseer through the installed launcher with a literal argument and a channel. Check that 0.23.1 has no self-update option.
2. Let the fake session take the lease and invoke the self-update via uvx from the checkout. Use real uv for the command replacement. Watch the running launcher exit and check that the installed command now offers self-update.
3. Compare the two launches. The account folder, repository, channel folder and literal arguments match, and the new invocation uses the original conversation ID with the CLI's resume argument. Read the repository result and handoff.
4. Repeat from the updated installed command. An unchanged checkout reports that Legion is current. Stop the container when finished.

Report the commands, timing, result line, and any friction or failures. Never try this in an owner session on the host.
