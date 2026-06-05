# QM5_10779_tv-orb-fvg - Strategy Spec

**EA ID:** QM5_10779
**Slug:** `tv-orb-fvg`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView ORB Strategy by osterhansi_)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA captures the broker-time opening range from 16:30 to 16:35, which is the card's 09:30-09:35 New York default ported to DarwinexZero broker time. During the 16:36-18:00 broker-time trading window, it buys when the last closed bar closes above the opening-range high and sells when the last closed bar closes below the opening-range low. By default the signal also requires a standard three-candle fair value gap in the breakout direction and enters at the nearest FVG edge. The stop is placed at the breakout candle extreme by default, the target is set by risk-to-reward, and any open trade is flattened after the trading window ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_capture_start_hhmm` | 1630 | 0000-2359 | Broker-time start of the opening-range capture window. |
| `strategy_capture_minutes` | 5 | 1-60 | Number of minutes used to build the opening range. |
| `strategy_trade_start_hhmm` | 1636 | 0000-2359 | Broker-time start of the allowed post-capture entry window. |
| `strategy_trade_end_hhmm` | 1800 | 0000-2359 | Broker-time end of entries and time-stop flattening. |
| `strategy_fvg_filter_enabled` | true | true/false | Requires a fair value gap in the breakout direction. |
| `strategy_fvg_edge_entry` | true | true/false | Uses a limit order at the nearest FVG edge instead of market entry. |
| `strategy_ema_period` | 0 | 0, 50, 100 | Optional EMA trend filter; 0 disables it. |
| `strategy_stop_mode` | 0 | 0-2 | 0 breakout candle, 1 opposite opening-range side, 2 ATR stop. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for stop buffer or ATR stop mode. |
| `strategy_atr_buffer_mult` | 0.0 | 0.0-5.0 | Optional ATR buffer added beyond candle or range stop. |
| `strategy_atr_sl_mult` | 1.0 | 0.1-10.0 | ATR multiple used when `strategy_stop_mode=2`. |
| `strategy_rr_target` | 2.0 | 0.5-10.0 | Take-profit multiple of initial risk. |
| `strategy_max_spread_points` | 0 | 0-1000 | Optional spread ceiling; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major named in the approved R3 basket.
- `GBPUSD.DWX` - liquid FX major named in the approved R3 basket.
- `USDJPY.DWX` - liquid FX major named in the approved R3 basket.
- `XAUUSD.DWX` - canonical DWX form of the card's XAUUSD gold leg.
- `GDAXI.DWX` - canonical DAX proxy for the card's GER40 leg in the local DWX matrix.
- `NDX.DWX` - liquid US index CFD named in the approved R3 basket.
- `WS30.DWX` - liquid US index CFD named in the approved R3 basket.

**Explicitly NOT for:**
- Non-DWX broker symbols - the V5 test pipeline uses only symbols present in `framework/registry/dwx_symbol_matrix.csv`.
- `GER40.DWX` - not present in the local DWX matrix; this build uses `GDAXI.DWX` instead.
- `XAUUSD` without suffix - not a pipeline symbol; this build uses `XAUUSD.DWX`.

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
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, from post-open breakout until TP, SL, or same-session time stop |
| Expected drawdown profile | False-break sensitive intraday breakout profile |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | Medium with 1:2 default reward-to-risk |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/BACpXcNb-ORB-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10779_tv-orb-fvg.md`

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
| v1 | 2026-06-05 | Initial build from card | 3f09779c-ab5b-45f2-9492-4d02b37bbf70 |
