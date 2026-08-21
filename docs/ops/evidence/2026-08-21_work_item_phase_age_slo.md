# Work-item per-phase age SLO — 2026-08-21

## Result

MNT-039 follow-up is implemented as the `work_item_phase_age_slo` farm-health check. It is registered as a database-backed critical check in `health.ALL_CHECKS`; consequently its result is written to `D:/QM/strategy_farm/state/health.json`, included in `health_alarms.log` when failing, and displayed on the existing cockpit health surface.

The threshold is not a hand-authored duration. For each canonical Q phase, the check measures elapsed seconds from `created_at` to the terminal `updated_at` of every `done` or `failed` row, then uses the empirical nearest-rank p95. Legacy `Pn` labels are folded into `Qnn` before deriving the distribution. An open `pending` or `active` row violates when its age since `created_at` exceeds that phase's own threshold. An open phase with no terminal sample is `UNKNOWN`/WARN, never green by absence.

## Live derivation and violations

Observed during implementation on 2026-08-21 (thresholds rounded here; the JSON receipt retains seconds and every violating row):

| Q phase | Terminal n | Empirical p95 hours | Open | Violations | Oldest violating row IDs |
|---|---:|---:|---:|---:|---|
| Q02 | 74,963 | 585.91 | 718 | 584 | `b967119e`, `38c3b787`, `2294c626` |
| Q03 | 13,069 | 210.87 | 43 | 21 | `2735c545`, `adfa7182`, `c15e6f39` |
| Q04 | 16,775 | 438.05 | 1,439 | 2 | `34c5dfbf`, `d7e0fb4a` |
| Q05 | 1,072 | 1,187.91 | 6 | 0 | — |
| Q06 | 518 | 15.13 | 1 | 1 | `558b70da` |
| Q07 | 479 | 270.10 | 21 | 0 | — |
| Q08 | 691 | 511.45 | 6 | 0 | — |
| Q09_NEWS | 85 | 41.73 | 24 | 21 | `1bc0c677`, `4263d6b3`, `494651b2` |

Total current violation count: **629**. A non-production harness phase also had one open row and no terminal sample; the check surfaces that class as unmeasured rather than treating it as compliant.

The complete current violation list, including work-item UUID, EA ID, symbol, state, creation timestamp, measured age, per-phase sample count, and exact threshold, is in `2026-08-21_work_item_phase_age_slo_snapshot.json` beside this document.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_mnt039_limbo_contract.py -q` → `6 passed`.
- `python -m py_compile tools/strategy_farm/health.py` → exit 0.
- Direct read-only live invocation → `FAIL`, value `629`, with the five violating Q-phase cohorts named above.
- The fixture test proves legacy `P2` and canonical `Q02` share one distribution, nearest-rank p95 is used, and an actionable-looking open row over that measured threshold is refused as stale.
- The no-history fixture proves an open phase without a completion distribution is WARN/UNKNOWN and that the check is registered in the farm-health surface.

No queue row, verdict, gate result, terminal setting, or pipeline threshold was changed.
