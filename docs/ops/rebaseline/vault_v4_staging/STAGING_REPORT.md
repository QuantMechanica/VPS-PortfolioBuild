# STAGING_REPORT — Gate Manifest v4 Vault-Migration (2026-08-23)

**Autor:** Claude (Orchestrator), Branch `agents/board-advisor`
**Zweck:** Nachweis, dass die v4-Vault-Migration vollständig gestaged, dry-run-geprüft und
lint-sauber ist. **Kein Vault-Edit erfolgt** — alles liegt in
`docs/ops/rebaseline/vault_v4_staging/`. `APPLY.py --apply` ist NICHT ausgeführt.

Kontext: v4 ist ein Design-/Migrationsentwurf (`gate_manifest.v4.draft.json`, READ_INERT,
`default_manifest_switch=false`). Der aktive Runtime-Vertrag bleibt v3 bis zur OWNER-Ratifikation
(ROT). v4 ändert **keine** Kriterien/Schwellen/Seeds/Fenster — nur IDs, Reihenfolge, Phasen und
entfernt die zwei Nicht-Linearitäten (Q10A-vor-Q09, Rücksprung Q16→Q11).

---

## 1 · Gestagte Dateien (23)

**`03 Pipeline/` — 18 Gate-Seiten Q00…Q17** (Kriterien/Schwellen/Fenster/Owner-Text verbatim
aus den v3-Seiten; ergänzt um v4-Kopf, „Herkunft"-Zeile und aktualisierte prev/next-Links):

| v4 | Datei | Herkunft |
|---|---|---|
| Q00 | `Q00 Research Intake.md` | v3 Q00 (unverändert) |
| Q01 | `Q01 Build & Spec.md` | v3 Q01 (unverändert) |
| Q02 | `Q02 Baseline Screening.md` | v3 Q02 (unverändert) |
| Q03 | `Q03 Parameter Sweep.md` | v3 Q03 (unverändert) |
| Q04 | `Q04 Walk-Forward + Commission.md` | v3 Q04 (unverändert) |
| Q05 | `Q05 Gross Full-History Robustness.md` | v3 Q05 (unverändert) |
| Q06 | `Q06 Stress HARSH.md` | v3 Q06 (unverändert) |
| Q07 | `Q07 Multi-Seed.md` | v3 Q07 (unverändert) |
| Q08 | `Q08 Davey Statistical Validation.md` | v3 Q08 (unverändert; In-Text-Gate-Refs auf v4 gezogen) |
| Q09 | `Q09 Baseline Full Run.md` | **neu** aus v3 Q10A/Q08-Baseline + Proposal (promoviert) |
| Q10 | `Q10 News Impact + FTMO Recommendation.md` | v3 Q09 |
| Q11 | `Q11 Incumbent Full-History Confirmation.md` | v3 Q10 |
| Q12 | `Q12 Pattern Filter Selection.md` | v3 Q14 |
| Q13 | `Q13 Parameter Optimization & Freeze.md` | v3 Q15 |
| Q14 | `Q14 Best-Settings Head-to-Head.md` | v3 Q16 (terminal, `next=null`, KEEP_INCUMBENT gültig) |
| Q15 | `Q15 Final Portfolio Construction.md` | v3 Q11 (Buch-Trigger-Eintritt, 2026-08-23-Banner eingefaltet) |
| Q16 | `Q16 Operational Readiness.md` | v3 Q12 |
| Q17 | `Q17 Live Burn-In DXZ.md` | v3 Q13 |

**`03 Pipeline/` — 3 Hub-Seiten:**
- `Pipeline Overview.md` — für v4 neu geschrieben (drei Phasentabellen, linearer Pfad,
  Mapping-Tabelle v3→v4, Storage/`gate_contract_version`-Notiz, Buch-Trigger).
- `Pipeline Operations Workflow.md` — v4-Topologie (`gate_manifest.v4.json`); **Q05-Namensdrift
  korrigiert** zu „Gross Full-History Robustness" (v3-Seite sagte fälschlich „Stress Medium").
- `Gate Manifest v4 Diff.md` — v3→v4-Diff-Tabelle inkl. Dependency-Role-Remap + Storage-Strategie.

**Staging-Wurzel:** `ARCHIVE_PLAN.md`, `APPLY.py`, `STAGING_REPORT.md` (diese Datei).

---

## 2 · Dry-run-Zusammenfassung (`python APPLY.py --dry-run`)

```
--- 1. ARCHIVE (move to _ARCHIV/03 Pipeline/) ---   9 to move, 0 already archived
--- 2. COPY (staging -> vault) ---                  21 to write (9 overwrite Q00-Q08,
                                                    2 overwrite hubs, 10 create), 0 missing
--- 3. REPLACEMENTS ---                             11 to apply, 0 already applied, 0 unresolved
--- 4a. SIMULATED post-apply lint ---               PASS  (forbidden tokens + wikilinks)
--- 4b. REAL LINTER on current vault [baseline] --- Company Reference lint: PASS  (rc=0)
```

- **9 Archivierungen** (alte v3-Seiten Q09…Q16 + „Gate Manifest v3 Diff") → `_ARCHIV/03 Pipeline/`
  mit „Superseded by v4 2026-08-23"-Header.
- **21 Kopien** aus dem Staging in `03 Pipeline/`.
- **11 Ersetzungen** (7 Inbound-Wikilink-Retargets + 4 in-place-Token/Delta-Inserts), alle mit
  Status `APPLY` — Anker gefunden, nichts unauflösbar.
- **Simulierte post-apply Lint: PASS.** Die Simulation modelliert den Nach-Zustand
  (Archiv-Verschiebung, Staging-Kopien, Ersetzungen) und prüft die zwei von der Migration
  berührbaren Linter-Checks (verbotene Aktiv-Tokens, Wikilink-Auflösung). Die übrigen
  Linter-Checks (Frontmatter, Symbole, ToDo-Routing) werden von der Migration nicht berührt.
- **Baseline-Lint (unveränderter Vault): PASS** — die Migration startet von einem grünen Vault
  und hält ihn grün.
- **Idempotenz:** Bei erneutem Lauf melden bereits archivierte Seiten `ALREADY_ARCHIVED` und
  bereits angewandte Ersetzungen `ALREADY_APPLIED`; der Archiv-Header wird nie doppelt gesetzt.

**Kollisionsprüfung:** Alle 9 Altnamen unterscheiden sich von den 18 v4-Dateinamen; kein
Überschreiben eines Archivkandidaten durch eine neue Seite. Q00–Q08 behalten Dateinamen und
werden in-place überschrieben. Wikilinks lösen nach der Archivierung weiter per Dateinamen-Stamm
auf (kein Broken-Link).

---

## 3 · Mehrdeutigkeiten / bewusst NICHT automatisch angewandt (Human-Review)

Diese Fälle sind aus `APPLY.py` **ausgelassen** und dem Review vorgelegt (Details in
`ARCHIVE_PLAN.md` §E):

1. **`08 Current State/Heartbeat.md`** — auto-gerendert (`heartbeat_snapshot.py`, alle 15 min
   überschrieben). Zähler-Labels `Q10-PASS / Q14 / Q09_NEWS offen / Q06 PASS_SOFT` stammen aus
   dem Code; ein Vault-Edit wäre wirkungslos. **Folge-Ticket Codex:** Label-Quelle in
   `heartbeat_snapshot.py`/`phase_ids.py` gleichzeitig mit der v4-Aktivierung umstellen (sonst
   Drift gegen den aktiven v3-Runtime).

2. **Datierte historische Delta-Blöcke in `Current Operating State.md`** (Delta 2026-08-21:
   `Q02..Q10 → Q14 → Q15 → Q16 → Q11`, `Welle 2 (Q14→Q16)`; 2026-08-10/2026-08-20: `Q09_NEWS`,
   `Q02–Q10`) — **nicht rückwirkend umnummeriert** (Direktive §3: alte IDs behalten ihre
   Bedeutung). Nur die aktuelle strukturelle Zeile `Q00–Q13-Pipeline` → `Q00–Q17-Pipeline` wird
   ersetzt, plus ein additiver v4-Delta-Bullet.

3. **`Mission Baseline.md` semantische Zeilen** (L71 automatisierte-Gates-Band; L78 Heureka-Zeile
   `Q10 PASS, Q11-Aufnahme, Q12-Bereitschaft, Q13-Burn-In`) — **semantische Remaps**, kein reiner
   Token-Swap; Human-Review. Nur die eindeutigen Span-Token (`Q00–Q16-Vertrag`→`Q00–Q17`,
   `EA-Lifecycle Q00..Q13`→`..Q17`) werden ersetzt.

4. **`12 ToDo/`-Prosaseiten mit Q09–Q16-Tokens** — bewusst nicht angetastet außer den zwei
   klaren Wikilink-Retargets in `07_FTMO_Kampagne.md` und `08_DXZ_Live_Book.md` (Portfolio
   Construction → Q15). Beispiele für **echte Mehrdeutigkeit** „Q10 könnte beide Verträge
   meinen":
   - `08_DXZ_Live_Book.md:20` „Q08-, Q09- und Q10-Dashboardchips stammen aus unterschiedlichen
     Regelgenerationen" und `:84` „der dokumentierte Q10-FAIL" — hier ist `Q10` die v3-Confirmation
     (=v4 Q11), **nicht** v4-Q10 (News). Ein naiver Token-Swap wäre falsch. → Human-Review.
   - `04_Website.md:106–110` listet „Q09 News … Q13 Live Burn-In" als öffentliche Methodik-Beschreibung
     (semantisch, v3). → Human-Review.
   - `01_Prozesse_Datenbanken_Wissensquellen.md:46/138`, `02_Vault_Ueberarbeitung.md:42/68`,
     `03_Mission_Control_Cockpit.md:44/166/168/246`, `05_MQL5_EA_Productisierung.md:30/39/58`,
     `00_CEO_Masterplan_2026-08-21.md` (zahlreich), `AI ToDos/{Claude,Codex}.md` — alle enthalten
     v3-Gate-IDs in Planungs-/Historienkontext. Sammel-Folge-Ticket „ToDo-/MC-Seiten auf
     v4-Nummerierung nachziehen" **nach** v4-Aktivierung; heute nicht angefasst (Drift-Vermeidung
     gegen aktiven v3-Runtime + Goodhart-Risiko bei Massen-Regex).

5. **In-Text-Gate-Verweise in den kopierten v3-Bodies** (Q10/Q11/Q12/Q13/Q15) nennen im Fließtext
   noch v3-IDs und Storage-Tokens (`Q09_NEWS`, `q10_confirmation.py` etc.). **Absicht:** Storage-
   und Code-Tokens bleiben bis zur v4-DB-Migration v3; Kopf-Tabelle + Herkunft-Zeile +
   [[Gate Manifest v4 Diff]] liefern das Mapping. Ein „Lese-Hinweis"-Block auf jeder betroffenen
   Seite macht das explizit. Optionaler redaktioneller Feinschliff nach v4-Aktivierung.

---

## 4 · Empfohlene nächste Schritte

1. **OWNER-Ratifikation der v4-IDs/Fenster** (ROT) gemäß `GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md` §8.
2. Nach Ratifikation: `python APPLY.py --apply` (schreibt Vault, läuft Linter, erwartet PASS).
3. Codex-Folge-Ticket: `heartbeat_snapshot.py`/`phase_ids.py` Label-Quelle + `gate_manifest.py`
   Loader/Schema/Storage-Migration (`gate_contract_version`, Dependency-Role-CHECK-Union) —
   gleichzeitig mit der Runtime-Aktivierung (`default_manifest_switch`).
4. Human-Review der §3-Positionen (ToDo-/MC-/Mission-Baseline-Prosa) als eigener Redaktions-Pass.
