# QM5_1012_lien-fader - Strategy Spec

**EA ID:** QM5_1012
**Slug:** lien-fader
**Source:** SRC04_S06
**Author of this spec:** Codex
**Last revised:** 2026-06-28

---

## 1. Strategy Logic

The EA implements Kathy Lien's Fader setup on forex pairs. On each new D1 session it reads the prior closed D1 bar high/low and ADX(14). If ADX is below 20, the day is eligible for a false-breakout fade. On each closed H1 bar, a break at least 15 pips below the prior-day low arms a buy-stop at the prior-day high plus 5 pips; a break at least 15 pips above the prior-day high arms a sell-stop at the prior-day low minus 5 pips. Initial stop distance is 20 pips from the entry. Once price moves 1R in favor, the EA closes half, moves the remaining stop to breakeven, then trails the remainder with the card default two-bar extreme.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `adx_period` | 14 | 10-20 | ADX lookback on the signal timeframe. |
| `adx_threshold` | 20.0 | 15-25 | Maximum ADX value for range-regime eligibility. |
| `adx_trending_down_required` | false | false/true | Optional card variant requiring ADX to be lower than `adx_period` bars ago. |
| `spike_threshold_pips` | 15 | 10-25 | Required break beyond the prior-day range before arming the fade. |
| `entry_offset_pips` | 5 | 2-15 | Offset beyond the opposite prior-day extreme for the pending stop entry. |
| `stop_offset_pips` | 20 | 10-30 | Initial stop distance in pips. |
| `tp1_rr` | 1.0 | 0.75-2.0 | R multiple for closing half and moving the rest to breakeven. |
| `trail_method` | two-bar extreme | two/three-bar, ATR, Donchian | Remainder trailing method after TP1. |
| `tf_signal` | D1 | D1/H4 | Timeframe used for ADX and prior-bar range. |
| `tf_entry` | H1 | M30/H1/H4 | Timeframe used for false-breakout detection. |
| `max_spread_points` | 0 | >=0 | Optional spread cap; zero disables the guard for DWX backtests. |

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - Lien worked example and registered symbol slot.
- `EURUSD.DWX` - Lien worked example and registered symbol slot.
- `EURGBP.DWX` - tight-range FX cohort from the card.
- `USDCAD.DWX` - tight-range FX cohort from the card.
- `EURCHF.DWX` - tight-range FX cohort from the card.
- `EURCAD.DWX` - tight-range FX cohort from the card.
- `AUDCAD.DWX` - tight-range FX cohort from the card.
- `GBPUSD.DWX` - major-FX generalization from the card.
- `AUDUSD.DWX` - major-FX generalization from the card.
- `NZDUSD.DWX` - major-FX generalization from the card.

**Explicitly NOT for:**
- Non-FX symbols - the thesis is an FX prior-day-range stop-hunt fade.
- FX symbols without active magic rows for EA 1012 - the V5 magic resolver rejects unregistered slots.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 ADX and prior-day high/low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry gate |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30-80 |
| Typical hold time | hours to one trading day |
| Expected drawdown profile | Tight-stop mean-reversion losses during genuine range breakouts. |
| Regime preference | range-bound false-breakout mean reversion |
| Win rate target (qualitative) | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** SRC04_S06
**Source type:** book
**Pointer:** `strategy-seeds/cards/lien-fader_card.md`, sourced from Kathy Lien, *Day Trading and Swing Trading the Currency Market*, Chapter 13.
**R1-R4 verdict (Q00):** all PASS per the approved strategy card.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% - 0.5% |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-28 | Initial build from card | Built for Q02 enqueue on branch agents/board-advisor. |
