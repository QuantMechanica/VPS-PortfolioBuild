# QM5_13008_xng-aud-rspread - Strategy Spec

**EA ID:** QM5_13008
**Slug:** `xng-aud-rspread`
**Source:** `RBA-AUD-COMMODITY-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency market-neutral commodity-FX basket on
`XNGUSD.DWX` and `AUDUSD.DWX`. On each new D1 host bar it computes a rolling
return spread:

`log(XNG[t] / XNG[t-L]) - beta_aud * log(AUDUSD[t] / AUDUSD[t-L])`

The current return spread is standardized against recent D1 history. A high
positive z-score means natural gas has outperformed AUDUSD over the fixed
return window, so the basket sells gas and buys AUDUSD. A high negative z-score
buys gas and sells AUDUSD. The package exits when the z-score reverts near
zero, max hold expires, Friday close intervenes, or per-leg ATR stops fire.

This is not a duplicate of `QM5_12567_cum-rsi2-commodity` because there is no
RSI or single-symbol oscillator component. It is also distinct from XNG
seasonal/storage/weather/event logic, `QM5_13002_xng-cad-rspread`, XBR/XNG,
XTI/XNG, metals-ratio, WTI calendar/event, and index sleeves.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_return_lookback_d1` | 20 | 10-40 | D1 return window for both legs |
| `strategy_z_lookback_d1` | 120 | 80-180 | History length for return-spread z-score |
| `strategy_beta_aud` | 0.75 | 0.5-1.0 | AUDUSD return multiplier and risk weight proxy |
| `strategy_entry_z` | 1.9 | 1.6-2.3 | Absolute z-score required for entry |
| `strategy_exit_z` | 0.4 | 0.2-0.7 | Mean-reversion exit band |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period for each leg |
| `strategy_atr_sl_mult` | 3.0 | 2.25-4.0 | Per-leg hard stop distance |
| `strategy_max_hold_days` | 30 | 20-45 | Calendar-day stale package exit |
| `strategy_xng_max_spread_pts` | 2500 | 1500-3500 | Natural-gas spread cap |
| `strategy_audusd_max_spread_pts` | 90 | 60-140 | AUDUSD spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- Logical basket symbol: `QM5_13008_XNG_AUD_RSPREAD_D1`.
- Host symbol: `XNGUSD.DWX`, magic slot 0.
- Second leg: `AUDUSD.DWX`, magic slot 1.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` on the `XNGUSD.DWX` host chart.

## 5. Expected Behaviour

- Expected package frequency: about 6-14 paired packages/year before Q02 proves
  or rejects the hypothesis.
- Typical hold: several D1 bars to a few weeks.
- Regime preference: temporary natural-gas versus AUD commodity-FX return
  dislocations.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Reserve Bank of Australia, "Drivers of the Australian Dollar Exchange Rate",
URL https://www.rba.gov.au/education/resources/explainers/drivers-of-the-aud-exchange-rate.html.

The source is used for structural mechanism only. No source performance claim is
imported.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, AutoTrading setting, portfolio admission file,
or portfolio gate file is touched by this build.

