# Decision: activate Q10 recency for the 2026-09-01 cohort

- Date: 2026-08-22
- Status: accepted
- Authority: OWNER-DEC-GATECONTRACT
- Effective cohort: every Q10 work item with `created_at >= 2026-09-01T00:00:00Z`
- Pre-effective veto: OWNER may reverse this decision before 2026-09-01

## Decision

The recency policy switch is enabled now with an automatic, immutable cohort
boundary. Q10 rows created before the boundary remain shadow-only and are not
regraded. For a post-boundary row whose full-history base verdict is PASS:

- trailing-24-month PF below 1.0 at at least 10 trailing trades is Q10 FAIL;
- authoritative half-vs-half decline at or above 40% is Q10 FAIL;
- fewer than 10 trailing trades or otherwise non-assessable recency remains
  `UNKNOWN`: the base verdict stays unchanged, but deployment is blocked;
- an evidence endpoint more than nine calendar months older than the work
  item's creation month is `STALE_WINDOW`: the base verdict stays unchanged,
  but deployment is blocked.

The canonical `work_items.created_at` is passed to the runner; wall-clock time,
rerun time, and artifact modification time do not choose the cohort. This makes
the switch deterministic and prevents retroactive enforcement.

## Thresholds and scope

The 24-month window, PF 1.0 floor, 10-trade floor, 40% decline boundary, and
nine-month staleness limit are unchanged from the accepted 2026-07-26 decision.
This record supplies the previously missing effective cohort.

## Executable binding

- `framework/scripts/q10_recency.py::RECENCY_AXIS_ENFORCED`
- `framework/scripts/q10_confirmation.py::_apply_recency_gate`
- `tools/strategy_farm/farmctl.py::_phase_runner_cmd_for_work_item`
- `framework/scripts/tests/test_q10_recency.py`
- `tools/strategy_farm/tests/test_phase_runner_process_lineage.py`
