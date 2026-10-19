---
name: gitbutler-stack-merge
version: 0.1.0
description: "Merge a GitButler PR stack by pulling, pushing, enabling GitHub auto-merge with gh, waiting for each PR, and repeating until the stack is integrated. Use when asked to merge a GitButler stack, enable auto-merge across stacked PRs, or babysit stacked branches until merged."
author: foxfire/pi
---

# GitButler Stack Merge Loop

Use this when the user asks to merge a GitButler stack or repeatedly enable auto-merge for stacked PRs.

## Required Companion Skill

Load and follow the GitButler skill first. Use `but` for version-control writes (`pull`, `push`, applying/unapplying branches, PR creation via GitButler). Do **not** use raw `git` write commands.

Use `gh` for GitHub PR state and auto-merge when GitButler auto-merge is broken or insufficient.

## Procedure

1. Inspect the current stack.

   ```bash
   but status -fv
   but branch list --review --no-check
   ```

   In `but status`, the short two-letter labels at stack/branch headers (for example `ub`, `ho`) are GitButler CLI selectors. PR numbers are shown as `#N` when review metadata is available.

2. Sync and push before enabling merge.

   ```bash
   but pull --check
   but pull
   but push
   ```

   If `but pull --check` reports integrated branches, run `but pull` so GitButler removes/rebases local stack entries before continuing.

3. Identify the next open PR in merge order.

   Prefer the PR whose base is already merged or is the next lower branch in the stack. Check PR state with:

   ```bash
   gh pr view <number> --json number,title,state,isDraft,baseRefName,headRefName,mergeStateStatus,autoMergeRequest,statusCheckRollup \
     --jq '{number:.number,title:.title,state:.state,isDraft:.isDraft,base:.baseRefName,head:.headRefName,mergeStateStatus:.mergeStateStatus,autoMerge:(.autoMergeRequest != null),checks:[.statusCheckRollup[]? | {name:.name,status:.status,conclusion:.conclusion}]}'
   ```

   To check for existing/duplicate PRs for a branch:

   ```bash
   gh pr list --head <branch-name> --state all --json number,state,title,baseRefName,headRefName,mergedAt,url
   ```

4. Make draft PRs ready if needed.

   ```bash
   gh pr ready <number>
   ```

5. Enable auto-merge with GitHub CLI.

   ```bash
   gh pr merge <number> --auto --squash
   ```

   If checks are already green and branch protection allows it, this may merge immediately. Otherwise it schedules auto-merge.

6. Wait for the PR to merge.

   Poll with separate `gh pr view` commands (avoid compound shell loops if pi-auto review-only routing blocks them):

   ```bash
   gh pr view <number> --json number,state,mergeStateStatus,autoMergeRequest,statusCheckRollup \
     --jq '{number:.number,state:.state,mergeStateStatus:.mergeStateStatus,autoMerge:(.autoMergeRequest != null),checks:[.statusCheckRollup[]? | {name:.name,status:.status,conclusion:.conclusion}]}'
   ```

   If not merged yet, wait briefly (`sleep 20` or `sleep 40`) and poll again.

7. After each merge, sync GitButler and push the remaining stack.

   ```bash
   but pull --check
   but pull
   but push
   but status -fv
   ```

   Repeat from step 3 until all relevant PRs are `MERGED` and `but status -fv` shows no active stack branches.

8. Final verification.

   ```bash
   but status -fv
   gh pr list --state open --head <branch-name> --json number,state,title,url
   gh pr view <number> --json number,state,mergedAt --jq '{number:.number,state:.state,mergedAt:.mergedAt}'
   ```

   Confirm there are no unassigned changes and no open PRs for the stack heads.

## Pitfalls

- `but pr auto-merge <selector>` may partially succeed and then fail with a GraphQL decode error. Prefer `gh pr merge <number> --auto --squash` when asked to use `gh` or when `but pr auto-merge` fails.
- GitButler and GitHub state can lag after a PR merges. Run `but pull --check && but pull` before deciding a branch still needs a new PR.
- Do **not** create a new PR just because `but branch list` still shows a local/unapplied branch. First check `gh pr list --head <branch> --state all`; if the existing PR is merged, pull again and let GitButler mark it integrated.
- If a duplicate PR is accidentally created for already-merged commits, close it with a clear comment.
- Some PRs may be drafts. `gh pr merge --auto` fails with “Pull Request is still a draft”; run `gh pr ready <number>` first if the user’s intent is to merge it.
- In pi-auto environments, configured review-only prefixes may reject complex shell loops around `gh`. Use individual `gh` commands plus separate `sleep` calls instead of `for`/`while` shell scripts.
- Auto-merge can show `autoMerge: false` immediately after a successful `gh pr merge --auto --squash` if the PR merged immediately. Always trust `state: MERGED` over `autoMergeRequest`.

## Verification Evidence to Report

- The `but pull`, `but push`, and final `but status -fv` outputs.
- Each PR number processed and final `state` / `mergedAt`.
- Any duplicate PR closed or blocker encountered.
