# QM5_9217_mql5-dpo-ma - Strategy Spec

**EA ID:** QM5_9217
**Slug:** mql5-dpo-ma
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades an M15 moving-average recross validated by the Detrended Price Oscillator. A long entry is opened at the next bar when the prior closed bar was below SMA(20), the just-closed bar is above SMA(20), and DPO(20) is positive. A short entry mirrors the rule below the SMA with negative DPO. Exits occur when DPO crosses back through zero, price crosses back through SMA(20), or the position reaches the 48-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_dpo_period | 20 | 2-100 | Period used for the DPO displaced SMA calculation. |
| strategy_sma_period | 20 | 2-200 | SMA period used for entry and exit price crosses. |
| strategy_atr_period | 14 | 1-100 | ATR period used for initial stop distance. |
| strategy_atr_sl_mult | 1.4 | 0.1-10.0 | Initial stop distance in ATR multiples. |
| strategy_rr_tp | 2.0 | 0.1-10.0 | Initial take profit as an R multiple of stop distance. |
| strategy_max_hold_bars | 48 | 1-500 | Failsafe maximum holding period in M15 bars. |
| strategy_max_spread_points | 50 | 0-100000 | Optional spread ceiling in points; zero disables the strategy spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX major with complete DWX OHLC support.
- GBPUSD.DWX - card-listed liquid FX major with complete DWX OHLC support.
- NDX.DWX - card-listed liquid US index CFD with DWX OHLC support.

**Explicitly NOT for:**
- SPX500.DWX - not a canonical DWX matrix symbol; use only registered symbols for this EA.
- SPY.DWX - not a broker/custom symbol in the DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via the framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Up to 48 M15 bars, roughly 12 trading hours maximum |
| Expected drawdown profile | Moderate intraday drawdown from frequent fixed-risk momentum/cycle trades |
| Regime preference | Cycle-trading with momentum-cross validation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** https://www.mql5.com/en/articles/19547
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9217_mql5-dpo-ma.md`

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
| v1 | 2026-06-23 | Initial build from card | 23202a64-5cff-4484-b976-b6cfc9421ddd |
