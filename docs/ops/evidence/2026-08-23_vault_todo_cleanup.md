# Vault ToDo-Sektion zusammengeräumt — 2026-08-23 (abends)

**Auftrag:** OWNER 2026-08-23 — „ToDo Sektion im Vault zusammenräumen", nach getaner Tagesarbeit.
**Betrieb:** Claude (Orchestrator). **Scope:** nur `12 ToDo/` + Archiv `12 ToDo/AI ToDos/Archive/`.
Kein Repo-Code/DB/Fabrik/T_Live berührt. Router-DB (`agent_tasks`) read-only (`mode=ro`) als
Autorität abgeglichen.

## Ergebnis in Zahlen

| Klasse | Anzahl | Wohin |
|---|---:|---|
| **DONE** (Router terminal PASSED/APPROVED oder Repo-Evidenz) | **~40** | abgehakt + verschoben nach `Archive/Erledigt 2026-08-23.md` |
| — davon @Claude-ToDos | 14 | inkl. Strategy-Archive-Matrix, Balke/XAUUSD, DL-090, Relikt-Purge, Q12-Register, 963-Disposition, REVIEW 80→0 |
| — davon @Codex-ToDos | 23 | Vault-Rebuild 08-20 (4), Maintenance-Ledger 08-21 (15), Health-/Snapshot-/Symbol-Tasks (3), Detailseite (1) |
| — davon @Antigravity / 09 | 3 | Source-Refill (`7f48a274`), keine Zweit-DB, Corpus-Manifest 130/130 |
| — Review-Lane 2026-08-23 | 31 | 14 APPROVED / 12 RECYCLE / 5 BLOCKED (`docs/ops/evidence/2026-08-23_review_*.md`) |
| **OPEN, Router-Task gebunden** | **~18** | auf den Boards belassen, Router-ID + Assignee je Zeile geprüft |
| **OPEN, nur notiert (kein Router-Task)** | **15** | markiert `(nur notiert — kein Router-Task)` → siehe Liste unten |
| **SUPERSEDED** | 1 Ticket + 9 Prosa-Stellen | `-502` (Q10.1–Q10.3) durchgestrichen + archiviert; v3-Gate-Nummerierung auf 8 Seiten mit v4-Banner versehen |
| **OWNER-Entscheidungen entschieden 2026-08-23** | 7 | verschoben nach `Archive/Entscheidungen 2026-08-23.md` |

## Was strukturell passiert ist

- **Archiv-Konvention** (`12 ToDo/AI ToDos/Archive/`, wie `Entscheidungen 2026-08-21/22`)
  erweitert um zwei neue Seiten: `Entscheidungen 2026-08-23.md` (7 OWNER-Entscheide + Gate-Manifest
  v4) und `Erledigt 2026-08-23.md` (abgeschlossene AI-ToDos mit Router-Verdikt + Evidenzpfad).
- **`_INDEX.md`** komplett neu als kurzer Hub: das eine Ziel (≥25 durch **Q14** → Buch), die drei
  Makrophasen (v4 Q00–Q17), Boards je Bearbeiter, OWNER-Entscheidungsschlange (≤5), „Heute
  erledigt 2026-08-23"-Pointer.
- **`AI ToDos/OWNER.md`** auf das Nötige gekürzt: 5er-Entscheidungsschlange (Pointer-Preset-Deploy
  `!`, A1-Zähleinheit, A2-Optimierung, Backfill-Tranche-1, SH-2-OFF-Fenster) + VID-XAG +
  REM-MNT-036 + vertagter MQL5-Kandidat. Entschiedenes raus.
- **`Claude.md` / `Codex.md` / `Antigravity.md`** auf offene/laufende Arbeit reduziert, jede Zeile
  mit Router-ID/Status oder „nur notiert"-Flag; Erledigtes in die Archivseite verschoben.
- **Gate-Nummerierung v3→v4** aktualisiert wo eindeutig (01 Prozesse, 03 Mission Control, 08 DXZ,
  Q12-Pattern-Filter) und mit datiertem v4-Banner + Mapping-Link versehen wo eine Vollumschreibung
  riskant/unnötig wäre (00 CEO-Masterplan, 02 Vault, 04 Website, 10/11/13 Analyse-Snapshots).
- **Design-/Programmseiten** (01, 02, 05, 06, MQL5/02) mit Banner „Checkboxen sind Design-/Abnahmepunkte,
  keine beauftragten Router-Tasks" versehen — hält die Trennung notiert vs. beauftragt, ohne ~50
  Zeilen einzeln zu taggen.

## „Nur notiert — kein Router-Task" (Kandidaten für Kommissionierung)

Diese offenen Punkte tragen keine `agent_tasks`-Zeile und sind damit **noch nicht beauftragt**:

**@Claude**
1. `QM-TODO-20260820-101` Mission-Control-Wireframe (Vorbedingung `-002` erledigt → jetzt commissionierbar)
2. `QM-TODO-20260820-102` Website-Kerzen-/Chart-Redesign (Vorbedingung `-003` erledigt → commissionierbar)
3. `QM-TODO-20260820-103` Logos/Media MQL5 (blockiert: OWNER-Kandidatenwahl)
4. `QM-TODO-20260821-133` Milestone-Ledger aufsetzen
5. `QM-TODO-20260821-124` Vault-Navigation kanonisieren
6. `QM-TODO-20260821-136` Probation-Review-Paket 06.09. (dated)
7. `QM-TODO-20260821-144` Q06/Q07-Altlast Live-Sleeves adjudizieren (braucht Codex-Kapazität + OWNER)
8. `QM-TODO-20260821-142` Quartals-Re-Q08 01.10. (dated, Start Mitte September)

**@Codex**
9. `QM-TODO-20260822-001` G-Drive Geisterordner-Purge (gated: `OWNER-DEC-G-RETENTION` manifest-first)
10. `QM-TODO-20260822-002` `.private/VPS_SERVER_RECORD.md` verschlüsseln (blockiert: `OWNER-DEC-BACKUP-KEY` vertagt)

**@Antigravity**
11. `QM-TODO-20260820-201` Website-Implementierungsbasis einbauen (läuft derzeit über Codex `rb-archive-public-website`)
12. `QM-TODO-20260822-201` „Alpha Refinery" Batch-Ingestion (geparkt: Reservoir-Regel)

**Programm 09 (Research)**
13. Point-in-time-Eventdaten mit `known_at_utc` definieren
14. Run-Selfreport um Pfad/SHA/Zeilenzahl/Max-Datum/Schema-Version erweitern
15. Drei MQ5-Quellen im Source-Ledger registrieren (quarantänisiert, aber nicht registriert)

Dazu die OWNER-/Live-gated Audit-Folgeaufgaben in `08_DXZ_Live_Book.md` (Deploy-Wahrheit,
Consumer-Bindung, Burn-in-Reparatur, Account-Governor, Full-chain-Requal) — als Block-Banner
markiert, einzeln zu kommissionieren, wenn der DXZ-Track vorgezogen wird.

## Terminal, Re-Route prüfen (auf Codex-Board vermerkt)

- `a3ba2414` (304 nie-gegatete EAs einschleusen) = BLOCKED
- `b2bf2460` (DL-089 Welle 1, Batch 2) = FAILED

Brauchen eine Wurzel-Analyse + append-only Neubeauftragung, nicht stille Ablage.

## Verifikation

- Vault-Linter: **PASS** (`python "G:/My Drive/QuantMechanica - Company Reference/00 Governance/lint_company_reference.py"`)
  vor und nach der Aufräumung. Keine Legacy-`P*`-Gate-Tokens, keine alten Rollennamen, keine
  gebrochenen Wikilinks.
- Q10.1–Q10.3 erscheinen nur noch durchgestrichen (Mission Control) und im Archiv.
- Router-Zustände gegen `farm_state.sqlite` (`mode=ro`) je zitierter Task-ID geprüft.
