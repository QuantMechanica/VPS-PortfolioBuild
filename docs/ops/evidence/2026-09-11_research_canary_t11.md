# T11 research_canary controller — build and guarded hand-back

Date: 2026-09-11
Router task: `8f6a6b3c-46a1-4ad9-a261-ba0a7fdb4ac8`

## Delivered controller

`tools/strategy_farm/research_canary.py` is a standalone, no-DB governed
controller. It accepts only T11 (T12 remains declared but disabled), creates a
unique artifact root below `D:/QM/reports/research/<program>/<run_id>/`, and
writes a receipt for every dry-run, refusal, or completed test.

Before a launch it requires all of the following:

- a read-only `farm_state.sqlite` count and identical before/after isolation
  snapshot; an absent `FACTORY_MUTATION.lock`; and T11 absent from the active
  custom-history `runner_terminals` list;
- an exact signed-manifest verification of every requested `.DWX` archive file
  in `T11/Bases/Custom`, using the existing private-identity verifier;
- five one-minute fleet-CPU samples at or below 90%, at least 20 GiB free RAM,
  and fewer than the caller-declared (1–4) MetaTester agents;
- an EX5 and setfile already staged under T11's permitted `MQL5` trees, with
  SHA-256 values recorded before launch.

The only actual terminal launch path is inside this component, using a hidden,
suspended `Popen` assigned to a kill-on-close Windows job before its primary
thread is resumed. It has a bounded timeout and refuses missing reports. It
does not invoke a worker, `run_smoke`, `custom_history_smoke_admission`, a
factory lock, or a state-DB mutation.

## Focused verification

```text
python -m pytest tools/strategy_farm/tests/test_research_canary.py -q
5 passed
python -m py_compile tools/strategy_farm/research_canary.py
PASS
```

The tests cover T11-only admission, unchanged before/after isolation, mutation
and activation refusals, resource refusal, and Model-4/shutdown INI rendering.

## S3 status: intentionally not launched

No terminal was started. Inspection found neither the required
`QM5_41398_balke-pattern-repair-opt` EX5 nor the `2021_s3_l3_x18` setfile
staged in T11's permitted paths. The matching fleet setfile is present under a
separate production terminal and the canonical WINSWEEP artifact, but copying
it into T11 outside the governed controller would violate the new component's
input-binding boundary. The requested controller must be reviewed before it is
used to stage/bind those inputs and run its five-minute guard.

Therefore there is no T11 S3 result, comparison table, report hash, or
identity claim. The active factory, T1–T10 backtests, T_Live, AutoTrading,
thresholds, gate contracts, and signed archive were untouched. This packet is
an implementation hand-back only and must remain REVIEW until the first
guarded S3 run produces receipts.
