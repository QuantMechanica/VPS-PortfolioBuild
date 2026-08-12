# Pipeline Documentation and Cockpit Cohort Repair — 2026-08-12

**Router task:** `00db5c53-0098-4e03-925f-af5d09e560ec`

**Assigned agent:** Codex

**Disposition:** REVIEW candidate

**Change class:** documentation and read-only display only; no gate or work-item mutation

## Delivered scope

1. Corrected the stale Q08 prose in `tools/strategy_farm/phase_ids.py` from 10 to
   11 Davey sub-gates, matching the executable list including Q08.11 shuffled-drawdown
   Monte Carlo.
2. Added implementation-of-record `SPEC.md` documents for:
   - `QM5_1567_demark-td-reverse-sequential-h4`
   - `QM5_13301_balke-minute-range-breakout`
3. Made the Q02-Q10 chip semantics explicit as
   `LIFETIME DISTINCT PASS (MIXED ERAS)`.
4. Added read-only cohort contract `qm.cockpit-adjacent-cohort/v1`:
   - strict upstream PASS pair denominator;
   - exclusive next-gate `NO_ROW / OPEN / INFRA / SOFT / HARD / PASS` buckets;
   - separate Q09 NEWS and Q09 PORTFOLIO arms;
   - Q09 `BOTH AUTHENTICATED` intersection;
   - Q10 `HISTORICAL VISIBLE` versus `CURRENT CONTRACT BOUND` split.

The cohort panel uses canonical Q-row phase names only. It states that the evidence is
lifetime pair evidence and does not claim that historical rows share one lineage or gate
era. Q10's display binding means both Q09 dependency roles are present in the database;
execution-time evidence/hash verification remains authoritative.

## Atomic commits and main integration

| Unit | Canonical `agents/board-advisor` | Integrated `main` |
|---|---|---|
| Q08 prose + two SPEC documents | `39e0beb2e` | `4aae71664` |
| Cockpit cohort query/render + regression tests | `a6f75e11f` | `fbaab6d83` |

Only these task commits were cherry-picked into the clean registered main worktree
`C:/QM/worktrees/cto_main`; unrelated board-advisor history and unrelated dirty files in
the canonical checkout were not included.

## Verification

- `validate_spec_doc.py` — PASS for both new SPEC documents.
- `pytest test_render_cockpit_cohorts.py test_gate_manifest.py -q` — **11 passed** on
  both the canonical board-advisor checkout and integrated main.
- `py_compile` — PASS for `render_cockpit.py`, `phase_ids.py`, and the new cohort test.
- `git diff --check` — PASS for all task paths before commit.
- Full `render_cockpit.main()` integration run — PASS to a temporary HTML target
  (59,144 bytes); the live dashboard path was not written. Required lifetime label,
  cohort contract, Q09 arm/authentication, and Q10 split tokens were present.
- Live database read-only projection at verification time:

| Cohort | Projection |
|---|---|
| Q05 PASS -> Q06 | upstream 283; PASS 248, HARD 24, INFRA 9, NO_ROW 2 |
| Q06 PASS -> Q07 | upstream 255; PASS 179, HARD 35, INFRA 41 |
| Q07 PASS -> Q08 | upstream 179; PASS 18, HARD 96, SOFT 57, INFRA 8 |
| Q08 PASS -> Q09 NEWS | upstream 19; PASS 1, OPEN 18 |
| Q08 PASS -> Q09 PORTFOLIO | upstream 19; PASS 5, HARD 12, SOFT 2 |
| Q09 both authenticated | 1 |
| Q10 historical visible / current contract bound | 34 / 0 |

An exploratory pre-existing programme-panel suite remains coupled to mutable programme
status artifacts: on the board-advisor baseline it expected an older
`FACTORY INTENTIONALLY_OFF` string, and the pre-integration main baseline already had six
invalid-source failures. This task does not touch programme status loading, validation,
or rendering; the new hermetic database-query regressions and full temporary renderer
pass are the focused acceptance evidence.

## Safety and authority boundaries

- Database access uses SQLite `mode=ro` plus `PRAGMA query_only=ON` through the existing
  cockpit reader.
- No pipeline verdict, phase transition, dependency, task row, or gate threshold was
  written or changed.
- No EA source, binary, setfile, risk value, news staleness ceiling, terminal, T_Live,
  AutoTrading, or deploy surface was changed.
- Operator-facing phase labels remain Q-only.
