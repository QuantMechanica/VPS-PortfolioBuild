<!--
QuantMechanica V5 - EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_11372_micro-trading-bb18-ema3-macd-m1 - Strategy Spec

**EA ID:** QM5_11372
**Slug:** `micro-trading-bb18-ema3-macd-m1`
**Source:** `becda36b-263f-5989-b5fa-f1e945c0d4bd`
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades the M1 Micro Trading setup from the approved card. A long signal occurs when EMA(3) crosses above the EMA(18) Bollinger midline on the last closed bar, while MACD(12,26,9) main is positive and RSI(14) is above 50. A short signal is the mirror image: EMA(3) crosses below EMA(18), MACD main is negative, and RSI(14) is below 50. Entries use an 8-pip fixed stop and 10-pip fixed target, with a defensive strategy exit if EMA(3) closes back across the EMA(18) midline against the open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 18 | 14-20 P3 sweep | EMA basis period used as the Bollinger middle line |
| `strategy_bb_deviation` | 2.0 | 1.0-3.0 | Retained Bollinger outer-band deviation for later secondary-target sweeps |
| `strategy_ema_fast_period` | 3 | 3-7 P3 sweep | Fast EMA crossing the EMA(18) midline |
| `strategy_macd_fast` | 12 | 5-12 P3 sweep | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 26-35 P3 sweep | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5-9 P3 sweep | MACD signal EMA period |
| `strategy_rsi_period` | 14 | 7-21 | RSI confirmation period |
| `strategy_rsi_mid` | 50.0 | 45.0-55.0 | RSI momentum threshold |
| `strategy_tp_pips` | 10.0 | 5-15 P3 sweep | Fixed scalp take-profit in pips |
| `strategy_sl_pips` | 8.0 | 8-12 | Fixed stop-loss in pips |
| `strategy_session_start_hour` | 7 | 0-23 | First broker hour allowed for entries |
| `strategy_session_end_hour` | 22 | 0-23 | First broker hour blocked for the Asian dead-zone filter |
| `strategy_spread_cap_pips` | 8.0 | 0-20 | Maximum genuine spread in pips; zero modeled spread stays tradable |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary source instrument and the most liquid FX pair for M1 scalping.
- `GBPUSD.DWX` - card-listed portable FX major with similar London/NY session liquidity.

**Explicitly NOT for:**
- Index, metal, energy, and non-FX `.DWX` symbols - the source logic is a one-minute FX scalping system with pip-based stops and session assumptions.
- Crosses not listed by the card - not registered for P2 because the card names only EURUSD and GBPUSD.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 800 |
| Typical hold time | minutes; M1 scalp target |
| Expected drawdown profile | Frequent small wins and losses, sensitive to spread and execution cost |
| Regime preference | short-term momentum during liquid London/NY FX sessions |
| Win rate target (qualitative) | medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `becda36b-263f-5989-b5fa-f1e945c0d4bd`
**Source type:** forum/PDF compilation
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\### Forex to read\452915895-9-Forex-Systems-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11372_micro-trading-bb18-ema3-macd-m1.md`

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
| v1 | 2026-06-20 | Initial build from card | 4d223367-8415-42d9-b943-95d26e916749 |
