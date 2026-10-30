# Flavour `ticket-pr`

For repos without Jira. A ticket is a Markdown file; reviewing and merging the
ticket PR is the human's go.

1. A person opens a PR that adds `docs/tasks/todo/<slug>.md` (title, user
   story, acceptance criteria) — no code.
2. The PR is reviewed and merged. `templates/workflows/factory-ticket-pr.yml`
   sees the new file and runs `/factory ticket docs/tasks/todo/<slug>.md`.
3. The factory runs headless: spec, design, build, reviews, CI, approve.
   Questions go to the job's GitHub issue (`needs-human`); a member answers
   with `/factory approve|rework|build|respec …` as a comment.
4. Instead of merging, the factory opens a PR `factory/<job-id>` → `main`
   that also moves the ticket to `docs/tasks/archived/`. A person merges it.

Secrets: `ANTHROPIC_API_KEY`, `FACTORY_GH_TOKEN`.
