# Factory

**English** · [Deutsch](README.de.md)

**Turn a request into a reviewed pull request – with a spec, a design, tests and four independent reviews, traceable in files and on a board.**

Factory is a plugin for [Claude Code](https://claude.com/claude-code). It turns a single AI assistant into a **small development team with fixed roles**: a spec writer clarifies what gets built. A builder implements it. Four reviewers check **security, code, usability and visual design** – in parallel and independently. An approver decides whether it is good enough or a human needs to look. And where it matters, **you decide**.

```
 Request ─► Spec ─► Design ─► Build ─► Security · Code · UX · UI ─► CI ─► Approval ─► Merge
              ▲        ▲                         │ changes requested          ▲
              │        │                         └──────► builder ───────────┘ (max. 2 rounds)
            human    human                                                    human, when needed
```

---

## Why

An AI assistant in a chat writes code fast. What is missing is what makes good teams good:

- **Clear requirements before building.** Without a spec you build the wrong thing, only faster.
- **A second pair of eyes that is not your own.** Whoever reviews their own code misses their own mistakes.
- **A memory.** What was decided and why is gone from the chat history three weeks later.
- **Limits.** Security-relevant changes, data migrations and new dependencies belong in front of a person.

Factory builds exactly that in – as **a process that runs the same way every time**, no matter who starts it.

## What you get

| | |
|---|---|
| **A spec with testable criteria** | 3–7 acceptance criteria, each with an automated test. Your project's security and quality rules become criteria. |
| **Design before code** | Screens come from **Figma**, **FigCraft** or a **click-through prototype** the factory builds itself and shows you for approval. |
| **Four independent reviews** | Security (with a complete checklist of your guideline), code, UX and UI. The UI review **renders the pages** at 375 and 1280 px and compares them with the design. |
| **CI as the source of truth** | Tests run once, in your CI. Red means: back to the builder. |
| **Human gates** | Stack choice, design, auth/secrets/data deletion and anything the approver won't sign off land with you. |
| **Everything in files** | Every job has a folder with `feature.md`, `spec.md`, `build.md`, reviews per round and `decision.md`. **Traceable, diffable, auditable.** |
| **A board** | `/factory board` shows every job live: stage, round, review lights. |
| **No secrets in code** | A gitleaks scan before every push, pinned and checksum-verified. |
| **Work in parallel** | Job numbers come from GitHub issues and every job has its own state file. Several people, no conflicts. |

## Five minutes to start

```text
/plugin marketplace add janrenz/factory
/plugin install factory@janrenz-factory
/factory init
```

`/factory init` creates `factory/profile.md`, `factory/backlog.md` and `factory/jobs/` in your repo and fills the profile from what your repo already says about itself. Read the profile, adjust it, commit. Then:

```text
/factory Users can reset their password themselves
```

or add features to `factory/backlog.md` and start with `/factory next`. Plain words work too: "build 012", "approve 014", "revise the spec of 015: …".

For a whole team, in the repo's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "janrenz-factory": { "source": { "source": "github", "repo": "janrenz/factory", "ref": "v0.2.1" } }
  },
  "enabledPlugins": { "factory@janrenz-factory": true }
}
```

## One core, three ways to run it

The process is **always the same**. What differs is who starts it and where you answer:

| Flavour | Started by | You answer | Runs |
|---|---|---|---|
| **`local`** | `/factory …` in a chat | in the chat | in your session, you watch |
| **`jira`** | label "Agent-Ready" on a Jira ticket | comment on the issue, Jira | in the background in GitHub Actions |
| **`ticket-pr`** | merged ticket PR `docs/tasks/todo/*.md` | PR review, comment | in the background in GitHub Actions |

In the background the factory **opens PRs instead of merging** – a person presses the button. A Jira ticket can also span **several repos**: one job, one branch per repo, one end-to-end criterion across all of them. Details: [`flavours/`](flavours/).

## Reviews on their own

The four reviewers also work **without a factory job** – on any branch or pull request, in any repo:

- **In a chat:** `/factory:review` reviews the current branch against the default branch; `/factory:review security --base origin/release` picks lens and base.
- **In CI:** add one workflow and every PR gets a factory review as a comment, updated on every push, with a failing check on CHANGES:

  ```yaml
  # .github/workflows/factory-review.yml
  on: { pull_request: { types: [opened, synchronize, reopened, ready_for_review] } }
  jobs:
    review:
      uses: janrenz/factory/.github/workflows/review.yml@v0.2.1
      with: { lenses: security,code }
      secrets: inherit          # ANTHROPIC_API_KEY
  ```

Same agents, same rules: if the repo has a `factory/profile.md`, the review applies it – including the complete checklist of your secure-coding guideline. Without a profile the reviewers use their built-in checklists. **So there is exactly one security reviewer**, used by the factory, by CI in other repos and in the chat.

Fork PRs are skipped (they get no secrets). The reviewers run code-reading tools on the PR's content with your API key, so use this for PRs from your own team.

## Your project in the profile

The agents are generic. **What makes your project special lives in one file:** `factory/profile.md`.

- **At the top (frontmatter):** flavour, CI workflow, which reviews run, where guidelines, NFRs and the design live.
- **Below, one section per role:** Who are the users? Which rules apply to every spec? What does the UX review look for with ten-year-olds, and what with admin professionals?

So every repo gets **the same factory with its own character** – without copied agent files drifting apart. Examples: [`examples/`](examples/).

## Design in the spec process

The spec has a `## Design` section with source and status:

- **Figma** – the spec names the file and frames; a pinned token export (`design.tokens`) fixes colours, type and spacing. With the Figma MCP the factory reads the frames directly.
- **FigCraft** – the same with an open, self-hosted design tool: document and frames as the reference.
- **Prototype** – if there is no design, the **prototyper** builds a click-through HTML prototype with every state (empty, error, many items …) at 375 and 1280 px. You approve it or say what should change. Approved prototypes move into the repo and become the reference for the next jobs.

Building starts only once the design is settled. The UI review puts its screenshots **next to the design**.

## What it looks like

```
factory/
├── profile.md                  ← your project
├── backlog.md                  ← what comes next
└── jobs/
    └── 042-password-reset/
        ├── state.json          ← stage, round, lights (for the board)
        ├── feature.md          ← the request, verbatim
        ├── spec.md             ← problem, scope, criteria, design, surfaces
        ├── design.md           ← Figma link or approved prototype
        ├── prototype/          ← click-through prototype + screenshots
        ├── build.md            ← what was built, test table, commits
        ├── round-1/
        │   ├── review-security.md   VERDICT: CHANGES
        │   ├── review-code.md       VERDICT: PASS
        │   ├── review-ux.md         VERDICT: PASS
        │   ├── review-ui.md         VERDICT: PASS  (+ screenshots/)
        │   └── ci.md                CI: success
        ├── round-2/ …
        └── decision.md         ← APPROVE or ESCALATE, with the reason
```

## More

- [Concept and vision](docs/concept.md) – why the factory is built this way and where it is going.
- [Profile template](templates/profile.md) · [Flavours](flavours/) · [Workflow templates](templates/workflows/)
- [Changes](CHANGELOG.md)

## License

MIT – see [LICENSE](LICENSE). The UI review's stance ("render first, then judge") is adapted from `design-critic` in [plugin87/ux-ui-agent-skills](https://github.com/plugin87/ux-ui-agent-skills) (MIT).
