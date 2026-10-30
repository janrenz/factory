# Flavour `jira`

A team backlog in Jira, worked through in the background. The factory runs
headless in GitHub Actions; people answer in Jira or on the job's GitHub issue.

## Set-up

Usually a **harness repo** owns the factory (jobs, profile, workflows, secrets)
and checks out the product repos at run time. A single product repo can also
run it for itself.

1. `factory/profile.md` with `flavour: jira` and a `jira` block:
   ```yaml
   jira:
     label: Agent-Ready              # the label that starts a job
     status_in_progress: In Arbeit
     status_review: In Review
     repo_labels:                    # Jira label=target repo
       - repo-anbieterportal=FWU-DE/anbieterportal
       - repo-vidis-portal=FWU-DE/vidis-portal-new
   ```
2. Copy `templates/workflows/factory-jira.yml` to `.github/workflows/`.
3. Secrets: `ANTHROPIC_API_KEY`, `FACTORY_GH_TOKEN` (fine-grained or app token
   with contents/issues/pull-requests write on this repo and every target),
   `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`.
4. Jira automation rule: *label added = Agent-Ready* → *Send web request* to
   `https://api.github.com/repos/<owner>/<harness>/dispatches`, body
   `{"event_type":"factory-jira","client_payload":{"key":"{{issue.key}}","targets":"<repos from the repo labels>"}}`.

## Run

| Step | What happens |
|---|---|
| Jira label | dispatch → `/factory jira <KEY>` |
| claim | GitHub issue `[KEY] …`, job folder, Jira comment with the link, status *in progress* |
| spec, design, stack | as in every flavour; a question → `needs-human`, comment on issue and ticket |
| build, reviews, CI | as in every flavour; one branch `factory/<job-id>` per target repo |
| approve | approver; `Human gate: yes` always waits for a person |
| merge | **PRs, not a merge**: one PR per repo, drafts with merge order for multi-repo jobs; Jira comment with the links, status *review*, label removed |

People continue a waiting job with a comment on the GitHub issue:
`/factory approve <job-id>`, `/factory rework <job-id> <note>`,
`/factory build <job-id>`, `/factory respec <job-id> <note>`. Only members and
collaborators can trigger it.

## Multi-repo jobs

A ticket with several repo labels becomes one job with `targets.json`. Every
target is cloned into `.worktrees/<job-id>/<repo>/` and gets its own branch,
CI run and PR. The spec names the repo in front of every criterion and adds one
end-to-end criterion across the repos; the stacks must be able to run side by
side (disjoint host ports).
