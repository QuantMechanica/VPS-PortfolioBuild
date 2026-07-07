# QM5_9510_carver-forecast - Strategy Spec

**EA ID:** QM5_9510
**Slug:** `carver-forecast`
**Source:** `1a059d6d-84fa-5d0c-94c5-86dd0481637c`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

On each closed D1 bar, compute:

`RawForecast = (EMA(16) - EMA(64)) / ATR(25)`

The forecast is capped to `[-2.0, +2.0]`. Enter long when the capped forecast is at least `+0.50`; enter short when it is at most `-0.50`. Only one position per symbol/magic is allowed, so direction changes occur only after the existing position closes.

Exit a long when the capped forecast falls to `+0.10` or lower. Exit a short when the capped forecast rises to `-0.10` or higher. Also exit a losing position when the latest closed D1 true range exceeds `4.0 * MedianTrueRange(252)`. New entries use a `3.0 * ATR(25)` hard stop.

Implementation note: the card's dynamic forecast risk multiplier (`abs(Forecast) / 2.0`, floor `0.25`) is not directly representable in the current single-symbol `QM_EntryRequest`, which has no per-order risk/lot field. This build preserves the signal, exits, ATR stop, and the required `RISK_FIXED` backtest sizing path.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ema_period` | 16 | 1-128 | Fast EMA period for the EWMAC forecast. |
| `strategy_slow_ema_period` | 64 | 2-256 | Slow EMA period for the EWMAC forecast; must exceed fast period. |
| `strategy_atr_period` | 25 | 1-128 | ATR period used for forecast normalization and hard-stop distance. |
| `strategy_forecast_cap` | 2.0 | 0.1-10.0 | Absolute cap applied to the raw forecast. |
| `strategy_entry_forecast` | 0.50 | 0.01-2.0 | Forecast threshold for new long/short entries. |
| `strategy_exit_forecast` | 0.10 | 0.0-1.0 | Forecast buffer threshold for closing existing positions. |
| `strategy_atr_sl_mult` | 3.0 | 0.1-10.0 | Initial stop distance in ATR multiples. |
| `strategy_min_history_bars` | 300 | 80-1000 | Minimum D1 history gate before signals are valid. |
| `strategy_reentry_cooldown_bars` | 5 | 0-60 | Closed D1 bars to wait after a position closes before re-entry. |
| `strategy_median_tr_lookback` | 252 | 20-1000 | Lookback for the emergency true-range median. |
| `strategy_emergency_tr_mult` | 4.0 | 1.0-20.0 | Emergency true-range multiple that triggers a losing-position exit. |
| `strategy_max_spread_points` | 200 | 0-10000 | Entry-only spread cap in points; zero modeled spread is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX D1 trend exposure.
- `GBPUSD.DWX` - liquid major FX D1 trend exposure.
- `USDJPY.DWX` - liquid major FX D1 trend exposure.
- `AUDUSD.DWX` - liquid major FX D1 trend exposure.
- `XAUUSD.DWX` - liquid metal D1 trend exposure.
- `NDX.DWX` - liquid index D1 trend exposure.
- `WS30.DWX` - liquid index D1 trend exposure.
- `GDAXI.DWX` - liquid non-US index D1 trend exposure.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no verified DWX history or routing.
- Intraday-only microstructure symbols - this card is a D1 continuous forecast model.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 24 |
| Typical hold time | several days to weeks |
| Expected drawdown profile | Trend-following whipsaw losses in sideways regimes, with ATR hard stops. |
| Regime preference | trend / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1a059d6d-84fa-5d0c-94c5-86dd0481637c`
**Source type:** book / companion spreadsheet
**Pointer:** Robert Carver, "Leveraged Trading", Harriman House, 2019, chapter 10 position adjustment; companion resources at `https://www.systematicmoney.org/leveraged-trading-resources`
**R1-R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9510_carver-forecast.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% - 0.5% |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-07 | Initial build from approved card | build commit pending |
