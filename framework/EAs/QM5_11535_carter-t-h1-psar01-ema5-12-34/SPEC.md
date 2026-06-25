# QM5_11535_carter-t-h1-psar01-ema5-12-34 - Strategy Spec

**EA ID:** QM5_11535
**Slug:** carter-t-h1-psar01-ema5-12-34
**Source:** 3001a121-97a0-5db0-b6ff-69b89a0fc07d (see `sources/carter-thomas-20-forex-strategies-1h`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades EURUSD on H1 when the last closed bar has a triple EMA trend stack and a matching Parabolic SAR confirmation. A long entry requires EMA(5) above EMA(12), EMA(12) above EMA(34), SAR(0.1,0.2) below the last closed bar low, and SAR falling versus the prior closed bar. A short entry uses the inverse EMA stack, SAR above the last closed bar high, and SAR rising versus the prior closed bar. Exits use a fixed 30-pip stop loss and 50-pip take profit, with no discretionary exit beyond framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 5 | >0 | Fast EMA period for the trend stack. |
| `strategy_ema_mid_period` | 12 | >0 | Middle EMA period for the trend stack. |
| `strategy_ema_slow_period` | 34 | >0 | Slow EMA period for the trend stack. |
| `strategy_sar_step` | 0.1 | >0 | Parabolic SAR acceleration step. |
| `strategy_sar_maximum` | 0.2 | >0 | Parabolic SAR acceleration maximum. |
| `strategy_sl_pips` | 30 | >0 | Fixed stop-loss distance in pips. |
| `strategy_tp_pips` | 50 | >0 | Fixed take-profit distance in pips. |
| `strategy_spread_cap_pips` | 15 | >=0 | Blocks new entries only when live spread is wider than this pip cap. |
| `strategy_block_friday` | true | true/false | Blocks new Friday entries per the card filter. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - the card's R3 PASS section names H1 EURUSD.DWX as the available DWX test symbol.

**Explicitly NOT for:**
- Non-EURUSD `.DWX` symbols - the card does not declare a portable basket or expansion universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Hours to a few days, bounded by 30-pip SL and 50-pip TP plus Friday close. |
| Expected drawdown profile | Trend-following intraday drawdown with losses capped by fixed SL. |
| Regime preference | H1 directional trend with PSAR confirmation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3001a121-97a0-5db0-b6ff-69b89a0fc07d
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", System #9; `sources/carter-thomas-20-forex-strategies-1h`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11535_carter-t-h1-psar01-ema5-12-34.md`

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
| v1 | 2026-06-25 | Initial build from card | 3b890334-b00e-467e-bed9-efd8481c8e06 |
