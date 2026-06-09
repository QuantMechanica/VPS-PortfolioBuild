# QM5_10192_tv-ma922-trail - Strategy Spec

**EA ID:** QM5_10192
**Slug:** `tv-ma922-trail`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades M5 and M15 index bars when the 9-period simple moving average crosses the 22-period simple moving average on the last closed bar. A long also requires the close to break the prior swing high by at least 0.5 ATR(14), candle body to be at least half of the candle range, tick volume to exceed its 20-bar average, and RSI(14) to be above 50; shorts mirror those conditions below the swing low with RSI below 50. The initial stop is the larger of 1.5 percent of entry price or 1.0 ATR(14). Open positions are trailed by 1.5 percent of average entry price and closed early on an opposite 9/22 cross.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ma_period` | 9 | `>= 1` and `< slow` | Fast moving average period used for cross entries and opposite-cross exits. |
| `strategy_slow_ma_period` | 22 | `> fast` | Slow moving average period used for cross entries and opposite-cross exits. |
| `strategy_atr_period` | 14 | `>= 1` | ATR period for breakout distance and the ATR component of the initial stop. |
| `strategy_rsi_period` | 14 | `>= 1` | RSI period for the frozen-on momentum filter. |
| `strategy_volume_sma_period` | 20 | `>= 1` | Tick-volume average lookback for the frozen-on volume filter. |
| `strategy_swing_lookback_bars` | 20 | `>= 1` | Recent structure window for swing high and swing low breakout confirmation. |
| `strategy_breakout_atr_mult` | 0.5 | `> 0` | Minimum distance beyond the recent swing level, expressed in ATR. |
| `strategy_min_body_pct` | 0.5 | `> 0` | Minimum candle body as a fraction of full candle range. |
| `strategy_initial_stop_pct` | 1.5 | `> 0` | Percent-of-entry component of the initial stop distance. |
| `strategy_initial_atr_mult` | 1.0 | `> 0` | ATR component of the initial stop distance. |
| `strategy_trailing_stop_pct` | 1.5 | `> 0` | Percent-of-entry trailing stop distance, moved only in the profitable direction. |
| `strategy_max_spread_stop_frac` | 0.15 | `>= 0` | Maximum spread as a fraction of the candidate initial stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index CFD; fits the card's DWX index-CFD port of the BANKNIFTY source instrument.
- `GDAXI.DWX` - DAX index custom symbol; matrix-valid replacement for the card's unavailable `GER40.DWX` label.
- `WS30.DWX` - Dow 30 index CFD; fits the liquid index-CFD basket.
- `SP500.DWX` - S&P 500 custom symbol; valid for backtest registration and included by the card's DWX index-CFD port.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Any unregistered symbol - this EA relies on active magic-number rows for the symbols above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` and `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday to multi-bar, governed by the 1.5 percent trailing stop or opposite cross |
| Expected drawdown profile | Fixed-risk, one-position-per-magic trend/breakout drawdown profile |
| Regime preference | Trend-following breakout with volatility expansion confirmation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script page
**Pointer:** TradingView script `9:22 5 MIN 15 MIN BANKNIFTY`, author `ashokkumarsand`, published 2023-06-04, `https://www.tradingview.com/script/5MQm4L0J-9-22-5-MIN-15-MIN-BANKNIFTY/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10192_tv-ma922-trail.md`

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
| v1 | 2026-06-09 | Initial build from card | d08c35c3-5e27-41ac-9d09-c52c3530a8e1 |
