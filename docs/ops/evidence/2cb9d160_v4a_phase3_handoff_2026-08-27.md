# V4a Phase 3 governed backend — review handoff

Task: `2cb9d160-d5c0-46ea-ae45-d145a63cf1f4`

Verdict: **IMPLEMENTATION PASS; VALIDATION BLOCKED BEFORE MT5 START**

The validation-only backend is implemented behind the process-scoped
`QM_ENABLE_WARM_CELL_RUNNER` feature flag. It invokes only the governed DEV2
Scheduled-Task controller, runs cells sequentially in the isolated lane, binds
the controller, lane contract, credential, helper, cold runner, terminal
program hashes, EA bytes, set-file bytes, and frozen history, and stops on the
first receipt deviation. It does not add production wiring or claim resident
MT5 IPC.

## Focused verification

- `python -m pytest -q tools/strategy_farm/tests/test_warm_cell_runner.py tools/strategy_farm/tests/test_warm_cell_phase3.py`: **29 passed**.
- `pwsh -NoLogo -NoProfile -NonInteractive -File framework/scripts/tests/Test-Dev2ControllerContracts.ps1`: **PASS**.
- Default-OFF probe: activation refused before output creation or controller
  launch when the feature flag was absent.
- The prepared cohort contains exactly 20 logger-complete authenticated cold
  receipts. All set files enforce `RISK_FIXED=1000` and `RISK_PERCENT=0`; none
  raises `qm_news_stale_max_hours` above 336.
- The 20 per-claim history receipts bind the same manifest
  `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`
  and the same 108-file byte inventory
  `b849a1608e0533f633ee516b2bb468ea9819dfe38b9008ddfae2c5893dfe5640`.
- The logger-complete cohort's measured cold total is `6741.611` seconds. The
  older `7394.198`-second Phase-2 cohort was not reused because four of its
  rows lacked the logger artifact required for exact receipt parity.

Implementation commits:

- `9d4a25dec` — governed restart backend, validation driver, tests, and inputs.
- `c078853ab` — immutable session-input binding and receipt authentication.
- `4db94c2ad` — frozen logger-complete 20-cell cohort.
- `08f6ca21f` — common-manifest and byte-inventory proof across distinct claim
  receipt paths.

## Governed validation result

The commissioned run opened DEV2 only through the governed controller. The
controller's physical-tree preflight refused cell 1 because the lane contains
an unapproved extra custom-history symbol directory:

`DEV2 Custom/history symbol directories drifted. Expected=EURUSD.DWX,GBPUSD.DWX,GDAXI.DWX,NDX.DWX,USDJPY.DWX,XAUUSD.DWX; actual=EURUSD.DWX,GBPUSD.DWX,GDAXI.DWX,NDX.DWX,USDJPY.DWX,WS30.DWX,XAUUSD.DWX`

No terminal or tester started: `terminal_restarts=0`, `cells_authenticated=0`,
and no cell receipt was compared. Session closeout reports
`closed_exact=true`, zero DEV2 processes, the QMDev2 account disabled, and the
108-file frozen history inventory unchanged before/after. Consequently,
20/20 parity and the >=2.5x complete-batch speed target remain **not measured**,
not failed by pipeline evidence.

The extra `WS30.DWX` projection was not removed, moved, or incorporated into
the contract because that would be untracked DEV2 remediation outside this
router task. Review must either commission reconciliation of DEV2 to its
current signed contract or approve a revised contract/projection before the
validation is rerun.

## Evidence index

- Machine packet: `2cb9d160_v4a_phase3_governed_restart_2026-08-27_packet.json`
- Human-readable generated report:
  `2cb9d160_v4a_phase3_governed_restart_2026-08-27.md`
- Twenty-row comparison ledger:
  `2cb9d160_v4a_phase3_governed_restart_2026-08-27_comparison.csv`
- Controller failure receipt:
  `2cb9d160_v4a_phase3_governed_restart_2026-08-27_runtime/cell_01/controller_stderr.log`
- Containment closeout:
  `2cb9d160_v4a_phase3_governed_restart_2026-08-27_runtime/session_summary.json`
- Frozen guarded inputs: `2cb9d160_v4a_phase3_inputs/`

## Safety and activation status

- Production remains Default-OFF. No worker, queue row, production claim,
  pipeline verdict, or DL-089 behavior was changed.
- The Phase-3 cold-path files and DL-089 remain byte-identical to their
  task-start hashes.
- T1-T10, T_Live, and AutoTrading were not changed or interrupted.
- This is review evidence only. It does not authorize production activation.
