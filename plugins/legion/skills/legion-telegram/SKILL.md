---
name: legion-telegram
description: Use when the owner wants to talk using Telegram or add a Telegram destination.
---

# Telegram

Read the [owner's notes](../legion-personalisation/references/fields.md) first. Reuse known answers.

Follow [sending](references/send.md) for every owner-facing Telegram update, including receipts, progress, decisions, completions, handoffs and spontaneous updates.

Choose supported accounts. Check what is already ready. Preview missing work and wait for yes. Follow [installation](references/install.md).

Guide the owner through [connection](references/connect.md). The owner handles secrets and pairing alone. Never request or inspect credentials.

Each repository's overseer has its own bot. For a second bot, tell the owner in plain words:

1. Ask BotFather for a new bot (`/newbot`) and copy its token.
2. Legion starts that repository's overseer with its own bot folder.
3. In that session, the owner runs `/telegram:configure`, pastes the token, then pairs with `/telegram:access`.
4. From then on that overseer starts its own bot.

A bot set up before this change lives in the account's default folder. The owner moves it by running `/telegram:configure` again in the new session; there is no migration. Launch details are in [bot folder](references/bot-folder.md). One session uses one Telegram channel, and accounts on third-party providers (Foundry) cannot use channels.

Check each account and destination. Record only verified bindings. Keep unfinished work in the notes. Do not claim a failed connection is ready.

Agree on a short test. Send the text and bundled image using [sending](references/send.md). Ask the owner to confirm both arrived.

Offer to continue oversight in the chosen account. Name it before a relaunch. A session can oversee without a channel.
