# QM5_12821 T-WIN Modular Rebuild Evidence

Task: `6223e7f6-3125-483c-b5c3-57c836593de6`  
Date: 2026-07-01  
EA: `framework/EAs/QM5_12821_twin-csm-basket`

## Result

Rebuilt QM5_12821 as a modular T-WIN basket EA aligned to the 2026-07-01 fidelity audit and Agy design-gap closeout.

Implemented / verified source surface:

- `framework/include/QM/QM_CurrencyStrength.mqh`: 28-pair CSM, base-add/quote-subtract strength, zero-sum, normalized exhaustion, 7-cross probability ratio.
- `framework/include/QM/QM_MTFCoherence.mqh`: hard D1 + W1 + MN sign coherence.
- `framework/include/QM/QM_BasketBuilder.mqh`: Mode C 7-to-1 single-currency cluster; GBP-strong exact set.
- `framework/include/QM/QM_BasketEquityStop.mqh`: magic-group floating PnL stop / TP, flatten all owned legs.
- `framework/include/QM/QM_PullbackGate.mqh`: M30 fair-price center / outer boundary gate, boundary touch, rejection close, low tick-volume confirmation.
- `framework/EAs/QM5_12821_twin-csm-basket/QM5_12821_twin-csm-basket.mq5`: thin host EA composing the modules; opens all 7 legs as pending limit orders at the M30 pullback boundary; `req.sl=0.0` only; no ATR/broker-side SL.
- `framework/EAs/_tests/QM_TWIN_Module_tests/QM_TWIN_Module_tests.mq5`: standalone MT5 harness for CSM, MTF, basket builder, pullback gate, and basket equity-stop pure decisions.

Packaging:

- Updated all 29 QM5_12821 `.set` files to pin session/flat inputs explicitly so the build guardrail accepts the tactical/session EA package.
- Confirmed backtest sets keep `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- No `qm_news_stale_max_hours` bypass added; EA default remains `336`.

## Verification

Strict compile: module test harness

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/_tests/QM_TWIN_Module_tests -Strict
compile_one.result=PASS
compile_one.errors=0
compile_one.warnings=0
compile_one.log=C:\QM\repo\framework\build\compile\20260701_120003\QM_TWIN_Module_tests.compile.log
```

Strict compile: QM5_12821 EA

```text
powershell -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12821_twin-csm-basket -Strict
compile_one.result=PASS
compile_one.errors=0
compile_one.warnings=0
compile_one.log=C:\QM\repo\framework\build\compile\20260701_120013\QM5_12821_twin-csm-basket.compile.log
compile_one.ex5=C:\QM\repo\framework\EAs\QM5_12821_twin-csm-basket\QM5_12821_twin-csm-basket.ex5
```

Build guardrails:

```text
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12821_twin-csm-basket
verdict=PASS
files_checked=29 set files + 1 mq5
findings=[]
max_news_stale_hours=336
```

Static fidelity checks:

- `PERIOD_W1` and `PERIOD_MN1` are present in the MTF path.
- `QM_BasketBuilder_ModeC(...)` is the entry basket builder.
- `QM_BUY_LIMIT` / `QM_SELL_LIMIT` are used for boundary orders.
- `QM_BasketEquityStop_Enforce(...)` is the basket stop primitive.
- Search for nonzero `req.sl` and `QM_StopATR` in the rebuilt EA returned no broker-side SL path.

## Notes

The Agy design-gap findings landed in `docs/ops/evidence/2026-07-01_qm5_12821_twin_fidelity_audit.md` while this cycle was active. The final pullback implementation was tightened after reading section C.1.

The MT5 harness was strict-compiled but not executed as a live terminal/tester run in this cycle; the operator hard rules forbid manually starting `terminal64.exe`. Logical-basket Q02 was not re-enqueued here; it should happen after Codex/Claude review, per the task routing contract.
