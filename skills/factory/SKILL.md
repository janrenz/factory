---
name: factory
description: Run the software factory. Takes a feature through spec → build → parallel reviews (security, ux, ui, code) → approval → merge, tracking every step in factory/jobs/<job-id>/state.json (job ids come from GitHub issues). Use for /factory <feature>, /factory next, /factory spec|build|respec|approve|rework <job-id>, /factory init, /factory board.
argument-hint: <feature> | init | next | board | spec <feature> | build <job-id> | respec <job-id> <note> | approve <job-id> | rework <job-id> <note>
allowed-tools: Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/*), Bash(python3 ${CLAUDE_PLUGIN_ROOT}/scripts/*)
---

# Software factory

The session running this skill is the **orchestrator**. It runs the loop, spawns
every agent, and is the **only writer of the jobs' `state.json` files**. It never
writes product code itself.

Arguments: `$ARGUMENTS`

`FACTORY_HOME` = `${CLAUDE_PLUGIN_ROOT}` — the factory core (agents, scripts,
dashboard, templates). It changes with every version: never write into it.
Pass it to every agent as `FACTORY_HOME`.

## The loop

```
   feature ─► spec-writer ─► [stack gate] ─► builder ◄──────────────┐
                                               │                    │
                      ┌──────────┬─────────────┼───────────┐        │
                      ▼          ▼             ▼           ▼        │
                  security       ux         ui design     code      │
                      └──────────┴──────┬──────┴───────────┘        │
                                        ▼                           │
                               WAIT FOR ALL reviews ── CHANGES ─────┘
                                        │ all PASS     (max 2 rework rounds)
                                        ▼
                                     CI gate
                                        ▼
                                     approver ── ESCALATE ─► needs-human
                                        │ APPROVE                │
                                        ▼                        ▼ /factory approve
                                      merge ◄────────────────────┘
```

Agents (from this plugin): `factory:spec-writer`, `factory:builder`,
`factory:reviewer-security`, `factory:reviewer-ux`, `factory:reviewer-ui`,
`factory:reviewer-code`, `factory:approver`, and `factory:prototyper` for the
design gate. Spawn them with exactly these `subagent_type` names.

## The profile

`REPO/factory/profile.md` holds everything project-specific. Read its
frontmatter once per command (`python3 FACTORY_HOME/scripts/profile.py`):

- `flavour` — how the factory is run (below).
- `main` — the branch jobs start from and merge into (default `main`).
- `ci_workflow` — workflow file of the CI gate; `none` skips the gate.
- `lenses` — which reviewers run (always `security` and `code`).
- `ui_paths` — globs that make a rework round re-run ui/ux.
- `secret_scan` — run `FACTORY_HOME/scripts/gitleaks.sh` before every push.
- `docs.*` — AGENTS.md, NFRs, design guideline, secure-coding guideline.
- `secure_coding_rules` — the rule range the security checklist must cover.
- `issue_ids_from` — jobs below this number predate issue ids (default 1).
- `design.source` — where screens are designed: `figma`, `figcraft`,
  `prototype` or `none`; `design.file`, `design.tokens` (pinned token snapshot),
  `design.prototypes` (approved prototypes kept in the repo).

The Markdown sections of the profile are for the agents; you don't interpret them.

## Flavours

The loop is the same in every flavour. The flavour decides where a job comes
from, where a human answers, and whether you run interactively.

| | `local` | `jira` | `ticket-pr` |
|---|---|---|---|
| started by | `/factory …` in a chat | Jira label → CI | merged `docs/tasks/todo/*.md` → CI |
| human gates | AskUserQuestion in the chat | Jira comment + label, PR review | PR review |
| you run | interactive | headless (`claude -p`) | headless (`claude -p`) |

Headless (`jira`, `ticket-pr`): never call AskUserQuestion. Wherever this skill
says "ask the human", set `stage: needs-human` with a `note`, post the question
as a comment on the job's issue (and, for `jira`, on the Jira ticket via
`FACTORY_HOME/scripts/jira.sh comment`), commit and push the job folder, and
stop. The human answers with a comment that the flavour's workflow turns into
`/factory approve|rework|build|respec …`. Details: `FACTORY_HOME/flavours/<flavour>.md`
— read it once at the start of every command in a headless flavour.

## Paths

- `REPO` — `git rev-parse --show-toplevel`. The main checkout; it stays on `main`.
- `JOB_DIR` — `REPO/factory/jobs/<job-id>/`. All job markdown lives here, on `main`.
- `WORKTREE` — `REPO/.worktrees/<job-id>/`, a git worktree on branch
  `factory/<job-id>`. All product code is written and committed here, so the
  main checkout and the dashboard never change branch.
  **Multi-repo jobs** (`JOB_DIR/targets.json` lists repos, flavour `jira`): the
  jobs live in the harness repo; `WORKTREE` is a folder with one worktree per
  target, `WORKTREE/<repo>/`, each on branch `factory/<job-id>` of that repo.
- `ROUND_DIR` — `JOB_DIR/round-<n>/`.
- `STATE` — `JOB_DIR/state.json`, the job's board state.

## Rules

1. **Files, not conversation.** Agent prompts contain only the job id and the
   absolute paths above plus `FACTORY_HOME`. Everything else an agent needs is
   in files.
2. **One file per agent.** spec-writer → `spec.md`; builder → `build.md` (+ code
   in `WORKTREE`); reviewers → `ROUND_DIR/review-<lens>.md`; approver →
   `decision.md`. You write only `state.json`, `backlog.md`,
   `stack-decision.md`, `rework-<n>.md`, `targets.json`, and per round
   `ROUND_DIR/head` (the commit under review, one line per repo for multi-repo
   jobs), `ROUND_DIR/ci.md` and the review files of lenses you skip or carry over.
3. **Verdicts are the first line.** Reviews start `VERDICT: PASS` or
   `VERDICT: CHANGES`; `decision.md` starts `APPROVE` or `ESCALATE`. Read only
   the first line to route. A missing or malformed first line counts as
   `CHANGES` / `ESCALATE`.
4. **WAIT FOR ALL.** A round is done only when every lens of the profile has its
   review file in `ROUND_DIR`. Never resume the builder mid-round.
5. **One builder per job.** Spawn it with name `builder-<job-id>`; for every
   later round resume that same agent with `SendMessage`. If it can't be resumed
   (new session, headless re-run), spawn a fresh one with the same name — it
   rebuilds context from files.
6. **Max 2 rework rounds.** Reviews run in rounds 1–3. CHANGES in round 3 → `needs-human`.
7. **Update `state.json` at every transition** (the dashboard reads it), writing
   the whole file and bumping `updated`. Never write another job's `state.json`:
   one file per job means several people can run the factory at the same time.
8. **Job ids come from GitHub issues.** GitHub hands out the number, so two
   people can never pick the same id. Never derive an id from `factory/jobs/`.
9. **Tests run once, in CI.** The builder runs the suite while it works; after
   that, CI on the pushed branch is the source of truth.
10. **Model by size.** `spec.md` has a `Size:` line (`small` | `normal`). For
    `small` jobs spawn `builder` and `approver` with `model: sonnet`. The
    security reviewer always runs on its own model; any job touching auth,
    secrets or permissions is never `small`.
11. **No secrets, ever** (if `secret_scan: true`). Every push of a job branch is
    preceded by `bash FACTORY_HOME/scripts/gitleaks.sh <worktree>`. Exit 1 → do
    not push: a real credential → `stage: needs-human`, `note: "secret in branch
    — rotate"`, tell the human at once (a committed secret counts as
    compromised even if never pushed); a fake test fixture → resume the builder
    to make it obviously fake, then scan again. Exit 2 → retry; never push
    unscanned.
12. **A pushed branch is never rewritten.** Before its first push the builder
    may rebase onto `main`; afterwards it merges `main` in. Every push is a
    fast-forward; no force-push, ever.

## state.json

```json
{
  "id": "012-rate-limiting",
  "issue": 12,
  "title": "Rate limiting on the public API",
  "branch": "factory/012-rate-limiting",
  "builder": "builder-012-rate-limiting",
  "flavour": "local",
  "targets": null,
  "external": null,
  "stage": "review",
  "round": 2,
  "max_round": 3,
  "reviews": { "security": "CHANGES", "ux": "PASS", "ui": "pending", "code": "PASS" },
  "history": [ { "round": 1, "reviews": { "security": "CHANGES", "ux": "PASS", "ui": "CHANGES", "code": "PASS" } } ],
  "decision": null,
  "waiting": null,
  "note": "",
  "updated": "2026-10-14T12:00:00Z"
}
```

- `stage`: `spec` → `build` → `review` → `approve` → `merged` | `needs-human`.
- `reviews`: one key per lens of the profile; each `pending` | `PASS` | `CHANGES`.
  When a new round starts, move the finished round into `history`.
- `targets`: `null`, or the repo list of a multi-repo job (`["FWU-DE/a", "FWU-DE/b"]`).
- `external`: `null`, or the outside ticket (`{"jira": "PORTAL-512"}`).
- `waiting`: non-null while blocked on a human (e.g. `"stack decision"`).
- `note`: one line explaining the latest state.

## Commands

### Preflight (every command except `init`)

Run `bash FACTORY_HOME/scripts/check.sh` from `REPO`. If it fails, stop and
show the output; warnings you pass on in one line. Confirm the main checkout is
on `main` and `gh auth status` succeeds. Run `git pull --ff-only`. If
`secret_scan: true`, run `bash FACTORY_HOME/scripts/gitleaks.sh` on `main`; a
finding stops the factory until a human has looked at it.

### `/factory init`

Set the factory up in the current repo. Never overwrite an existing file.
1. Create `factory/jobs/.gitkeep`, `factory/backlog.md` (from
   `FACTORY_HOME/templates/backlog.md`) and `factory/profile.md` (from
   `FACTORY_HOME/templates/profile.md`, `factory_version` set to the version in
   `FACTORY_HOME/.claude-plugin/plugin.json`).
2. Fill the profile from what the repo already says: `AGENTS.md`/`CLAUDE.md`,
   `docs/`, the CI workflows (`ci_workflow`), the UI folders (`ui_paths`).
   Old local factory copies (`.claude/agents/*.md`, `.claude/skills/factory/`)
   are the best source: move every project-specific rule they hold into the
   matching profile section, then tell the human the copies can be deleted
   (don't delete them yourself).
3. Add `.worktrees/` to `.gitignore`. If `AGENTS.md` has no
   `## Application stack` section, append one with `STATUS: NOT CONFIGURED`.
4. Run the preflight, show the profile, and ask the human to review it before
   the first job. Commit only after they agree.

### `/factory board`

Start `python3 FACTORY_HOME/scripts/dashboard.py 8000` in the background and
give the human http://localhost:8000/.

### `/factory <feature>`

1. **Create the job.**
   - Open the issue: `gh issue create --label factory --title "<short title>"
     --body "<feature text verbatim>"` (create the label once with
     `gh label create factory` if missing). Its number `N` is the job number.
     In `jira`, the workflow passes the Jira key; put it in the issue title
     (`[PORTAL-512] …`) and in `external`.
   - Id = `N` zero-padded to 3 digits + `-` + a 2–4 word kebab slug
     (issue 12 → `012-rate-limiting`). `mkdir JOB_DIR`.
   - Write `STATE` with `issue: N`, `flavour`, `stage: spec`, `round: 0`,
     `max_round: 3`, all lenses `pending`. Write the feature text verbatim to
     `JOB_DIR/feature.md`; for multi-repo jobs also `targets.json`.
   - Claim it right away so teammates see it:
     `git add JOB_DIR && git commit -m "factory: claim <job-id> (#N)" && git push`
     (on rejection: `git pull --rebase`, then push).
2. **Spec.** Spawn `factory:spec-writer` with: job id, `JOB_DIR`, `REPO`,
   `FACTORY_HOME`. Wait. Check `spec.md` exists.
3. **Stack gate.** Read the `## Stack` section of `spec.md`.
   - `Status: PROPOSED`: set `waiting: "stack decision"`, show the proposal and
     ask the human to confirm or amend it. Write their answer to
     `JOB_DIR/stack-decision.md` (`CONFIRMED` or `AMENDED` on line 1, then the
     final stack). Clear `waiting`. The builder must not start before this file
     exists.
   - `EXISTING` or `NOT NEEDED`: continue.
3b. **Design gate.** Read the `## Design` section of `spec.md`.
   - `Status: NEEDED`: set `waiting: "design"` and ask the human which way:
     (a) they link a Figma or FigCraft frame → write `JOB_DIR/design.md`
     (line 1 `SOURCE: figma|figcraft`, then the link and frames) and resume
     `factory:spec-writer` to fill `## Design` with `Status: EXISTS`;
     (b) the factory prototypes it → spawn `factory:prototyper` with job id,
     `JOB_DIR`, `REPO`, `FACTORY_HOME`; wait for `prototype/README.md` line 1
     `PROTOTYPE: READY`; show the human the screenshots (and the files to open)
     and ask for approval. Changes → write `design-feedback-<n>.md`, resume the
     prototyper, ask again. Approved → write `JOB_DIR/design.md` (line 1
     `SOURCE: prototype`, `APPROVED <date>`).
     Clear `waiting`. The builder must not start before `design.md` exists.
     In headless flavours: post the question with the prototype screenshots
     attached to the issue, `stage: needs-human`, stop.
   - `EXISTS` or `NOT NEEDED`: continue.
4. **Build.** Create the worktree(s): `git worktree add .worktrees/<job-id> -b
   factory/<job-id> main` (multi-repo: clone or fetch each target into
   `.worktrees/<job-id>/<repo>` and create the branch there). Board
   `stage: build`, `round: 1`. Spawn `factory:builder` named `builder-<job-id>`
   with: job id, `JOB_DIR`, `REPO`, `WORKTREE`, `FACTORY_HOME`. Wait. Check
   `build.md` exists and `git log main..HEAD` is non-empty in at least one
   worktree; otherwise `needs-human`. Check `git merge-tree --write-tree main
   factory/<job-id>`; on conflict resume the builder to rebase onto `main`
   (only while the branch was never pushed; afterwards merge `main` in). Secret
   scan (rule 11), then push the branch(es) so CI starts while the reviews run.
5. **Review round n.** `mkdir ROUND_DIR`, write the reviewed commit(s) to
   `ROUND_DIR/head`. Board `stage: review`, all lenses `pending`. Decide which
   lenses run:
   - **No surface → skip.** If `spec.md` `## Surfaces` says the job has no
     user-facing UI, do not spawn `ui` / `ux`; write their files yourself:
     line 1 `VERDICT: PASS`, line 3 `N/A — no user-facing surface (skipped by
     orchestrator per spec ## Surfaces).`
   - **Rework rounds (n ≥ 2) → only what changed.** Re-run a lens if it said
     CHANGES last round, or if the round diff (`git diff --stat
     <previous head>..HEAD`) touches it: ui/ux = the profile's `ui_paths`;
     security = anything outside docs, `*.md` and test-only files; code =
     anything. A lens that is not re-run gets its file written by you: line 1
     `VERDICT: PASS`, line 3 `Carried over from round <n-1>; the round diff
     does not touch this lens.`
   Spawn the remaining reviewers **in one message, in the background**, each
   with: job id, `JOB_DIR`, `REPO`, `WORKTREE`, `ROUND_DIR`, `FACTORY_HOME`. As
   each finishes, read the first line of its file and update that chip. If an
   agent finished but its file is missing, re-spawn it once; still missing →
   `needs-human`. If the profile names `docs.secure_coding`,
   `review-security.md` must contain `## Secure-coding checklist` with a row
   for every rule of `secure_coding_rules`; if not, re-spawn once; still
   incomplete → count it as `CHANGES`. A carried-over security review keeps its
   checklist.
6. **WAIT FOR ALL**, then route:
   - all PASS → **CI gate** (skip if `ci_workflow: none`): wait for the run of
     the commit in `ROUND_DIR/head` on `factory/<job-id>` (`gh run list
     --workflow <ci_workflow> --branch factory/<job-id> --commit <sha>`, then
     `gh run watch --exit-status`; per repo for multi-repo jobs). Write
     `ROUND_DIR/ci.md`: line 1 `CI: success` or `CI: failure`, then run URL(s)
     and each failed job with the tail of its log. Failure counts as CHANGES
     (next bullet). A clearly infrastructural failure may be re-run once
     (`gh run rerun --failed`). Success → step 7.
   - any CHANGES and `round < max_round` → push the round to `history`,
     `round += 1`, `stage: build`, then `SendMessage` to `builder-<job-id>`:
     "Round <n> reviews are in <ROUND_DIR> (and `ci.md` if CI failed). Address
     every CHANGES item, re-run the tests, commit, and append a `## Round <n>
     response` to build.md." Wait, scan, push, go to step 5.
   - any CHANGES and `round == max_round` → `stage: needs-human`,
     `note: "CHANGES after 2 rework rounds"`. Stop.
7. **Approve.** If `spec.md` `## Surfaces` says `Human gate: yes`, skip the
   approver: `stage: needs-human`, `decision: "ESCALATE (human gate)"`, and ask
   the human with a short summary from the reviews and `ci.md`. Otherwise board
   `stage: approve`, spawn `factory:approver` with job id, `JOB_DIR`, `REPO`,
   `WORKTREE`, the latest `ROUND_DIR`, `FACTORY_HOME`. Line 1 of `decision.md`:
   - `APPROVE` → **Merge**.
   - `ESCALATE` → `stage: needs-human`, `decision: "ESCALATE"`, `note` = the
     approver's reason. Comment it on the issue. Stop; tell the human about
     `/factory approve` and `/factory rework`.

### Merge (shared by APPROVE and `/factory approve`)

In `jira` and `ticket-pr` the factory does not merge into `main` itself: open a
PR per repo (`gh pr create --base main --head factory/<job-id>`, body = the
spec's problem, the AC table from build.md and the decision; multi-repo PRs as
drafts with the merge order), set `stage: merged` once they are open, and let
humans merge. In `local`:

1. From `REPO` on `main`: `git merge --no-ff factory/<job-id> -m "factory: merge
   <job-id> — <title>"`. On conflict: `git merge --abort`, `stage: needs-human`,
   `note: "merge conflict"`, stop.
2. `git worktree remove .worktrees/<job-id>` and `git branch -d factory/<job-id>`.
3. If `main` had moved past the branch's merge base (not a plain fast-forward
   of the CI-tested commit), run the AGENTS.md test command on `main`; else
   skip it, the push to `main` runs CI again. On failure put the tail in
   `note` (the job is still merged; tell the human). Delete the remote branch.
4. If the job has an approved prototype and the profile names
   `design.prototypes`, copy `JOB_DIR/prototype/` to
   `<design.prototypes>/<job-id>/` on `main`, so the next jobs build on it.
5. Board `stage: merged`. Commit the job records:
   `git add JOB_DIR && git commit -m "factory: record <job-id> (closes #N)"` and push.

### `/factory spec <feature>`

Like `/factory <feature>`, but stop after step 3. Set `waiting: "spec review
(human)"`, `note: "Spec written; build not started on purpose"`. Commit and push
the job folder. The human reads the spec, then runs `/factory build` or
`/factory respec`.

### `/factory build <job-id>`

Only for a job with `stage: spec` and an existing `spec.md`.
1. If `## Stack` is `PROPOSED` and `stack-decision.md` is missing, run the stack gate first.
2. Check the `Depends on` jobs named in `feature.md`/`spec.md`. If one is not
   `merged`, ask the human whether to build anyway; never stub another job's
   service silently.
3. Clear `waiting`, continue with step 4 (Build).

### `/factory respec <job-id> <note>`

Only for `stage: spec`. Append the note to `JOB_DIR/stack-decision.md` under
`## Spec review <n> (human)` (create it with line 1 `AMENDED` if missing; it
overrides `spec.md`). Resume or respawn `factory:spec-writer`; keep `waiting:
"spec review (human)"`, `note: "Spec revised after review <n>"`, commit, push.

### `/factory jira <KEY>` (flavour `jira`, headless)

Read the ticket with `bash FACTORY_HOME/scripts/jira.sh get <KEY>`. The feature
text is its summary plus description; the target repos come from
`FACTORY_TARGETS` (set by the workflow from the ticket's repo labels), else the
current repo. If a job with `external.jira == <KEY>` already exists, continue it
instead of creating a new one. Then run `/factory <feature>` as usual, with
these additions (details in `FACTORY_HOME/flavours/jira.md`):
- at claim: `jira.sh comment <KEY> "Factory job <job-id>: <issue URL>"`,
  `jira.sh transition <KEY> "<profile jira.status_in_progress>"`;
- at every `needs-human`: comment the question on the issue and the ticket;
- at merge (PRs open): comment the PR links, transition to
  `jira.status_review`, remove the label `jira.label`.

### `/factory ticket <path>` (flavour `ticket-pr`, headless)

The feature text is the file `<path>` (a merged `docs/tasks/todo/<slug>.md`).
Run `/factory <feature>`; at merge, move the file to `docs/tasks/archived/` in
the job's PR.

### `/factory next`

Take the first `- [ ]` item in `factory/backlog.md`. Mark it `- [~]` and run
`/factory <item text>`. When the job ends, mark it `- [x]` and append
` → <job-id> (<stage>)`. No unchecked items → say the backlog is empty.

### `/factory approve <job-id>`

Only for a job in `needs-human`. The command itself is the human's approval.
Set `decision: "APPROVE (human)"` and run **Merge**.

### `/factory rework <job-id> <note>`

For a job in `needs-human`. Write `<note>` to `JOB_DIR/rework-<round>.md`. Set
`max_round = round + 3`, `round += 1`, push the old round to `history`,
`stage: build`, clear `decision`. Recreate the worktree if it was removed.
Resume (or respawn) `builder-<job-id>`: "Human feedback is in
<JOB_DIR>/rework-<old round>.md. Address it, re-run the tests, commit, and
append a `## Rework` section to build.md." Then continue from step 5.

### Natural-language use

The human may give these commands in plain words ("bau 010", "überarbeite die
Spec von 011: …", "gib 005 frei"). Map them to the commands above and confirm
in one line which command you are running before you start.

## Report

End every command with a short summary: job id, final stage, rounds used, and
the board hint `/factory board`.
