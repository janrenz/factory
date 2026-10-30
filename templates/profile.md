---
# Factory profile. The core reads the frontmatter; each agent reads
# `## All agents` plus its own section below. Delete what you don't need.
factory_version: 0.2.0          # the core version this repo was set up with
flavour: local                  # local | jira | ticket-pr
main: main                      # branch jobs start from and merge into
ci_workflow: ci.yml             # workflow file the CI gate waits for; "none" = no CI gate
lenses: [security, ux, ui, code]
ui_paths:                       # a rework round re-runs ui/ux only if these change
  - "web/**"
secret_scan: true               # gitleaks before every push (scripts/gitleaks.sh)
docs:
  agents: AGENTS.md             # layout, conventions, ## Application stack
  nfr: docs/non-functional-requirements.md     # optional
  design: docs/design-guidelines.md            # optional, reference for reviewer-ui
  secure_coding: docs/secure-coding-guideline.md   # optional
secure_coding_rules: SC-2.1..SC-12.1           # range the security checklist covers
design:
  source: figma                 # figma | figcraft | prototype | none
  file: https://www.figma.com/design/<key>/<name>   # or the FigCraft document
  tokens: docs/design/tokens.json                   # pinned token snapshot, optional
  prototypes: docs/design/prototypes                # approved prototypes, optional
---

# Factory profile: <project>

## All agents

- Users: <who uses the product; age, role, language, reading level>.
- Languages: <e.g. every user-facing string in de and en, referenced by key>.
- Content format: <e.g. user content is stored as Markdown, rendered sanitised>.

## spec-writer

- Extra `## Surfaces` lines: <e.g. "Data volume: yes/no — …", "Connectors: …">.
- <rules that turn into acceptance criteria for every matching feature>

## builder

- <project rules, e.g. "every connector works in fixture mode without network">

## prototyper

- <house style for prototypes, e.g. "use the VIDIS components; no new colours">

## reviewer-security

- NFR sections: Architecture, API design, Security, Privacy.

## reviewer-ux

- NFR sections: API design, Clients and usability, Internationalisation.
- <what good looks like for these users>

## reviewer-ui

- NFR sections: Clients and usability, Internationalisation.
- Screenshot command: <e.g. `npm --prefix web run screenshots`, or none>.

## reviewer-code

- NFR sections: Architecture, API design, Reliability, Observability, Maintainability.

## approver

- <extra escalation rules, e.g. "any change to the payment flow">
