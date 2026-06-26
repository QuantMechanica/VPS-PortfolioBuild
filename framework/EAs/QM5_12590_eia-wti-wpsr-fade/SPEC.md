# QM5_12590_eia-wti-wpsr-fade - Strategy Spec

**EA ID:** QM5_12590
**Slug:** `eia-wti-wpsr-fade`
**Source:** `EIA-WTI-WPSR-FADE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-26

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
On each new D1 bar, it inspects the prior closed D1 bar only when that bar was
Wednesday or Thursday. If the event-day range expands versus ATR(20), the body
is directional, the close is in the outer tail of the bar, and the close is
stretched from SMA(50), the EA fades the event-day move. It exits on reversion
to SMA(50) or after a short fixed calendar-day window.

The strategy is intentionally not a duplicate of `QM5_12579_eia-wti-aftershock`:
that EA follows large event-day continuation; this EA enters the opposite
direction only after an exhaustion/tail/stretch condition. It is also not a
duplicate of WTI monthly seasonality or RBOB seasonal sleeves.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for range filter and stop |
| `strategy_mean_period` | 50 | 34-84 | SMA mean-reversion anchor |
| `strategy_min_range_atr` | 1.25 | 1.0-1.75 | Minimum event-day range versus ATR |
| `strategy_min_body_ratio` | 0.45 | 0.35-0.6 | Minimum absolute body/range ratio |
| `strategy_close_tail_ratio` | 0.20 | 0.15-0.30 | Outer bar tail close-location threshold |
| `strategy_min_stretch_atr` | 0.75 | 0.5-1.0 | Minimum close-to-SMA stretch in ATR |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | Stop distance multiplier |
| `strategy_max_hold_days` | 4 | 2-6 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-14.
- Typical hold: 1-4 D1 bars.
- Regime preference: WTI information-event exhaustion and short mean reversion.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration, "Weekly Petroleum Status Report", URL
https://www.eia.gov/petroleum/supply/weekly/. Release schedule URL
https://www.eia.gov/petroleum/supply/weekly/schedule.php.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest or `T_Live` file is touched by this build.
