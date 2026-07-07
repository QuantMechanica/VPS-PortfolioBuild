# QM5_13026_xti-import-flow-fade - Strategy Spec

**EA ID:** QM5_13026
**Slug:** `xti-import-flow-fade`
**Source:** `EIA-XTI-IMPORT-FLOW-FADE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency WTI monthly crude-import information-cycle
absorption fade on `XTIUSD.DWX`. On each new D1 bar it inspects the previous
completed D1 bar and requires that bar to sit inside the first broker business
days of the month.

If that bar is an ATR-sized stretch away from SMA, has a meaningful body, and
has not closed beyond the prior Donchian channel, the EA fades the move on the
next bar. Positions use ATR hard stop, ATR target, SMA reversion exit, max-hold
exit, standard V5 news and Friday close, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_window_business_days` | 4 | 3-5 | First broker business days eligible for the import-flow proxy window |
| `strategy_channel_lookback` | 30 | 20-45 | Prior D1 Donchian window excluding the signal bar |
| `strategy_sma_period` | 50 | 34-80 | SMA reversion anchor |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.85 | 0.70-1.05 | Minimum signal-bar high-low range in ATR units |
| `strategy_min_body_atr` | 0.25 | 0.20-0.35 | Minimum absolute signal-bar body in ATR units |
| `strategy_min_sma_distance_atr` | 0.65 | 0.50-0.85 | Minimum close-to-SMA stretch in ATR units |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.0 | 1.5-2.5 | ATR target distance |
| `strategy_max_hold_days` | 6 | 4-8 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-8.
- Typical hold: several D1 bars, capped by stale-position and SMA-reversion
  exits.
- Regime preference: first-business-days absorption after the monthly crude
  import data cycle.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration crude-import and petroleum data pages:

- https://www.eia.gov/dnav/pet/pet_move_impcus_a2_nus_epc0_im0_mbblpd_a.htm
- https://www.eia.gov/petroleum/data.php
- https://www.eia.gov/petroleum/supply/weekly/

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
