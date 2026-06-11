<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_11839_ait-sma5-37 — Strategy Spec

**EA ID:** QM5_11839
**Slug:** `ait-sma5-37`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Long-only D1 trend-following strategy based on a two-SMA crossover. The EA enters a long position on the close of a D1 bar when the 5-period SMA crosses above the 37-period SMA (golden cross). It exits the long position when the 5-period SMA crosses below the 37-period SMA (death cross). A hard protective stop is placed at 2 × ATR(14) below the entry price. One position per symbol is permitted at any time; no short entries are taken.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_period` | 5 | 3–20 | Period for the fast SMA |
| `strategy_slow_period` | 37 | 20–100 | Period for the slow SMA |
| `strategy_atr_period` | 14 | 7–28 | ATR period used to compute the hard stop distance |
| `strategy_atr_sl_mult` | 2.0 | 1.0–4.0 | ATR multiplier for the hard stop below entry |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; D1 SMA crossovers have well-defined trend phases
- `GBPUSD.DWX` — liquid major FX pair; trending characteristics on D1 suit SMA crossover
- `USDJPY.DWX` — liquid major FX pair; close-derived SMA portable across sessions
- `XAUUSD.DWX` — gold; trending commodity with clear D1 trend regimes
- `GDAXI.DWX` — DAX 40 index CFD; mapped from card GER40.DWX (same instrument, canonical DWX name)
- `NDX.DWX` — Nasdaq 100 index CFD; trending equity index suited to D1 crossover
- `WS30.DWX` — Dow Jones 30 index CFD; trending equity index suited to D1 crossover

**Explicitly NOT for:**
- `SP500.DWX` — omitted from P2 basket (card lists GER40/indices basket; SP500 is backtest-only and not in primary R3 basket)

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (conservative estimate 6–20) |
| Typical hold time | Days to weeks (D1 crossover reversal exit) |
| Expected drawdown profile | Moderate; whipsaw risk in sideways markets; ~20% max DD per card |
| Regime preference | Trend-following |
| Win rate target (qualitative) | Low–medium (trend-following; large winners offset losers) |

---

## 6. Source Citation

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** GitHub repository
**Pointer:** `https://github.com/whchien/ai-trader/blob/main/ai_trader/backtesting/strategies/classic/sma.py` (CrossSMAStrategy)
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11839_ait-sma5-37.md`

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
| v1 | 2026-06-11 | Initial build from card | 735b07d7-bc3e-49b9-9cb1-141d58fb2fbe |
