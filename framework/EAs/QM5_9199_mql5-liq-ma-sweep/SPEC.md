<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9199_mql5-liq-ma-sweep — Strategy Spec

**EA ID:** QM5_9199
**Slug:** `mql5-liq-ma-sweep`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each closed M15 bar, the EA computes the highest high and lowest low of the 20 bars preceding the just-closed bar (the "liquidity range"). A long sweep is signalled when the just-closed bar's low dips below that range low and the close recovers back above it, provided the close is also above the SMA(50) or the SMA(50) slope is rising. A short sweep is the mirror: bar high exceeds the range high, close recovers below it, and price is below the SMA or the slope is falling. Entries are placed as market orders on the next bar open. The stop loss is placed below the sweep candle's low (long) or above its high (short) by ATR(14) × 0.25. Take-profit is set at whichever is closer to entry: the 2R projection or the opposite side of the 20-bar range. Positions are closed if a subsequent bar closes back through the SMA against the trade direction. A per-direction cooldown of 20 bars prevents back-to-back sweep entries.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_liq_lookback` | 20 | 5–100 | Number of bars before the sweep bar used to define the liquidity high/low |
| `strategy_ma_period` | 50 | 10–200 | Period of the SMA used as direction filter and exit trigger |
| `strategy_atr_period` | 14 | 5–50 | ATR period for stop-loss distance sizing |
| `strategy_atr_sl_mult` | 0.25 | 0.1–2.0 | Multiplier applied to ATR to set stop distance beyond the sweep extreme |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major forex pair with deep liquidity; sweep patterns well-defined on M15
- `GBPUSD.DWX` — high-volatility major; frequent intraday liquidity grabs
- `XAUUSD.DWX` — gold; intraday sweep-and-reverse patterns driven by stop-hunt behaviour

**Explicitly NOT for:**
- Index CFDs (NDX, WS30, SP500) — card targets forex/gold; indices have different spread and session structure

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | `1–8 hours (1–32 M15 bars)` |
| Expected drawdown profile | `Short-lived mean-reversion drawdowns; exits on MA cross` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** `forum`
**Pointer:** `https://www.mql5.com/en/articles/18379` (Christian Benjamin, MQL5 Articles Part 20, 2025-06-11)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9199_mql5-liq-ma-sweep.md`

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
| v1 | 2026-06-10 | Initial build from card | 022e019c-bbe0-4ce0-bb23-1da08613038b |
