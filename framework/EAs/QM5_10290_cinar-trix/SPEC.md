# QM5_10290_cinar-trix - Strategy Spec

**EA ID:** QM5_10290
**Slug:** cinar-trix
**Source:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA computes TRIX on the close of D1 bars using period 15. TRIX is the one-bar rate of change of a triple-smoothed EMA of close: EMA1(15), EMA2(15) of EMA1, EMA3(15) of EMA2, then `(EMA3 - previous EMA3) / previous EMA3`. It opens long when TRIX is above zero and opens short when TRIX is below zero. If an opposite position is already open, the EA closes it and opens the new direction on the same closed-bar signal; when TRIX is exactly zero it holds.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_trix_period | 15 | >= 2 | Period for each of the three EMA smoothing passes used by TRIX. |
| strategy_trix_warmup_bars | 160 | >= 47 | Closed-bar history used to warm up the triple EMA calculation. |
| strategy_atr_period | 14 | >= 1 | ATR period for the catastrophic stop required by the card. |
| strategy_atr_sl_mult | 2.0 | > 0.0 | Multiplier for the ATR stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- AUDCAD.DWX - DWX forex cross suitable for close-derived daily trend following.
- AUDCHF.DWX - DWX forex cross suitable for close-derived daily trend following.
- AUDJPY.DWX - DWX forex cross suitable for close-derived daily trend following.
- AUDNZD.DWX - DWX forex cross suitable for close-derived daily trend following.
- AUDUSD.DWX - DWX major suitable for close-derived daily trend following.
- CADCHF.DWX - DWX forex cross suitable for close-derived daily trend following.
- CADJPY.DWX - DWX forex cross suitable for close-derived daily trend following.
- CHFJPY.DWX - DWX forex cross suitable for close-derived daily trend following.
- EURAUD.DWX - DWX forex cross suitable for close-derived daily trend following.
- EURCAD.DWX - DWX forex cross suitable for close-derived daily trend following.
- EURCHF.DWX - DWX forex cross suitable for close-derived daily trend following.
- EURGBP.DWX - DWX forex cross suitable for close-derived daily trend following.
- EURJPY.DWX - DWX forex cross suitable for close-derived daily trend following.
- EURNZD.DWX - DWX forex cross suitable for close-derived daily trend following.
- EURUSD.DWX - DWX major suitable for close-derived daily trend following.
- GBPAUD.DWX - DWX forex cross suitable for close-derived daily trend following.
- GBPCAD.DWX - DWX forex cross suitable for close-derived daily trend following.
- GBPCHF.DWX - DWX forex cross suitable for close-derived daily trend following.
- GBPJPY.DWX - Card-listed DWX forex cross suitable for close-derived daily trend following.
- GBPNZD.DWX - DWX forex cross suitable for close-derived daily trend following.
- GBPUSD.DWX - DWX major suitable for close-derived daily trend following.
- GDAXI.DWX - Canonical DWX DAX symbol replacing the card's non-matrix DAX.DWX label.
- NDX.DWX - Card-listed DWX index suitable for close-derived daily trend following.
- NZDCAD.DWX - DWX forex cross suitable for close-derived daily trend following.
- NZDCHF.DWX - DWX forex cross suitable for close-derived daily trend following.
- NZDJPY.DWX - DWX forex cross suitable for close-derived daily trend following.
- NZDUSD.DWX - DWX major suitable for close-derived daily trend following.
- SP500.DWX - DWX S&P 500 custom symbol; valid for backtest, live gate handled downstream.
- UK100.DWX - DWX index suitable for close-derived daily trend following.
- USDCAD.DWX - DWX major suitable for close-derived daily trend following.
- USDCHF.DWX - DWX major suitable for close-derived daily trend following.
- USDJPY.DWX - DWX major suitable for close-derived daily trend following.
- WS30.DWX - Card-listed DWX index suitable for close-derived daily trend following.
- XAGUSD.DWX - DWX metal suitable for close-derived daily trend following.
- XAUUSD.DWX - Card-listed DWX metal suitable for close-derived daily trend following.
- XNGUSD.DWX - DWX energy CFD suitable for close-derived daily trend following.
- XTIUSD.DWX - DWX energy CFD suitable for close-derived daily trend following.

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
| Trades / year / symbol | 18 |
| Typical hold time | Not specified in card frontmatter; stop-and-reverse implies multi-day trend holds. |
| Expected drawdown profile | Not specified in card frontmatter; catastrophic stop is 2.0 * ATR(14). |
| Regime preference | Trend / momentum / zero-line-cross regime. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1b906e79-c619-5a61-90db-ee19ac95a19f
**Source type:** GitHub repository
**Pointer:** https://github.com/cinar/indicator/blob/master/strategy/trend/trix_strategy.go and https://github.com/cinar/indicator/blob/master/trend/trix.go
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10290_cinar-trix.md`

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
| v1 | 2026-06-12 | Initial build from card | d1bca6c3-aec0-4e81-a213-e9592ae87278 |
