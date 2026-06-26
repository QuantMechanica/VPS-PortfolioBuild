# QM5_11536_carter-t-h1-ema14hl-psar - Strategy Spec

**EA ID:** QM5_11536
**Slug:** `carter-t-h1-ema14hl-psar`
**Source:** `3001a121-97a0-5db0-b6ff-69b89a0fc07d` (see `strategy-seeds/sources/3001a121-97a0-5db0-b6ff-69b89a0fc07d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades an H1 channel formed by EMA(14) of high prices and EMA(14) of low prices. It opens long when the last closed H1 candle closes above the EMA(high) channel and the Parabolic SAR value is below that candle's low. It opens short when the last closed H1 candle closes below the EMA(low) channel and the Parabolic SAR value is above that candle's high. Exits are the fixed 55-pip stop loss, fixed 75-pip take profit, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 14 | 1+ | EMA period for the high/low channel. |
| `strategy_sar_step` | 0.02 | >0 | Parabolic SAR acceleration step. |
| `strategy_sar_maximum` | 0.20 | >0 | Parabolic SAR maximum acceleration. |
| `strategy_stop_pips` | 55 | 1+ | Fixed stop loss distance in pips. |
| `strategy_take_pips` | 75 | 1+ | Fixed take profit distance in pips. |
| `strategy_spread_cap_pips` | 15 | 0+ | Maximum allowed live spread in pips; zero modeled spread is allowed. |
| `strategy_no_friday_entry` | true | true / false | Suppress new entries on broker-time Fridays. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the card's R3 PASS section specifies H1 EURUSD.DWX availability in the DWX factory.

**Explicitly NOT for:**
- Other `.DWX` symbols - the approved card names EURUSD.DWX only and does not authorize basket expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | intraday to multi-hour, bounded by 55-pip SL / 75-pip TP and Friday close |
| Expected drawdown profile | fixed-risk breakout losses during non-trending H1 periods |
| Regime preference | breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3001a121-97a0-5db0-b6ff-69b89a0fc07d`
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", System #10; all R1-R4 PASS per `artifacts/cards_approved/QM5_11536_carter-t-h1-ema14hl-psar.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11536_carter-t-h1-ema14hl-psar.md`

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
| v1 | 2026-06-26 | Initial build from card | b4087be2-8685-4886-adde-3e721b41db65 |
