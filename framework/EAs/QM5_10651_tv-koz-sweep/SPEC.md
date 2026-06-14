# QM5_10651_tv-koz-sweep - Strategy Spec

**EA ID:** QM5_10651
**Slug:** tv-koz-sweep
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades M5 rejection candles that sweep a prior liquidity level while M15 swing structure gives directional bias. A long requires M15 higher-high and higher-low structure, an M5 sweep below prior-day low or the latest M15 swing low, a close back above that level, OB/FVG confluence at the swept level, and a bullish engulfing or bullish pin-bar trigger. A short mirrors the same rules against prior-day high or the latest M15 swing high. Stops are placed at the sweep wick extreme, and the baseline exits the full position at TP1, the nearest opposite M15 swing level.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_broker_to_ny_offset_hours` | 7 | 0-12 | Broker-time hours subtracted to approximate New York session time. |
| `strategy_ny_start_1_hhmm` | 930 | 0-2359 | First New York trading window start. |
| `strategy_ny_end_1_hhmm` | 1100 | 0-2359 | First New York trading window end. |
| `strategy_ny_start_2_hhmm` | 1400 | 0-2359 | Second New York trading window start. |
| `strategy_ny_end_2_hhmm` | 1530 | 0-2359 | Second New York trading window end. |
| `strategy_m15_swing_wing_bars` | 2 | 1-10 | Bars on each side required to confirm an M15 swing high or low. |
| `strategy_m15_scan_bars` | 120 | 30-300 | M15 closed bars scanned for recent/prior swing structure. |
| `strategy_m5_scan_bars` | 32 | 10-100 | M5 closed bars loaded for sweep, OB, and FVG checks. |
| `strategy_fvg_lookback_bars` | 10 | 3-50 | Recent M5 bars searched for a three-candle fair-value gap. |
| `strategy_ob_lookback_bars` | 12 | 3-50 | Recent M5 bars searched for an opposite-candle order block touching the swept level. |
| `strategy_confluence_tolerance_pts` | 20 | 0-1000 | Point tolerance around the swept level for OB/FVG confluence. |
| `strategy_pin_max_body_ratio` | 0.35 | 0.05-0.80 | Maximum body-to-range ratio for pin-bar triggers. |
| `strategy_pin_wick_body_mult` | 2.0 | 1.0-5.0 | Minimum dominant-wick multiple versus candle body. |
| `strategy_min_stop_points` | 20 | 1-10000 | Minimum stop distance in points for risk sizing. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - card-approved primary index CFD with liquid intraday OHLC structure.
- `WS30.DWX` - card-approved primary index CFD with liquid intraday OHLC structure.
- `XAUUSD.DWX` - card-approved metal CFD with liquid intraday sweep behavior.
- `EURUSD.DWX` - card-approved FX pair with native DWX history and intraday liquidity levels.

**Explicitly NOT for:**
- Non-DWX symbols - the V5 research and backtest registry requires canonical `.DWX` symbols.
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no validated broker/custom-symbol history is available.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `M15` swing structure and previous `D1` high/low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, from minutes to a few hours |
| Expected drawdown profile | Moderate; fixed-risk sweep reversals can cluster losses during trend continuation. |
| Regime preference | Liquidity sweep reversal during active New York sessions |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView script
**Pointer:** TradingView script `KOZ Algo SMC/ICT Strategy`, author handle `M_LOADING`, published 2026-03-28, https://www.tradingview.com/script/cWLDZXrh-KOZ-Algo-SMC-ICT-Strategy/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10651_tv-koz-sweep.md`

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
| v1 | 2026-06-14 | Initial build from card | d4b5f4a9-704c-463a-b7f8-36f7657f21e4 |
