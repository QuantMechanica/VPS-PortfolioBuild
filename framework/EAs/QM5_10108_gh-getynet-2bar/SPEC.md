# QM5_10108_gh-getynet-2bar - Strategy Spec

**EA ID:** QM5_10108
**Slug:** `gh-getynet-2bar`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

This EA trades the completed M15 candle at the configured DWX broker open hour, default 09:00. A long entry requires the low of the fixed 7-bar window to be at the card's bar 5, bar 4 to be bearish, bar 5 high below bar 4 high, and bar 6 high above bar 4 high; shorts mirror the pattern with the high at bar 5 and a downside break. Entries use the pattern-derived SL and TP from the card, and there is no separate manual close signal beyond SL/TP and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_open_hour_broker` | 9 | 0-23 | Broker hour used for the London-open setup bar. |
| `strategy_pinbar_opposite_body` | false | true/false | When true, require bar 5 to have the opposite body direction from bar 4. |
| `strategy_range_min_points` | 0.0 | 0+ | Optional minimum 7-bar window range in points; 0 disables. |
| `strategy_range_max_points` | 0.0 | 0+ | Optional maximum 7-bar window range in points; 0 disables. |
| `strategy_min_accum_points` | 0.0 | 0+ | Optional minimum pattern accumulation size in points; 0 disables. |
| `strategy_max_spread_risk_pct` | 5.0 | 0+ | Maximum spread as a percent of SL distance; 0 disables. |
| `strategy_atr_period` | 14 | 1+ | ATR period for rejecting oversized stop distances. |
| `strategy_max_sl_atr_mult` | 3.0 | 0+ | Maximum SL distance as ATR multiple; 0 disables. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - card primary FX basket member and canonical DWX symbol.
- `GBPUSD.DWX` - card P2 basket member and canonical DWX symbol.
- `EURUSD.DWX` - card P2 basket member and canonical DWX symbol.

**Explicitly NOT for:**
- Symbols outside the registered basket - the card does not authorize expansion beyond the three listed DWX FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Intraday, usually minutes to hours until pattern SL/TP or Friday close. |
| Expected drawdown profile | Fixed-risk reversal losses can cluster around London-open trend continuation days. |
| Regime preference | London-open mean-reversion / candlestick reversal. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub MQL5 repository
**Pointer:** `https://github.com/peterthomet/MetaTrader-5-and-4-Tools/blob/master/EA%20Snippets/Reversal/2BarReversal.mq5`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10108_gh-getynet-2bar.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | d3c3fc0c-e25d-4ef0-85cf-2fb975adb770 |
