# QM5_9207_mql5-mom-trend — Strategy Spec

**EA ID:** QM5_9207
**Slug:** `mql5-mom-trend`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each closed H1 bar, the EA reads Momentum(14), EMA(100), and ATR(14). A long entry fires when the last closed bar's price is above EMA(100) and Momentum crosses upward through 100 (bar N-1 had Momentum ≤ 100, bar N has Momentum > 100), provided the close is not within 0.25 × ATR of the EMA (sideways filter). The short entry is the mirror: price below EMA(100) and Momentum crosses downward through 100. Stop loss is placed at ATR(14) × 1.8 from entry; take profit is 2.2 × the SL distance. A signal exit closes the trade when Momentum reverses back through 100 or price crosses back through EMA(100). A failsafe time exit closes after 48 H1 bars regardless.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_momentum_period` | 14 | 5–50 | Momentum indicator lookback in bars |
| `strategy_ema_period` | 100 | 20–200 | EMA period for trend direction filter |
| `strategy_atr_period` | 14 | 5–30 | ATR period for stop and sideways filter |
| `strategy_sl_atr_mult` | 1.8 | 1.0–4.0 | Stop loss distance = ATR × this multiple |
| `strategy_tp_r_mult` | 2.2 | 1.0–5.0 | Take profit = SL distance × this R multiple |
| `strategy_sideways_atr_frac` | 0.25 | 0.0–1.0 | Sideways threshold: skip entry if |close−EMA| < frac×ATR |
| `strategy_max_hold_bars` | 48 | 10–200 | Failsafe close after N H1 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major forex pair; liquid H1 trending behaviour matches the EMA/Momentum framework
- `GBPUSD.DWX` — major forex pair; sufficient trend amplitude for ATR-based stops
- `NDX.DWX` — Nasdaq-100 index; directional trending instrument, wide ATR accommodates momentum signals

**Explicitly NOT for:**
- `SP500.DWX` — not registered; card targets EURUSD/GBPUSD/NDX specifically

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
| Trades / year / symbol | ~70 |
| Typical hold time | 4–48 hours (signal or time exit) |
| Expected drawdown profile | Medium; ATR-based stops with 2.2R target |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** forum
**Pointer:** Mohamed Abdelmaaboud, "Learn how to design a trading system by Momentum", MQL5 Articles, 2022-03-22
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9207_mql5-mom-trend.md`

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
| v1 | 2026-06-10 | Initial build from card | 0ffb8d36-696d-4eba-addf-b0a9448307e3 |
