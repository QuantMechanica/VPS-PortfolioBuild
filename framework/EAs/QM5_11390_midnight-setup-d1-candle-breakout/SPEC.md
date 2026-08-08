# QM5_11390_midnight-setup-d1-candle-breakout — Strategy Spec

**EA ID:** QM5_11390
**Slug:** `midnight-setup-d1-candle-breakout`
**Source:** `dfd32799-2055-5ef8-b99b-dcbfa51daba0`
**Author of this spec:** Codex
**Last revised:** 2026-08-07

---

## 1. Strategy Logic

At the first tick of each new D1 bar, the EA reads the prior closed daily candle. If that candle's high-low range is at least 90 pips, it places a BUY STOP 5 pips above the high and a SELL STOP 5 pips below the low; both orders expire at the next daily boundary, and the first fill cancels the other order. Every filled trade has a fixed 50-pip stop loss and 100-pip take profit, with no discretionary exit in the base configuration.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_min_range_pips` | 90 | 70-110 | Minimum prior-D1 high-low range required by the card |
| `strategy_offset_pips` | 5 | 3-10 | Distance beyond the prior high or low for each pending stop |
| `strategy_sl_pips` | 50 | 1-50 | Fixed stop-loss distance; 50 pips is the card's P2 cap |
| `strategy_tp_pips` | 100 | 80-150 | Fixed take-profit distance from entry |
| `strategy_spread_cap_pips` | 30 | 1-30 | Blocks only a genuinely positive spread wider than the card's cap |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`; this table lists only strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**

- `GBPUSD.DWX` — primary source instrument and a liquid FX major whose daily range can satisfy the 90-pip breakout threshold.
- `EURUSD.DWX` — the card's portable variant and a liquid FX major with the same pip-scale mechanics.

**Explicitly NOT for:**

- Index, metal, and energy CFDs — the fixed FX-pip range, offset, SL, and TP calibration is not portable to their point scales.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` on a D1 chart |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `25` |
| Expected trade frequency | Roughly two trades per month per symbol |
| Typical hold time | Intraday to one daily bar; pending orders expire at the next D1 boundary |
| Expected drawdown profile | Fixed 50-pip risk per filled trade, with losses potentially clustering during false breakouts |
| Regime preference | Volatility expansion / breakout |
| Win rate target (qualitative) | Low-to-medium; the fixed target is twice the fixed stop |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `dfd32799-2055-5ef8-b99b-dcbfa51daba0`
**Source type:** anonymous forex strategy compilation
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\pdfcoffee.com_forex-strategy-7-pdf-free.pdf`
**R1 lineage and R2-R4 verdict:** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11390_midnight-setup-d1-candle-breakout.md`.

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
| v1 | 2026-08-07 | Initial build from card | 91d56258-ea4f-4f82-b124-7699c6e59d09 |
