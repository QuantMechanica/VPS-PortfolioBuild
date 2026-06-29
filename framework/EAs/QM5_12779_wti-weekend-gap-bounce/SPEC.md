# QM5_12779_wti-weekend-gap-bounce - Strategy Spec

**EA ID:** QM5_12779
**Slug:** `wti-weekend-gap-bounce`
**Source:** `TGIF-WTI-WEEKEND-2017`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency WTI weekend-gap sleeve on `XTIUSD.DWX`.
On each new D1 bar, it permits a long entry only when the current
broker-calendar bar is Monday, the previous completed D1 bar is Friday, and the
Monday open is at least `strategy_min_gap_pct` percent below the prior Friday
close. The take-profit is the prior Friday close, i.e. the gap-fill level.
Positions that do not fill are flattened after the Monday bar or by a
calendar-day stale-position guard.

The strategy is intentionally not a duplicate of `QM5_12750_wti-weekend-gap-fade`:
that EA is short-only on positive Monday gaps. This EA is long-only on negative
Monday gaps. It is also not `QM5_12596_wti-mon-fade`, which shorts all Mondays
and has no gap-fill target.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_gap_pct` | 0.75 | 0.50-1.25 | Minimum Monday open gap below prior Friday close |
| `strategy_atr_period` | 20 | 14-30 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.25 | 1.5-3.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 2 | 1-3 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 6-16.
- Typical hold: intraday to one D1 bar, capped by stale-position guard.
- Regime preference: WTI weekend-effect / downside gap-fill mean reversion.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

"TGIF? The weekend effect in energy commodities", Journal of Finance Issues,
URL https://jfi-aof.org/index.php/jfi/article/view/2264.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
