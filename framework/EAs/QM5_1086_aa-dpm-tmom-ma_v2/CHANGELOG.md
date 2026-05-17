# QM5_1086_aa-dpm-tmom-ma_v2 Changelog

## v2 - 2026-05-17

Source: Alpha Architect / Wesley Gray, PhD, "Avoiding the Big Drawdown with Trend-Following Investment Strategies".

v1 zero-trade diagnosis:

- Card/source describe a monthly close Downside Protection Model.
- v1 setfiles were H1 and `Strategy_NoTradeFilter()` / `Strategy_ExitSignal()` rejected non-H1 charts.
- This made the implementation a fragile H1 port of a monthly allocation rule.

v2 rule change:

- Keep the DPM logic: 12-month TMOM plus 12-month moving average.
- Move the executable port to D1 setfiles.
- Compute the 12-month source lookback from D1 bars as `12 * 21 = 252`
  trading days, avoiding MN1 history gaps in DWX/custom-symbol tester runs.
- Allow D1 in `Strategy_NoTradeFilter()` and `Strategy_ExitSignal()`.
- Header comment in `.mq5` documents the source-based v2 change.

Smoke evidence:

- Build check PASS: `D:/QM/reports/framework/21/build_check_20260517_183909.json`
- Smoke 2024 NDX.DWX: `D:/QM/reports/smoke_task028/QM5_1086/20260517_183920/summary.json` -> 0 trades
- Smoke 2020-2024 NDX.DWX: `D:/QM/reports/smoke_task028/QM5_1086/20260517_184021/summary.json` -> 0 trades
- No P2 enqueue; see `QM5_1086_aa-dpm-tmom-ma_v2_zero_trade_diagnosis.md`.
