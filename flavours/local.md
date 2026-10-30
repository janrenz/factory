# Flavour `local`

The default. A person runs the factory in a Claude Code session in the repo.

- **Start:** `/factory <feature>`, `/factory next` (first open backlog item),
  or in plain words ("bau 010").
- **Human gates:** stack decision, design, `Human gate: yes`, escalations — the
  orchestrator asks in the chat (AskUserQuestion).
- **Merge:** the orchestrator merges `factory/<job-id>` into `main` itself
  after APPROVE.
- **Several people:** each job has its own `state.json` and a GitHub issue
  number as id, so several sessions can run jobs at the same time. Pull before
  you start (`git pull --ff-only`, the preflight does it).
- **Remote control:** a running session can be driven from a phone; natural
  language commands map to the commands of the skill.
