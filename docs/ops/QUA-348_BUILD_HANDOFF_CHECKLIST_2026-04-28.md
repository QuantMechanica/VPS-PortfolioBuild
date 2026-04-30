# QUA-348 Build Handoff Checklist (2026-04-28)

## Purpose

Convert current blocker (`missing_src04_s09_ea_mapping_or_build_artifact`) into concrete Dev/CTO deliverables.

## Required Deliverables (must all exist)

1. EA source path (MQ5)
- Example target format: `framework/EAs/QM5_<eaid>_lien_perfect_order/QM5_<eaid>_lien_perfect_order.mq5`

2. Compiled artifact (EX5)
- Same folder as EA source.

3. Setfile path
- Example target format: `framework/EAs/QM5_<eaid>_lien_perfect_order/sets/QM5_<eaid>_EURUSD.DWX_D1_backtest.set`

4. Manifest mapping update
- Update `artifacts/qua-348/src04_s09_cto_payload_proposal_2026-04-28T122900Z.json`:
  - `ea_name`
  - `setfile_path`

5. Compile evidence JSON
- Create `artifacts/qua-348/src04_s09_compile_evidence.json` containing:
  - `ea_name`
  - `ea_source_path`
  - `ex5_path`
  - `compile_timestamp`
  - `compile_pass: true|false`

## Verification Steps

1. Rerun readiness checker:
- `artifacts/qua-348/check_src04_s09_readiness.ps1`

2. Confirm readiness output:
- `artifacts/qua-348/src04_s09_readiness_latest.json`
- Must show `ready: true` and empty `missing`.

## Operator Next Step (after ready)

Run first valid baseline cohort for `SRC04_S09` and publish:
- filesystem-truth report counts
- tracker-vs-filesystem comparison
- report byte-size NO_REPORT disambiguation
