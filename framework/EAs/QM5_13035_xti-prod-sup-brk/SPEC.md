# QM5_13035_xti-prod-sup-brk - Strategy Spec

**EA ID:** QM5_13035
**Slug:** `xti-prod-sup-brk`
**Source:** `EIA-XTI-PRODSUP-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency WTI product-supplied demand proxy breakout
on `XTIUSD.DWX`. On each new D1 bar it inspects the previous completed D1 bar,
requiring that bar to be Wednesday or Thursday in broker time. Long setups are
allowed only in the April-August demand window; short setups are allowed only
in the September-February weak-demand window.

Entries require a Donchian breakout, SMA slope confirmation, ATR-sized range
and body, and the signal bar closing in the breakout direction. Positions use
ATR hard stop, ATR target, SMA trend-failure exit, seasonal invalidation,
max-hold exit, standard V5 news and Friday close, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_long_start_month` | 4 | fixed | First month of long-demand season |
| `strategy_long_end_month` | 8 | fixed | Last month of long-demand season |
| `strategy_short_start_month` | 9 | fixed | First month of weak-demand short season |
| `strategy_short_end_month` | 2 | fixed | Last month of weak-demand short season |
| `strategy_channel_lookback` | 40 | 30-60 | Prior D1 Donchian window excluding the signal bar |
| `strategy_sma_period` | 20 | 20-40 | Four-week D1 SMA trend proxy |
| `strategy_sma_slope_shift` | 5 | 3-10 | Completed D1 bars used for SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.70 | 0.55-0.90 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.20 | 0.15-0.35 | Minimum absolute signal-bar body in ATR units |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | ATR stop distance |
| `strategy_atr_tp_mult` | 3.0 | 2.0-4.0 | ATR target distance |
| `strategy_max_hold_days` | 7 | 4-10 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-12.
- Typical hold: several D1 bars, capped by stale-position, SMA trend-failure,
  and seasonal invalidation guards.
- Regime preference: weekly petroleum demand-proxy information windows with
  price breakout confirmation.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration product-supplied demand proxy and
weekly petroleum data pages:

- https://www.eia.gov/todayinenergy/detail.php?id=63184
- https://www.eia.gov/petroleum/data.php
- https://www.eia.gov/dnav/pet/pet_cons_wpsup_k_w.htm

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
