# QM5_11203_ft-bbrsi - Strategy Spec

**EA ID:** QM5_11203
**Slug:** ft-bbrsi
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long-only H1 mean reversion. On each closed H1 bar it computes RSI(14) and Bollinger Bands using a 20-bar typical-price basis with 2.0 standard deviations. It opens a long when RSI is below 30 and the closed-bar close is below the lower Bollinger Band. The position exits through a fixed 10% ROI target, an ATR(14) stop at 2.0 times ATR, RSI above 70, or the V5 Friday-close guard.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 10-20 | RSI lookback for entry and exit. |
| `strategy_rsi_entry` | 30.0 | 20-30 | Long entry threshold; RSI must be below this value. |
| `strategy_rsi_exit` | 70.0 | 60-80 | Strategy close threshold; RSI must be above this value. |
| `strategy_bb_period` | 20 | 14-30 | Bollinger Band lookback. |
| `strategy_bb_stdev` | 2.0 | 1.8-2.4 | Bollinger Band standard-deviation multiplier. |
| `strategy_atr_stop_period` | 14 | 14 | ATR lookback for the baseline stop. |
| `strategy_atr_stop_mult` | 2.0 | 1.5-2.5 | ATR multiple for stop placement. |
| `strategy_roi_pct` | 10.0 | 10.0 | Fixed ROI take-profit percentage from the source strategy. |
| `strategy_max_spread_stop_frac` | 0.08 | 0.00-0.08 | Maximum spread as a fraction of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair in the card's P2 basket.
- `GBPUSD.DWX` - liquid major FX pair in the card's P2 basket.
- `XAUUSD.DWX` - liquid metal CFD in the card's P2 basket.
- `GDAXI.DWX` - available DWX DAX custom symbol used as the matrix-valid port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated DAX label, but absent from `dwx_symbol_matrix.csv`; `GDAXI.DWX` is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `55` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | `medium risk, driven by mean-reversion stopouts during persistent trends` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/BbandRsi.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11203_ft-bbrsi.md`

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
| v1 | 2026-06-08 | Initial build from card | ac342c80-e699-411f-92e8-66069600f068 |
