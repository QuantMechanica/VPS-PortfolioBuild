# QM5_12754_eia-wti-hurr-fade - Strategy Spec

**EA ID:** QM5_12754
**Slug:** `eia-wti-hurr-fade`
**Source:** `EIA-WTI-HURRICANE-2025`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural WTI hurricane-season exhaustion
fade on `XTIUSD.DWX`. On each new D1 bar, it permits a short entry only during
the configured peak hurricane-risk months, default August through October. The
prior completed D1 bar must have stretched above SMA(`strategy_mean_period`) by
the configured ATR threshold, printed a sufficiently large real body, and then
closed as a bearish rejection bar in the lower part of its range. The position
is flattened when price reaches the D1 mean, the calendar window ends, or the
fixed max-hold guard is reached.

The strategy is intentionally not a duplicate of the existing WTI family:
`QM5_12591` buys hurricane-season breakouts, `QM5_12593` fades refinery
turnaround shoulder-month moves, and the WPSR, OPEC, ETF-roll, month/weekday,
CAD/oil, XTI/XNG, XAU/XAG, and XNG RSI sleeves use different timing or
information sets.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for stretch, range, and hard stop |
| `strategy_mean_period` | 50 | 34-84 | SMA period for mean/stretched-state detection |
| `strategy_min_range_atr` | 0.90 | 0.70-1.30 | Minimum prior D1 range in ATR units |
| `strategy_min_body_ratio` | 0.35 | 0.25-0.45 | Minimum real-body share of prior D1 range |
| `strategy_reversal_tail_ratio` | 0.35 | 0.25-0.45 | Maximum close location for bearish rejection |
| `strategy_min_stretch_atr` | 1.10 | 0.90-1.80 | Minimum prior high stretch above SMA in ATR units |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position guard |
| `strategy_start_month` | 8 | 6-8 | First eligible broker-calendar month |
| `strategy_end_month` | 10 | 9-11 | Last eligible broker-calendar month |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-7.
- Typical hold: 1-5 D1 bars.
- Regime preference: failed upside WTI storm-risk spikes during the
  late-summer hurricane-risk window.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Refining industry risks from 2025
hurricane season", Today in Energy, URL
https://www.eia.gov/todayinenergy/detail.php?id=65304.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
