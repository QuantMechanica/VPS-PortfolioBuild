<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_11514_carter-t-macd3916-adx16-d1 — Strategy Spec

**EA ID:** QM5_11514
**Slug:** `carter-t-macd3916-adx16-d1`
**Source:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf`
**Author of this spec:** Codex
**Last revised:** 2026-08-02

---

## 1. Strategy Logic

On each new D1 bar, the EA buys when the MACD(3,9,16) main line has crossed above its signal line on the latest closed bar and ADX(16) +DI is above -DI. It sells on the inverse MACD cross when -DI is above +DI. Each trade uses a fixed 100-pip stop and a take-profit at twice the stop distance; there is no discretionary close or active trade management beyond the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_macd_fast` | 3 | P3 values: 3, 5 | Fast EMA period of the MACD trigger. |
| `strategy_macd_slow` | 9 | P3 values: 9, 12 | Slow EMA period of the MACD trigger. |
| `strategy_macd_signal` | 16 | P3 values: 9, 16 | MACD signal-line smoothing period. |
| `strategy_adx_period` | 16 | P3 values: 14, 16, 20 | Period used for the +DI and -DI directional check. |
| `strategy_sl_pips` | 100 | P3 values: 75, 100, 150 | Fixed stop distance in scale-correct pips. |
| `strategy_tp_rr` | 2.0 | Fixed by card: 2.0 | Take-profit distance as a multiple of stop risk. |
| `strategy_spread_cap_pips` | 30 | Fixed by card: 30 | Blocks entry only when the modeled spread is genuinely wider than 30 pips. |
| `strategy_no_friday_entry` | true | Fixed by card: true | Prevents new entries on Friday broker time. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — source-specified major FX pair with D1 DWX history.
- `GBPUSD.DWX` — source-specified major FX pair with D1 DWX history.

**Explicitly NOT for:**

- Other `.DWX` instruments — the approved card names only EUR/USD and GBP/USD, so no broader basket is registered at Q01.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the D1 host chart |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 40, copied from card frontmatter. |
| Trade frequency | Not separately supplied; 40 per year implies about 3.3 trades per month per symbol. |
| Typical hold time | Not supplied by the card; the D1 signal with a 100-pip stop and 200-pip target implies multi-day holds. |
| Expected drawdown profile | Not supplied by the card; no numerical drawdown expectation is asserted at Q01. |
| Regime preference | Directional trend shifts, as stated by the card's trend-following concept and ADX directional confirmation. |
| Win rate target (qualitative) | Not supplied by the card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `8794b680-f6f4-5142-b12c-e5e0057e7bcf`
**Source type:** book
**Pointer:** Thomas Carter, *Forex Trend Following Strategies: 20 Trend Following Systems*, System 9, self-published 2014; source record `sources/carter-thomas-20-forex-trend-following-systems`.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11514_carter-t-macd3916-adx16-d1.md`.

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
| v1 | 2026-08-02 | Initial build from card | 80224433-5f03-4a2a-b0dd-f68b24288dc7 |

