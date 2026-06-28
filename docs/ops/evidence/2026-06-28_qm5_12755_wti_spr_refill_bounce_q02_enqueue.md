# QM5_12755 WTI SPR Refill Bounce Q02 Enqueue Evidence

Date: 2026-06-28

## Scope

- Added `QM5_12755_wti-spr-refill-bounce` as a new structural WTI commodity
  sleeve.
- Source lineage: U.S. Department of Energy / CESER SPR refill purchase policy
  (`DOE-WTI-SPR-REFILL-2024`).
- Runtime data: `XTIUSD.DWX` D1 OHLC and broker calendar only.
- Live safety: no `T_Live`, AutoTrading, portfolio gate, or live manifest
  change.

## Build Artifacts

- EA source:
  `framework/EAs/QM5_12755_wti-spr-refill-bounce/QM5_12755_wti-spr-refill-bounce.mq5`
- Binary:
  `framework/EAs/QM5_12755_wti-spr-refill-bounce/QM5_12755_wti-spr-refill-bounce.ex5`
- Fixed-risk Q02 setfile:
  `framework/EAs/QM5_12755_wti-spr-refill-bounce/sets/QM5_12755_wti-spr-refill-bounce_XTIUSD.DWX_D1_backtest.set`
- Build result:
  `artifacts/qm5_12755_build_result.json`

## Validation

- Card schema lint: PASS.
- SPEC validation: PASS.
- Symbol scope: `SINGLE_SYMBOL_OK`.
- Build guardrails: PASS.
- Compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 16 shared-framework advisory warnings.
- `.ex5` SHA-256:
  `df85ed8754585721a21e78c22b2cfc2b8d5a930c428026c94106e9347522b061`.

## Farm Enqueue

- Build task: `756385d5-6afe-4124-aebe-9d51658cb17b`.
- `record-build`: recorded true, status `done`.
- Q02 work item: `d57072b7`, symbol `XTIUSD.DWX`, timeframe `D1`.
- Smoke result: `deferred_p2_smoke`; paced fleet Q02 will run the tester pass.
