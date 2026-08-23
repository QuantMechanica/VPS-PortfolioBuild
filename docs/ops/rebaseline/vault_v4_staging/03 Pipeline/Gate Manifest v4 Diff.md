# Gate Manifest v4 — Diff-Tabelle v3 → v4 (OWNER-Direktive 2026-08-23)

**Status:** Design-/Migrations-Entwurf. Manifest `tools/strategy_farm/config/gate_manifest.v4.draft.json`
(`status=DRAFT_PROPOSAL_NOT_ACTIVATED`, READ_INERT, `default_manifest_switch=false`). Der aktive
Runtime-Vertrag bleibt `gate_manifest.v3.json`, bis der OWNER IDs/Fenster ratifiziert (ROT).
Quellen: `docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md`,
`decisions/2026-08-23_owner_gate_manifest_v4_linear.md`,
[[Pipeline Rebaseline Directive 2026-08-23]].

**Was sich NICHT ändert (ROT):** Kriterien, Schwellen, Seeds, Fenster, Verdikt-Vokabular,
DL-089/DL-084-Auswahlregeln, Authorities. v4 ändert **nur** Reihenfolge, Gate-IDs und
Phasengruppierung — und entfernt die zwei Nicht-Linearitäten.

## Die zwei behobenen Nicht-Linearitäten

1. **`Q10A` vor `Q09`** (Baseline-Stufe stand numerisch vor der News-Stufe) → v4 promoviert die
   Baseline zu einem echten linearen Gate an Position **Q09** (Baseline Full Run).
2. **Rücksprung `Q16 → Q11`** (Head-to-Head kehrte zum Buch-Gate zurück) → v4 macht das
   Head-to-Head zum **terminalen** Phase-2-Gate **Q14** (`next = null`); der Buch-Eintritt (Q15)
   erfolgt nur über den fail-closed Buch-Trigger.

## Drei Makrophasen

| Makrophase | Gates (v4) | Bedeutung |
|---|---|---|
| **1 · Strategie beweist sich** | Q00 … Q08 | Build, Baseline, DEV-Stabilität, OOS, Full-History/Stress/Statistik → target-neutrale, eingefrorene Baseline. IDs+Kriterien unverändert. |
| **2 · Strategie wird optimiert / requalifiziert** | Q09 … Q14 | Pre-News-Lauf → News+FTMO-Empfehlung → Incumbent-Confirmation → Pattern-Filter → Param-Opt/Freeze → versiegelter Head-to-Head. Terminiert in Requal-Verdikt; `KEEP_INCUMBENT` gültig. |
| **3 · Strategie wird zum Buch bewertet** | Q15 … Q17 | Portfolio → Operational Readiness → Live Burn-In. Eintritt nur via fail-closed Buch-Trigger. |

## Alt → Neu Mapping (je Gate)

| v3 ID | v3 Rolle | → v4 ID | Makrophase | Reuse-/Rerun-/Supersession-Regel |
|---|---|---|---|---|
| Q00 | Research Intake | Q00 | 1 | REUSE, ID unverändert |
| Q01 | Build & Spec | Q01 | 1 | REUSE, ID unverändert |
| Q02 | Baseline Screening | Q02 | 1 | REUSE, hash-gebunden; Economic FAIL terminal (Direktive §1) |
| Q03 | Parameter Sweep | Q03 | 1 | REUSE, hash-gebunden |
| Q04 | Walk-Forward + Commission | Q04 | 1 | REUSE, hash-gebunden |
| Q05 | Gross Full-History Robustness | Q05 | 1 | REUSE, hash-gebunden |
| Q06 | Stress HARSH | Q06 | 1 | REUSE, hash-gebunden |
| Q07 | Multi-Seed | Q07 | 1 | REUSE, hash-gebunden |
| Q08 | Davey Statistical Validation | Q08 | 1 | REUSE, hash-gebunden; eingefrorene Baseline |
| **Q10A** (Evidenz-Stufe) | Baseline Full Run (`source_phase` Q08) | **Q09** | 2 | **RENUMBER + PROMOTE.** v3 = display-only Evidenzbindung; v4 = echtes schreibbares Gate. Reuse nur hash-gebundene Q08-Full-History-Baseline. |
| Q09 (`Q09_NEWS`/`Q09_PORTFOLIO`) | News Impact + FTMO Recommendation | **Q10** (`Q10_NEWS`/`Q10_PORTFOLIO`) | 2 | RENUMBER. Storage-Split erhalten. Portfolio-Arm informational (OWNER E1 2026-08-22). |
| Q10 | Incumbent Full-History Confirmation | **Q11** | 2 | RENUMBER. Per-`(EA,Symbol)`-Confirmation. |
| Q14 | Pattern Filter Selection (DL-089) | **Q12** | 2 | RENUMBER. Jetzt **verpflichtend linear**; Cap 3/Richtung; **0 Filter = gültiges Pass-Through**. |
| Q15 | Parameter Optimization & Freeze | **Q13** | 2 | RENUMBER. DEV-Sweep + Freeze. |
| Q16 | Best-Settings Head-to-Head | **Q14** | 2 | RENUMBER. **Terminal `next=null`.** Referenz = Q09-Baseline. `CHALLENGER_PROMOTED`/`KEEP_INCUMBENT`. Rücksprung Q16→Q11 entfernt. |
| Q11 (`Q11_DXZ`/`Q11_FTMO`) | Final Portfolio Construction | **Q15** (`Q15_DXZ`/`Q15_FTMO`) | 3 | RENUMBER. Eintritt = Buch-Trigger. Portfolio-Metriken neu berechnet, nicht per-EA reused. |
| Q12 | Operational Readiness | **Q16** | 3 | RENUMBER. |
| Q13 | Live Burn-In DXZ | **Q17** | 3 | RENUMBER. `next=null`. |

## Dependency-Role-Remap (DB-CHECK)

| v3 dependency_role | → v4 |
|---|---|
| `Q08_INPUT` | `Q08_INPUT` (unverändert) |
| `Q09_NEWS` | `Q10_NEWS` |
| `Q09_PORTFOLIO` | `Q10_PORTFOLIO` |
| `PARENT_LINEAGE` | `PARENT_LINEAGE` (unverändert) |
| `CHALLENGER_Q10` | `CHALLENGER_Q11` |
| `Q14_ADMISSION` | `Q12_ADMISSION` |

## Legacy-`P*`-Key-Remap (nur für historische UNION-Lesevorgänge)

Die Storage-`P*`-Keys innerhalb des unveränderten Q00…Q08-Bandes bleiben unberührt. Nur die
drei Phase-3-Keys verschieben sich mit: der frühere Portfolio-Key → Q15, Operational-Readiness →
Q16, Live-Burn-In → Q17. Diese Keys erscheinen ausschließlich in Migration-/UNION-Reads, nie auf
Operator-Flächen.

## Storage-Strategie: STAMP, DON'T RENAME

1. `work_items.phase` ist `TEXT` ohne CHECK → neue v4-IDs sind ohne Tabellenmigration schreibbar.
2. **Neue Spalte `gate_contract_version` (TEXT) in `work_items`.** Jede Zeile wird nur unter ihrem
   eigenen Vertrag gelesen: ein v3-`Q10` (Incumbent Confirmation) wird **nie** als v4-`Q10` (News)
   gelesen. Backfill: Zeilen ab 2026-08-23 → `v3`; frühere per `pipeline_version`, sonst `legacy`.
3. `work_item_dependencies.dependency_role` hat einen erzwungenen CHECK → v4-Aktivierung braucht
   eine Tabellen-Rebuild-Migration, die den CHECK auf die **UNION** aus v3- und v4-Tokens
   erweitert (append-only, alte Tokens bleiben für historische Reads). SQLite kann einen CHECK
   nicht per `ALTER` ändern.
4. **Reuse-Äquivalenz:** Q00–Q08 unverändert → historische Zeilen direkt reusebar. Phase-2/3
   reusen über `contract_equivalence.v3_to_v4` nur bei vertragsgleichen Kriterien (ROT: Schwellen
   unverändert) **und** übereinstimmenden Build-/Setfile-/Fenster-Hashes.

## Fail-closed Buch-Trigger (Phase-3-Eintritt)

```
BOOK BUILD PERMITTED  ⇔  (qualified_candidates >= 25)  AND  (owner_order_artifact vorhanden & verifiziert)
```

- **qualified_candidates:** `highest_contiguous_valid_gate == Q14` mit terminalem Requal-Verdikt
  (`CHALLENGER_PROMOTED`/`KEEP_INCUMBENT`). Einheit `(EA, Symbol)`; zusätzlich distinct EAs +
  Strategie-Familien ausweisen.
- **owner_order_artifact:** signiertes `decisions/YYYY-MM-DD_owner_book_order_<venue>.md`,
  `venue ∈ {dxz, ftmo}`.
- Der frühere Auto-Trigger bei 5 Q10-Paaren ist aufgehoben (im Code bereits weg, jetzt explizit
  verboten). Unter 25 nur messen/vervollständigen — kein Probe-Buch.

## Aktivierung (ROT — OWNER-Ratifikation erforderlich)

Renumbering, „Optimierung wird verpflichtend" und die Storage-/CHECK-Migration sind ROT. Nötig:
finale IDs (Q00…Q17), Bestätigung des verpflichtenden Optimierungssegments (`KEEP_INCUMBENT`
gültig), `Q10_PORTFOLIO` informational, Buch-Trigger-Konvention, Storage-Migration, „keine
Fensteränderung". Vorlage: `GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md` §8.

## Nachzuziehende / archivierte Vault-Seiten

- Neu/überschrieben: [[Pipeline Overview]] · [[Pipeline Operations Workflow]] · alle Q00–Q17-Seiten.
- Archiviert nach `_ARCHIV/03 Pipeline/` (v3-IDs mit geänderter Bedeutung): die alten Seiten
  Q09 News Impact Mode, Q10 Full-History Confirmation, Q11 Portfolio Construction, Q12 Operational
  Readiness, Q13 Live Burn-In DXZ, Q14 Optimization Admission, Q15 Challenger Build and Freeze,
  Q16 Head-to-Head Requalification sowie „Gate Manifest v3 Diff". Details: `ARCHIVE_PLAN.md` im
  Staging-Ordner.
