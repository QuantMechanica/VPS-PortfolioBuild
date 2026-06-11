<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9405_qs-forex-mac — Strategy Spec

**EA ID:** QM5_9405
**Slug:** `qs-forex-mac`
**Source:** `842161b9-a728-55c7-97e8-33e33719b70c` (see `strategy-seeds/sources/842161b9-a728-55c7-97e8-33e33719b70c/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Long-only SMA crossover on M1 bars. Compute a 500-bar simple moving average (fast) and a 2000-bar simple moving average (slow) of the close price on the M1 chart. Enter long at market when the fast SMA crosses above the slow SMA on the last closed bar and no position is currently open. Hold the position until the slow SMA meets or exceeds the fast SMA, then close at market. Stop loss is placed 2.0 × ATR(14) below the entry ask. No short entries.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_period` | 500 | 50–2000 | Number of M1 bars for the fast SMA |
| `strategy_slow_period` | 2000 | 200–5000 | Number of M1 bars for the slow SMA |
| `strategy_atr_period` | 14 | 5–50 | ATR period (M1 bars) for initial stop distance |
| `strategy_atr_sl_mult` | 2.0 | 1.0–5.0 | Multiplier applied to ATR to set SL distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary research symbol from the QuantStart source article (slot 0)
- `GBPUSD.DWX` — secondary research symbol cited in the same article (slot 1)

**Explicitly NOT for:**
- Index CFDs (NDX.DWX, WS30.DWX) — strategy designed specifically for liquid major forex pairs

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~80 |
| Typical hold time | hours to days |
| Expected drawdown profile | moderate; long-only trend-following exposed to choppy M1 price action |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `842161b9-a728-55c7-97e8-33e33719b70c`
**Source type:** article
**Pointer:** QuantStart "Forex Trading Diary #7 — New Backtest Interface" — lines 45-63 and 82-90 describe GBPUSD/EURUSD tick windows 500/2000 and long-only crossover
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9405_qs-forex-mac.md`

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
| v1 | 2026-06-11 | Initial build from card | da30d057-ef26-425f-8b09-ac97f22a3768 |
