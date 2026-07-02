# WS3 Swing Slate Review and Build Evidence - 2026-07-02

## Scope

- Factory remained OFF. No work items were enqueued.
- No T5 processes were touched.
- Cards reviewed from `D:\QM\strategy_farm\artifacts\cards_approved\`; the seven target cards were already in the approved folder when the independent review began.

## Independent G0 Review

| EA | Verdict | Review notes |
|---|---|---|
| QM5_12914_xau-weekly-donchian-swing | APPROVED | R1 canonical Donchian/Turtle and Kaufman support; R2 closed-bar 55/20 Donchian plus ATR trail; R3 XAUUSD.DWX D1 covered; R4 no ML/grid/martingale. Distinct from QM5_10513 Ichimoku and QM5_12897 XAG Donchian+ADX by instrument and trigger/exit family. |
| QM5_12915_sp500-weekly-oversold-swing | APPROVED | R1 Connors/Alvarez plus 200-SMA regime support; R2 closed-bar SMA200, 10-day-low entry, SMA10/time-stop exit; R3 SP500.DWX D1 covered; R4 no ML/grid/martingale. Distinct from live QM5_11132 cumulative RSI2 by trigger depth and hold horizon. |
| QM5_12916_chfjpy-carry-trend-swing | APPROVED | R1 peer-reviewed carry and FX momentum support; R2 SMA200 plus 63-day momentum, SMA10 recovery, SMA50 exit; R3 CHFJPY.DWX D1 covered; R4 no ML/grid/martingale. Adds missing single-cross carry-trend exposure. |
| QM5_12917_xti-driving-season-swing | APPROVED | R1 official EIA seasonality basis; R2 deterministic calendar window plus SMA/ATR rules; R3 XTIUSD.DWX D1 covered; R4 no ML/grid/martingale. Calendar implementation required `QM_CalendarPeriodKey`. |
| QM5_12958_nnfx-hma-wae-swing | APPROVED | R1 sufficient for OWNER NNFX hypothesis test; R2 HMA baseline, WAE expansion gate, ATR stop/partial, HMA exit; R3 XAUUSD/GDAXI/EURJPY D1 covered; R4 no ML/grid/martingale. |
| QM5_12959_elder-triple-screen-swing | APPROVED | R1 Elder Triple Screen source quality; R2 D1 SMA direction, H4 RSI wave, H1 stop-entry, 24h expiry, 2R target; R3 NDX/XAU D1/H4/H1 covered; R4 no ML/grid/martingale. WS3 build default keeps Friday close enabled for H4. |
| QM5_12960_keltner-pullback-swing | APPROVED | R1 Keltner/Kaufman support; R2 H4 EMA/ATR channel, EMA50 gate, band touch/re-entry, ATR stop, opposite-band exit; R3 SP500/XAG H4 covered; R4 no ML/grid/martingale. Distinct from QM5_12897 XAG Donchian trend and QM5_12915 D1 SP500 lowest-close MR. WS3 build default keeps Friday close enabled for H4. |

No cards were marked REWORK.

## Build Outputs

| EA | Files | Set files |
|---|---|---|
| QM5_12914_xau-weekly-donchian-swing | `.mq5`, `.ex5`, `SPEC.md` | `XAUUSD.DWX_D1_backtest` |
| QM5_12915_sp500-weekly-oversold-swing | `.mq5`, `.ex5`, `SPEC.md` | `SP500.DWX_D1_backtest` |
| QM5_12958_nnfx-hma-wae-swing | `.mq5`, `.ex5`, `SPEC.md` | `XAUUSD.DWX_D1_backtest`, `GDAXI.DWX_D1_backtest`, `EURJPY.DWX_D1_backtest` |
| QM5_12917_xti-driving-season-swing | `.mq5`, `.ex5`, `SPEC.md` | `XTIUSD.DWX_D1_backtest` |
| QM5_12916_chfjpy-carry-trend-swing | `.mq5`, `.ex5`, `SPEC.md` | `CHFJPY.DWX_D1_backtest` |
| QM5_12960_keltner-pullback-swing | `.mq5`, `.ex5`, `SPEC.md` | `SP500.DWX_H4_backtest`, `XAGUSD.DWX_H4_backtest` |
| QM5_12959_elder-triple-screen-swing | `.mq5`, `.ex5`, `SPEC.md` | `NDX.DWX_H4_backtest`, `XAUUSD.DWX_H4_backtest` |

## Compile Evidence

All compiles were run with:

```powershell
python tools/strategy_farm/compile_ea.py --ea-label <label> --force --json --fail-on-error
```

| EA | Verdict | Errors | Warnings | Symbol scope | Compile log |
|---|---|---:|---:|---|---|
| QM5_12914_xau-weekly-donchian-swing | COMPILED | 0 | 0 | SINGLE_SYMBOL_OK | `framework/build/compile/20260702_162814/QM5_12914_xau-weekly-donchian-swing.compile.log` |
| QM5_12915_sp500-weekly-oversold-swing | COMPILED | 0 | 0 | SINGLE_SYMBOL_OK | `framework/build/compile/20260702_162938/QM5_12915_sp500-weekly-oversold-swing.compile.log` |
| QM5_12958_nnfx-hma-wae-swing | COMPILED | 0 | 0 | SINGLE_SYMBOL_OK | `framework/build/compile/20260702_163145/QM5_12958_nnfx-hma-wae-swing.compile.log` |
| QM5_12917_xti-driving-season-swing | COMPILED | 0 | 0 | SINGLE_SYMBOL_OK | `framework/build/compile/20260702_163310/QM5_12917_xti-driving-season-swing.compile.log` |
| QM5_12916_chfjpy-carry-trend-swing | COMPILED | 0 | 0 | SINGLE_SYMBOL_OK | `framework/build/compile/20260702_163428/QM5_12916_chfjpy-carry-trend-swing.compile.log` |
| QM5_12960_keltner-pullback-swing | COMPILED | 0 | 0 | SINGLE_SYMBOL_OK | `framework/build/compile/20260702_163601/QM5_12960_keltner-pullback-swing.compile.log` |
| QM5_12959_elder-triple-screen-swing | COMPILED | 0 | 0 | SINGLE_SYMBOL_OK | `framework/build/compile/20260702_163754/QM5_12959_elder-triple-screen-swing.compile.log` |

## Guardrails

Explicit post-build sweep:

```powershell
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_12914_xau-weekly-donchian-swing framework/EAs/QM5_12915_sp500-weekly-oversold-swing framework/EAs/QM5_12958_nnfx-hma-wae-swing framework/EAs/QM5_12917_xti-driving-season-swing framework/EAs/QM5_12916_chfjpy-carry-trend-swing framework/EAs/QM5_12960_keltner-pullback-swing framework/EAs/QM5_12959_elder-triple-screen-swing
```

Result: `PASS`, no findings.

`validate_symbol_scope.py --json --ea-label <label>` returned `SINGLE_SYMBOL_OK` with zero violations for all seven EAs.

## Notes

- `QM5_12914` and `QM5_12915` were already tracked in the worktree at the final status check; the remaining five EA folders were added in this wave.
- The V5 risk-sizing contract requires an SL for lot sizing. Cards without an alpha stop (`12915`, `12916`) received documented ATR hard risk stops while retaining their card-defined signal exits.
- H4 cards `12959` and `12960` keep `qm_friday_close_enabled=true` per WS3 instruction.

## TODO

None for this WS3 build wave. Claude/Factory can run downstream smokes/backtests separately.
