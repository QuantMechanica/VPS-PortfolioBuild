# QM5_9931_bandy-turn-of-month-overlay-index - Strategy Spec

**EA ID:** QM5_9931
**Slug:** `bandy-turn-of-month-overlay-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016` (see `strategy-seeds/sources/9ef19e06-5ca6-5b35-aa06-b8187aa0e016/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA is a long-only daily turn-of-month overlay for equity indices. It opens long on the next D1 bar when the last closed bar is inside the last three trading days of the month or the first two trading days of the new month, and the closed price is above SMA(200). The initial stop is fixed at entry_price - 2.5 * ATR(14), with no trailing or partial exits. The EA exits after the turn-of-month window has passed, after seven trading days, or through the initial catastrophic stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pre_month_end_days` | 3 | 1-5 | Number of final month trading days eligible for entry. |
| `strategy_post_month_start_days` | 2 | 1-5 | Number of first new-month trading days eligible for entry. |
| `strategy_exit_after_start_day` | 3 | 2-7 | Close after this trading day of the new month. |
| `strategy_regime_sma_period` | 200 | 50-400 | Daily SMA regime gate; closed price must be above it. |
| `strategy_atr_period` | 14 | 5-50 | Daily ATR lookback for the catastrophic stop. |
| `strategy_atr_stop_mult` | 2.5 | 1.0-5.0 | ATR multiple used for the initial long stop. |
| `strategy_time_stop_trading_days` | 7 | 3-12 | Maximum holding period measured in closed D1 bars. |
| `strategy_require_d1` | true | true/false | Blocks trading unless the chart period is D1. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread cap; 0 disables the cap for DWX zero-spread tests. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index substrate for the turn-of-month effect; backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 live-routable large-cap US index proxy.
- `WS30.DWX` - Dow 30 live-routable large-cap US index proxy.

**Explicitly NOT for:**
- Forex and commodity `.DWX` symbols - the card states the index family is the canonical substrate and non-index TOM evidence is weak.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entry; cached D1 calendar state updates once per broker day |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | 5-7 trading days |
| Expected drawdown profile | Stop losses should cluster during regime breaks; one bad-month skip rule suppresses immediate re-entry after catastrophic SL. |
| Regime preference | Seasonal overlay in bullish index regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** book
**Pointer:** Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 9780979183850; all R1-R4 PASS per `artifacts/cards_approved/QM5_9931_bandy-turn-of-month-overlay-index.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9931_bandy-turn-of-month-overlay-index.md`

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
| v1 | 2026-06-25 | Initial build from card | 635df9ff-1f76-4222-8cf1-b5ce5f9886bb |
