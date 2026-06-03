# QM5_10760_tv-iu-orb_v2 - Strategy Spec

**EA ID:** QM5_10760
**Slug:** tv-iu-orb
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA records the high and low of the configured opening-range window on M5 bars. After that range is complete, it buys when a completed candle closes from at or below the range high to above the range high, and sells when a completed candle closes from at or above the range low to below the range low. Long stops use the signal candle low; short stops use the signal candle high; take profit is placed at a fixed risk-to-reward multiple. New entries are capped per day, and any open position is force-closed at the configured session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session_start_hhmm` | 915 | 0000-2359 | Broker-time start of the opening session. |
| `strategy_session_end_hhmm` | 1515 | 0000-2359 | Broker-time session close where open positions are flattened. |
| `strategy_opening_range_minutes` | 15 | 5-60 | Minutes after session start used to lock the opening range. |
| `strategy_max_trades_per_day` | 2 | 1+ | Maximum entries allowed per symbol per day. |
| `strategy_rr_target` | 2.0 | >0 | Take-profit distance as a multiple of stop distance. |
| `strategy_atr_period` | 14 | 1+ | ATR period used only for minimum and maximum stop-distance guards. |
| `strategy_min_stop_atr` | 0.25 | >=0 | Minimum stop distance as ATR multiple. |
| `strategy_max_stop_atr` | 3.00 | >=0 | Maximum stop distance as ATR multiple. |
| `strategy_max_spread_points` | 0.0 | >=0 | Optional spread ceiling in points; zero disables the check. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 includes major FX where M5 OHLC/session breakout mechanics are available.
- `GBPUSD.DWX` - Card R3 includes major FX where M5 OHLC/session breakout mechanics are available.
- `USDJPY.DWX` - Card R3 includes major FX where M5 OHLC/session breakout mechanics are available.
- `XAUUSD.DWX` - Card lists XAUUSD; `.DWX` is the matrix-verified canonical backtest symbol.
- `GDAXI.DWX` - Card lists GER40.DWX; the DWX matrix canonical DAX symbol is GDAXI.DWX.
- `NDX.DWX` - Card R3 includes Nasdaq index exposure for the intraday ORB basket.
- `WS30.DWX` - Card R3 includes Dow index exposure for the intraday ORB basket.
- `SP500.DWX` - Card lists SP500.DWX as optional backtest-only; it is matrix-verified for build and P2 backtests.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `XAUUSD` - Unsuffixed research symbol; use `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday; flat by configured session end. |
| Expected drawdown profile | High-cadence breakout with stop size constrained by ATR guards. |
| Regime preference | Opening-range breakout / volatility expansion. |
| Win rate target (qualitative) | Medium; reward target defaults to 2R. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/JnOdejSN-IU-Opening-range-Breakout-Strategy/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10760_tv-iu-orb_v2.md`

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
| v1 | 2026-05-31 | Initial build from card | 6fff897b-4318-4381-ac4f-6e3cf0191c71 |

