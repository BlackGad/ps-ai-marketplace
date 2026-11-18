# Independent reviews

Freeze a worktree at the review commit under `.agents/temp/floor-<n>/`; reviewers read that commit and cannot edit the checkout. Pick reviewers from personalisation `routing.review` across different **model families**, not merely account ids. Use the matching tool skill to construct read-only invocations; Copilot reviewers need explicit write and shell denials. Paid accounts require owner approval. Reviewer content comes from an installed review skill when present; ps-ai owns dispatch and synthesis.

Send the same [prompts/review.md](prompts/review.md) brief to each reviewer, with repo rules, spec, plan rulings, base and review commit. Keep reports separate; no reviewer sees another's report. Use one independent verifier per report with [prompts/verify.md](prompts/verify.md). Confirm or refute each finding against file:line evidence. Record refutations and reasons in milestone history.

Merge confirmed findings by underlying rule and owner type. Rank agreement between families first, then severity; report at most one screen to the owner. Ask for the fix round before dispatching [prompts/fix.md](prompts/fix.md). A review never edits the frozen checkout. If reviewer family diversity cannot be met with configured accounts, record the limitation and ask the owner how to proceed.
