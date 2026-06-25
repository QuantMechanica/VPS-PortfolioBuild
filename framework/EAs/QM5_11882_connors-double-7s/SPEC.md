# QM5_11882_connors-double-7s - Strategy Spec

**EA ID:** QM5_11882
**Slug:** `connors-double-7s`
**Source:** `2f18abf6-a4aa-5974-8299-aa2d8913fa7d` (see local PDF archive)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades the Connors Double 7's mean-reversion rule on D1 bars. It buys when the last closed D1 close is above SMA(200) and is the lowest close of the last 7 closed sessions. It sells when the last closed D1 close is below SMA(200) and is the highest close of the last 7 closed sessions. Long positions exit when the close becomes the highest close of the last 7 sessions; short positions exit when the close becomes the lowest close of the last 7 sessions, with an ATR stop and 14-bar time stop as protection.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback` | 7 | >= 2 | Number of closed D1 closes used for entry and opposite-extreme exit. |
| `strategy_regime_sma_period` | 200 | >= 2 | SMA period used to define long or short regime on the last closed bar. |
| `strategy_sl_atr_mult` | 2.0 | > 0 | ATR multiple used for the initial protective stop. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used for the protective stop calculation. |
| `strategy_max_holding_bars` | 14 | >= 0 | Maximum D1 bars to hold a position before strategy exit; 0 disables the time stop. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major available in the DWX matrix and listed by the card.
- `GBPUSD.DWX` - FX major available in the DWX matrix and listed by the card.
- `USDJPY.DWX` - FX major available in the DWX matrix and listed by the card.
- `USDCAD.DWX` - FX major available in the DWX matrix and listed by the card.
- `USDCHF.DWX` - FX major available in the DWX matrix and listed by the card.
- `AUDUSD.DWX` - FX major available in the DWX matrix and listed by the card.
- `NZDUSD.DWX` - FX major available in the DWX matrix and listed by the card.
- `EURJPY.DWX` - FX cross available in the DWX matrix and listed by the card.
- `GBPJPY.DWX` - FX cross available in the DWX matrix and listed by the card.
- `NDX.DWX` - US large-cap index CFD available in the DWX matrix and listed by the card.
- `WS30.DWX` - US large-cap index CFD available in the DWX matrix and listed by the card.
- `SP500.DWX` - S&P 500 custom DWX symbol available for backtest and listed by the card.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not registered for this EA and not guaranteed to have DWX backtest data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via skeleton OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | Up to 14 D1 bars |
| Expected drawdown profile | Mean-reversion drawdowns during persistent directional trends. |
| Regime preference | Mean-reversion within SMA(200)-defined direction. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2f18abf6-a4aa-5974-8299-aa2d8913fa7d`
**Source type:** book
**Pointer:** Connors, L. & Alvarez, C. (2009), Short Term Trading Strategies That Work - A Quantified Guide to Trading Stocks and ETFs; local PDF archive.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11882_connors-double-7s.md`

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
| v1 | 2026-06-25 | Initial build from card | d1670117-b88f-4d3e-b37a-61bb79023f98 |
