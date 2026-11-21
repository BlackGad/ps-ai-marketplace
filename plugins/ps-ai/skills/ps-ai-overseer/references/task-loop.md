# Task loop

Use the terms and work sizes in [the overseer skill](../SKILL.md#terms-and-work-size).

1. Read the task from the plan and its spec. For ad hoc work, write one explicitly scoped brief from the owner's request; no milestone plan is needed. In either case, dispatch inside the assigned repository worktree. Put the available spec and plan, rules file, base commit, file scope, report path, checks, commit message, and stop points into [prompts/task.md](prompts/task.md). For an ad hoc brief, omit absent plan/spec inputs from the prompt. Keep every task input inside that worktree; copy ignored inputs into its `.legion/temp/` before dispatch if needed, and pass the local absolute paths. Use `ps-ai-legion` for the worker contract; do not duplicate it in the prompt.
2. Read [owner notes](../../ps-ai-personalisation/references/fields.md) and repository workflow before dispatch. Owner preferences always win; save newly stated preferences using the [shared memory rule](../../ps-ai-personalisation/SKILL.md#identity-and-hard-rules). Without preferences, prefer cheaper accounts suited to [working-tier tasks](#model-tiers) and spread work across them. Say which agent was chosen. Pass no model flag by default; follow [model tiers](#model-tiers) when choosing a model. Do not discover models or offer model lists for subscription agents. Check the legion consent below before launching. Ping through the tool skill before declaring an account out of credit. If no legion account is usable, follow [milestone-flow.md](milestone-flow.md#execution-choice) for a milestone. For ad hoc work, use the [overseer's in-session fallback](../SKILL.md#identity-and-hard-rules) if possible; otherwise record the blocked next action and tell the owner.
3. Create task prompt/report/log paths under the assigned worktree's `.legion/temp/`. Write a handoff row and next action to disk **before** the tool skill launches the process. Use `skills/ps-ai-<agent.tool>/SKILL.md` and its run reference (stop if the tool skill is missing) with `LEGION_ROLE=member` and `LEGION_TASK=<prompt path>` on that process only. Set the process working directory to the assigned worktree and inherit the owner's environment. Legion runs without a sandbox; dispatch only the plan task or scoped ad hoc brief, inside that worktree. Long work runs in the background; wait for completion, do not poll logs. A simulation describes the proposed run without executing it; show commands only when requested or when the owner must run them themselves.
4. Read the report and inspect status, commit message, changed-file list, and the risky change against the task scope. Check tests, script results, open questions, encoding, and user rulings. Fixed before/after gates come from `workflow.md` and `scripts/index.md`. Never run a missing or unindexed gate.
5. If a real defect remains, add the scoped fix to the plan or ad hoc brief before dispatch. A scope or API question goes to the owner. If a worker reports a missing or wrong-version tool, stop dispatching the blocked task and ask the owner how to proceed; do not tell legion to download or install it. If an account ran out mid-task, save a patch and fresh-run on another routed account; resume only on the original account and folder. Do not amend or force-push. Record the result, clear the row, and write the next handoff state before the next task; commit it with the task's stage.

Legion writes its report; overseer alone writes handoff. Delivery follows `workflow.md` and owner rulings. Do not merge to main for `merge-request` delivery.

Before dispatch in a worktree, prepare its configuration and scripts using [lanes.md](lanes.md), including the Private copies. In Private mode, all worktrees share `.git/info/exclude`. The `.legion/` entry keeps each worktree's prompts, reports, and logs out of code Git. Commit state through the owning Git repository in [takeover.md](takeover.md).

## Model tiers

Runs pass no model by default. Use each account's own CLI default unless owner notes name a model or allow a tier for this work. These are examples, not fixed model assignments:

| Tier | Work | Examples |
| --- | --- | --- |
| Higher | Review, design, planning and other brain work | opus, astra, argon |
| Working | Coding tasks | sol, sonnet, carbon |

Never choose Fable automatically. Use it only when the owner asks.

Before the first higher-tier choice, read notes and the current conversation for an answer. If none exists, ask once: “Higher-tier models can cost more. May I use them for reviews, design and planning?” Wait for the answer. Save a free-form line in owner notes, such as “Higher-tier models are allowed for reviews and design.” Save a refusal too, such as “Use each agent's default model; do not choose higher-tier models.” On refusal, pass no model flag. Never ask again while notes hold an answer; only a later owner change replaces it.

Tell the owner once: “The overseer works best when you start its session on a higher model; it cannot switch its own model.” Record that this was said in owner notes so later sessions do not repeat it.

## Foundry runs

For a Foundry agent, resolve a requested tier word against separate tokens in discovered deployment names or models and pass the matching deployment name, newest numeric version first; use the token and version rules in [Foundry model mapping](../../ps-ai-personalisation/references/foundry-models.md). If the word has no match or the newest versions tie, ask the owner about that choice only.

## First legion dispatch

Read notes and the current conversation for the owner's legion access answer. If an explicit answer exists, follow it and record it in notes if missing. Never ask again. If no answer exists, explain and ask before the first dispatch:

“Legion members run without a sandbox and with your full user rights so they can edit, run checks, and commit using your installed tools. Sandboxes can hide those tools. Workers must stay in their assigned repository or worktree, never push or touch other folders, and never download or install tools. If a tool is missing or the wrong version, they stop and report it. These are instructions, not an enforced access boundary. Do you allow legion work?”

Wait for the answer. Record approval or refusal as a plain sentence in owner notes, then re-read them. Reuse an explicit answer already given in the conversation. A refusal leaves legion unused; follow the execution fallback above. Only an explicit later change from the owner replaces the recorded answer. Add no JSON setting.
