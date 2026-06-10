# QM5_9296_mql5-cmf-obos — Strategy Spec

**EA ID:** QM5_9296
**Slug:** `mql5-cmf-obos`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each closed M15 bar, compute the 20-period Chaikin Money Flow using OHLC and tick volume. CMF measures buying/selling pressure: values below -0.20 signal extreme net selling (oversold), values above +0.20 signal extreme net buying (overbought). The EA fades these extremes: enter long when CMF crosses at or below -0.20, enter short when CMF crosses at or above +0.20. Each trade uses a fixed 300-point stop loss and 900-point take profit. An optional zero-cross exit closes longs when CMF returns above 0 and closes shorts when CMF falls back below 0, providing an early exit if the extreme pressure normalises before the TP is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cmf_period` | 20 | 5-50 | CMF lookback periods |
| `strategy_cmf_threshold` | 0.20 | 0.10-0.40 | Overbought/oversold CMF threshold |
| `strategy_sl_points` | 300 | 50-1000 | Stop loss distance in points |
| `strategy_tp_points` | 900 | 100-3000 | Take profit distance in points |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; sufficient tick volume for CMF; card primary target
- `GBPUSD.DWX` — liquid major FX pair; same rationale as EURUSD
- `XAUUSD.DWX` — high-volume commodity; CMF extremes on gold historically meaningful
- `GDAXI.DWX` — DAX 40 index; card specified GER40 (DAX 40 = GDAXI.DWX in DWX matrix); ported from card GER40 reference

**Explicitly NOT for:**
- `GER40.DWX` — not present in dwx_symbol_matrix.csv; ported to GDAXI.DWX

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~90 |
| Typical hold time | hours to a few days (M15 bars, TP/SL or zero-cross exit) |
| Expected drawdown profile | moderate; mean-reversion can face trend risk |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Mohamed Abdelmaaboud, "How to build and optimize a volume-based trading system (Chaikin Money Flow - CMF)", MQL5 Articles, 2024-12-17
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9296_mql5-cmf-obos.md`

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
| v1 | 2026-06-10 | Initial build from card | 6f2c5e03-947f-4be3-8380-67c62f1e5e1c |
