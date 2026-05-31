# QM5_10771_tv-trail-hunter - Strategy Spec

**EA ID:** QM5_10771
**Slug:** tv-trail-hunter
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

This EA is a long-only mean-reversion strategy on H1. It enters when SMA(24) crosses below SMA(31) and CCI(11) crosses below -80 within the configured keep-alive window. It uses one entry per signal cycle and does not add to positions. The position has a hard stop below entry and a trailing full-position exit that activates after the configured profit threshold, then closes when price falls by the configured trailing deviation from the post-activation high.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fast_sma_period | 24 | 18-31 tested | Fast SMA period for the cross-under signal. |
| strategy_slow_sma_period | 31 | 31-50 tested | Slow SMA period for the cross-under signal. |
| strategy_cci_period | 11 | 11-20 tested | CCI lookback for exhaustion signal. |
| strategy_cci_oversold | -80.0 | -100 to -70 tested | CCI threshold that must be crossed downward. |
| strategy_keep_alive_bars | 3 | 1-5 tested | Number of closed bars where the two entry signals may combine. |
| strategy_use_atr_equivalent | false | false or true | Uses percent distances when false and ATR-normalized distances when true. |
| strategy_atr_period | 14 | 10-30 expected | ATR period used only for ATR-equivalent stops and trailing distances. |
| strategy_stop_loss_pct | 3.25 | 2.0-5.0 tested | Hard stop distance below entry in percent mode. |
| strategy_stop_atr_mult | 3.0 | 1.0-6.0 expected | Hard stop ATR multiple in ATR-equivalent mode. |
| strategy_trail_activation_pct | 1.50 | 1.0-2.0 tested | Profit threshold that activates trailing in percent mode. |
| strategy_trail_activation_atr | 1.5 | 0.5-3.0 expected | Profit threshold ATR multiple in ATR-equivalent mode. |
| strategy_trail_deviation_pct | 0.15 | 0.05-0.30 tested | Price fallback from post-activation high that closes the trade in percent mode. |
| strategy_trail_deviation_atr | 0.5 | 0.1-2.0 expected | Price fallback ATR multiple in ATR-equivalent mode. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card-listed FX major with DWX history.
- GBPUSD.DWX - Card-listed FX major with DWX history.
- USDJPY.DWX - Card-listed FX major with DWX history.
- XAUUSD.DWX - Canonical DWX metal symbol for the card's XAUUSD target.
- GDAXI.DWX - Canonical matrix DAX symbol used for the card's GER40.DWX target.
- NDX.DWX - Card-listed US index CFD with DWX history.
- WS30.DWX - Card-listed US index CFD with DWX history.

**Explicitly NOT for:**
- GER40.DWX - Not present in the DWX symbol matrix; use GDAXI.DWX.
- XAUUSD - Missing the required DWX suffix for backtest registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Typical hold time | Hours to days, depending on trailing activation and rebound persistence. |
| Expected drawdown profile | Long-only mean reversion can draw down during persistent downtrends. |
| Regime preference | Mean-reversion after downside exhaustion. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/d117dN6D-3Commas-Trail-Hunter-Reversal-Long/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10771_tv-trail-hunter.md`

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
| v1 | 2026-05-31 | Initial build from card | b4e5d919-e36a-4327-98a0-62528ef74f53 |
