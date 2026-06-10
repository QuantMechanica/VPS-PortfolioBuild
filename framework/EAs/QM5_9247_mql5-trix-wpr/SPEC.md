<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9247_mql5-trix-wpr — Strategy Spec

**EA ID:** QM5_9247
**Slug:** `mql5-trix-wpr`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Long entry fires on the first H4 closed bar where TRIX(3) crosses from below zero to above zero (TRIX[1]<0, TRIX[0]>0) while Williams %R(14) is above the -50 midline (WPR>-50) and below -20 (not yet in overbought territory). Short entry is the mirror: TRIX crosses from above zero to below zero while WPR is below -50 and above -80. Stop is set at 1.9 × ATR(14) from entry; take-profit is 2.2 × that risk distance (R:R 2.2). A long is closed when TRIX falls back below zero or WPR drops below -50; a short is closed when TRIX rises above zero or WPR rises above -50. A failsafe time exit closes the position after 30 H4 bars if neither signal condition fires.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trix_period` | 3 | 3–15 | Period for the TRIX triple-EMA oscillator |
| `strategy_wpr_period` | 14 | 7–28 | Williams %R lookback period |
| `strategy_atr_period` | 14 | 7–21 | ATR lookback for stop and TP sizing |
| `strategy_atr_sl_mult` | 1.9 | 1.0–3.0 | Stop distance multiplier on ATR |
| `strategy_atr_tp_rr` | 2.2 | 1.5–4.0 | Take-profit as R:R multiple of the stop |
| `strategy_max_hold_bars` | 30 | 10–60 | Failsafe time exit after N H4 bars |
| `strategy_wpr_long_max` | -20.0 | -30 – -10 | Long entry requires WPR below this (not overbought) |
| `strategy_wpr_short_min` | -80.0 | -90 – -70 | Short entry requires WPR above this (not oversold) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair with deep liquidity; TRIX/WPR momentum patterns documented on H4
- `CHFJPY.DWX` — risk-sentiment proxy; directional moves favour zero-cross trend entry
- `GBPJPY.DWX` — volatile cross with strong trending behaviour on H4 suited to TRIX momentum

**Explicitly NOT for:**
- Equity indices — not tested; card specifies FX pairs only

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~45 |
| Typical hold time | 1–5 days (4–30 H4 bars) |
| Expected drawdown profile | Moderate; 1.9 ATR stop limits per-trade risk |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** https://www.mql5.com/en/articles/18251 — Stephen Njuki, MQL5 Wizard Techniques Part 67, Pattern 2 (TRIX zero-cross + WPR midline)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9247_mql5-trix-wpr.md`

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
| v1 | 2026-06-10 | Initial build from card | 7a7618d3-2475-425f-9ea1-d912998d974d |
