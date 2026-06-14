# QM5_10897_brown-micro-ema - Strategy Spec

**EA ID:** QM5_10897
**Slug:** brown-micro-ema
**Source:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades an M1 micro-trend cross. A long entry is opened when EMA(3) crosses above the Bollinger Bands middle line on the last closed M1 bar, MACD histogram is above zero, and RSI(14) is above 50. A short entry uses the inverse cross with MACD histogram below zero and RSI below 50. Exits occur at the fixed stop, at the larger of an 8 pip target or 1.0 ATR(14), on an opposite EMA/Bollinger middle cross, or after 30 M1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 3 | >=1 | EMA period used for the Bollinger middle-line cross. |
| `strategy_bb_period` | 20 | >=1 | Bollinger Bands period; middle line is the crossed reference. |
| `strategy_bb_deviation` | 2.0 | >0 | Bollinger Bands deviation parameter. |
| `strategy_macd_fast` | 12 | >=1 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | >=1 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | >=1 | MACD signal period used to form the histogram. |
| `strategy_rsi_period` | 14 | >=1 | RSI confirmation period. |
| `strategy_rsi_midline` | 50.0 | 0-100 | Longs require RSI above this level; shorts require RSI below it. |
| `strategy_fixed_sl_pips` | 8 | >=1 | Fixed stop loss in pips. |
| `strategy_fixed_tp_pips` | 8 | >=1 | Minimum fixed take profit in pips. |
| `strategy_atr_period` | 14 | >=1 | ATR period used for the larger target check. |
| `strategy_tp_atr_mult` | 1.0 | >0 | ATR multiplier used as the alternate take-profit distance. |
| `strategy_max_hold_bars` | 30 | >=1 | Maximum M1 bars to hold before strategy exit. |
| `strategy_session_start_hour` | 8 | 0-23 | Broker-hour start for the London/US session gate. |
| `strategy_session_end_hour` | 22 | 0-24 | Broker-hour end for the London/US session gate. |
| `strategy_eurusd_spread_cap_pips` | 1.5 | >0 | Maximum EURUSD spread allowed for entry. |
| `strategy_gbpusd_spread_cap_pips` | 2.5 | >0 | Maximum GBPUSD spread allowed for entry. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved EURUSD baseline with strict 1.5 pip spread cap.
- `GBPUSD.DWX` - card-approved GBPUSD baseline with strict 2.5 pip spread cap.

**Explicitly NOT for:**
- Non-EURUSD/GBPUSD symbols - card R3 restricts the P2 basket to EURUSD.DWX and GBPUSD.DWX because the M1 scalper is cost-sensitive.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 30 M1 bars |
| Expected drawdown profile | Scalping drawdowns driven by spread, whipsaw, and tight fixed stops. |
| Regime preference | M1 micro-trend continuation after EMA/Bollinger middle cross. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6facee24-8a58-5bbf-88e9-38d44291db50
**Source type:** book
**Pointer:** Jim Brown, FOREX TRADING the Basics Explained, local PDF file:///G:/My%20Drive/QuantMechanica/Ebook/PDF%20resources/FOREX%20TRADING%20the%20Basics%20Explai%20-%20Jim%20Brown.pdf, pp. 38-40
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10897_brown-micro-ema.md`

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
| v1 | 2026-06-14 | Initial build from card | db73e995-4c46-4b61-9b12-90598de08dce |
