# QM5_12773_opec-wti-fade - Strategy Spec

**EA ID:** QM5_12773
**Slug:** `opec-wti-fade`
**Source:** `OPEC-WTI-POSTFADE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural WTI supply-policy digestion
sleeve on `XTIUSD.DWX`. During June and December it scans the fixed OPEC
ordinary-meeting risk window, days 1-14, for a qualifying D1 impulse. During
the post-window period, days 15-24, it fades stretched same-direction
follow-through when price is ATR-stretched away from SMA(50).

The strategy is intentionally not a duplicate of `QM5_12598_opec-wti-brk`:
that EA follows Donchian breakouts inside the OPEC event window. This EA waits
until after the event window and takes the opposite side of stretched
continuation. It also differs from WTI weekday/month, WPSR, hurricane,
refinery, SPR, ETF-roll, CME-expiry, CAD/oil, XTI/XNG, XAU/XAG, XNG, and RSI
commodity sleeves.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_event_month_a` | 6 | 6 | June OPEC risk month |
| `strategy_event_month_b` | 12 | 12 | December OPEC risk month |
| `strategy_window_start_day` | 1 | 1 | First event-window day |
| `strategy_window_end_day` | 14 | 10-18 | Last event-window day |
| `strategy_fade_start_day` | 15 | 12-18 | First post-window fade day |
| `strategy_fade_end_day` | 24 | 21-27 | Last post-window fade day |
| `strategy_trend_period` | 50 | 34-84 | SMA reversion anchor |
| `strategy_atr_period` | 20 | 14-30 | ATR period for event proof, stretch, and stop |
| `strategy_min_event_return_pct` | 1.00 | 0.75-1.50 | Minimum absolute event-window return |
| `strategy_min_event_range_atr` | 0.80 | 0.60-1.00 | Minimum event-window range as ATR multiple |
| `strategy_min_follow_return_pct` | 0.35 | 0.20-0.60 | Minimum post-window continuation return |
| `strategy_min_close_location` | 0.65 | 0.60-0.75 | Event bar close-location threshold |
| `strategy_min_stretch_atr` | 0.65 | 0.45-0.90 | SMA stretch required before fade |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-10.
- Typical hold: several D1 bars; capped at 5 calendar days by default.
- Regime preference: post-OPEC policy-window impulse digestion.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

OPEC, "OPEC holds 181st Meeting of the Conference", URL
https://www.opec.org/pn-detail/86-15-june-2021.html. Supplement: U.S. Energy
Information Administration, "Oil supply and OPEC", URL
https://www.eia.gov/finance/markets/crudeoil/supply-opec.php.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
