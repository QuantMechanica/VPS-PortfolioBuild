# QM5_11821_carter-m5-s10-ema4080-cci21-m5 - Strategy Spec

**EA ID:** QM5_11821
**Slug:** carter-m5-s10-ema4080-cci21-m5
**Source:** f4430cee-7efb-592e-bf0f-e469ef156b2d (see `sources/20-forex-trading-strategies-5min-carter-367145560`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades on M5 bars. A long entry is opened when EMA(40) is above EMA(80) and CCI(21) crosses upward through zero on the last closed bar. A short entry is opened when EMA(40) is below EMA(80) and CCI(21) crosses downward through zero. Positions use the card factory defaults of a 12 pip stop loss and 12 pip take profit; there is no discretionary close beyond SL, TP, news, kill-switch, and Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_fast_period | 40 | 1-500 | Fast EMA period used for trend state. |
| strategy_ema_slow_period | 80 | 1-500 | Slow EMA period used for trend state. |
| strategy_cci_period | 21 | 1-500 | CCI lookback used for zero-line cross trigger. |
| strategy_sl_pips | 12 | 1-500 | Fixed stop loss in pips; card states 10-15 and factory uses 12. |
| strategy_tp_pips | 12 | 1-500 | Fixed take profit in pips for 1:1 risk-reward. |
| strategy_spread_cap_pips | 5.0 | 0.0-100.0 | Maximum quoted spread in pips before the EA skips new entries. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Major forex pair named in the approved card and present in the DWX matrix.
- GBPUSD.DWX - Major forex pair named in the approved card and present in the DWX matrix.
- USDJPY.DWX - Major forex pair named in the approved card and present in the DWX matrix.
- USDCHF.DWX - Major forex pair named in the approved card and present in the DWX matrix.
- AUDUSD.DWX - Major forex pair named in the approved card and present in the DWX matrix.

**Explicitly NOT for:**
- Non-forex `.DWX` symbols - The card targets a five-pair FX M5 basket only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | minutes to hours |
| Expected drawdown profile | Fixed 12 pip risk per trade with frequent M5 trend-following entries. |
| Regime preference | trend-following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** f4430cee-7efb-592e-bf0f-e469ef156b2d
**Source type:** retail PDF / strategy document
**Pointer:** `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`, Strategy 10
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11821_carter-m5-s10-ema4080-cci21-m5.md`

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
| v1 | 2026-06-25 | Initial build from card | 88895838-3505-408a-86e0-e5616e324df7 |
