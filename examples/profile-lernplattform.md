---
factory_version: 0.2.0
flavour: local
main: main
ci_workflow: ci.yml
lenses: [security, ux, ui, code]
ui_paths:
  - "app/web/**"
  - "app/web/src/lib/i18n/**"
secret_scan: true
issue_ids_from: 6
docs:
  agents: AGENTS.md
  nfr: docs/non-functional-requirements.md
  design: docs/design-guidelines.md
  secure_coding: docs/secure-coding-guideline.md
secure_coding_rules: SC-2.1..SC-12.1
design:
  source: prototype
  prototypes: docs/design/prototypes
---

# Factory profile: Lernplattform (Beispiel)

Eine Lernplattform mit Rust-Microservices und einem SvelteKit-Client; native Apps nutzen dieselbe API.

## All agents

- Users: Lernende und Lehrende an Hochschulen, Deutsch und Englisch.
- Languages: jeder sichtbare Text in `en` und `de`, per Schlüssel referenziert (NFR-I18N-1…6).
- Content format: Inhalte von Nutzenden werden als **Markdown** gespeichert und erst bei der Ausgabe bereinigt zu HTML.

## spec-writer

- Extra `## Surfaces` line: `Data volume: yes/no` — yes, wenn gespeicherte Daten gelesen oder gelistet werden; dann ein Kriterium „realistisches Seed-Profil, Seitenbudget, kein N+1“.
- Neue oder geänderte Funktionen aktualisieren Onboarding-Tour und Handbuchseite (en + de) oder begründen die Ausnahme.

## builder

- Seeder des Dienstes erweitern, wenn der Job Daten liest.
- Handbuch-Screenshots mit `scripts/manual-build.sh --update` neu erzeugen.

## prototyper

- Komponenten und Tokens aus `docs/design-guidelines.md`; keine neuen Farben.

## reviewer-security

- NFR sections: Architecture, API design, Security, Privacy.

## reviewer-ux

- NFR sections: Architecture (non-web clients), API design, Clients and usability, Internationalisation.
- Fehlende Tour- oder Handbuch-Aktualisierung ist ein must-fix.

## reviewer-ui

- NFR sections: Clients and usability, Internationalisation.
- Screenshot command: `npm --prefix app/web run screenshots`.

## reviewer-code

- NFR sections: Architecture, API design, Reliability, Observability, Maintainability.
- Ein Job, der Daten liest, ohne Seeder und Seitenbudget: must-fix.

## approver

- —
