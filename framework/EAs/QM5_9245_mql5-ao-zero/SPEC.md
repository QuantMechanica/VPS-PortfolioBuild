<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9245_mql5-ao-zero — Strategy Spec

**EA ID:** QM5_9245
**Slug:** `mql5-ao-zero`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades Awesome Oscillator zero-line crossovers on H4 bars. A long entry fires when the AO value on the last closed bar crosses from negative to positive (AO[2] < 0 and AO[1] > 0); a short entry fires on the reverse cross. An additional noise filter requires the signal bar's absolute AO value to exceed 0.2 times the median absolute AO over the prior 50 bars, suppressing near-zero flat-market entries. The position is closed when AO crosses back through zero in the opposite direction, or after a 30-bar failsafe time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 5–50 | ATR period for stop-loss and take-profit sizing |
| `strategy_atr_sl_mult` | 1.8 | 0.5–5.0 | Stop-loss distance = ATR × mult |
| `strategy_tp_rr` | 2.2 | 1.0–5.0 | Take-profit distance = SL_distance × RR |
| `strategy_ao_noise_lookback` | 50 | 10–200 | Lookback bars for median absolute AO noise filter |
| `strategy_ao_noise_mult` | 0.2 | 0.0–1.0 | Signal bar must have AO > mult × median to qualify |
| `strategy_time_stop_bars` | 30 | 5–200 | Failsafe exit after N closed H4 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major liquid forex pair; H4 AO crossovers well-defined on trending price action
- `GBPJPY.DWX` — high-momentum cross pair; trending regimes suit AO zero-cross momentum
- `XAUUSD.DWX` — gold; strong trending behaviour with clear AO momentum regimes

**Explicitly NOT for:**
- Indices (NDX.DWX, WS30.DWX) — card targets forex + gold only; indices not in card basket

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
| Trades / year / symbol | ~50 |
| Typical hold time | 1–10 H4 bars (4–40 hours) |
| Expected drawdown profile | Moderate intra-trade DD; SL at 1.8× ATR |
| Regime preference | trend-following / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Stephen Njuki, "MQL5 Wizard Techniques you should know (Part 50): Awesome Oscillator", MQL5 Articles, 2024-11-29, https://www.mql5.com/en/articles/16502
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9245_mql5-ao-zero.md`

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
| v1 | 2026-06-10 | Initial build from card | 77251513-1db8-4145-ae3b-de23989e7fd2 |
