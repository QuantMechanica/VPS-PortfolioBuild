# QM5_12740_eia-wti-postdrive - Strategy Spec

**EA ID:** QM5_12740
**Slug:** `eia-wti-postdrive`
**Source:** `EIA-WTI-POSTDRIVE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
It trades short-only D1 channel breakdowns during the post-driving shoulder
window from September 1 through October 15. It exits outside that date window,
on a D1 channel reversal, on a max-hold timeout, or via the framework Friday
close.

The strategy is intentionally not a duplicate of `QM5_12737_eia-wti-drive`:
that EA is long-only during the April-August driving-season support window.
This EA trades the unwind side after that window and only shorts on confirmed
D1 downside breaks.

It is also not `QM5_12701_wti-oct-fade` or `QM5_12726_wti-nov-fade`, which are
static month-of-year one-bar fades. This build requires a D1 channel breakdown
and uses a narrower post-driving shoulder window.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 9 | fixed | Post-driving window start month |
| `strategy_start_day` | 1 | 1-10 | Post-driving window start day |
| `strategy_end_month` | 10 | fixed | Post-driving window end month |
| `strategy_end_day` | 15 | 15-31 | Post-driving window end day |
| `strategy_entry_channel` | 30 | 20-55 | Previous-bar channel for short breakdown |
| `strategy_exit_channel` | 15 | 10-20 | Previous-bar channel for exit reversal |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Stop distance multiplier |
| `strategy_max_hold_days` | 15 | 10-25 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 2-6.
- Typical hold: days to several weeks, segmented by Friday close when applicable.
- Regime preference: WTI downside breakdowns after peak gasoline demand season.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

U.S. Energy Information Administration gasoline price fluctuation source packet
captured under `EIA-WTI-POSTDRIVE-2026`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, portfolio-admission artifact, or live-terminal file is touched by this build.
