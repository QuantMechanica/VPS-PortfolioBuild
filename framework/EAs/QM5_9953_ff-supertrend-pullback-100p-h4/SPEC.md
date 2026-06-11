# QM5_9953_ff-supertrend-pullback-100p-h4 — Strategy Spec

**EA ID:** QM5_9953
**Slug:** `ff-supertrend-pullback-100p-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On H4 bars, compute a SuperTrend channel with ATR period 10 and multiplier 3.0. The middle line is the average of the final upper and lower SuperTrend bands. After a bullish trend flip sustained for at least 3 consecutive bullish H4 closes, the EA waits for the first pullback bar where the H4 low touches or pierces the middle line but the bar closes back above it. On the next H4 bar, a buy limit order is placed at the middle line with a 100-pip stop loss below and 100-pip take profit above; the limit is cancelled if unfilled after 2 H4 bars. Short entries mirror this in bearish SuperTrend conditions. Any open position is additionally closed if an H4 bar closes beyond the opposite SuperTrend boundary, signalling a trend reversal.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 10 | 5-20 | ATR period for SuperTrend band computation |
| `strategy_st_multiplier` | 3.0 | 1.0-5.0 | SuperTrend ATR multiplier for band width |
| `strategy_min_trend_bars` | 3 | 1-10 | Minimum consecutive H4 bars in trend direction before pullback scan activates |
| `strategy_sl_tp_pips` | 100 | 50-200 | Fixed stop-loss and take-profit distance in pips (1:1 R/R) |
| `strategy_pending_cancel_bars` | 2 | 1-5 | Cancel unfilled limit order after this many new H4 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary source pair; deep liquidity and clear H4 SuperTrend structure
- `AUDUSD.DWX` — source pair; risk-asset trending behaviour suits pullback entries
- `USDCAD.DWX` — source pair; commodity-driven trends provide distinct SuperTrend legs
- `GBPUSD.DWX` — source pair; wide H4 swings support 100-pip fixed targets
- `USDCHF.DWX` — source pair; inverse correlation to EURUSD diversifies the FX basket

**Explicitly NOT for:**
- Index, commodity, or exotic FX CFDs — strategy is calibrated for liquid major FX pairs only

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` — state advances at start of each new-bar block |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~30 |
| Typical hold time | 4–48 hours (limit to TP/SL hit or boundary-cross exit) |
| Expected drawdown profile | Trend-following swing; sequential 100-pip SL losses possible before winning trade |
| Regime preference | trend |
| Win rate target (qualitative) | low-medium (first-pullback only per trend leg, fixed 1:1 R/R) |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** jamesagnew, "4 hour timeframe 100 pip trader", ForexFactory, 2026
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9953_ff-supertrend-pullback-100p-h4.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 4a3844cb-5de3-48f0-ad09-a525575ffa2d |
