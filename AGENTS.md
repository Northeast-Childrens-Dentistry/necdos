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
Check `gh run list --limit 5` first. The rules below are from `.github/workflows/build.yml` on `main` (October 2026, after #4 merged).

| Action | Effect |
|---|---|
| Open or update a PR | Safe. Builds and lints only, never pushes or signs, and runs in its own concurrency group. |
| Merge to `main` (code, not just `*.md`/`docs/`) | **Starts a build** that pushes `testing-*`, signs, boot-tests, then promotes to `stable`. Clinic PCs and any VM following `stable` will update to it. |
| Several runs on `main` | They queue (`cancel-in-progress` only for PRs); promotions are serialized. |
| `workflow_dispatch` on `main` or a branch | Builds, signs and publishes `candidate*` tags. Doesn't touch `stable`. |

When unsure: open a PR and don't merge or dispatch until the user says their test is finished. Merging is now a release.

## Where things go
- KDE/Plasma defaults for all users go in `system_files/usr/share/kde-settings/kde-profile/default/xdg/`. A user's own `~/.config` copy takes precedence over these, so existing users may not get a change.
- `build_files/build.sh` ends with build-time checks. Add one for each change, so the build fails if the change didn't land.
- Test desktop behaviour in a VM before calling it done.
