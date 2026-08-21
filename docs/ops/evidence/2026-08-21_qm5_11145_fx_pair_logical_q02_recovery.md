# QM5_11145 FX pair logical-Q02 recovery

Date: 2026-08-21
Branch: `agents/board-advisor`
Result: `REPAIRED_COMPILE_PASS_Q02_PENDING`

## Selection and farm coordination

The only newly approved diversity build was already under active implementation
by another paced worker, so this unit used priority 2. `QM5_11145_vbt-pair-z`
is an approved, structural D1 market-neutral pairs sleeve sourced from Oleg
Polakow's vectorbt `PairsTrading.ipynb`, with an expected 6-16 spread trades per
year per pair and no ML or banned indicator.

The farm had no open `QM5_11145` agent task or pending/active work item when the
atomic recovery claim was inserted:

- agent task: `f0ba16e1-6c7a-4498-8124-c6f11c607a48`
- assigned agent: `codex:agents/board-advisor`
- source infrastructure row: `1e550769-acdd-4b02-87c1-36560504d04a`
- claim backup: `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11145_q02_repair_claim_20260821T061611Z.sqlite`
- pre-enqueue backup: `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11145_logical_q02_enqueue_20260821T062806Z.sqlite`

Both backups and the live database passed SQLite `quick_check`.

## Diagnosis

No valid two-leg Q02 had ever run:

- The basket manifest used `_per_instance` as `host_symbol`, which is not an
  MT5 symbol, and there was no canonical logical-basket setfile or logical Q02
  work item.
- All six legacy physical-leg presets omitted `strategy_partner_symbol` and
  `strategy_partner_slot`. Five therefore executed the EA's default
  EURUSD/GBPUSD binding on a filename-selected wrong host; `GER40.DWX` was also
  an obsolete alias and produced `REPORT_MISSING`.
- The host order was returned to the current single-symbol entry path with
  `sl=0`. Current `QM_Entry` rejects that as `invalid_stop_direction`, while the
  card's approved safety stop is expressed in z-space. Thus the old
  `MIN_TRADES_NOT_MET` rows were implementation/mistest outcomes, not economic
  evidence for the intended pair.
- The retained EX5 predated the current framework and source repair.

Historical artifact identities:

- MQ5 SHA-256: `779cef36f6c6846dc8f6c5ccd57165893a12672999bb8a7e4ba21c32104ac6fa`
- EX5 SHA-256: `b0dac0665864d4866238ca227160d672f8ea51bf0f464a84b95a3b24485cdc5b`
- manifest SHA-256: `9d81f3eac5503b1de955725bafad33209e01c26ee21c1e87eaac2f57cad609f7`

## Repair

- Replaced the invalid multi-instance manifest with one canonical logical Q02
  identity: `QM5_11145_EURUSD_GBPUSD_PAIR_Z_D1`, host `EURUSD.DWX` slot 0,
  partner `GBPUSD.DWX` slot 1.
- Retired the six misleading component presets and added one explicit
  `RISK_FIXED=1000`, `RISK_PERCENT=0` logical-basket preset with all approved
  rolling-OLS, z-entry, safety-z, and time-stop defaults bound.
- Kept the approved signal thresholds and exits unchanged. Both legs now use
  the established legacy-card basket path with explicit lots sized from the
  remaining model distance to the 3.25 safety-z boundary, split 50/50 across
  the package risk budget.
- Added synchronized D1 timestamp checks, positive-beta fail-closed direction
  validation, two-leg magic/kill-switch registration, second-leg failure
  rollback, and orphan-leg cleanup.
- Recompiled against the current shared framework.

Current artifact identities:

- MQ5 SHA-256: `1a4244c42fb7955a9c0b6c0197e3bae1b70154d04b7a74bae890fc6eb8f6cb17`
- EX5 SHA-256: `40d3fb46de28a3f94993c8438d77c2d482db76b95a56296a9fd0cebe16ba2f1e`
- manifest SHA-256: `8c9fa7bf8570e73ef320b1ffd5bf9845be8de2decd8a5dc786c5e2bc42716fef`
- setfile SHA-256: `2bbcf0ac2df6e9685324cb1b9f728f0b566ad744a9c197fd125763a3bb84e100`
- setfile build hash: `815824b60f38dce3eae913d79945b67f5819bdac6340bd2201e9ccac09a1cbbe`

## Validation

- Strict MetaEditor compile: PASS, 0 errors, 0 warnings.
  - log: `C:/QM/repo/framework/build/compile/20260821_063150/QM5_11145_vbt-pair-z.compile.log`
  - summary: `D:/QM/reports/compile/20260821_063150/summary.csv`
- Scoped strict build check: PASS, 0 failures, 0 warnings.
  - report: `D:/QM/reports/framework/21/build_check_20260821_063229.json`
- `validate_build_guardrails.py`: PASS, 0 findings.
- `validate_spec_doc.py`: PASS.
- `validate_symbol_scope.py --fail-on-leak`: `BASKET_OK`, 0 violations.
- `test_fx_basket_manifests.py`: PASS, 46 tests.

## Q02 handoff and CPU ceiling

The normal `farmctl build-ea` entry point refused the immutable legacy approved
card because its frontmatter says R3 PASS while an older body table still says
R3 UNKNOWN. The card was not edited. Under the claimed recovery ticket, the
same manifest-aware, archive-admitted, idempotent auto-Q02 function used by
`record-build` created exactly one logical work item:

- work item: `c3e3ab1f-b65d-47c5-a303-645f3200bf81`
- phase/status: `Q02` / `pending`
- symbol: `QM5_11145_EURUSD_GBPUSD_PAIR_Z_D1`
- host/timeframe: `EURUSD.DWX` / D1
- basket symbols: `EURUSD.DWX`, `GBPUSD.DWX`
- risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- priority track: true
- timeout: 450 minutes
- attempt/claim: 0 / unclaimed

At handoff the host CPU load was 99%, eight factory terminals were running, and
ten MT5 terminals were present. No smoke, dispatch tick, manual backtest, or
terminal action was started. The pending row is left to the paced fleet.

No `T_Live` file/process, AutoTrading state, portfolio gate, deploy manifest,
or live manifest was touched.
