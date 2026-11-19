# Parallel lanes

At most two independent lanes, each in its own detached worktree `.legion/temp/floor-<n>/`. Split by owner type and disjoint files, not by equal task counts. Name file ownership in each task prompt. If two tasks change the same owner or lifecycle path, run them sequentially. A legion member needing another lane's file stops and reports the dependency; the overseer resolves it.

Launch only planned tasks with the lane worktree as the process working directory. Before dispatch, copy any needed ignored specs and plans into that worktree and put its prompt, report, and logs under its own `.legion/temp/`. Legion runs without a sandbox but may work only inside that assigned worktree. The overseer copies needed evidence out before cleanup; workers never access sibling lanes or the main working tree.

In Private mode, a new lane or review worktree has no `.legion/`. Before dispatch, the overseer copies `.legion/configuration/` and `.legion/scripts/` from the main tree into the same paths in the worktree. Workers treat these copies as read-only; script or rules changes go through the main tree. Shared mode needs no copy. Git shares `info/exclude` across worktrees, so its `.legion/` entry keeps the copies and scratch ignored.

Review each lane's local commits and reports before integration. Cherry-pick into the working branch; preserve both handoff evidence sets and write one correct next action. Run affected indexed gates on the integrated tree. Remove lane worktrees only after needed reports and patches are archived. Never amend or force-push to resolve a lane collision.
