# Factory

[English](README.md) · **Deutsch**

**Aus einer Anforderung wird ein geprüfter Pull Request – mit Spec, Design, Tests und vier unabhängigen Reviews, nachvollziehbar in Dateien und auf einem Board.**

Factory ist ein Plugin für [Claude Code](https://claude.com/claude-code). Es macht aus einem einzelnen KI-Assistenten ein **kleines Entwicklungsteam mit festen Rollen**: Eine Spec-Autorin klärt, was gebaut wird. Ein Builder setzt es um. Vier Reviewer prüfen **Sicherheit, Code, Bedienbarkeit und Gestaltung** – parallel und unabhängig voneinander. Ein Approver entscheidet, ob es reicht oder ein Mensch draufschauen muss. Und an den Stellen, die zählen, **entscheidest du**.

```
 Anforderung ─► Spec ─► Design ─► Build ─► Security · Code · UX · UI ─► CI ─► Freigabe ─► Merge
                  ▲        ▲                         │ Änderungen nötig           ▲
                  │        │                         └──────► Builder ──────────┘ (max. 2 Runden)
               Mensch   Mensch                                                    Mensch, wenn nötig
```

---

## Warum

Ein KI-Assistent im Chat schreibt schnell Code. Was dabei fehlt, ist das, was gute Teams ausmacht:

- **Klare Anforderungen, bevor gebaut wird.** Ohne Spec baut man das Falsche, nur schneller.
- **Ein zweiter Blick, der nicht der eigene ist.** Wer seinen Code selbst prüft, findet seine eigenen Fehler nicht.
- **Ein Gedächtnis.** Was entschieden wurde und warum, steht nach drei Wochen nicht mehr im Chatverlauf.
- **Grenzen.** Sicherheitsrelevantes, Datenmigrationen und neue Abhängigkeiten gehören vor einen Menschen.

Die Factory baut genau das ein – als **Ablauf, der jedes Mal gleich läuft**, egal wer ihn startet.

## Was du bekommst

| | |
|---|---|
| **Spec mit prüfbaren Kriterien** | 3–7 Akzeptanzkriterien, jedes mit einem automatischen Test. Sicherheits- und Qualitätsregeln deines Projekts werden zu Kriterien. |
| **Design vor Code** | Bildschirme kommen aus **Figma**, **FigCraft** oder einem **Klick-Prototyp**, den die Factory selbst baut und dir zur Freigabe zeigt. |
| **Vier unabhängige Reviews** | Security (mit vollständiger Checkliste deiner Richtlinie), Code, UX und UI. Die UI-Prüfung **rendert die Seiten** bei 375 und 1280 px und vergleicht mit dem Design. |
| **CI als Wahrheit** | Tests laufen einmal, in deiner CI. Rot heißt: zurück an den Builder. |
| **Menschliche Gates** | Stack-Wahl, Design, Auth/Secrets/Datenlöschung und alles, was der Approver nicht verantworten will, landen bei dir. |
| **Alles in Dateien** | Jeder Job hat einen Ordner mit `feature.md`, `spec.md`, `build.md`, Reviews je Runde und `decision.md`. **Nachvollziehbar, diffbar, revisionssicher.** |
| **Ein Board** | `/factory board` zeigt alle Jobs live: Stufe, Runde, Review-Ampeln. |
| **Keine Geheimnisse im Code** | Vor jedem Push ein gitleaks-Scan, gepinnt und mit Prüfsumme. |
| **Parallel arbeiten** | Job-Nummern kommen aus GitHub-Issues, jeder Job hat seine eigene Zustandsdatei. Mehrere Personen, keine Konflikte. |

## In fünf Minuten

```text
/plugin marketplace add janrenz/factory
/plugin install factory@janrenz-factory
/factory init
```

`/factory init` legt in deinem Repo `factory/profile.md`, `factory/backlog.md` und `factory/jobs/` an und füllt das Profil aus dem, was dein Repo schon über sich sagt. Lies das Profil, passe es an, committe. Dann:

```text
/factory Nutzer können ihr Passwort selbst zurücksetzen
```

oder trag Features in `factory/backlog.md` ein und starte mit `/factory next`. In normalen Worten geht es auch: „bau 012“, „gib 014 frei“, „überarbeite die Spec von 015: …“.

Für ein ganzes Team: in `.claude/settings.json` des Repos

```json
{
  "extraKnownMarketplaces": {
    "janrenz-factory": { "source": { "source": "github", "repo": "janrenz/factory", "ref": "v0.1.0" } }
  },
  "enabledPlugins": { "factory@janrenz-factory": true }
}
```

## Ein Kern, drei Betriebsarten

Der Ablauf ist **immer derselbe**. Was sich unterscheidet, ist, wer ihn anstößt und wo du antwortest:

| Flavour | Start | Du antwortest | Läuft |
|---|---|---|---|
| **`local`** | `/factory …` im Chat | im Chat | in deiner Sitzung, du schaust zu |
| **`jira`** | Label „Agent-Ready“ am Jira-Ticket | Kommentar am Issue, Jira | im Hintergrund in GitHub Actions |
| **`ticket-pr`** | gemergter Ticket-PR `docs/tasks/todo/*.md` | PR-Review, Kommentar | im Hintergrund in GitHub Actions |

Im Hintergrund öffnet die Factory **PRs statt zu mergen** – ein Mensch drückt den Knopf. Ein Jira-Ticket kann auch **mehrere Repos** betreffen: dann ein Job, ein Branch je Repo, ein End-to-End-Kriterium über alle. Details: [`flavours/`](flavours/).

## Dein Projekt im Profil

Die Agents sind allgemein. **Was dein Projekt besonders macht, steht in einer Datei:** `factory/profile.md`.

- **Oben (Frontmatter):** Flavour, CI-Workflow, welche Reviews laufen, wo Richtlinien, NFRs und das Design liegen.
- **Darunter je Rolle ein Abschnitt:** Wer sind die Nutzer? Welche Regeln gelten für jede Spec? Worauf achtet die UX-Prüfung bei Zehnjährigen, worauf bei Verwaltungsprofis?

So bekommt jedes Repo **dieselbe Factory mit eigenem Charakter** – ohne kopierte und auseinanderlaufende Agent-Dateien. Beispiele: [`examples/`](examples/).

## Design im Spec-Prozess

Die Spec hat einen Abschnitt `## Design` mit Quelle und Status:

- **Figma** – die Spec nennt Datei und Frames; ein gepinnter Token-Export (`design.tokens`) hält Farben, Typo und Abstände fest. Mit dem Figma-MCP liest die Factory die Frames direkt.
- **FigCraft** – dasselbe mit einem offenen, selbst gehosteten Design-Werkzeug: Dokument und Frames als Referenz.
- **Prototyp** – fehlt ein Design, baut der **Prototyper** einen klickbaren HTML-Prototyp mit allen Zuständen (leer, Fehler, viele Einträge …) bei 375 und 1280 px. Du gibst ihn frei oder schreibst, was anders sein soll. Freigegebene Prototypen wandern ins Repo und sind die Referenz für die nächsten Jobs.

Erst wenn das Design steht, wird gebaut. Die UI-Prüfung legt ihre Screenshots **neben das Design**.

## Wie es aussieht

```
factory/
├── profile.md                  ← dein Projekt
├── backlog.md                  ← was als Nächstes kommt
└── jobs/
    └── 042-passwort-reset/
        ├── state.json          ← Stufe, Runde, Ampeln (fürs Board)
        ├── feature.md          ← die Anforderung, wörtlich
        ├── spec.md             ← Problem, Scope, Kriterien, Design, Surfaces
        ├── design.md           ← Figma-Link oder freigegebener Prototyp
        ├── prototype/          ← Klick-Prototyp + Screenshots
        ├── build.md            ← was gebaut wurde, Test-Tabelle, Commits
        ├── round-1/
        │   ├── review-security.md   VERDICT: CHANGES
        │   ├── review-code.md       VERDICT: PASS
        │   ├── review-ux.md         VERDICT: PASS
        │   ├── review-ui.md         VERDICT: PASS  (+ screenshots/)
        │   └── ci.md                CI: success
        ├── round-2/ …
        └── decision.md         ← APPROVE oder ESCALATE, mit Begründung
```

## Mehr

- [Konzept und Vision](docs/konzept.de.md) – warum die Factory so gebaut ist und wohin sie geht.
- [Profil-Vorlage](templates/profile.md) · [Flavours](flavours/) · [Workflow-Vorlagen](templates/workflows/)
- [Änderungen](CHANGELOG.md)

## Lizenz

MIT – siehe [LICENSE](LICENSE). Die Haltung der UI-Prüfung („erst rendern, dann urteilen“) ist angelehnt an `design-critic` aus [plugin87/ux-ui-agent-skills](https://github.com/plugin87/ux-ui-agent-skills) (MIT).
