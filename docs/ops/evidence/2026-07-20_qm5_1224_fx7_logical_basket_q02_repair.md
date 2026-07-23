# QM5_1224 Q02 logical-basket infrastructure repair

Date: 2026-07-20  
Router task: `19983f60-f3ba-4c18-9f5c-bef086d37f65`  
EA: `QM5_1224_white-okunev-fx-xmom`

## Outcome

QM5_1224 is queued for Q02 as one atomic seven-symbol cross-sectional basket. The replacement work item is `ed171be3-4dfb-47b7-80c9-11af01a6a24d`, with logical evidence identity `QM5_1224_FX7_XMOM_D1`, tester host `EURUSD.DWX`, timeframe D1, and status `pending` at verification time. This repair makes no pipeline verdict claim.

The six component rows recreated on 2026-07-20 were retired as `failed/INVALID` because a standalone component test cannot express the EA's cross-sectional rank package. Their payloads point to the replacement logical work item and carry `LOGICAL_BASKET_SUPERSEDES_COMPONENT`. Earlier historical component results remain untouched as audit history.

## Canonical inputs

- Manifest: `framework/EAs/QM5_1224_white-okunev-fx-xmom/basket_manifest.json`
- Logical setfile: `framework/EAs/QM5_1224_white-okunev-fx-xmom/sets/QM5_1224_white-okunev-fx-xmom_QM5_1224_FX7_XMOM_D1_D1_backtest.set`
- Compiled EA: `framework/EAs/QM5_1224_white-okunev-fx-xmom/QM5_1224_white-okunev-fx-xmom.ex5`
- Compile log: `framework/build/compile/20260720_152909/QM5_1224_white-okunev-fx-xmom.compile.log`
- Build check: `D:/QM/reports/framework/21/build_check_20260720_152932.json`

The manifest contains exactly seven traded symbols: EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX, USDCHF.DWX, and USDJPY.DWX. Its Q02 window is 2017-01-02 through 2024-12-31.

## Guardrail verification

The logical backtest setfile is fail-closed at the required limits:

- `RISK_FIXED=500`
- `RISK_PERCENT=0`
- `qm_news_stale_max_hours=336`
- `PORTFOLIO_WEIGHT=1`

The existing strict build artifacts were present during verification: the EX5 is 350,672 bytes, and the referenced compile log and build-check JSON both exist. No terminal was launched manually, no active backtest was interrupted, and neither T_Live nor AutoTrading was changed.

Focused automated verification on canonical main:

- `tools/strategy_farm/tests/test_fx_basket_manifests.py`: the QM5_1224 atomic-package assertions pass.
- Combined basket-focused run: 31 passed, 4 failed. The four failures are test-double incompatibilities with newer process-identity hardening (`expected_creation_key` and spawned-process identity capture); they do not challenge the QM5_1224 manifest, setfile, or queue invariant recorded here.

## Queue invariant at handoff

Exactly one current pending Q02 row exists for QM5_1224, and it is the logical basket row `ed171be3-4dfb-47b7-80c9-11af01a6a24d`. It uses the logical setfile, has `portfolio_scope=basket`, `host_symbol=EURUSD.DWX`, `host_timeframe=D1`, `RISK_FIXED` metadata with fixed risk 500 and percent risk 0, and is left for the deterministic worker fleet. Pipeline evidence alone will determine PASS/FAIL.
