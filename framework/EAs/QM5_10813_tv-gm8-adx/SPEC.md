# QM5_10813_tv-gm8-adx - Strategy Spec

**EA ID:** QM5_10813
**Slug:** tv-gm8-adx
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

This EA trades the confirmed close relative to an 8-period moving average and an EMA(59) trend filter. It opens long when the last closed bar closes above both averages and ADX(14) is above 20, and opens short when the last closed bar closes below both averages and ADX(14) is above 20. Initial risk is a 2.0 x ATR(14) stop from entry. It exits on the opposite long or short condition, with an optional max-bars safety exit for the M30/H1 baseline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_gm_ma_period | 8 | >= 1 | Period for the GM-8 moving average, implemented as SMA because the card does not specify MA type. |
| strategy_ema_filter_period | 59 | >= 1 | EMA trend filter period. |
| strategy_adx_period | 14 | >= 1 | ADX period. |
| strategy_adx_threshold | 20.0 | > 0 | Minimum ADX value required for entries and opposite-signal exits. |
| strategy_atr_period | 14 | >= 1 | ATR period for the safety stop. |
| strategy_atr_sl_mult | 2.0 | > 0 | ATR multiple for the initial stop. |
| strategy_slope_filter | false | true/false | Optional card slope filter requiring both averages to slope in the trade direction. |
| strategy_max_bars_exit | true | true/false | Enables the optional V5 max-bars exit. |
| strategy_max_bars_m30 | 160 | >= 1 | Max holding bars when run on M30. |
| strategy_max_bars_h1 | 120 | >= 1 | Max holding bars when run on H1 or other tested baseline periods. |
| strategy_trail_after_1r | false | true/false | Optional P3 Chandelier-style ATR trail after price reaches +1R. |
| strategy_trail_atr_mult | 3.0 | > 0 | ATR multiple for the optional trailing stop. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid FX major with complete DWX OHLC coverage.
- GBPUSD.DWX - liquid FX major with complete DWX OHLC coverage.
- USDJPY.DWX - liquid FX major with complete DWX OHLC coverage.
- XAUUSD.DWX - canonical DWX gold symbol for the card's XAUUSD target.
- GDAXI.DWX - canonical DAX DWX symbol used for the card's GER40.DWX target.
- NDX.DWX - liquid US large-cap index CFD in the card basket.
- WS30.DWX - liquid US large-cap index CFD in the card basket.

**Explicitly NOT for:**
- SP500.DWX - not in the card's R3 P2 basket.
- GER40.DWX - not present in the DWX symbol matrix; mapped to GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | Intraday to several days; card provides max-bars safety exits of 160 M30 bars or 120 H1 bars. |
| Expected drawdown profile | Trend-following drawdowns from whipsaw and low-direction regimes, bounded by ATR safety stop. |
| Regime preference | Directional trend-following regimes with ADX above threshold. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/bph5KW8A/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10813_tv-gm8-adx.md`

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
| v1 | 2026-06-05 | Initial build from card | 05ff5b48-1003-402a-8ea6-95e9ac2854b2 |
