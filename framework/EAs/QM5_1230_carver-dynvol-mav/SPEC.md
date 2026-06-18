# QM5_1230_carver-dynvol-mav - Strategy Spec

**EA ID:** QM5_1230
**Slug:** `carver-dynvol-mav`
**Source:** `2a380bee-1ec4-50d1-a348-b10fac642c7a` (see `sources/rob-carver-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a discrete D1 trend-following rule. It goes long when EMA(16) of the D1 close is above EMA(64), goes short when EMA(16) is below EMA(64), and does not enter when the averages are equal. The initial stop distance is `8 * StdDev(D1 close-to-close price changes, 25)`. While a position is open, the EA keeps the broker stop synchronized as a volatility trailing stop and optionally exits early if the moving-average signal flips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_ema_period` | 16 | 1-200 | Fast D1 EMA period for the binary trend signal. |
| `strategy_slow_ema_period` | 64 | 2-400 | Slow D1 EMA period for the binary trend signal. |
| `strategy_daily_vol_period` | 25 | 2-252 | Number of D1 close-to-close changes used for price volatility. |
| `strategy_stop_gap_vol_mult` | 8.0 | 0.1-20.0 | Stop gap multiplier applied to current daily price volatility. |
| `strategy_min_d1_bars` | 100 | 65-1000 | Minimum available D1 history before entries are allowed. |
| `strategy_cooldown_bars` | 20 | 0-100 | Bars to wait before same-direction re-entry after a closed position. |
| `strategy_exit_on_ma_flip` | true | true/false | Enables the card's conservative opposite-signal exit. |
| `strategy_dynamic_derisk` | true | true/false | Reduces open volume when current volatility rises above entry volatility. |
| `strategy_derisk_step` | 0.10 | 0.0-1.0 | Minimum volatility increase before a partial de-risk is attempted. |
| `strategy_spread_cap_points` | 0 | 0-100000 | Optional current-spread cap in points; 0 disables the cap for DWX zero-spread tests. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major supported by the card's D1 OHLC-only rule.
- `GBPUSD.DWX` - liquid FX major supported by the card's D1 OHLC-only rule.
- `AUDUSD.DWX` - liquid FX major supported by the card's D1 OHLC-only rule.
- `NDX.DWX` - liquid index CFD supported by the card's D1 OHLC-only rule.
- `WS30.DWX` - liquid index CFD supported by the card's D1 OHLC-only rule.
- `GDAXI.DWX` - liquid European index CFD supported by the card's D1 OHLC-only rule.
- `UK100.DWX` - liquid European index CFD supported by the card's D1 OHLC-only rule.
- `XAUUSD.DWX` - metal CFD supported by the card's D1 OHLC-only rule.
- `XAGUSD.DWX` - metal CFD supported by the card's D1 OHLC-only rule.
- `XTIUSD.DWX` - oil CFD supported by the card's D1 OHLC-only rule.
- `AUDCAD.DWX` - portable FX cross in the DWX symbol matrix.
- `AUDCHF.DWX` - portable FX cross in the DWX symbol matrix.
- `AUDJPY.DWX` - portable FX cross in the DWX symbol matrix.
- `AUDNZD.DWX` - portable FX cross in the DWX symbol matrix.
- `CADCHF.DWX` - portable FX cross in the DWX symbol matrix.
- `CADJPY.DWX` - portable FX cross in the DWX symbol matrix.
- `CHFJPY.DWX` - portable FX cross in the DWX symbol matrix.
- `EURAUD.DWX` - portable FX cross in the DWX symbol matrix.
- `EURCAD.DWX` - portable FX cross in the DWX symbol matrix.
- `EURCHF.DWX` - portable FX cross in the DWX symbol matrix.
- `EURGBP.DWX` - portable FX cross in the DWX symbol matrix.
- `EURJPY.DWX` - portable FX cross in the DWX symbol matrix.
- `EURNZD.DWX` - portable FX cross in the DWX symbol matrix.
- `GBPAUD.DWX` - portable FX cross in the DWX symbol matrix.
- `GBPCAD.DWX` - portable FX cross in the DWX symbol matrix.
- `GBPCHF.DWX` - portable FX cross in the DWX symbol matrix.
- `GBPJPY.DWX` - portable FX cross in the DWX symbol matrix.
- `GBPNZD.DWX` - portable FX cross in the DWX symbol matrix.
- `NZDCAD.DWX` - portable FX cross in the DWX symbol matrix.
- `NZDCHF.DWX` - portable FX cross in the DWX symbol matrix.
- `NZDJPY.DWX` - portable FX cross in the DWX symbol matrix.
- `NZDUSD.DWX` - portable FX cross in the DWX symbol matrix.
- `USDCAD.DWX` - portable FX major in the DWX symbol matrix.
- `USDCHF.DWX` - portable FX major in the DWX symbol matrix.
- `USDJPY.DWX` - portable FX major in the DWX symbol matrix.
- `XNGUSD.DWX` - energy CFD supported by the card's D1 OHLC-only rule.

**Explicitly NOT for:**
- `SP500.DWX` - card says SP500.DWX is not required and proposes broker-routable DWX symbols only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | multi-day to multi-week trend trades |
| Expected drawdown profile | Trend-following whipsaws during choppy regimes; volatility stop limits single-trade loss. |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2a380bee-1ec4-50d1-a348-b10fac642c7a`
**Source type:** `blog`
**Pointer:** `https://qoppac.blogspot.com/2020/12/dynamic-trend-following.html`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1230_carver-dynvol-mav.md`

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
| v1 | 2026-06-18 | Initial build from card | 41d2bc9c-ca87-4b60-b3a6-fd847a53fa6e |
