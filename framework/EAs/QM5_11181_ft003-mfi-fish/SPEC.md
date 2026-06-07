# QM5_11181_ft003-mfi-fish - Strategy Spec

**EA ID:** QM5_11181
**Slug:** `ft003-mfi-fish`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

This EA trades long-only M5 oversold reversals. It enters when RSI(14) is below 28, close is below SMA(40), Fisher-transformed RSI is below -0.94, MFI(14) is below 16, stochastic fastD is above fastK, and either EMA(50) is above EMA(100) or EMA(5) has crossed above EMA(10). It exits with the source ROI ladder, with a strategy close when Parabolic SAR is above the closed-bar close and Fisher RSI is above 0.30. The source -10% stop is preserved as the initial stop so the V5 risk model can size the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 14 | 2-100 | RSI lookback used for entry and Fisher RSI. |
| `strategy_rsi_entry` | 28.0 | 20-32 | Maximum RSI value for long entry. |
| `strategy_fisher_entry` | -0.94 | -0.98--0.85 | Maximum Fisher RSI value for long entry. |
| `strategy_fisher_exit` | 0.30 | 0.0-1.0 | Minimum Fisher RSI value for SAR/Fisher exit. |
| `strategy_mfi_period` | 14 | 2-100 | MFI lookback using DWX tick volume. |
| `strategy_mfi_entry` | 16.0 | 10-25 | Maximum MFI value for long entry. |
| `strategy_sma_period` | 40 | 30-60 | SMA filter; close must be below it. |
| `strategy_ema_fast` | 5 | 2-50 | Fast EMA for short cross confirmation. |
| `strategy_ema_slow` | 10 | 3-80 | Slow EMA for short cross confirmation. |
| `strategy_ema_trend_fast` | 50 | 30-75 | Fast EMA for trend confirmation. |
| `strategy_ema_trend_slow` | 100 | 75-150 | Slow EMA for trend confirmation. |
| `strategy_stoch_k` | 5 | 2-50 | Stochastic fastK period. |
| `strategy_stoch_d` | 3 | 1-20 | Stochastic fastD period. |
| `strategy_stoch_slowing` | 3 | 1-20 | Stochastic slowing value. |
| `strategy_stoploss_pct` | 10.0 | 1-20 | Source stoploss percentage below entry. |
| `strategy_roi_0_pct` | 5.0 | 0-10 | Profit target from entry until 20 minutes. |
| `strategy_roi_20_pct` | 4.0 | 0-10 | Profit target after 20 minutes. |
| `strategy_roi_30_pct` | 3.0 | 0-10 | Profit target after 30 minutes. |
| `strategy_roi_60_pct` | 1.0 | 0-10 | Profit target after 60 minutes. |
| `strategy_exit_profit_only` | true | true/false | Require SAR/Fisher exit to be profitable, matching the source exit behaviour. |
| `strategy_psar_step` | 0.02 | 0.001-0.20 | Parabolic SAR acceleration step. |
| `strategy_psar_maximum` | 0.20 | 0.01-1.00 | Parabolic SAR maximum acceleration. |
| `strategy_psar_warmup_bars` | 120 | 20-300 | Closed bars used for bounded SAR reconstruction. |
| `strategy_atr_period` | 14 | 2-100 | ATR lookback for spread guard. |
| `strategy_max_spread_atr_pct` | 15.0 | 0-100 | Maximum allowed spread as a percentage of ATR. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary liquid FX symbol from the approved P2 basket.
- `GBPUSD.DWX` - liquid major FX pair from the approved P2 basket.
- `USDJPY.DWX` - liquid major FX pair from the approved P2 basket.
- `XAUUSD.DWX` - liquid metals symbol from the approved P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - they are not valid DWX backtest targets.
- Symbols with missing tick volume - MFI depends on usable DWX tick volume.

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
| Trades / year / symbol | 55 |
| Typical hold time | 227.5 minutes from source README sample |
| Expected drawdown profile | Medium risk due to scalping frequency and source -10% stop. |
| Regime preference | Trend-filtered mean reversion after deep oscillator oversold states. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy repository
**Pointer:** Gerald Lonlas / freqtrade community, `Strategy003.py`, commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Strategy003.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11181_ft003-mfi-fish.md`

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
| v1 | 2026-06-07 | Initial build from card | 76b2eefa-3dba-45a3-9127-b77ea68c1b0b |
