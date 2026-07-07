# QM5_13047_eia-steo-fade - Strategy Spec

**EA ID:** QM5_13047
**Slug:** `eia-steo-fade`
**Source:** `EIA-STEO-XTI-FADE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency WTI Short-Term Energy Outlook failed-reaction
fade on `XTIUSD.DWX`. On each new D1 bar it inspects the previous completed D1
bar, requiring that bar to match the deterministic EIA STEO monthly release
proxy: first Tuesday after the first Thursday of the broker-calendar month, with
optional Wednesday delay handling.

Entries fade failed outside-range probes. A long setup requires a downside probe
below the prior D1 context range and a close back inside that range. A short
setup requires an upside probe above the prior D1 context range and a close back
inside that range. Positions use ATR hard stop, ATR target, max-hold exit,
standard V5 news and Friday close handling, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_context_lookback` | 14 | 10-20 | Completed D1 bars used for context high/low |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.50 | 0.40-0.80 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.10 | 0.05-0.20 | Minimum signal-bar body in ATR units |
| `strategy_min_probe_atr` | 0.05 | 0.00-0.15 | Minimum outside-context probe in ATR units |
| `strategy_long_min_close_location` | 0.50 | 0.45-0.60 | Minimum close location for failed-downside long |
| `strategy_short_max_close_location` | 0.50 | 0.40-0.55 | Maximum close location for failed-upside short |
| `strategy_atr_sl_mult` | 2.25 | 1.75-3.0 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.75 | 2.0-3.5 | ATR target distance |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |
| `strategy_allow_wed_delay` | true | true/false | Allow Wednesday delayed STEO proxy |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 5-10.
- Direction: symmetric long/short.
- Typical hold: several D1 bars, capped by ATR target/stop and max-hold exit.
- Regime preference: monthly EIA STEO information windows where WTI probes
  outside the recent D1 range and fails back inside it.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Official U.S. Energy Information Administration STEO source family:

- https://www.eia.gov/outlooks/steo/
- https://www.eia.gov/outlooks/steo/release_schedule.php
- https://www.eia.gov/outlooks/steo/report/global_oil.php

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Evidence

- Build result: `artifacts/qm5_13047_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13047_q02_enqueue_20260708.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Mission-directed STEO failed-breakout energy sleeve build | Enqueue to Q02 |
