# QM5_12920_qp-pre-election-sp500 - Strategy Spec

**EA ID:** QM5_12920
**Slug:** `qp-pre-election-sp500`
**Source:** `7ede58dd-d184-5099-9d48-7a65de230853`
**Author of this spec:** Gemini
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

This EA implements the Quantpedia Pre-Election Drift strategy on the S&P 500 (`SP500.DWX`). US Federal Elections (presidential and midterm) occur on the Tuesday after the first Monday in November of every even-numbered year.

On the close of D-5 trading days (the Tuesday exactly 7 calendar days before Election Day), the EA opens a LONG position in SP500.DWX. The position is held through the election window and closed on the close of Election Day (D0, Tuesday).

A 2.0x D1 ATR(20) hard stop provides catastrophic protection. Time-based exit is enforced at Election Day close.

The EA uses only Darwinex MT5 price history and calendar computation. It does not use external APIs, ML, grids, martingale, pyramiding, or trailing stops.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `qm_ea_id` | 12920 | fixed | Canonical EA ID |
| `qm_magic_slot_offset` | 2 | 0-12 | Registered magic slot (slot 2 = SP500.DWX) |
| `strategy_atr_period` | 20 | 5-50 | ATR lookback for hard protective stop |
| `strategy_atr_sl_mult` | 2.0 | 1.0-5.0 | ATR stop distance multiplier |
| `strategy_min_d1_bars` | 60 | 30-100 | Minimum D1 history required before trading |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - core equity index instrument for US election drift research.

**Explicitly NOT for:**
- FX, commodity, or crypto symbols.
- Live promotion caveat: SP500.DWX is not broker-routable on DXZ live; T6 promotion requires parallel validation on NDX.DWX or WS30.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()`; entry/exit logic evaluates once per D1 bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~1 trade every 2 years (even-numbered election years) |
| Typical hold time | 5 trading days (D-5 to D0) |
| Expected drawdown profile | Low frequency calendar event holding risk |
| Regime preference | US election cycle equity seasonality |
| Win rate target | High historical positive drift probability |

---

## 6. Source Citation

This card was mechanised from:
- **Source ID:** `7ede58dd-d184-5099-9d48-7a65de230853`
- **Source:** [[sources/quantpedia-encyclopedia]] - Quantpedia "Pre-Election Drift in the Stock Market"
- **Authors:** Radovan Vojtko, Dominik Cisar
- **URI:** https://quantpedia.com/pre-election-drift-in-the-stock-market/
- **R1-R4 verdict (Q00):** all PASS per approved card

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-21 | Initial build from approved card | Built during single-pass orchestration cycle |
