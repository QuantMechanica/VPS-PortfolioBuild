<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9228_mql5-alligator-teeth — Strategy Spec

**EA ID:** QM5_9228
**Slug:** `mql5-alligator-teeth`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA uses Bill Williams' Alligator indicator computed on the H1 timeframe using median price (HL/2). The three lines are Jaws (SMMA 13, shift 8), Teeth (SMMA 8, shift 5), and Lips (SMMA 5, shift 3). A long entry fires when Lips is below both Teeth and Jaws, and the closing price of the last completed H1 bar crosses above the Teeth line. A short entry fires when Lips is above both Teeth and Jaws, and close crosses below Teeth. Entries are at market on the next bar open. Exits trigger when close crosses back through Teeth in the opposite direction, when Lips crosses back through both Teeth and Jaws (trend exhaustion), or after 60 bars as a failsafe. An ATR-based volatility filter blocks entries when ATR(14) is below half of ATR(100), avoiding low-volatility chop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_jaw_period` | 13 | 5-50 | SMMA period for Alligator Jaws |
| `strategy_jaw_shift` | 8 | 1-20 | Forward bar shift for Jaws line |
| `strategy_teeth_period` | 8 | 3-30 | SMMA period for Alligator Teeth |
| `strategy_teeth_shift` | 5 | 1-15 | Forward bar shift for Teeth line |
| `strategy_lips_period` | 5 | 2-20 | SMMA period for Alligator Lips |
| `strategy_lips_shift` | 3 | 1-10 | Forward bar shift for Lips line |
| `strategy_atr_period` | 14 | 5-50 | ATR period for stop and TP sizing |
| `strategy_atr_sl_mult` | 1.8 | 0.5-5.0 | ATR multiplier for stop loss distance |
| `strategy_atr_tp_mult` | 2.2 | 1.0-10.0 | Risk-reward multiple for take profit (R) |
| `strategy_atr_slow_period` | 100 | 20-500 | Slow ATR period for volatility filter |
| `strategy_atr_slow_ratio` | 0.5 | 0.1-1.0 | Min ratio ATR14/ATR100 to allow entry |
| `strategy_max_hold_bars` | 60 | 10-200 | Failsafe exit after N H1 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair with sufficient trend behaviour and H1 liquidity
- `GBPUSD.DWX` — major FX pair with similar trend characteristics to EURUSD
- `XAUUSD.DWX` — gold with strong trending regimes suited to Alligator logic

**Explicitly NOT for:**
- Index CFDs — Alligator calibrated for Forex volatility profiles; index spreads and commission invalidate the ATR-filter threshold

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
| Trades / year / symbol | ~75 |
| Typical hold time | 5–30 hours (mean-reversion within trending move) |
| Expected drawdown profile | Moderate; ATR-sized stops with 1.8R risk per trade |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Mohamed Abdelmaaboud, "Learn how to design a trading system by Alligator", MQL5 Articles, 2022-10-12, https://www.mql5.com/en/articles/11549
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9228_mql5-alligator-teeth.md`

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
| v1 | 2026-06-10 | Initial build from card | 29cab562-3294-4919-bcf7-8cb509890fe4 |
