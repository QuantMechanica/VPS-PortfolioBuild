# QM5_10298_cinar-force - Strategy Spec

**EA ID:** QM5_10298
**Slug:** cinar-force
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA computes Force Index on closed D1 bars as EMA(13) of `(CurrentClose - PreviousClose) * tick volume`. It opens long when Force Index is above zero and opens short when Force Index is below zero. If an opposite position is already open, the EA closes it and opens the new direction on the same closed-bar signal. If Force Index is exactly zero, the EA holds and does not open or reverse.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_signal_tf | PERIOD_D1 | D1 for this card | Timeframe used for Force Index signals and ATR stop. |
| strategy_force_period | 13 | >= 2 | EMA period for the Force Index calculation. |
| strategy_atr_period | 14 | >= 1 | ATR period for the catastrophic stop required by the card. |
| strategy_atr_sl_mult | 2.0 | > 0.0 | Multiplier for the ATR stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- AUDCAD.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- AUDCHF.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- AUDJPY.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- AUDNZD.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- AUDUSD.DWX - DWX major with daily close and tick-volume history for Force Index.
- CADCHF.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- CADJPY.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- CHFJPY.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- EURAUD.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- EURCAD.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- EURCHF.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- EURGBP.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- EURJPY.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- EURNZD.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- EURUSD.DWX - DWX major with daily close and tick-volume history for Force Index.
- GBPAUD.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- GBPCAD.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- GBPCHF.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- GBPJPY.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- GBPNZD.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- GBPUSD.DWX - DWX major with daily close and tick-volume history for Force Index.
- GDAXI.DWX - Canonical DWX DAX symbol replacing the card's non-matrix DAX.DWX label.
- NDX.DWX - Card-listed DWX index with daily close and tick-volume history for Force Index.
- NZDCAD.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- NZDCHF.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- NZDJPY.DWX - DWX forex cross with daily close and tick-volume history for Force Index.
- NZDUSD.DWX - DWX major with daily close and tick-volume history for Force Index.
- SP500.DWX - DWX S&P 500 custom symbol; valid for backtest, live gate handled downstream.
- UK100.DWX - DWX index with daily close and tick-volume history for Force Index.
- USDCAD.DWX - DWX major with daily close and tick-volume history for Force Index.
- USDCHF.DWX - DWX major with daily close and tick-volume history for Force Index.
- USDJPY.DWX - DWX major with daily close and tick-volume history for Force Index.
- WS30.DWX - Card-listed DWX index with daily close and tick-volume history for Force Index.
- XAGUSD.DWX - DWX metal with daily close and tick-volume history for Force Index.
- XAUUSD.DWX - Card-listed DWX metal with daily close and tick-volume history for Force Index.
- XNGUSD.DWX - DWX energy CFD with daily close and tick-volume history for Force Index.
- XTIUSD.DWX - DWX energy CFD with daily close and tick-volume history for Force Index.

**Explicitly NOT for:**
- DAX.DWX - Not present in `dwx_symbol_matrix.csv`; GDAXI.DWX is the canonical DAX registration target.
- SPX500.DWX, SPY.DWX, ES.DWX - Not present in `dwx_symbol_matrix.csv`; SP500.DWX is the only canonical S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Not specified in card frontmatter; stop-and-reverse implies multi-day holds. |
| Expected drawdown profile | Not specified in card frontmatter; catastrophic stop is 2.0 * ATR(14). |
| Regime preference | Momentum / volume-confirmed impulse regime. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/cinar/indicator/blob/master/strategy/volume/force_index_strategy.go and https://github.com/cinar/indicator/blob/master/volume/fi.go
**R1-R4 verdict (Q00):** all PASS per approved frontmatter / see `artifacts/cards_approved/QM5_10298_cinar-force.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-12 | Initial build from card | 14f3cdaa-baf6-46ce-a31d-cc3b91b5821d |
