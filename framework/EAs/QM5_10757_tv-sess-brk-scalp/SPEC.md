# QM5_10757_tv-sess-brk-scalp - Strategy Spec

**EA ID:** QM5_10757
**Slug:** tv-sess-brk-scalp
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades a time-conditional session breakout on M5. After the configured broker-time session marker, it waits for the configured number of closed bars, builds a range from the same number of bars before and after the marker, then places stop entries at the range high and range low. The stop loss is ATR(14) times 1.5 with symbol-class pip bounds, and the take profit is a fixed 1.5R target. Optional regime filters are enabled by default: LWTI must be above 50 for long or below 50 for short, and the Andean bull line must be above the bear line for long or below it for short.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_session_hour_broker | 8 | 0-23 | Broker-hour session marker for the baseline London-open set. |
| strategy_session_minute_broker | 0 | 0-59 | Broker-minute session marker. |
| strategy_box_bars_each_side | 3 | 2-5 | Bars before and after the marker used to form the symmetrical range box. |
| strategy_atr_period | 14 | 2-100 | ATR period for the stop distance. |
| strategy_atr_sl_mult | 1.5 | 0.1-10.0 | ATR multiplier for the initial stop. |
| strategy_tp_rr | 1.5 | 0.1-10.0 | Static take-profit distance in R multiples. |
| strategy_regime_filter_mode | 2 | 0-2 | 0 disables filters, 1 enables LWTI, 2 enables LWTI plus Andean Oscillator. |
| strategy_lwti_period | 25 | 2-200 | LWTI lookback used for the momentum quotient. |
| strategy_andean_length | 50 | 2-300 | Andean Oscillator recursive envelope length. |
| strategy_max_spread_points | 80 | 0-10000 | Maximum allowed spread in points; 0 disables the spread gate. |
| strategy_fx_min_sl_pips | 5 | 0-10000 | Minimum ATR stop bound for FX symbols. |
| strategy_fx_max_sl_pips | 35 | 0-10000 | Maximum ATR stop bound for FX symbols. |
| strategy_xau_min_sl_pips | 50 | 0-10000 | Minimum ATR stop bound for XAUUSD.DWX. |
| strategy_xau_max_sl_pips | 300 | 0-10000 | Maximum ATR stop bound for XAUUSD.DWX. |
| strategy_index_min_sl_pips | 20 | 0-10000 | Minimum ATR stop bound for index symbols. |
| strategy_index_max_sl_pips | 300 | 0-10000 | Maximum ATR stop bound for index symbols. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 lists EURUSD for the portable FX session-breakout basket.
- GBPUSD.DWX - Card R3 lists GBPUSD for the portable FX session-breakout basket.
- USDJPY.DWX - Card R3 lists USDJPY for the portable FX session-breakout basket.
- XAUUSD.DWX - Card R3 lists XAUUSD and the DWX matrix provides XAUUSD.DWX.
- GDAXI.DWX - Card R3 lists GER40; the DWX matrix does not provide GER40.DWX, so GDAXI.DWX is the available DAX equivalent.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`.

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
| Trades / year / symbol | 150 |
| Typical hold time | Intraday scalper; exits by TP, SL, regime failure, or next configured session. |
| Expected drawdown profile | Scalping-sensitive with spread, latency, and fill-assumption risk. |
| Regime preference | Volatility-expansion breakout with momentum-regime confirmation. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/7abDoROC-Session-Breakout-Scalper-Trading-Bot/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10757_tv-sess-brk-scalp.md`

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
| v1 | 2026-06-14 | Initial build from card | 7ceeabdb-a88a-4342-bda5-7005e3ca2d07 |
