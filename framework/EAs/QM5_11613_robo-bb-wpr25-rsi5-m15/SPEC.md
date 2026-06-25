# QM5_11613_robo-bb-wpr25-rsi5-m15 - Strategy Spec

**EA ID:** QM5_11613
**Slug:** robo-bb-wpr25-rsi5-m15
**Source:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d (RoboForex Educational Team, "Forex Strategy Collection", strategy "The right moment", pages 30-33)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades the M15 RoboForex "The right moment" mean-reversion setup. A long entry opens when the last closed bar touches or breaks the lower Bollinger Band(20, 2.0), RSI(5) crosses below 30, and WPR(25) is below -80. A short entry opens when the last closed bar touches or breaks the upper Bollinger Band(20, 2.0), RSI(5) crosses above 70, and WPR(25) is above -20. Each entry uses a 2 x ATR(14) protective stop and targets the current Bollinger middle band, with a 4 x ATR(14) fallback target if the middle band is not directionally valid at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_tf | PERIOD_M15 | M15 baseline | Signal timeframe for BB, WPR, RSI, ATR, and closed-bar OHLC checks. |
| strategy_bb_period | 20 | >=2 | Bollinger Band moving-average period. |
| strategy_bb_deviation | 2.0 | >0 | Bollinger Band standard-deviation multiplier. |
| strategy_wpr_period | 25 | >=2 | Williams Percent Range lookback period. |
| strategy_wpr_oversold | -80.0 | -100 to 0 | Long confirmation threshold for WPR. |
| strategy_wpr_overbought | -20.0 | -100 to 0 | Short confirmation threshold for WPR. |
| strategy_rsi_period | 5 | >=2 | RSI lookback period. |
| strategy_rsi_oversold | 30.0 | 0 to 100 | Long trigger threshold for RSI cross below. |
| strategy_rsi_overbought | 70.0 | 0 to 100 | Short trigger threshold for RSI cross above. |
| strategy_atr_period | 14 | >=1 | ATR lookback for stop and fallback target distance. |
| strategy_atr_sl_mult | 2.0 | >0 | Stop-loss distance in ATR multiples. |
| strategy_atr_fallback_tp_mult | 4.0 | >0 | Fallback take-profit distance in ATR multiples when BB middle is not directionally valid. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card target; liquid major FX pair with DWX M15 history for BB, WPR, RSI, and ATR.
- GBPUSD.DWX - card target; liquid major FX pair with DWX M15 history for BB, WPR, RSI, and ATR.

**Explicitly NOT for:**
- Non-DWX symbols - V5 research and backtest artifacts must use broker/custom-symbol `.DWX` names.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX data source for the P2 baseline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) through the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Card does not specify; expected to be intraday mean-reversion holds until BB middle, ATR target, SL, or Friday close. |
| Expected drawdown profile | Card does not specify; bounded per trade by 2 x ATR(14) stop and framework risk sizing. |
| Regime preference | Flat or sideways mean-reversion regime per card note. |
| Win rate target (qualitative) | Card does not specify. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Source type:** book / educational PDF
**Pointer:** RoboForex Educational Team, "Forex Strategy Collection" (~2015), pages 30-33; local source `362359657-Robo-forex-strategy.pdf`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11613_robo-bb-wpr25-rsi5-m15.md`

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
| v1 | 2026-06-26 | Initial build from card | a0787626-6326-4ff3-9a09-302f7e03ccf4 |
