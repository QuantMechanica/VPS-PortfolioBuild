# QM5_11507_carter-t-ema20-macd-buystop-m15 - Strategy Spec

**EA ID:** QM5_11507
**Slug:** carter-t-ema20-macd-buystop-m15
**Source:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf (see `strategy-seeds/sources/8794b680-f6f4-5142-b12c-e5e0057e7bcf/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades M15 momentum continuation with an EMA(20) trend filter and MACD(12,26,9) zero-line confirmation. A long setup requires EMA(20) to be rising, MACD main to be positive, and MACD main to have crossed above zero within the last five closed bars; it places a Buy Stop 10 pips above the current EMA(20). A short setup mirrors the rule with falling EMA(20), negative MACD, recent cross below zero, and a Sell Stop 10 pips below the current EMA(20). Pending orders expire after five M15 bars, with a 20-pip stop and 1:1 take profit from the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 20 | 2-200 | EMA period for the trend slope and pending-order anchor. |
| `strategy_macd_fast` | 12 | 1-100 | Fast EMA period for MACD main. |
| `strategy_macd_slow` | 26 | fast+1-200 | Slow EMA period for MACD main. |
| `strategy_macd_signal` | 9 | 1-100 | MACD signal period. |
| `strategy_macd_recency_bars` | 5 | 1-20 | Closed-bar lookback for a recent MACD zero-line cross. |
| `strategy_entry_offset_pips` | 10 | 0-50 | Pending stop offset from EMA(20). |
| `strategy_sl_pips` | 20 | 1-100 | Fixed stop distance from entry price. |
| `strategy_take_rr` | 1.0 | 0.1-5.0 | Take-profit multiple of stop distance. |
| `strategy_pending_expiry_bars` | 5 | 1-20 | Pending order expiry in M15 bars. |
| `strategy_spread_cap_pips` | 15 | 0-100 | Maximum modeled spread allowed for new trades; zero spread passes. |
| `strategy_no_friday_entry` | true | true/false | Blocks new entries on broker-time Friday. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed live-tradable DWX FX instrument with M15 history.
- GBPUSD.DWX - card-listed live-tradable DWX FX instrument with M15 history.
- AUDUSD.DWX - card-listed live-tradable DWX FX instrument with M15 history.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research and backtest registry requires `.DWX` symbols.
- Index or commodity CFDs - the card targets the listed major FX pairs only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | Not specified in card frontmatter; expected intraday because entries, expiry, SL, and TP are all M15-native. |
| Expected drawdown profile | Not specified in card frontmatter; fixed 20-pip stop per trade with framework risk sizing. |
| Regime preference | Trend-following momentum continuation / breakout. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8794b680-f6f4-5142-b12c-e5e0057e7bcf
**Source type:** book
**Pointer:** Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following Systems", System #2, self-published 2014; see `strategy-seeds/sources/8794b680-f6f4-5142-b12c-e5e0057e7bcf/`.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11507_carter-t-ema20-macd-buystop-m15.md`

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
| v1 | 2026-06-20 | Initial build from card | 87e3e9fe-2605-4dc9-a2e6-c278480ec899 |
