# Git Worktrees — a practical guide (for this repo)

A **worktree** is a second working directory backed by the *same* repository. It lets you
have two branches checked out at once, in two folders, without stashing or switching. Your
main checkout stays exactly as it was while work happens in the worktree's folder.

## What we set up for the learning-loop work

| Thing | Value |
|---|---|
| Main checkout | `/Users/ukcci1jbo/projects/tianlu` (branch: `feature/persistent-local-dev-twin`) |
| Worktree folder | `/Users/ukcci1jbo/projects/tianlu/.claude/worktrees/feature+learning-loop` |
| Worktree branch | `worktree-feature+learning-loop` (branched from `origin/main`) |

Both folders share ONE `.git`. Commits made in the worktree land on
`worktree-feature+learning-loop`; your main checkout's branch is untouched.

> The `/` in the intended name became `+` because the native worktree tool sanitizes
> slashes. That's cosmetic — when we push, we can give it the clean name
> `feature/learning-loop` on the remote (see "Merging back", step B).

## Everyday commands

```bash
# See all worktrees and which branch each is on
git worktree list

# Where am I / what branch is this folder on?
pwd
git branch --show-current

# Normal git works inside the worktree folder exactly as usual
git status
git log --oneline -5
```

**Moving between them is just `cd`** — there's no "switch worktree" command:

```bash
cd /Users/ukcci1jbo/projects/tianlu/.claude/worktrees/feature+learning-loop   # into the learning-loop work
cd /Users/ukcci1jbo/projects/tianlu                                            # back to the main checkout
```

Rule of thumb: **one branch per folder.** You cannot check out the same branch in two
worktrees at once — git refuses, which is a feature (it prevents clobbering).

## Merging the work back to main

Do these from your **main checkout** (`/Users/ukcci1jbo/projects/tianlu`), after the
learning-loop branch is complete and its final review is clean.

### Option A — local merge (simplest, no PR)

```bash
cd /Users/ukcci1jbo/projects/tianlu
git fetch origin                         # get the latest main
git checkout main
git merge --ff-only origin/main          # make sure local main matches remote
git merge worktree-feature+learning-loop # bring the learning-loop commits onto main
git push origin main
```

`--ff-only` on the second line just guards against a surprise divergence. If the final
`git merge` reports conflicts, git pauses and tells you which files — resolve them, `git add`
those files, then `git commit` to finish the merge. (This branch only adds new files under
`docs/learning/`, `docs/superpowers/`, and `.claude/`, so conflicts with the installer work
are unlikely.)

### Option B — push and open a Pull Request (recommended for a shared repo)

Because another collaborator shares this repo, a PR gives them visibility and runs CI:

```bash
cd /Users/ukcci1jbo/projects/tianlu/.claude/worktrees/feature+learning-loop
# push the local worktree branch to a cleanly-named REMOTE branch:
git push -u origin worktree-feature+learning-loop:feature/learning-loop
gh pr create --base main --head feature/learning-loop \
  --title "Add /learn Socratic research loop (docs/learning)" \
  --body "Isolated learning workflow under docs/learning/ + learn-* .claude assets."
```

Then merge the PR from the GitHub UI (or `gh pr merge`) once it's approved and green.

## Cleaning up the worktree when done

After the branch is merged, remove the worktree folder so it doesn't linger:

```bash
cd /Users/ukcci1jbo/projects/tianlu
git worktree remove .claude/worktrees/feature+learning-loop
# if git says it's dirty and you're sure: add --force
git branch -d worktree-feature+learning-loop   # delete the now-merged local branch
git worktree prune                             # tidy any stale worktree metadata
```

In this Claude session, the equivalent is the `ExitWorktree` tool (keep or remove) — I'll
handle that at the end via the finishing-a-development-branch step.

## Mental model / gotchas

- **Shared history, separate folders.** `git log`, tags, and remotes are shared; only the
  *checked-out branch and working files* differ per folder.
- **Don't delete the worktree folder with `rm -rf` alone** — that leaves git metadata
  behind. Use `git worktree remove` (or follow with `git worktree prune`).
- **`git clean -fdx` inside the worktree** will wipe untracked scratch (including
  `.superpowers/sdd/`). Avoid it here.
- **Uncommitted files don't travel between worktrees.** That's why the spec/plan had to be
  copied into this worktree explicitly — they were untracked in the main checkout.
