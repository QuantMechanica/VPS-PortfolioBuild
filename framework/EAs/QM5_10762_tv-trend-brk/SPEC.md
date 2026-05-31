# QM5_10762_tv-trend-brk - Strategy Spec

**EA ID:** QM5_10762
**Slug:** tv-trend-brk
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades confirmed closed-bar breakouts in the direction of an EMA trend filter. A long signal requires the last closed bar to close above EMA(50) and above the highest high of the prior 20 closed bars. A short signal requires the last closed bar to close below EMA(50) and below the lowest low of the prior 20 closed bars.

Entries are blocked when Bollinger-band width is compressed relative to ATR and the close remains inside the band, matching the card's range-filter instruction. Stops are ATR(14) times 1.5 from entry, and targets are placed at 2.0R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 50 | 50, 100, 200 | EMA period used for trend direction. |
| strategy_structure_lookback | 20 | 10, 20, 40 | Prior closed bars used for structure high/low breakout. |
| strategy_bb_period | 20 | 20, 30 | Bollinger period used by the compression range filter. |
| strategy_bb_deviation | 2.0 | 1.5, 2.0, 2.5 | Bollinger deviation multiplier used by the range filter. |
| strategy_atr_period | 14 | 14, 21 | ATR period used for stop distance and compression width. |
| strategy_atr_stop_mult | 1.5 | 1.0, 1.5, 2.0 | Stop distance multiplier applied to ATR. |
| strategy_target_rr | 2.0 | 1.5, 2.0, 2.5 | Take-profit distance in multiples of stop risk. |
| strategy_max_spread_points | 0 | 0 or higher | Optional spread block; 0 disables the filter. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid FX major with native DWX data and trend-breakout portability.
- GBPUSD.DWX - liquid FX major with native DWX data and trend-breakout portability.
- USDJPY.DWX - liquid FX major with native DWX data and trend-breakout portability.
- XAUUSD.DWX - gold CFD with DWX data; card listed XAUUSD and framework uses the `.DWX` custom symbol.
- GDAXI.DWX - DAX port for the card's GER40.DWX target; GER40.DWX is not in the DWX matrix.
- NDX.DWX - Nasdaq 100 index exposure from the card's P2 basket.
- WS30.DWX - Dow 30 index exposure from the card's P2 basket.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable S&P aliases.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 and H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday to multiday until ATR stop or 2.0R target is reached. |
| Expected drawdown profile | Clean trend-continuation candidate; main drawdown risk is repeated false breakouts in range regimes. |
| Regime preference | Trend-following breakout with volatility expansion. |
| Win rate target (qualitative) | Medium to low, offset by 2.0R target distance. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/7Tx5yF0f-Trend-Break-Structure-Range-Filter/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10762_tv-trend-brk.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-31 | Initial build from card | acf8ff05-3557-4763-92d4-2d54cf63b70f |
