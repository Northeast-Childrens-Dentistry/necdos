# Notes for agents

## Pick up work from issues
Each task is a GitHub issue on the **NECD OS — Roadmap** project (`gh project view 2 --owner Northeast-Childrens-Dentistry`).
The issue body is the plan and its source of truth. The latest issue comment records the current state: decision, branch, worktree and what's left.
Read the issue before you start, and add a comment whenever the state changes.

## Several sessions share this repo
- Do one task per git worktree, branched from `origin/main`: `git worktree add -b <branch> ../necdos-<topic> origin/main`.
  Never switch branches, stash or commit in a checkout another session is using.
- Leave other sessions' uncommitted changes alone.

## Don't disturb a build someone is testing
Check `gh run list --limit 5` first. The rules below are from `.github/workflows/build.yml` on `main` (October 2026).

| Action | Effect |
|---|---|
| Open or update a PR | Safe. Builds and lints only, never pushes or signs, and runs in its own concurrency group. |
| Merge to `main` | Doesn't start a build by itself today. |
| `workflow_dispatch` on `main` | **Cancels a `main` build already in progress** (`cancel-in-progress: true`), then publishes and signs the `candidate` tags. |
| `workflow_dispatch` on a branch | Builds without publishing. |

When `feat/auto-updates` (#4) merges, these rules change:
- A push to `main` builds `testing` and, if checks pass, promotes it to `stable`. That changes what clinic PCs and any VM following those tags will update to.
- Runs on `main` queue instead of cancelling each other.
- Dispatching from a branch publishes `candidate-*` tags.

Whoever merges #4 updates this table. When unsure: open a PR and don't merge or dispatch until the user says their test is finished.

## Where things go
- KDE/Plasma defaults for all users go in `system_files/usr/share/kde-settings/kde-profile/default/xdg/`. A user's own `~/.config` copy takes precedence over these, so existing users may not get a change.
- `build_files/build.sh` ends with build-time checks. Add one for each change, so the build fails if the change didn't land.
- Test desktop behaviour in a VM before calling it done.
