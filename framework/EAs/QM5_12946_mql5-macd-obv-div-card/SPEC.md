# QM5_12946_mql5-macd-obv-div-card - Strategy Spec

**EA ID:** QM5_12946
**Slug:** `mql5-macd-obv-div-card`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

On H1 closed bars, the EA confirms price swing highs and lows with a strict
three-bars-left and three-bars-right fractal. A long divergence exists when the
newest confirmed price swing low is lower than the previous confirmed swing
low, the MACD main line is higher at the newer swing, and tick-volume OBV either
is higher at the newer swing or rises on all three closed bars after it. A short
divergence reverses those comparisons. The signal expires after ten bars and
enters on the first later bullish candle for a long or bearish candle for a
short.

The initial long stop is the second swing low minus 0.25 times ATR(14); the
short stop is the second swing high plus that buffer. The target is two times
initial risk. An open long closes early on a confirmed short divergence or a
MACD-main cross below zero; an open short uses the inverse rules. Framework
Friday-close and news-entry controls remain authoritative.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_macd_fast` | 12 | 6-24 | Fast EMA period in standard MACD main. |
| `strategy_macd_slow` | 26 | 18-52 | Slow EMA period; must exceed the fast period. |
| `strategy_macd_signal` | 9 | 5-18 | MACD signal period used by the pooled MACD handle. |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the structural stop buffer. |
| `strategy_atr_swing_buffer` | 0.25 | 0.10-0.75 | ATR multiple beyond the divergence swing. |
| `strategy_reward_risk` | 2.0 | 1.0-4.0 | Fixed take-profit multiple of initial risk. |
| `strategy_divergence_expiry_bars` | 10 | 3-20 | Bars allowed for the first confirming candle. |
| `strategy_swing_scan_bars` | 160 | 48-480 | Bounded closed-bar window used to locate the prior fractal and build OBV. |

The card fixes fractal strength at 3-left/3-right and the post-swing OBV trend
at three bars; they are compile-time constants rather than optimisation inputs.
The source card does not state MACD periods, so the implementation uses the
standard 12/26/9 convention.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` - liquid major-FX H1 series with broker tick volume.
- `GBPUSD.DWX` - liquid major-FX H1 series with broker tick volume.
- `XAUUSD.DWX` - liquid metal H1 series included by the approved card.

**Explicitly NOT for:**

- Symbols without reliable tick-volume history - the OBV confirmation would
  not represent the approved mechanism.
- Non-`.DWX` aliases - registry identity, history, and magic binding are not
  governed for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

The entry hook rejects any chart period other than H1.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 35 |
| Typical hold time | hours to several days |
| Expected drawdown profile | clustered losses when trends continue through apparent divergence |
| Regime preference | reversal after momentum and volume participation weaken |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** named-author MQL5 article
**Pointer:** Christian Benjamin, "MQL5 Wizard Techniques you should know
(Part 71): MACD plus OBV," 2025-05-28,
`https://www.mql5.com/en/articles/18462`
**R1-R4 verdict (Q00):** all PASS; see
`artifacts/cards_approved/QM5_12946_mql5-macd-obv-div-card.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3%-0.5% |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-22 | Initial build from approved card | Build task `7bc9f0f5-251e-4755-b829-33e38cfd740b`. |
