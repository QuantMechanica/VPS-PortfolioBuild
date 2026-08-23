# OWNER-DEC-RISK-FREEZE — prevention wiring evidence

Date: 2026-08-23

Router task: `6e512650-a3e6-4563-8b62-7a9e31f04df7`

Authority: `decisions/2026-08-22_owner_dec_risk_freeze_executed.md`

Branch: `agents/board-advisor`

Disposition: **REVIEW — prevention implemented; freeze remains ACTIVE and held**

## Result

The live-risk freeze is now a fail-closed precondition at every repository
control point capable of staging, authenticating, defining, or copying a new
DXZ live book.  All control points consume
`tools/strategy_farm/risk_freeze.py::diff_against_baseline()` through the one
canonical `assert_live_book_mutation_allowed()` function; no second ACTIVE/
inactive interpretation was introduced.

The guard refuses:

- `ACTIVE`, even when `held=true`;
- a missing state file;
- unreadable JSON;
- a wrong schema or incomplete baseline;
- an unknown status; and
- an `INACTIVE`/`LIFTED` record without both explicit lift authority and a lift
  timestamp.

An allowed result therefore requires a durable `INACTIVE` or `LIFTED` record
with `lift_authority` (or legacy `lifted_by`) and `lifted_at_utc`.  This is not a
lift mechanism: no such state was written in this task.  Every ACTIVE refusal
prints the lift rule and the current three condition IDs, statuses, and blockers.

## Complete control-point inventory

### Search method

The inventory was derived, not guessed.  The canonical checkout was searched
for all of the following, then every hit was classified by whether it can
change the deployed composition/risk contract or merely reads it:

1. every `T_Live`, `live_deployment_pointer`, `MQL5/Presets`,
   `MQL5/Experts`, and DXZ profile reference under `tools/` and `docs/`;
2. Python and PowerShell mutation primitives (`write_text`, `write_bytes`,
   `json.dump`, `os.replace`, `shutil.copy*`, `Copy-Item`, `Move-Item`,
   `Set-Content`, `New-Item`);
3. every portfolio source containing `set_file_expectation`,
   `deployment_action`, `STAGE_ONLY`, `DRAFT_FOR_OWNER_APPROVAL`, or
   `APPLY_RECOMMENDED`; and
4. all consumers/producers of the runtime signed deployment pointer.

The resulting write/authentication boundaries are below.  Line numbers are for
the implementation under review.

| Boundary | Guarded location | Why it is a control point | Behaviour while ACTIVE |
|---|---|---|---|
| Canonical decision | `risk_freeze.py:205,362` | Only source of state parsing, baseline diff, and allow/refuse semantics | Refuses and names all lift blockers |
| Existing-preset risk staging | `portfolio/stage_tlive_presets_risk.py:71` | `--apply` materialises the proposed risk-vector files | `--apply` refused; dry-run remains read-only |
| New 11422 sleeve staging | `portfolio/build_11422_preset_FINAL24b.py:53` | `--apply` materialises a new sleeve preset | `--apply` refused; dry-run remains read-only |
| Current T_Live manifest builder | `portfolio/portfolio_manifest.py:408` | Mints the deploy-prep T_Live composition/risk contract | Refused before manifest write |
| Current Q11 DXZ builder | `portfolio/build_book_dxz.py:276` | Mints a proposed DXZ composition manifest | Refused before manifest/evidence write |
| Legacy deploy-capable DXZ generators | `gen_dxz_23sleeve_manifest.py:7`; `gen_dxz24_weekend_manifest.py:24`; `gen_dxz_final_manifest.py:32`; `gen_dxz23_20260726.py:96`; `gen_dxz24b_20260726.py:119` | Still-executable one-off generators can mint deploy-shaped manifests | Refused before output write |
| Signed deployment pointer | `generate_live_deployment_pointer.py:216` | `--signed` authenticates a composition as the runtime live book | Signed write refused; unsigned and dry-run review remain available |
| Sealed chart-contract edit | `reseal_chart09_ks_delta.py:66` | Changes a chart contract that recovery later binds to the live profile | Refused before reading/writing the target |
| Operational profile creation | `prepare_dxz_v2_liveops_profile.ps1:72-78` | Creates the chart profile that defines the loaded sleeve roster | Creation refused; `-VerifyOnly` deliberately remains read-only |
| Former manual copy | `deploy_tlive_book.py:56,115-160` | Copies staged `.set` and `.ex5` bytes to the two exact live-book directories | `--apply` calls the guard before plan parsing, directory creation, backup, or temp write |

The copy ceremony is default-dry-run, requires an existing OWNER approval
record, exact source SHA-256 values, destinations directly below only
`MQL5/Presets` or `MQL5/Experts/Live EAs`, a fresh backup directory outside
T_Live for apply, and post-copy SHA verification.  It never starts MT5, edits
configuration/charts, or touches AutoTrading.  Repository code cannot intercept
an arbitrary out-of-band Explorer/PowerShell write; the controlled procedure is
therefore now this guarded command, and raw copy is not a valid runbook step.

### Classified non-control hits

- `T_Live_ON.ps1` verifies and restarts the already-bound, unchanged profile.
  It does not stage or select a new composition.  Blocking it would turn a book
  freeze into an uptime halt, which the OWNER decision did not order; its
  AutoTrading authority remains OWNER+Claude only.
- `T_Live_Watchdog.ps1`, pulse, journal, health, dashboard, and audit tools read
  the book or write monitoring state only.
- `q09_live_news_backfill.py`, `dxz_as_live_requal.py`, and evidence resolvers
  use T_Live as a read-only source and stage into isolated tester sandboxes.
- News-calendar refresh and fail-closed news inputs are operational data, not a
  composition/risk mutation.  They remain available as required by the stale-
  news hard rule.
- `dxz_live_blend_reweight.py`, `dxz_next_book_trigger.py`, and other portfolio
  experiments emit analysis/OWNER templates with no apply path; FTMO builders
  target a different book.  Neither class was frozen.
- Portfolio/DD halt signals reduce risk and do not change roster, preset, or
  binary identity.

This classification plus the literal-path/mutation-primitive searches accounts
for every repository hit.  Before this change there was no repository command
that copied live presets/binaries: the last boundary was explicitly manual.

## Mission Control visibility

`mission_control_v2_data.py:912` now adds a `risk_freeze` contract section
directly from the canonical diff result.  Its schema requires status, held,
baseline/current sleeve count and total risk, drift, and lift conditions.
`render_cockpit_v2.py:357,832` renders a dedicated **Live Risk Freeze** panel.

A live read-only contract build on 2026-08-23 validated and returned:

```text
status=ACTIVE
held=true
baseline=24 sleeves / 9.7499 total RISK_PERCENT
current=24 sleeves / 9.7499 total RISK_PERCENT
lift_conditions=3
```

The three displayed conditions are:

1. `SP-A1/A2-DEPLOY-POINTER` — `BLOCKED`;
2. `NEWS-CONTRACT-V2` — `PARTIAL`; and
3. `GOVERNOR-HARDENING` — `PARTIAL`.

The emitter remains read-only.  While making its 24-hour ETA test deterministic,
the query was also corrected to use the function's supplied `now` value instead
of SQLite wall-clock `datetime('now')`; this changes no gate or queue state.

## Negative and positive proof

Focused suite:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_risk_freeze_prevention.py \
  tools/strategy_farm/tests/test_mission_control_v2_data.py \
  tools/strategy_farm/tests/test_render_cockpit_v2.py \
  tools/strategy_farm/tests/test_portfolio_manifest.py \
  tools/strategy_farm/tests/test_dual_book_builders.py

62 passed, 2 skipped in 4.76s
```

The tests prove both refusal and allow paths for the canonical gate, incumbent
staging, new-sleeve staging, signed pointer, current manifest builders, chart
reseal, and hash-bound live copy.  They separately prove missing, unreadable,
and invalid state refusal, the three condition IDs in an ACTIVE error, an
explicit OWNER-lift fixture that passes, dry-run read-only behaviour, and static
coverage of every legacy generator and the PowerShell profile boundary.

PowerShell/live read-only checks:

```text
prepare_dxz_v2_liveops_profile.ps1 -VerifyOnly
VERIFIED: DarwinexZero_V2_LiveOps = sealed 24-strategy V2 contract + read-only account monitor

prepare_dxz_v2_liveops_profile.ps1
LIVE_RISK_FREEZE_BLOCKED ... status=ACTIVE; held=True; ...
DXZ LiveOps profile creation refused by live-risk freeze guard.
```

The second invocation reached the guard before any mutation primitive.  No
profile, preset, binary, chart, terminal process, or AutoTrading state changed.

## Non-frozen pipeline proof

The freeze import is absent from `farmctl.py`, `terminal_worker.py`,
`compile_ea.py`, `build_gate_hardening.py`, `agent_router.py`, and
`q09_news_runner.py`; a dedicated regression test enforces that boundary.
Existing terminal-dispatch, cascade Q-phase, and review-repair tests also ran:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_terminal_worker_identity.py \
  tools/strategy_farm/tests/test_cascade_real_phase_runners.py \
  tools/strategy_farm/tests/test_review_repair.py

18 passed in 55.12s
```

Thus backtests, T1-T10, Q02-Q10 gates, builds, and reviews retain their prior
execution paths.  The guard is imported only by live-book control surfaces and
Mission Control's read-only projection.

## Live-state preservation

Final canonical verification:

```text
python tools/strategy_farm/risk_freeze.py verify
status=ACTIVE, held=true, drift=[], 24 -> 24 sleeves, 9.7499 -> 9.7499
```

Final freeze-state file SHA-256:
`82695AC67A7342C5F9443D4625FC849C83A9358937E5A5736F6F20D68CED13E5`.
Direct-file inventories had no task-time write:

| Live location | Direct files | Latest write UTC before this task |
|---|---:|---|
| `MQL5/Presets` | 24 | 2026-07-19T10:00:08.7093059Z |
| `MQL5/Experts/Live EAs` | 24 | 2026-07-31T17:13:30.4350067Z |
| `Profiles/Charts/DarwinexZero_V2` | 25 | 2026-08-13T19:23:30.1058166Z |
| `Profiles/Charts/DarwinexZero_V2_LiveOps` | 26 | 2026-08-22T14:02:57.2234942Z |

No terminal was launched, no active T1-T10 backtest was interrupted, and no
T_Live or AutoTrading action was performed.
