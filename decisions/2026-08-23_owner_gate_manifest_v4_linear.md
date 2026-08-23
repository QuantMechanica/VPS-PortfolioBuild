# OWNER decision record — Gate Manifest v4 (linear three-phase renumbering)

Date: 2026-08-23
Authority: OWNER, chat 2026-08-23 (two instructions, same day):
1. "Wenn Q11 jetzt nach Q16 ist, dann muss das auch in der Nummerierung logisch sein … Grob
   teilen wir das ganze jetzt in 3 Phasen: Strategie muss sich beweisen, Strategie wird
   optimiert, Strategie wird zum Buch korreliert und gegebenenfalls hinzugefügt."
2. "Bring es soweit, dass alles automatisch funktioniert, Skripten (zB Factory On und
   Factory Off) angepasst werden, der Vault dann aktuell ist und alles alte archiviert sowie
   die Gatesbenennung konsistent ist! Los gehts Ultracode"
Vault mirror: `03 Pipeline/Pipeline Rebaseline Directive 2026-08-23.md`.
Implementation task: `QM-TODO-20260822-402` / router `0257da30`.

## What is ratified by the OWNER instruction

- The per-EA path is strictly monotone; the Q16→Q11 back-edge and the Q10A-before-Q09
  ordering are removed.
- Three visible macro phases: **Strategiebeweis → Optimierung/Requalifikation →
  Buchbewertung**.
- **No gate threshold, window, criterion, seed or verdict changes.** v4 carries every v3
  criterion verbatim per gate (ROT untouched); only identifiers, order and phase grouping
  change.
- Book build is fail-closed: ≥25 fully requalified candidates **and** an explicit OWNER
  order artifact; the old auto-trigger (≥5 Q10 pairs) is abolished.

## Alt→Neu mapping (v3 → v4)

| v4 | Phase | Name | v3 origin | Evidence rule |
|---|---|---|---|---|
| Q00–Q08 | 1 Strategiebeweis | unchanged | Q00–Q08 | identical id + contract → REUSABLE |
| Q09 | 2 | Baseline Full Run | Q10A (evidence role) | hash-bound Q08 full-history baseline reusable, else run |
| Q10 | 2 | News Impact + FTMO Recommendation | Q09 (Q09_NEWS / Q09_PORTFOLIO storage) | RENUMBER_ONLY; portfolio arm informational (OWNER E1 2026-08-22) |
| Q11 | 2 | Incumbent Full-History Confirmation | Q10 | RENUMBER_ONLY |
| Q12 | 2 | Pattern Filter Selection (DL-089) | Q14 | RENUMBER_ONLY; zero-filter is a valid outcome |
| Q13 | 2 | Parameter Optimization & Freeze | Q15 | RENUMBER_ONLY; no-change valid |
| Q14 | 2 | Best-Settings Head-to-Head + Holdout | Q16 | terminal per-EA gate (`next=null`); KEEP_INCUMBENT valid |
| Q15 | 3 Buchbewertung | Final Portfolio Construction | Q11 | entry only via book guard |
| Q16 | 3 | Operational Readiness | Q12 | OWNER/manual |
| Q17 | 3 | Live Burn-In DXZ | Q13 | OWNER/manual |

Storage: `work_items.phase` keeps writing the id valid under the contract named in the new
`gate_contract_version` column; historical rows are never re-read with v4 semantics
(`contract_equivalence` map in the manifest gives version-aware display with provenance).

## Sub-decisions executed under the Auffangregel (Stehende Vollmacht 2026-08-20)

Reversible, documented, with rollback (v3 stays loadable as fixture; `DEFAULT_MANIFEST`
flip is a one-line revert). OWNER may override within 12h; until then these are the
recommendation being executed:

| # | Question | Executed recommendation | Rollback |
|---|---|---|---|
| A1 | Count unit for the ≥25 book trigger | `(EA, Symbol)` pairs at terminal Q14; report distinct EAs and strategy families alongside (Directive §6) | change constant in `book_build_guard.py` |
| A2 | Optimization segment mandatory? | Yes — every book candidate passes Q12–Q14; "no improvement" = `KEEP_INCUMBENT`, still terminal PASS | manifest flag |
| A3 | Q10 portfolio arm | stays informational-only (restates OWNER E1 2026-08-22) | n/a |
| A4 | Q09 (Baseline Full Run) as a numbered gate | yes, numbered and writable so the before/after comparison has a first-class row | n/a |

## Not decided here (still OWNER-only, ROT)

Any threshold/window change (e.g. the 12% Q02 replacement, activity pro-rata), candidate
pool / card universe definitions, anything touching the live account.

## Evidence trail

- `docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md`
- `docs/ops/rebaseline/DB_TEST_CENSUS_2026-08-23.md` (0 book-eligible pairs today; frontier = news gate)
- `tools/strategy_farm/config/gate_manifest.v4.json` (activation evidence appended on flip)
