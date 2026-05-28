# QM5_10457_mql5-keltner — Strategy Spec

**EA ID:** QM5_10457
**Slug:** mql5-keltner
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see MQL5 CodeBase source note in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

This EA trades an M15 Keltner channel breakout with trend confirmation. A long entry is allowed when EMA(10) crosses above or closes above the upper Keltner band and the closed bar is above EMA(200). A short entry is allowed when EMA(10) crosses below or closes below the lower Keltner band and the closed bar is below EMA(200). The Keltner center is EMA(20), the band width is ATR(50) times 2.0, and exits are fixed initial SL/TP with SL at the wider of 1.5 ATR(50) or the current opposite channel band and TP at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_signal_ema_period | 10 | >=1 | EMA used for channel breakout signal. |
| strategy_center_ema_period | 20 | >=1 | EMA used as the Keltner channel center line. |
| strategy_trend_ema_period | 200 | >=1 | Trend filter; longs require price above this EMA and shorts below it. |
| strategy_atr_period | 50 | >=1 | ATR lookback used for Keltner width and stop distance. |
| strategy_keltner_mult | 2.0 | >0 | ATR multiplier for the upper and lower Keltner bands. |
| strategy_sl_atr_mult | 1.5 | >0 | Minimum stop distance as a multiple of ATR(50). |
| strategy_take_profit_rr | 2.0 | >0 | Take-profit distance in units of initial risk. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX — primary gold symbol named by the card and source strategy.
- AUDCAD.DWX — liquid FX cross in the DWX matrix for portability testing.
- AUDCHF.DWX — liquid FX cross in the DWX matrix for portability testing.
- AUDJPY.DWX — liquid FX cross in the DWX matrix for portability testing.
- AUDNZD.DWX — liquid FX cross in the DWX matrix for portability testing.
- AUDUSD.DWX — liquid FX major in the DWX matrix for portability testing.
- CADCHF.DWX — liquid FX cross in the DWX matrix for portability testing.
- CADJPY.DWX — liquid FX cross in the DWX matrix for portability testing.
- CHFJPY.DWX — liquid FX cross in the DWX matrix for portability testing.
- EURAUD.DWX — liquid FX cross in the DWX matrix for portability testing.
- EURCAD.DWX — liquid FX cross in the DWX matrix for portability testing.
- EURCHF.DWX — liquid FX cross in the DWX matrix for portability testing.
- EURGBP.DWX — liquid FX cross in the DWX matrix for portability testing.
- EURJPY.DWX — liquid FX cross in the DWX matrix for portability testing.
- EURNZD.DWX — liquid FX cross in the DWX matrix for portability testing.
- EURUSD.DWX — liquid FX major in the DWX matrix for portability testing.
- GBPAUD.DWX — liquid FX cross in the DWX matrix for portability testing.
- GBPCAD.DWX — liquid FX cross in the DWX matrix for portability testing.
- GBPCHF.DWX — liquid FX cross in the DWX matrix for portability testing.
- GBPJPY.DWX — liquid FX cross in the DWX matrix for portability testing.
- GBPNZD.DWX — liquid FX cross in the DWX matrix for portability testing.
- GBPUSD.DWX — liquid FX major in the DWX matrix for portability testing.
- GDAXI.DWX — liquid index CFD in the DWX matrix for portability testing.
- NDX.DWX — liquid index CFD in the DWX matrix for portability testing.
- NZDCAD.DWX — liquid FX cross in the DWX matrix for portability testing.
- NZDCHF.DWX — liquid FX cross in the DWX matrix for portability testing.
- NZDJPY.DWX — liquid FX cross in the DWX matrix for portability testing.
- NZDUSD.DWX — liquid FX major in the DWX matrix for portability testing.
- SP500.DWX — liquid index custom symbol in the DWX matrix for backtest-only portability testing.
- UK100.DWX — liquid index CFD in the DWX matrix for portability testing.
- USDCAD.DWX — liquid FX major in the DWX matrix for portability testing.
- USDCHF.DWX — liquid FX major in the DWX matrix for portability testing.
- USDJPY.DWX — liquid FX major in the DWX matrix for portability testing.
- WS30.DWX — liquid index CFD in the DWX matrix for portability testing.

**Explicitly NOT for:**
- XAGUSD.DWX — not included because the card says FX/index symbols after gold, not the full commodities basket.
- XNGUSD.DWX — not included because the card says FX/index symbols after gold, not the full commodities basket.
- XTIUSD.DWX — not included because the card says FX/index symbols after gold, not the full commodities basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | intraday to multi-session, bounded by SL/TP and Friday close |
| Expected drawdown profile | trend-breakout losses during chop, controlled by fixed 1R risk |
| Regime preference | trend / channel breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** MQL5 CodeBase, "KA-Gold Bot MT5 - expert for MetaTrader 5", author Nguyen Quoc Hung, published 2024-02-19, https://www.mql5.com/en/code/48251
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10457_mql5-keltner.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-28 | Initial build from card | 22eea958-c295-4904-9fa5-722e60b24b3c |
