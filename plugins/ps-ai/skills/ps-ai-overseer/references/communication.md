# Owner communication and session handoff

Follow [owner notes](../../ps-ai-personalisation/references/fields.md) and repository workflow before communication or account choices. Report meaningful steps in two to five plain sentences: result, evidence and next action. For progress, inspect handoff, commits and reports. Put open decisions first when the owner is away. Send reports and owner questions as the [console and channels rule](../../ps-ai-personalisation/SKILL.md#identity-and-hard-rules) says.

Any owner-started repository session may take the lease on request, including one with no channel. Declining a relaunch permits current channel-free oversight. No preset overseer account exists.

For requested destinations, resolve each ID and its bindings. Clarify ambiguous targets. Route setup and sending through `skills/ps-ai-<kind>/SKILL.md`; stop if missing. Finish missing setup before channel handoff. Notes override kind defaults.

Prefer the current account when it is bound to every selected destination and required session tools are available. Otherwise name a supported bound alternate before an authorized relaunch. If the current tool is unsupported, explain and name the alternate; never silently change accounts. Disjoint bindings cannot share one launch. The launcher validates explicit choices; it never selects from prose.

After approval, handoff order is strict: write accurate handoff to disk; release the lease; launch the chosen account with explicit channels in the same repo; tell the owner where to continue; stop old-session overseer work. Launch through:

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-overseer.ps1 -Account <id> -Tool <tool> -Channel <id[]> -Repo <repo>
```

`-Account` is optional when one account fits; pass it when several do. One matching channel is added by default; `-NoChannel` skips it. Setup writes the `ps-ai-overseer` command, so the owner can also run it directly.

The new session takes the lease, reads handoff and confirms takeover through the channel skill. A failed launch leaves accurate handoff evidence; the old session must reacquire the lease before resuming oversight. No overlapping overseers.

Before every owner question after taking the lease, write the exact decision needed to handoff. Pre-lease questions write nothing. Ask real design, scope, API, budget or tool choices. Recommend first and explain tradeoffs briefly. Ask as the [console and channels rule](../../ps-ai-personalisation/SKILL.md#identity-and-hard-rules) says. Direct launcher invocation is authorization to launch. Simulations describe proposed actions without running them.
