# Parallel lanes

At most two independent lanes, each in its own detached worktree `.agents/temp/floor-<n>/`. Split by owner type and disjoint files, not by equal task counts. Name file ownership in each task prompt. If two tasks change the same owner or lifecycle path, run them sequentially. A legion member needing another lane's file stops and reports the dependency; the overseer resolves it.

Review each lane's local commits and reports before integration. Cherry-pick into the working branch; preserve both handoff evidence sets and write one correct next action. Run affected indexed gates on the integrated tree. Remove lane worktrees only after needed reports and patches are archived. Never amend or force-push to resolve a lane collision.
