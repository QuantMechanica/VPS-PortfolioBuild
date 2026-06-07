# QM5_11185_ft-rsi-hammer — Strategy Spec

**EA ID:** QM5_11185
**Slug:** `ft-rsi-hammer`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades long-only M5 oversold reversals. On each newly closed M5 bar it requires RSI(14) below 30, Stochastic slow %K below 20, close below the lower Bollinger Band built on typical price with period 20 and 2 standard deviations, and a hammer candle shape. It enters at the next bar's market price, uses a 2.0 x ATR(14) stop, closes on the source ROI ladder when profit thresholds are reached, and otherwise exits when reconstructed Parabolic SAR is above the closed-bar close while inverse Fisher RSI is above 0.3.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 14 | 2-100 | RSI lookback for entry and inverse Fisher exit. |
| `strategy_rsi_entry` | 30.0 | 1-50 | Maximum RSI value allowed for a long entry. |
| `strategy_stoch_k` | 5 | 1-100 | Stochastic %K lookback. |
| `strategy_stoch_d` | 3 | 1-100 | Stochastic %D lookback. |
| `strategy_stoch_slowing` | 3 | 1-100 | Stochastic slowing value. |
| `strategy_stoch_k_entry` | 20.0 | 1-50 | Maximum slow %K value allowed for a long entry. |
| `strategy_bb_period` | 20 | 2-200 | Bollinger Band lookback on typical price. |
| `strategy_bb_deviation` | 2.0 | 0.1-5.0 | Bollinger Band standard deviation multiplier. |
| `strategy_atr_period` | 14 | 2-100 | ATR lookback for the MT5 baseline stop and filters. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | ATR multiple used by `QM_StopATR` for the stop loss. |
| `strategy_max_spread_stop_pct` | 8.0 | 0-100 | Maximum spread as percent of planned ATR stop distance. |
| `strategy_min_atr_points` | 1.0 | 0-10000 | Minimum M5 ATR in points before entry evaluation is allowed. |
| `strategy_roi_0_pct` | 5.0 | 0-100 | Source ROI threshold before 20 minutes. |
| `strategy_roi_20_pct` | 4.0 | 0-100 | Source ROI threshold after 20 minutes. |
| `strategy_roi_30_pct` | 3.0 | 0-100 | Source ROI threshold after 30 minutes. |
| `strategy_roi_60_pct` | 1.0 | 0-100 | Source ROI threshold after 60 minutes. |
| `strategy_fisher_exit` | 0.30 | -1.0-1.0 | Inverse Fisher RSI threshold for the SAR exit. |
| `strategy_exit_profit_only` | false | true/false | Optional guard requiring profit before the SAR/Fisher exit. |
| `strategy_psar_step` | 0.02 | 0.001-1.0 | Parabolic SAR acceleration step. |
| `strategy_psar_maximum` | 0.20 | 0.001-1.0 | Parabolic SAR maximum acceleration. |
| `strategy_psar_warmup_bars` | 120 | 30-1000 | Closed-bar warmup length for SAR reconstruction. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major in the card's P2 portable basket.
- `GBPUSD.DWX` — liquid FX major in the card's P2 portable basket.
- `USDJPY.DWX` — liquid FX major in the card's P2 portable basket.
- `XAUUSD.DWX` — liquid metal CFD in the card's P2 portable basket.

**Explicitly NOT for:**
- `SP500.DWX` — not part of the card's FX/metals R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Minutes to hours, governed by the 20/30/60 minute ROI ladder and SAR/Fisher exit. |
| Expected drawdown profile | Mean-reversion drawdowns during persistent selloffs before hammer reversals resolve. |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy
**Pointer:** Gerald Lonlas, `Strategy002.py`, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Strategy002.py
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11185_ft-rsi-hammer.md`

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
| v1 | 2026-06-07 | Initial build from card | 339914a8-e827-4791-8223-cae9f7a20aed |
