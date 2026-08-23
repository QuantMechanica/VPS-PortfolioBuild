# ARCHIVE_PLAN — Vault-Migration Gate Manifest v4 (2026-08-23)

Dieser Plan ist die Autorität dafür, was `APPLY.py` tut. Er nennt (A) die nach `_ARCHIV`
verschobenen Seiten, (B) die aus dem Staging in den Vault kopierten Seiten, (C) die verlangten
Inbound-Wikilink-Updates (mit file:line), (D) die in-place-Token-Ersetzungen, und (E) die
bewusst NICHT automatisch angewandten, mehrdeutigen Fälle (Human-Review).

Vault-Wurzel: `G:/My Drive/QuantMechanica - Company Reference`. Kein Vault-Edit ohne
`APPLY.py --apply`. Der Linter (`00 Governance/lint_company_reference.py`) steht heute auf **PASS**;
die Migration muss ihn grün halten (keine Legacy-`P*`-Gate-Tokens, keine abgeschalteten Rollennamen
auf aktiven Seiten).

---

## A · Nach `_ARCHIV/03 Pipeline/` verschieben (alte v3-Seiten, deren ID die Bedeutung ändert)

Jede Datei erhält beim Verschieben einen vorangestellten Header
`> **Superseded by v4 2026-08-23.** …` (siehe `APPLY.py`). Der Ordner `_ARCHIV` ist vom
Forbidden-Term-Check ausgenommen; alte Tokens dürfen dort verbleiben.

| # | Quelle (`03 Pipeline/`) | Ziel (`_ARCHIV/03 Pipeline/`) | Grund |
|---|---|---|---|
| 1 | `Q09 News Impact Mode.md` | dito | v3 Q09 → v4 Q10 (Bedeutung wandert; neue Seite `Q09 Baseline Full Run.md`) |
| 2 | `Q10 Full-History Confirmation.md` | dito | v3 Q10 → v4 Q11 |
| 3 | `Q11 Portfolio Construction.md` | dito | v3 Q11 → v4 Q15 |
| 4 | `Q12 Operational Readiness.md` | dito | v3 Q12 → v4 Q16 |
| 5 | `Q13 Live Burn-In DXZ.md` | dito | v3 Q13 → v4 Q17 |
| 6 | `Q14 Optimization Admission.md` | dito | v3 Q14 → v4 Q12 (Name „Pattern Filter Selection") |
| 7 | `Q15 Challenger Build and Freeze.md` | dito | v3 Q15 → v4 Q13 |
| 8 | `Q16 Head-to-Head Requalification.md` | dito | v3 Q16 → v4 Q14 (terminal) |
| 9 | `Gate Manifest v3 Diff.md` | dito | eingefroren als historischer v2→v3-Diff; ersetzt durch `Gate Manifest v4 Diff.md` |

**Kollisionsfreiheit:** alle neuen v4-Dateinamen unterscheiden sich von diesen 9 Altnamen; die
Q00–Q08-Seiten behalten ihre Dateinamen und werden in-place überschrieben (siehe B).

**Wikilink-Auflösbarkeit nach Archivierung:** Der Vault-Linter registriert für jede Datei auch
den reinen Dateinamen-Stamm; ein `[[Q10 Full-History Confirmation]]` löst daher weiter auf die
`_ARCHIV`-Kopie auf und bricht nicht. Trotzdem werden semantisch falsch zeigende Inbound-Links
(die auf das *aktuelle* Konzept zeigen sollen) unter C korrekt umgehängt.

---

## B · Aus dem Staging in den Vault kopieren (`03 Pipeline/`)

Überschreiben bzw. neu anlegen (voller Dateiinhalt aus dem Staging):

- **In-place-Rewrite (gleicher Dateiname, v4-Header + Herkunft ergänzt):**
  `Q00 Research Intake.md`, `Q01 Build & Spec.md`, `Q02 Baseline Screening.md`,
  `Q03 Parameter Sweep.md`, `Q04 Walk-Forward + Commission.md`,
  `Q05 Gross Full-History Robustness.md`, `Q06 Stress HARSH.md`, `Q07 Multi-Seed.md`,
  `Q08 Davey Statistical Validation.md`, `Pipeline Overview.md`,
  `Pipeline Operations Workflow.md`.
- **Neu (v4-Dateinamen):** `Q09 Baseline Full Run.md`,
  `Q10 News Impact + FTMO Recommendation.md`, `Q11 Incumbent Full-History Confirmation.md`,
  `Q12 Pattern Filter Selection.md`, `Q13 Parameter Optimization & Freeze.md`,
  `Q14 Best-Settings Head-to-Head.md`, `Q15 Final Portfolio Construction.md`,
  `Q16 Operational Readiness.md`, `Q17 Live Burn-In DXZ.md`, `Gate Manifest v4 Diff.md`.

`Pipeline Rebaseline Directive 2026-08-23.md` bleibt unverändert (Quelle der Autorität).

---

## C · Inbound-Wikilink-Updates (aktive Seiten, die auf archivierte Ziele zeigen)

Ergebnis eines Vault-weiten Greps nach `[[…Q09..Q16 alte Namen…]]` und `Gate Manifest v3 Diff`.
Nur aktive Seiten außerhalb der archivierten/überschriebenen Seiten sind gelistet.

| Datei | Zeile | Alt | Neu |
|---|---|---|---|
| `05 Skills/qm-t6-deploy-verification.md` | 25 | `[[../03 Pipeline/Q12 Operational Readiness]]` | `[[../03 Pipeline/Q16 Operational Readiness]]` |
| `05 Skills/qm-t6-deploy-verification.md` | 25 | `[[../03 Pipeline/Q13 Live Burn-In DXZ]]` | `[[../03 Pipeline/Q17 Live Burn-In DXZ]]` |
| `12 ToDo/08_DXZ_Live_Book.md` | 14 | `[[../03 Pipeline/Q11 Portfolio Construction\|Q11]]` | `[[../03 Pipeline/Q15 Final Portfolio Construction\|Q15]]` |
| `12 ToDo/08_DXZ_Live_Book.md` | 120 | `[[../03 Pipeline/Q11 Portfolio Construction]]` | `[[../03 Pipeline/Q15 Final Portfolio Construction]]` |
| `12 ToDo/07_FTMO_Kampagne.md` | 72 | `[[../03 Pipeline/Q11 Portfolio Construction\|Q11]]` | `[[../03 Pipeline/Q15 Final Portfolio Construction\|Q15]]` |
| `12 ToDo/07_FTMO_Kampagne.md` | 109 | `[[../03 Pipeline/Q11 Portfolio Construction]]` | `[[../03 Pipeline/Q15 Final Portfolio Construction]]` |
| `12 ToDo/AI ToDos/OWNER.md` | 38 | `[[03 Pipeline/Gate Manifest v3 Diff\|Gate Manifest v3 Diff]]` | `[[_ARCHIV/03 Pipeline/Gate Manifest v3 Diff\|Gate Manifest v3 Diff]]` |

Hinweis: Inbound-Links **innerhalb** überschriebener Hub-Seiten (Pipeline Overview / Operations
Workflow) werden durch den Staging-Inhalt ersetzt und brauchen keine separate Ersetzung.
Links **innerhalb** archivierter Seiten bleiben v3 (in `_ARCHIV` erlaubt) und lösen per Stamm auf.

---

## D · In-place-Token-Ersetzungen (aktive Nicht-Gate-Seiten)

Q00–Q08-Verweise bleiben unverändert. Nur eindeutige Ganzbereichs-/Struktur-Token werden ersetzt.

| Datei | Alt | Neu | Anmerkung |
|---|---|---|---|
| `08 Current State/Current Operating State.md` | `## Delta 2026-08-23`-Abschnitt (erster Bullet) | zusätzlicher v4-Bullet davor eingefügt | Delta-Notiz zur v4-Migration (additiv) |
| `08 Current State/Current Operating State.md` | `Q00–Q13-Pipeline` | `Q00–Q17-Pipeline` | aktuelle strukturelle Aussage (Abschnitt „Factory / Pipeline") |
| `08 Current State/Mission Baseline.md` | `Q00–Q16-Vertrag` | `Q00–Q17-Vertrag` | Top-Banner: Gesamt-Pipeline-Span |
| `08 Current State/Mission Baseline.md` | `EA-Lifecycle Q00..Q13` | `EA-Lifecycle Q00..Q17` | Verlinkter Detailhinweis |

Alle Ersetzungen sind idempotent (Skip, wenn das Neu-Token bereits vorhanden ist).

---

## E · Bewusst NICHT automatisch angewandt (Human-Review / Folge-Tickets)

Diese Änderungen sind semantische Umschreibungen oder liegen außerhalb einer reinen
Vault-Datei-Bearbeitung. `APPLY.py` fasst sie **nicht** an; sie sind hier für den Review gelistet.

1. **`08 Current State/Heartbeat.md`** — auto-gerendert (`tools/strategy_farm/heartbeat_snapshot.py`,
   Task `QM_Orchestrator_Heartbeat_15min`, alle 15 min überschrieben). Die Zähler-Labels
   (`Q10-PASS`, `Q14`, `Q09_NEWS offen`, `Q06 PASS_SOFT`) stammen aus dem Code. Ein Vault-Edit
   wäre wirkungslos. **Folge-Ticket (Codex):** Label-Quelle in `heartbeat_snapshot.py` /
   `phase_ids.py` auf v4-Nummerierung umstellen (erst zusammen mit der v4-Aktivierung, sonst
   Drift gegen den aktiven v3-Runtime).
2. **`08 Current State/Current Operating State.md`** — die datierten Delta-Blöcke
   (Delta 2026-08-21: `Q02..Q10 → Q14 → Q15 → Q16 → Q11`, `Welle 2 (Q14→Q16, …)`;
   Delta 2026-08-10/2026-08-20: `Q09_NEWS`, `Q02–Q10`, `Q11-Portfolio-Admission`) sind
   **historische, datierte Einträge unter dem v3-Vertrag** und werden gemäß Direktive §3 (alte
   IDs behalten ihre Bedeutung) **nicht rückwirkend umnummeriert**.
3. **`08 Current State/Mission Baseline.md` L71** — „Die automatisierten Gates Q02–Q10 laufen
   über T1–T10; Q00/Q01 und Q11–Q13 besitzen eigene Autoritäten." ist eine **semantische**
   Aussage (v4: automatisiert Q02–Q14 pipeline, Q00/Q01 + Q15–Q17 eigene Autoritäten). Umschrift
   dem Human-Review überlassen — kein reiner Token-Swap.
4. **`08 Current State/Mission Baseline.md` L78** — Heureka-Zeile „Q10 PASS, Q11-Aufnahme,
   Q12-Bereitschaft und Q13-Burn-In" ist eine **semantische** Remap (v4: Q11-Confirmation,
   Q15-Aufnahme, Q16-Bereitschaft, Q17-Burn-In). Human-Review.
5. **In-Text-Gate-Verweise innerhalb der kopierten v3-Bodies** (Q10 News, Q11 Confirmation,
   Q12/Q13/Q15) nennen im Fließtext noch v3-IDs/Storage-Tokens. Das ist **Absicht** (Storage- und
   Code-Tokens bleiben bis zur v4-DB-Migration v3); Kopf-Tabelle, Herkunft-Zeile und
   [[Gate Manifest v4 Diff]] geben das Mapping. Optionaler redaktioneller Feinschliff nach
   v4-Aktivierung.

---

## F · Reihenfolge in `APPLY.py`

1. Archivieren (A) — Move + Header-Prepend.
2. Kopieren (B) — Staging → Vault.
3. Ersetzen (C + D) — Inbound-Wikilinks + Token.
4. Linter (`00 Governance/lint_company_reference.py`) ausführen, PASS/FAIL drucken.

`--dry-run` (Default) verändert nichts; es druckt den Plan und eine simulierte Lint-Prognose.
`--apply` führt 1–4 real aus.
