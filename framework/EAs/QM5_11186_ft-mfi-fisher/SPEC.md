# QM5_11186_ft-mfi-fisher - Strategy Spec

**EA ID:** QM5_11186
**Slug:** ft-mfi-fisher
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades long M5 oversold reversals. A signal requires RSI(14) below the entry threshold, Fisher RSI below the entry threshold, MFI below the entry threshold, close below SMA40, an EMA50-over-EMA100 trend gate or EMA5-over-EMA10 cross, and fast stochastic D above fast stochastic K. It enters long on the next bar open through a market order with an ATR(14) 2.0x stop. It exits through the source ROI ladder or when Parabolic SAR is above the closed-bar close and Fisher RSI is above the exit threshold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_rsi_period | 14 | fixed | RSI period used for RSI and Fisher RSI. |
| strategy_rsi_entry | 28.0 | 20-32 | Maximum RSI for long entry. |
| strategy_fisher_entry | -0.94 | -0.98--0.90 | Maximum Fisher RSI for long entry. |
| strategy_fisher_exit | 0.30 | 0.10-0.50 | Minimum Fisher RSI for source signal exit. |
| strategy_mfi_period | 14 | fixed | MFI period using DWX tick volume. |
| strategy_mfi_entry | 16.0 | 10.0-22.0 | Maximum MFI for long entry. |
| strategy_sma_period | 40 | 30-50 | SMA close filter; closed close must be below it. |
| strategy_ema_fast_period | 5 | fixed | Fast EMA for cross gate. |
| strategy_ema_signal_period | 10 | fixed | Slow EMA for cross gate. |
| strategy_ema_trend_fast | 50 | fixed | Fast trend EMA. |
| strategy_ema_trend_slow | 100 | fixed | Slow trend EMA and warmup anchor. |
| strategy_stoch_k_period | 5 | fixed | Fast stochastic K period. |
| strategy_stoch_d_period | 3 | fixed | Fast stochastic D period. |
| strategy_stoch_slowing | 1 | fixed | Fast stochastic smoothing. |
| strategy_bb_period | 20 | fixed | Bollinger warmup period from source indicator set. |
| strategy_bb_deviation | 2.0 | fixed | Bollinger warmup deviation from source indicator set. |
| strategy_atr_period | 14 | fixed | ATR period for MT5 baseline stop. |
| strategy_atr_sl_mult | 2.0 | fixed | ATR stop multiplier. |
| strategy_roi_0_min_pct | 5.0 | fixed | ROI close threshold before 20 minutes. |
| strategy_roi_20_min_pct | 4.0 | fixed | ROI close threshold after 20 minutes. |
| strategy_roi_30_min_pct | 3.0 | fixed | ROI close threshold after 30 minutes. |
| strategy_roi_60_min_pct | 1.0 | fixed | ROI close threshold after 60 minutes. |
| strategy_sar_step | 0.02 | fixed | Parabolic SAR acceleration step. |
| strategy_sar_max | 0.20 | fixed | Parabolic SAR max acceleration. |
| strategy_sar_lookback | 120 | fixed | Closed-bar lookback used to initialize bounded SAR state. |
| strategy_max_spread_stop_pct | 8.0 | fixed | Maximum spread as percent of planned ATR stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid DWX FX major matching the card's portable FX basket.
- GBPUSD.DWX - liquid DWX FX major matching the card's portable FX basket.
- USDJPY.DWX - liquid DWX FX major matching the card's portable FX basket.
- XAUUSD.DWX - liquid DWX metal symbol matching the card's FX/metals basket.

**Explicitly NOT for:**
- Crypto symbols - the source was crypto, but the approved card ports the method to DWX FX/metals only.
- Non-DWX symbols - research and backtest artifacts must keep the `.DWX` suffix.

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
| Trades / year / symbol | 50 |
| Typical hold time | README sample average duration 227.5 minutes; source ROI ladder starts at 20, 30, and 60 minutes. |
| Expected drawdown profile | medium risk from sparse oversold reversal entries with 10% source stop converted to ATR stop. |
| Regime preference | mean-revert oversold reversal with EMA trend support. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy
**Pointer:** Gerald Lonlas, Strategy003.py, freqtrade-strategies, `user_data/strategies/Strategy003.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11186_ft-mfi-fisher.md`

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
| v1 | 2026-06-07 | Initial build from card | e8d6b646-8d50-48ec-ad0f-f27fe95ef03d |
