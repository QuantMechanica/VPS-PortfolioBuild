# QM5_11051_pst-volatten-break - Strategy Spec

**EA ID:** QM5_11051
**Slug:** `pst-volatten-break`
**Source:** `352af9de-f372-5cf2-9a86-681a26224597` (see `strategy-seeds/sources/352af9de-f372-5cf2-9a86-681a26224597/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA evaluates once per completed D1 bar. It computes rolling close-range breakout forecasts for lookbacks 10, 20, 40, 80, 160, and 320, smooths each forecast with an EMA of N/4 bars, applies the card's fixed scalar for each horizon, caps each component to +/-20, then averages the valid components. When enabled and enough history exists, a volatility attenuation multiplier reduces the component forecasts in high relative-volatility regimes; otherwise the source-like fallback multiplier is 1.0.

The EA opens long when the combined forecast is at least +5 and opens short when it is at most -5. Long positions close when the forecast falls to +1 or below; short positions close when the forecast rises to -1 or above. Emergency protection is a 3.0 x ATR(20, D1) stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_forecast` | 5.0 | 3.0-8.0 | Absolute combined forecast threshold for new entries. |
| `strategy_exit_forecast` | 1.0 | 0.0-entry threshold | Forecast threshold for reversal-style exits. |
| `strategy_use_attenuation` | true | true/false | Enables the volatility attenuation overlay from the card. |
| `strategy_use_all_lookbacks` | true | true/false | true uses 10,20,40,80,160,320; false uses 20,40,80,160. |
| `strategy_daily_vol_period` | 25 | 2-252 | Daily return window used for rolling percentage volatility. |
| `strategy_vol_sma_period` | 2500 | 20-5000 | Long normalisation window for percentage volatility. |
| `strategy_vol_atten_ema_period` | 10 | 1-100 | EMA smoothing period for the attenuation multiplier. |
| `strategy_spread_median_days` | 60 | 2-256 | Daily spread sample used for the median-spread filter. |
| `strategy_spread_mult` | 2.0 | >0 | Blocks new entries when current spread is above this multiple of median spread. |
| `strategy_atr_period` | 20 | >=2 | ATR period used by the emergency stop. |
| `strategy_atr_sl_mult` | 3.0 | >0 | ATR multiple used by the emergency stop. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair with D1 OHLC and spread data for trend breakout rules.
- `GBPUSD.DWX` - major FX pair with D1 OHLC and spread data for trend breakout rules.
- `USDJPY.DWX` - major FX pair with D1 OHLC and spread data for trend breakout rules.
- `NDX.DWX` - Nasdaq 100 index CFD with D1 OHLC and spread data for trend breakout rules.
- `WS30.DWX` - Dow 30 index CFD with D1 OHLC and spread data for trend breakout rules.
- `XAUUSD.DWX` - gold CFD with D1 OHLC and spread data for trend breakout rules.
- `XTIUSD.DWX` - oil CFD with D1 OHLC and spread data for trend breakout rules.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX testbar support.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P 500 aliases; the card did not require S&P 500 registration.

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
| Trades / year / symbol | `45` |
| Typical hold time | Several D1 bars to multiple weeks, until forecast reversal or ATR stop. |
| Expected drawdown profile | Whipsaw-prone trend breakout drawdowns, attenuated during high relative-volatility regimes. |
| Regime preference | Trend-following breakout with volatility attenuation. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `352af9de-f372-5cf2-9a86-681a26224597`
**Source type:** GitHub source configuration and rule implementation
**Pointer:** `https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/rob_system/config.yaml`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11051_pst-volatten-break.md`

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
| v1 | 2026-06-07 | Initial build from card | a0175a7d-088c-45ac-b170-2f6d26f3894d |
