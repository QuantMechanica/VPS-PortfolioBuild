# QM5_12593_eia-wti-ref-fade - Strategy Spec

**EA ID:** QM5_12593
**Slug:** `eia-wti-ref-fade`
**Source:** `EIA-WTI-REFINERY-MAINT-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency structural WTI refinery-turnaround sleeve on
`XTIUSD.DWX`. In March-April and September-October, it fades D1 bars that are
stretched away from a slow mean but close back against the stretched direction.
The trade exits when the prior D1 close reaches the mean, after a short fixed
max hold, or at the ATR stop.

The strategy is intentionally not a duplicate of the existing WTI WPSR,
hurricane, broad monthly seasonality, RBOB product-spread, or XNG storage/season
cards. It is a single-symbol shoulder-window mean-reversion rule based on
refinery maintenance structure.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for range, stretch, and stop |
| `strategy_mean_period` | 50 | 34-84 | D1 SMA mean reference |
| `strategy_min_range_atr` | 0.80 | 0.60-1.10 | Minimum signal-bar range versus ATR |
| `strategy_min_body_ratio` | 0.35 | 0.25-0.50 | Minimum signal body as share of range |
| `strategy_reversal_tail_ratio` | 0.35 | 0.25-0.45 | Close-location rejection threshold |
| `strategy_min_stretch_atr` | 0.90 | 0.70-1.20 | Minimum close-to-SMA stretch versus ATR |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | Stop distance multiplier |
| `strategy_max_hold_days` | 6 | 3-9 | Calendar-day time exit |
| `strategy_spring_start_month` | 3 | 2-4 | First spring shoulder month |
| `strategy_spring_end_month` | 4 | 4-5 | Last spring shoulder month |
| `strategy_fall_start_month` | 9 | 8-10 | First autumn shoulder month |
| `strategy_fall_end_month` | 10 | 10-11 | Last autumn shoulder month |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-12.
- Typical hold: several D1 bars up to about one week.
- Regime preference: refinery-turnaround shoulder-month overshoots.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, "Refinery outages: planned and
unplanned outages, 2007-2011", URL
https://www.eia.gov/petroleum/articles/refoutagesindex.php.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | `RISK_FIXED` | 1000 |
| Live, if ever approved later | `RISK_PERCENT` | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
