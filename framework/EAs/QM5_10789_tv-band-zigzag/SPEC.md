# QM5_10789_tv-band-zigzag - Strategy Spec

**EA ID:** QM5_10789
**Slug:** `tv-band-zigzag`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView mechanical strategy scripts)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

This EA trades band breakouts only after the band-zigzag structure confirms a trend. It computes a fixed Bollinger, Keltner, or Donchian channel, records pivot highs only when price breaks the upper band, and records pivot lows only when price breaks the lower band. A long entry requires an upper-band breakout, higher highs and higher lows, pivot ratio above the configured threshold, and percentB above the breakout threshold; shorts mirror this with lower lows and lower highs. Exits occur when the opposite pivot structure appears, when the ATR/structure stop is hit, or when max-bars-in-trade is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_band_type` | 0 | 0-2 | Band family: 0 Bollinger, 1 Keltner, 2 Donchian. |
| `strategy_band_length` | 20 | 2+ | Lookback length for the selected band. |
| `strategy_band_mult` | 2.0 | >0 | Bollinger deviation or Keltner ATR multiplier. |
| `strategy_pivot_ratio_min` | 1.0 | >0 | Minimum pivot-ratio confirmation threshold. |
| `strategy_percentb_long_min` | 1.0 | any double | Minimum percentB for long breakout confirmation. |
| `strategy_percentb_short_max` | 0.0 | any double | Maximum percentB for short breakout confirmation. |
| `strategy_use_adx_filter` | true | true/false | Enables the optional ADX trend-strength filter. |
| `strategy_adx_period` | 14 | 1+ | ADX period. |
| `strategy_adx_min` | 20.0 | >=0 | Minimum ADX when the ADX filter is enabled. |
| `strategy_use_atr_filter` | false | true/false | Enables the optional low-volatility ATR filter. |
| `strategy_atr_period` | 14 | 1+ | ATR period for filters and safety stop. |
| `strategy_atr_filter_lookback` | 50 | 2+ | ATR average lookback for the low-volatility filter. |
| `strategy_atr_filter_min_ratio` | 0.75 | >0 | Current ATR must be at least this multiple of average ATR. |
| `strategy_atr_stop_mult` | 2.0 | >0 | ATR multiple used for safety stop placement. |
| `strategy_max_bars_in_trade` | 96 | 0+ | Time-stop in current-chart bars; 0 disables. |
| `strategy_allow_shorts` | true | true/false | Enables short entries. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair with DWX OHLC, ATR, ADX, and band data.
- `GBPUSD.DWX` - liquid major FX pair matching the card's FX portability claim.
- `USDJPY.DWX` - liquid major FX pair matching the card's FX portability claim.
- `XAUUSD.DWX` - canonical DWX gold symbol; card listed `XAUUSD` without suffix.
- `GDAXI.DWX` - canonical DWX DAX symbol; used instead of card alias `GER40.DWX`.
- `NDX.DWX` - liquid US index CFD for channel breakout testing.
- `WS30.DWX` - liquid US index CFD for channel breakout testing.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; canonical matrix equivalent is `GDAXI.DWX`.
- `XAUUSD` - unsuffixed symbol is not valid for DWX backtest registry rows.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Expected trade frequency | Medium cadence trend-following, per approved card. |
| Typical hold time | Hours to several days, capped by `strategy_max_bars_in_trade`. |
| Expected drawdown profile | Lower win rate with larger open-trade variance. |
| Regime preference | Trend-following channel breakout and volatility expansion. |
| Win rate target (qualitative) | Low to medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `Band-Zigzag - TrendFollower Strategy [Trendoscope]`, author `Trendoscope`, published 2023-01-21.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10789_tv-band-zigzag.md`

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
| v1 | 2026-06-05 | Initial build from card | 943206d5-07d2-462b-89bf-370748a71871 |
