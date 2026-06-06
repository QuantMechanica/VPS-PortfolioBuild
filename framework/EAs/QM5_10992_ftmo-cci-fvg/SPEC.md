# QM5_10992_ftmo-cci-fvg - Strategy Spec

**EA ID:** QM5_10992
**Slug:** `ftmo-cci-fvg`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see FTMO Academy citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades H1 trend-continuation setups after CCI(20) crosses the zero line in the trend direction. A long requires the last closed bar above EMA(50), a recent CCI cross above zero, and a bullish three-candle fair value gap whose height is between 0.25 and 1.5 ATR(14). It enters when the first retrace touches the upper half of that gap and closes back above the midpoint; shorts mirror the same logic below EMA(50). Initial stop is beyond the opposite FVG boundary by 0.35 ATR(14), target is 2.0R, SL moves to breakeven after 1.0R, and open trades exit if CCI closes back through zero or after 36 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H1` | H1 expected | Signal timeframe from the approved card. |
| `strategy_cci_period` | `20` | `2+` | CCI period used for zero-line confirmation and CCI exit. |
| `strategy_ema_period` | `50` | `2+` | EMA trend filter period. |
| `strategy_atr_period` | `14` | `2+` | ATR period used for FVG size filter and SL offset. |
| `strategy_cci_cross_lookback` | `3` | `1+` | Closed-bar lookback for the CCI zero-line cross. |
| `strategy_fvg_lookback` | `8` | `1+` | Lookback for locating the most recent qualifying FVG. |
| `strategy_fvg_min_atr` | `0.25` | `0+` | Minimum FVG height as a multiple of ATR(14). |
| `strategy_fvg_max_atr` | `1.50` | `0+` | Maximum FVG height as a multiple of ATR(14). |
| `strategy_sl_atr_mult` | `0.35` | `0+` | ATR offset beyond the FVG boundary for the initial stop. |
| `strategy_tp_r_multiple` | `2.0` | `0+` | Take-profit distance in R multiples. |
| `strategy_time_exit_bars` | `36` | `1+` | Maximum hold time in H1 bars. |
| `strategy_spread_lookback` | `20` | `2+` | Closed-bar spread sample length for the median spread filter. |
| `strategy_spread_median_mult` | `1.50` | `0+` | Current spread must not exceed this multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid DWX major FX pair named by the card's R3 basket.
- `GBPUSD.DWX` - liquid DWX major FX pair named by the card's R3 basket.
- `XAUUSD.DWX` - DWX metal instrument named by the card's R3 basket.
- `NDX.DWX` - DWX index instrument named by the card's R3 basket.

**Explicitly NOT for:**
- Symbols outside the approved R3 basket - not registered for this EA at Q01.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | Few H1 bars to maximum 36 H1 bars |
| Expected drawdown profile | ATR-bounded single-position risk with 2R target and breakeven after 1R |
| Regime preference | Trend continuation with FVG pullback |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog`
**Pointer:** FTMO Academy, "CCI: Technical Indicator", 2025, `https://academy.ftmo.com/lesson/cci-technical-indicator/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10992_ftmo-cci-fvg.md`

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
| v1 | 2026-06-07 | Initial build from card | e950f311-0472-4c68-8acb-c2f2a98ef716 |
