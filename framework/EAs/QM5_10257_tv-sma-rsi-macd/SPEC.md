# QM5_10257_tv-sma-rsi-macd — Strategy Spec

**EA ID:** QM5_10257
**Slug:** tv-sma-rsi-macd
**Source:** c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades the TradingView SMA-RSI-MACD scalper on M5 bars. A long setup requires price above EMA(200), SMA(5) above SMA(8) above SMA(13), RSI(4) crossing back above 30, and a bullish MACD crossover or bullish histogram turn within the last three bars. A short setup mirrors the rule below EMA(200), with the SMA ribbon stacked downward, RSI(4) crossing back below 70, and a bearish MACD crossover or bearish histogram turn. Positions use a 1.5 ATR(14) stop and a fixed 2R take-profit; there is no baseline discretionary close beyond SL, TP, and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_period | 200 | >0 | Trend baseline EMA period. |
| strategy_sma_fast_period | 5 | >0 | Fast SMA ribbon period. |
| strategy_sma_mid_period | 8 | >0 | Middle SMA ribbon period. |
| strategy_sma_slow_period | 13 | >0 | Slow SMA ribbon period. |
| strategy_rsi_period | 4 | >0 | RSI pullback period. |
| strategy_rsi_oversold | 30.0 | 0-100 | Long pullback recovery threshold. |
| strategy_rsi_overbought | 70.0 | 0-100 | Short pullback recovery threshold. |
| strategy_macd_fast | 12 | >0 | MACD fast EMA period. |
| strategy_macd_slow | 26 | > strategy_macd_fast | MACD slow EMA period. |
| strategy_macd_signal | 9 | >0 | MACD signal period. |
| strategy_macd_lookback | 3 | 1-3 baseline | Bars allowed since MACD crossover or turn. |
| strategy_atr_period | 14 | >0 | ATR period for stop distance. |
| strategy_atr_sl_mult | 1.5 | >0 | ATR multiple for stop loss. |
| strategy_take_profit_rr | 2.0 | >0 | Fixed reward:risk take-profit multiple. |
| strategy_session_enabled | true | true/false | Enables the liquid-hours entry filter. |
| strategy_session_start_h | 7 | 0-23 | Broker-hour session start. |
| strategy_session_end_h | 18 | 0-23 | Broker-hour session end. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX — primary FX symbol named in the approved card.
- GBPUSD.DWX — major FX pair named as a best DWX port.
- XAUUSD.DWX — liquid gold CFD named as a best DWX port.
- GDAXI.DWX — canonical DWX German index port for the card's GER40 target.
- NDX.DWX — liquid US index CFD named as a best DWX port.

**Explicitly NOT for:**
- Any unregistered symbol — magic resolution is only reserved for the five symbols above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday scalps, minutes to hours |
| Expected drawdown profile | Bounded by one-position ATR stop and framework fixed-risk sizing |
| Regime preference | Momentum pullback in liquid intraday sessions |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c84ae47e-8ea0-56f1-8b25-4436b6dda5b5
**Source type:** TradingView Pine script
**Pointer:** https://www.tradingview.com/script/DWzDv6Do-Scalper-SMA-RSI-MACD-Entry-Exit-Signals-v2/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10257_tv-sma-rsi-macd.md`

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
| v1 | 2026-06-09 | Initial build from card | 098564ed-8503-4c31-a447-427545a18301 |
