# QUA-605 Final Checkpoint Template (2026-05-15)

Purpose: final run-rate checkpoint for [QUA-601](/QUA/issues/QUA-601).

## Measurement Protocol

- Source query (authoritative):
  - `SELECT COUNT(*) AS weekly_run_count FROM heartbeat_runs WHERE started_at >= NOW() - INTERVAL '7 days';`
- Runtime source allowed: `public-data/company-runtime.json` when produced by `infra/scripts/Run-RuntimeHealthScan.ps1` and includes `data_source=postgres`.
- Baseline (from QUA-601): `14,639` runs/week.
- Target date: `2026-05-15`.
- Target threshold: `<= 11,700` runs/week.

## Final Snapshot Fields (fill on 2026-05-15)

- `generated_at_utc`:
- `weekly_run_count`:
- `delta_vs_baseline_abs` = weekly_run_count - 14639:
- `delta_vs_baseline_pct`:
- `gap_to_target_abs` = weekly_run_count - 11700:
- `gap_to_target_pct`:

## Decision Branch

### Branch A — Target met

Condition: `weekly_run_count <= 11700`.

Required output:
- Short confirmation note in [QUA-605](/QUA/issues/QUA-605) and [QUA-601](/QUA/issues/QUA-601).
- Link to evidence artifact and source query text.

### Branch B — Target missed

Condition: `weekly_run_count > 11700`.

Required output: structurally-floor-bound memo in issue comment containing:
- Constraints that prevent additional reduction without harming required operations.
- Which reduction levers were already exhausted.
- Numerical floor estimate with evidence.
- Recommended next governance action (accept floor / approve structural changes).

## Hard-Rule Evidence Requirements

- No fantasy numbers: every metric must cite source (`company-runtime.json` snapshot timestamp or direct query output).
- Stop digging: if a proposed mitigation worsened outcomes in prior snapshots, include explicit revert recommendation.
- Scale-invariance check before any re-run proposal:
  1. List metrics affected by the proposed systemic change.
  2. State whether affected metrics influence the gate decision (`weekly_run_count` threshold).
  3. If gate decision cannot change, do not re-run; post rationale instead.

## Publication Checklist (2026-05-15)

- Update this file with actual numbers.
- Post comment on [QUA-605](/QUA/issues/QUA-605) with branch result and evidence links.
- Post roll-up comment on [QUA-601](/QUA/issues/QUA-601).