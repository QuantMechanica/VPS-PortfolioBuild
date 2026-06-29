# QM5_12796_carver-vol-trend - Strategy Spec

**EA ID:** QM5_12796
**Slug:** `carver-vol-trend`
**Source:** `carver-vol-trend-inhouse-2026-06-29`
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

This EA trades Rob Carver-style daily trend following. On each closed D1 bar it computes EWMAC forecasts from 8/32, 16/64, and 32/128 EMA differences, divides each price difference by recent daily realized volatility, averages the scaled forecasts, and caps the result at +/-20. It opens long when the capped forecast is positive and short when it is negative. It exits when the forecast sign flips against the open position; the initial protective stop is placed at 3.0 x ATR(20).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tf` | `PERIOD_D1` | D1 | Base timeframe for all forecast and ATR calculations. |
| `strategy_use_multispeed` | `true` | true/false | Use the three-speed EWMAC average rather than only the first pair. |
| `strategy_fast_period_1` | `8` | 2-64 | Fast EMA period for speed 1. |
| `strategy_slow_period_1` | `32` | fast+1-256 | Slow EMA period for speed 1. |
| `strategy_fast_period_2` | `16` | 2-64 | Fast EMA period for speed 2. |
| `strategy_slow_period_2` | `64` | fast+1-256 | Slow EMA period for speed 2. |
| `strategy_fast_period_3` | `32` | 2-128 | Fast EMA period for speed 3. |
| `strategy_slow_period_3` | `128` | fast+1-512 | Slow EMA period for speed 3. |
| `strategy_vol_lookback` | `25` | 10-100 | Daily return window used to normalize EWMAC by realized volatility. |
| `strategy_forecast_multiplier` | `1.0` | 0.25-4.0 | Multiplier applied after Carver speed scalar normalization. |
| `strategy_forecast_cap` | `20.0` | 5.0-40.0 | Absolute cap applied to the averaged forecast. |
| `strategy_entry_forecast` | `0.0` | 0.0-10.0 | Minimum absolute forecast needed to enter. Zero follows the card's sign rule. |
| `strategy_atr_period` | `20` | 5-100 | ATR period for the protective stop. |
| `strategy_stop_atr_mult` | `3.0` | 1.0-8.0 | ATR multiple for the initial protective stop. |
| `strategy_spread_filter` | `true` | true/false | Enables the ATR-relative spread filter. |
| `strategy_max_spread_atr_mult` | `0.05` | 0.0-0.25 | Blocks only genuinely wide positive spreads versus ATR; zero spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq index trend exposure named in the card's NDX/US index set.
- `SP500.DWX` - S&P 500 backtest-only proxy for the card's US500 instrument.
- `GDAXI.DWX` - DAX/Germany index proxy for the card's GER40 instrument.
- `XAUUSD.DWX` - liquid metal trend exposure.
- `XAGUSD.DWX` - silver trend exposure; same metal bucket but different volatility profile.
- `XTIUSD.DWX` - WTI crude trend exposure, the energy-beyond-XNG sleeve requested for diversity.
- `XNGUSD.DWX` - natural gas proxy for the card's NATGAS line.

**Explicitly NOT for:**
- FX majors - the card explicitly puts index, metal, and energy first because FX trend is weaker and cost-heavier.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no external futures, ETF, or macro feed is read by the EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | About 10-20; card estimate is 15. |
| Typical hold time | Several days to multiple weeks, until the daily EWMAC forecast flips sign. |
| Expected drawdown profile | Trend-following whipsaw drawdowns during sideways regimes; bounded per-trade by ATR stop and V5 fixed risk. |
| Regime preference | Persistent daily trend in low-commission indices, metals, and energy. |
| Win rate target (qualitative) | Medium-low win rate with larger trend winners. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `carver-vol-trend-inhouse-2026-06-29`
**Source type:** book / in-house implementation card
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12796_carver-vol-trend.md`
**R1-R4 verdict (Q00):** all PASS per approved card; source basis is Rob Carver's published EWMAC forecast and volatility-scaling methodology.

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
| v1 | 2026-06-30 | Initial build from card | build task `ad04b4bc-768a-485e-b034-07246ea6b686` |
