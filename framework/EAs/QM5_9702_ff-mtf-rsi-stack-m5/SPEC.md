# QM5_9702_ff-mtf-rsi-stack-m5 - Strategy Spec

**EA ID:** QM5_9702
**Slug:** `ff-mtf-rsi-stack-m5`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades completed M5 bars when RSI(55) is aligned on M1, M5, M15, M30, and H1. A long entry requires all five RSI values above 50 and an M5 RSI cross from at or below 50 to above 50 within the last two completed M5 bars; shorts mirror this below 50. Entries are filtered by broker-hour session, current spread, and 5-day ADR. Exits use the attached SL/TP, session close, Friday close, or an M15 RSI cross back through 50 against the open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 55 | 2-200 | RSI period applied to all five timeframes. |
| `strategy_rsi_midline` | 50.0 | 1-99 | RSI stack threshold and cross level. |
| `strategy_cross_lookback_bars` | 2 | 1-2 | Completed M5 bars allowed for the trigger cross. |
| `strategy_adr_days` | 5 | 2-30 | D1 bars used for the ADR filter. |
| `strategy_min_adr_pips` | 60 | 1-500 | Minimum 5-day ADR in symbol-normalized pips. |
| `strategy_max_spread_pips` | 3 | 1-50 | Maximum modeled spread in symbol-normalized pips. |
| `strategy_stop_pips` | 20 | 1-500 | Fixed source stop distance before ATR floor. |
| `strategy_take_pips` | 25 | 1-500 | Fixed source take-profit cap. |
| `strategy_take_rr_cap` | 1.25 | 0.1-10.0 | Maximum TP expressed as risk multiple. |
| `strategy_atr_period` | 14 | 2-200 | ATR period for non-EURUSD minimum stop floor. |
| `strategy_min_stop_atr_mult` | 0.50 | 0.1-10.0 | Minimum non-EURUSD stop distance as ATR multiple. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour start of the liquid trading session. |
| `strategy_session_end_hour` | 22 | 0-23 | Broker-hour end of the liquid trading session and session-close exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid major FX pair directly available in DWX.
- `GBPUSD.DWX` - card target; liquid major FX pair directly available in DWX.
- `USDJPY.DWX` - card target; liquid major FX pair directly available in DWX.
- `XAUUSD.DWX` - card target; liquid gold CFD directly available in DWX.

**Explicitly NOT for:**
- `SP500.DWX` - not part of the card's ForexFactory FX/metals basket.
- `NDX.DWX` - not part of the card's ForexFactory FX/metals basket.
- `WS30.DWX` - not part of the card's ForexFactory FX/metals basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `M1`, `M5`, `M15`, `M30`, `H1` RSI(55) closed-bar reads |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | Intraday; minutes to hours, closed no later than configured session end unless SL/TP exits first. |
| Expected drawdown profile | High-frequency fixed-risk scalping profile with many small SL/TP outcomes. |
| Regime preference | RSI momentum alignment during liquid FX/metals sessions. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/504229-mtf-rsi-trading-system`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9702_ff-mtf-rsi-stack-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | c3752e65-73e2-4957-8c02-98a6453f909b |

