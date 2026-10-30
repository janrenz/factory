---
factory_version: 0.1.0
flavour: local
main: main
ci_workflow: ci.yml
lenses: [security, ux, ui, code]
ui_paths:
  - "app/web/**"
secret_scan: true
docs:
  agents: AGENTS.md
  nfr: docs/non-functional-requirements.md
  design: docs/design-guidelines.md
  secure_coding: docs/secure-coding-guideline.md
secure_coding_rules: SC-2.1..SC-12.1
design:
  source: figma
  file: https://www.figma.com/design/<key>/<design-system>
  tokens: docs/design/figma-tokens.json
---

# Factory profile: Schüler-Dashboard (Beispiel)

Ein Dashboard für Schülerinnen und Schüler; jeder Schuldienst hängt an einem Connector.

## All agents

- Users: Schülerinnen und Schüler von 10 bis 18 Jahren. Texte kurz, klares Deutsch (A2–B1), nie herablassend.
- Personal data: alles, was personenbezogene Daten zeigt oder speichert, zitiert `NFR-K12-*`.

## spec-writer

- Extra `## Surfaces` line: `Connectors: <ids, or none>`.
- Jeder externe Schuldienst läuft über genau einen Connector (`app/connectors/<id>/`) nach dem Connector-Vertrag in AGENTS.md: Operationen, Fixture-Daten (nur erfundene Personen), Verhalten bei „nicht verbunden“ und „Dienst nicht erreichbar“. Ist die echte API nicht dokumentiert, wird nur der Fixture-Modus ausgeliefert.

## builder

- Jeder Connector funktioniert im Fixture-Modus ohne Netz und ohne Zugangsdaten; Tests, CI und Demo rufen nie einen echten Dienst.

## prototyper

- Nur Komponenten und Tokens aus dem gepinnten Figma-Export.

## reviewer-security

- NFR sections: Architecture, API design, Security, Privacy, K12.

## reviewer-ux

- NFR sections: Architecture (non-web clients), API design, Clients and usability, Internationalisation, K12.
- Weiß eine Zehnjährige, was sie als Nächstes tun soll?
- Jede Connector-Karte hat klare Zustände für „nicht verbunden“, „Dienst gestört“ und „heute nichts zu tun“; eine leere oder technische Fehlermeldung ist ein must-fix.

## reviewer-ui

- NFR sections: Clients and usability, Internationalisation.

## reviewer-code

- NFR sections: Architecture, API design, Reliability, Observability, Maintainability.
- Connector nur über die Registry, mit Fixture-Modus und Vertragstest; ein ausgefallener Connector bricht nie das Dashboard. Fehlt etwas: must-fix.

## approver

- Jede Änderung an Anmeldung oder Rollen geht an einen Menschen.
