---
name: review
description: Run the factory's reviewers on their own, without a factory job — on the current branch or a pull request, in a chat or in CI. Lenses security, code, ux, ui; uses factory/profile.md when the repo has one. Use for /factory:review, "review this branch", "security review of my PR".
argument-hint: "[security,code,ux,ui | all] [--base <ref>] [--out <dir>] [--context <file>]"
allowed-tools: Bash(git diff *), Bash(git log *), Bash(git fetch *), Bash(git rev-parse *), Bash(git symbolic-ref *), Bash(mkdir *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*), Bash(python3 ${CLAUDE_PLUGIN_ROOT}/scripts/*), Read, Write, Glob, Grep, Agent
---

# Review without a job

Runs the factory's reviewers on a branch in **standalone mode**. Same agents,
same rules and the same profile as inside the factory — just no spec, build or
rounds.

Arguments: `$ARGUMENTS`

`FACTORY_HOME` = `${CLAUDE_PLUGIN_ROOT}`.

## 1. Settle the inputs

- `REPO` = `git rev-parse --show-toplevel`.
- **Lenses:** the comma list in the arguments; `all` = security, code, ux, ui.
  Default: the profile's `lenses` if `REPO/factory/profile.md` exists, else
  `security,code`.
- **BASE:** `--base <ref>`, else the upstream default branch
  (`git symbolic-ref refs/remotes/origin/HEAD`, fallback `origin/main`). Run
  `git fetch origin` first if the ref is missing. The diff is
  `git diff BASE...HEAD`; if it is empty, say so and stop.
- **OUT dir:** `--out <dir>`, else `REPO/.factory-review/<UTC timestamp>/`.
  Make sure `.factory-review/` is in `.gitignore` before writing there (add it
  if not; tell the human). Create the dir.
- **CONTEXT:** `--context <file>` if given (the review workflow passes the PR
  title and body); else write `OUT/context.md` with the branch name and
  `git log --format='- %s%n%b' BASE..HEAD`.

## 2. Skip what has no surface

`ux` and `ui` run only if the diff touches user-facing files: the profile's
`ui_paths`, or — without a profile — web/app UI files (`*.html`, `*.css`,
`*.svelte`, `*.vue`, `*.tsx`, `*.jsx`, templates, i18n files). Otherwise write
their file yourself: line 1 `VERDICT: PASS`, line 3 `N/A — the diff has no
user-facing surface (skipped).`

## 3. Run the reviewers

Spawn the remaining lenses **in one message, in the background**:
`factory:reviewer-<lens>` with the prompt

```
MODE: standalone
REPO: <REPO>
BASE: <BASE>
OUT: <OUT>/review-<lens>.md
CONTEXT: <context file>
FACTORY_HOME: <FACTORY_HOME>
```

Wait for all. A missing file → re-spawn that lens once; still missing → write
it yourself as `VERDICT: CHANGES` with "reviewer produced no file".

## 4. Summarise

Write `OUT/summary.md`:

```markdown
VERDICT: PASS | CHANGES        ← CHANGES if any lens says CHANGES
| Lens | Verdict | Must-fix | Notes |
|---|---|---|---|
| security | CHANGES | 2 | 1 |
…
```

Count `[must-fix]` and `[note]` lines per file. Then show the human the table
and every `[must-fix]` line with its lens, and the paths of the review files.
Do not change any code — the human (or the factory) decides what to fix.
