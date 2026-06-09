# QM5_10115_tv-ma-scalper-relief - Strategy Spec

**EA ID:** QM5_10115
**Slug:** `tv-ma-scalper-relief`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades long relief rallies on M15 after a bearish moving-average stack is already in place. It opens when SMA(9) crosses above SMA(50) while SMA(50) is below SMA(100) and SMA(100) is below SMA(200). It skips entries when the SMA(200) slope over the prior 20 bars is positive, and it exits when SMA(9) crosses above SMA(200) or when the position has been open for 96 M15 bars.

The stop is placed at the farther of 2 x ATR(14) below entry and the lowest low of the prior 20 bars. Entries are also skipped when the current spread is greater than 10% of the computed stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M15` | MT5 timeframe enum | Timeframe used for SMA, ATR, and hold-bar rules. |
| `strategy_sma_fast_period` | `9` | `> 0` | Fast SMA used for entry and exit crosses. |
| `strategy_sma_mid_period` | `50` | `> 0` | Mid SMA crossed by SMA(9) for entry. |
| `strategy_sma_slow_period` | `100` | `> 0` | Slow SMA in the bearish stack filter. |
| `strategy_sma_regime_period` | `200` | `> 0` | Long SMA used for bearish stack, slope filter, and exit cross. |
| `strategy_sma_slope_bars` | `20` | `> 0` | Bars used to detect whether SMA(200) slope is positive. |
| `strategy_atr_period` | `14` | `> 0` | ATR period for the volatility stop. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | ATR multiplier for the volatility stop. |
| `strategy_structure_lookback` | `20` | `> 0` | Prior-bar lookback for the structure stop. |
| `strategy_max_hold_bars` | `96` | `> 0` | Time-stop duration in signal timeframe bars. |
| `strategy_max_spread_stop_frac` | `0.10` | `>= 0` | Maximum spread as a fraction of stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed FX symbol with DWX matrix coverage.
- `GBPUSD.DWX` - Card-listed FX symbol with DWX matrix coverage.
- `XAUUSD.DWX` - Card-listed gold symbol with DWX matrix coverage.
- `GDAXI.DWX` - Available DWX DAX custom symbol used for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- Any other unregistered symbol - magic resolution is limited to the registered basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Up to 96 M15 bars, about 24 hours, unless the SMA(9)/SMA(200) exit triggers first. |
| Expected drawdown profile | Fixed-risk long-only scalper with ATR/structure stop and spread filter. |
| Regime preference | Mean-reversion relief rallies inside bearish moving-average regimes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView public script`
**Pointer:** `https://www.tradingview.com/script/PfBSgqMw-Moving-Average-Scalper/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10115_tv-ma-scalper-relief.md`

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
| v1 | 2026-06-09 | Initial build from card | d72a76ad-79e4-4808-ad3f-3d2292d32e7c |
