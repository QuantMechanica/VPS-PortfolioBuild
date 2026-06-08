# QM5_11269_qt-rsi-hs - Strategy Spec

**EA ID:** QM5_11269
**Slug:** qt-rsi-hs
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA computes RSI on the active chart timeframe and searches a 25-bar horizon for the source script's head-and-shoulders node sequence in the RSI series. It enters short when the current RSI acts as the bottom, a prior head is more than `head * delta` above that bottom, the two bottom nodes are within `delta`, and matching shoulder nodes are more than `shoulder * delta` above the bottom but below the head. The latest closed-bar close must not be a new 25-bar closing high. The short exits when closed-bar RSI has risen more than 4 points above the entry RSI or after 5 bars, with the framework also enforcing Friday close and news blackout.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rsi_period | 14 | 1+ | RSI period used for the pattern and RSI exit. |
| strategy_pattern_horizon | 25 | 8-60 | Closed-bar lookback window for the RSI head-and-shoulders search. |
| strategy_delta_rsi | 0.2 | >0 | Maximum RSI-point distance for shoulder equality and neckline-bottom proximity. |
| strategy_head_ratio | 1.1 | >1.0 | Multiplier applied to delta for the required head-vs-bottom RSI distance. |
| strategy_shoulder_ratio | 1.1 | >1.0 | Multiplier applied to delta for shoulder-vs-bottom and head-vs-shoulder RSI distances. |
| strategy_atr_period | 14 | 1+ | ATR period for the hard stop. |
| strategy_atr_sl_mult | 2.0 | >0 | ATR multiple for the default short stop. |
| strategy_head_atr_buffer | 0.25 | >=0 | Extra ATR buffer above the detected pattern head high for the optional protective stop. |
| strategy_exit_rsi_change | 4.0 | >0 | Close the short when RSI minus entry RSI exceeds this value. |
| strategy_exit_bars | 5 | 1+ | Time stop in chart bars if the RSI exit has not fired. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed FX major with DWX OHLC and RSI data.
- GBPUSD.DWX - card-listed FX major with DWX OHLC and RSI data.
- XAUUSD.DWX - card-listed gold symbol with DWX OHLC and RSI data.
- NDX.DWX - card-listed US index exposure with DWX OHLC and RSI data.
- GDAXI.DWX - DWX matrix DAX equivalent for the card's GER40.DWX target.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to GDAXI.DWX.

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
| Trades / year / symbol | 12 |
| Typical hold time | 5 bars |
| Expected drawdown profile | Medium-high risk because the source thresholds are sparse and hard-coded. |
| Regime preference | mean-reversion / oscillator reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository script
**Pointer:** je-suis-tm, quant-trading RSI Pattern Recognition backtest.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11269_qt-rsi-hs.md`

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
| v1 | 2026-06-08 | Initial build from card | 14c53408-7cc7-4a89-9912-4d1242406c28 |
