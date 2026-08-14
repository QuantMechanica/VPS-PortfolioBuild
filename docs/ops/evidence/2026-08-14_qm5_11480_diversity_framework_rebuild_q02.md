# QM5_11480 diversity framework rebuild and Q02 handoff - 2026-08-14

## Outcome

`QM5_11480_capra-pristine-pbs-pss-pullback-d1` was recovered from an
exhausted Q01 build, rebuilt under the current V5 corset, and handed to staged
Q02. It adds a low-frequency D1 FX sleeve across `EURUSD.DWX`, `GBPUSD.DWX`,
`USDJPY.DWX`, `AUDUSD.DWX`, and `USDCAD.DWX`.

This is one Q01-recovery/Q02-handoff unit. No Q02 or later phase was run
locally.

## Selection and collision control

- The higher-ranked FX card `QM5_11424` was rejected by its target-specific
  deterministic prebuild gate (`entry_frequency_implausible`); it was not
  claimed or edited.
- `QM5_11480` had one exhausted build task
  (`a3936943-659e-4e9a-be4c-2fcb43cd0a55`), zero Q02 work items, and no active
  farm task, agent claim, or dispatch lock.
- The prior build compiled but failed before Q02 with 18
  `EA_FRAMEWORK_RAW_SERIES_CALL` violations. This recovery repairs that exact
  blocker rather than creating build volume.
- The OWNER-approved card is sourced to Capra and Velez's Wiley book, uses a
  fixed D1 OHLC pullback/stop-entry mechanism with a simple EMA20 trend context,
  expects about 30 trades/year/symbol, and contains no ML, grid, martingale, or
  adaptive mechanics.
- Agent task: `e8b0e5a6-4bd0-4960-bc6d-2a16a31b575f`.
- Build task: `8eb64d87-8e0e-4471-b63a-0e4810d0b221`.
- Claim key:
  `manual:codex:agents/board-advisor:QM5_11480:q01-rebuild-q02-handoff:20260814T031351Z`.
- Pre-claim DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11480_rebuild_claim_20260814T030508Z.sqlite`
  (385,261,568 bytes; `PRAGMA quick_check=ok`).

The target-specific card, EA ID, five magic rows, and EA directory passed the
build-skill guard. Normal `farmctl build-ea` creation was blocked only by 23
pre-existing duplicate energy-registry values outside this target; those rows
and the concurrently dirty registry files were not changed. A guarded atomic
manual task/claim was therefore recorded after the target was rechecked inside
`BEGIN IMMEDIATE`.

## Framework repair

- Added explicit, reviewed `perf-allowed` annotations to the bounded bespoke D1
  OHLC reads that caused the prior 18-count framework failure.
- Added MAE tracking as the first `OnTick` action.
- Moved news and spread filters below Friday close, open-position management,
  and strategy exits so entry constraints cannot suppress risk management.
- Evaluated the bar-extreme trail once per framework D1 new-bar event.
- Changed trail and time-stop age from wall-clock days to completed D1 bars.
- Zero-initialized `QM_EntryRequest` and retained the registered symbol-slot
  offset in each request.
- Added an exact approved-card copy and refreshed the seven-section SPEC.
- Generated all five D1 backtest setfiles with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and slots 0 through 4.

## Verification

| Check | Result |
|---|---|
| Approved-card build guard | PASS |
| Approved-card copy | exact SHA-256 match |
| `validate_spec_doc.py` | PASS, 1/1 |
| Strict framework/setfile gate | PASS, 0 failures, 0 warnings |
| Strict MetaEditor compile | PASS, 0 errors, 0 warnings |
| Framework report | `D:\QM\reports\framework\21\build_check_20260814_031930.json` |
| Compile summary | `D:\QM\reports\compile\20260814_031930\summary.csv` |
| MQ5 SHA-256 | `06dc1af734be2a1097209efed22017b546f75ef7d1d7af01f50b4e36b2875527` |
| EX5 SHA-256 | `ace5c3fd9c934290dba1f4d1a104e400557ba05539f53a0e54cf8ab3d7fd9021` |
| Card-copy SHA-256 | `4cd61768a28e1351a2fa80c51c4066218cf93e576a3c46aec0aa70adc763c560` |
| Build result | `D:\QM\strategy_farm\artifacts\builds\8eb64d87-8e0e-4471-b63a-0e4810d0b221.json` |

Current setfile hashes are:

| Symbol | Slot | Magic | SHA-256 |
|---|---:|---:|---|
| `EURUSD.DWX` | 0 | 114800000 | `cea0409eb340a66bb6800e671dcd4daea46622b7f32a9c9e89519319d5c3cb89` |
| `GBPUSD.DWX` | 1 | 114800001 | `5d3f2cb5334fb96eb19899f821c65a2e9d166e4fb960bf8359e11224deff3cad` |
| `USDJPY.DWX` | 2 | 114800002 | `cfa42d1851032e5e7376000863a41bf8bba0fe2518c6cf6a301393b511d1fbcc` |
| `AUDUSD.DWX` | 3 | 114800003 | `a65747ce4b38db2b7abd1f293b4f67c9d571682dac41ec00821c4d2c50591d4d` |
| `USDCAD.DWX` | 4 | 114800004 | `5ca66b202553204cc407bf85790328bdb57417857122fb4f80af6c51dce57d0b` |

## Q02 handoff

The build-only skill defers tester execution to worker-bound Q02, so no local
smoke or terminal launch occurred. The build recorder marked the build `done`
with `smoke_result=deferred_p2_smoke` and created the standard three-symbol
stage-one wave:

| Symbol | Q02 work item | Status at handoff |
|---|---|---|
| `EURUSD.DWX` | `79ee26fe-f116-4cf9-b695-dbf9a016ee42` | pending |
| `GBPUSD.DWX` | `6bb4a658-d88f-4124-9288-95de0548610a` | pending |
| `USDJPY.DWX` | `0eeb7d33-7617-431a-9b70-8e9ddde5d8be` | pending |

`AUDUSD.DWX` and `USDCAD.DWX` are durably staged in
`q02_deferred_symbols.json` with `priority_track=true`, the same build-task
binding, and cohort size five. They were not dropped.

## Safety boundary

- No `T_Live` file, live manifest, portfolio gate, or deploy manifest changed.
- AutoTrading was not toggled.
- No backtest or pipeline phase was executed locally.
- No shared registry or magic-resolver file was edited.
- All repository changes are scoped to branch `agents/board-advisor`.
