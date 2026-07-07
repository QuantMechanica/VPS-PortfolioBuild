# QM5_13027_xti-cot-mom - Strategy Spec

**EA ID:** QM5_13027
**Slug:** `xti-cot-mom`
**Source:** `CFTC-COT-RELEASE-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency WTI positioning-window continuation sleeve
on `XTIUSD.DWX`. On the first D1 bar of a new broker week it inspects the
previous completed Friday D1 bar, used as the CFTC COT release-cadence proxy.

If that proxy bar is an ATR-sized directional displacement, closes near the
directional extreme, agrees with the SMA trend/slope filter, and breaks the
prior Donchian channel, the EA enters in the same direction. Positions use ATR
hard stop, trend-failure exit, favorable/adverse closed-bar exits, max-hold
exit, standard V5 news and Friday close, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_signal_return_pct` | 1.10 | 0.80-1.50 | Minimum absolute Friday log return |
| `strategy_min_atr_return_mult` | 0.55 | 0.40-0.75 | Minimum signal return relative to D1 ATR |
| `strategy_max_signal_return_pct` | 9.0 | 7.0-12.0 | Outlier guard for abnormal bars |
| `strategy_close_location_min` | 0.62 | 0.58-0.72 | Directional close-location confirmation |
| `strategy_signal_dow` | 5 | 5 | Required prior D1 signal day; default Friday |
| `strategy_channel_lookback` | 20 | 15-30 | Prior D1 Donchian window excluding the signal bar |
| `strategy_trend_period` | 80 | 50-120 | SMA trend filter period |
| `strategy_sma_slope_shift` | 5 | 3-10 | SMA slope comparison lag |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal scaling and stops |
| `strategy_atr_sl_mult` | 2.75 | 2.25-3.50 | ATR hard-stop distance |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position exit |
| `strategy_profit_close_atr_mult` | 1.40 | 1.00-2.00 | Favorable closed-bar exit threshold |
| `strategy_adverse_close_atr_mult` | 1.00 | 0.75-1.30 | Adverse closed-bar exit threshold |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-10.
- Typical hold: several D1 bars, capped by stale-position, trend-failure, and
  favorable/adverse closed-bar exits.
- Regime preference: CFTC COT release-window WTI trend continuation.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Commodity Futures Trading Commission, Commitments of Traders pages and
release schedule:

- https://www.cftc.gov/MarketReports/CommitmentsofTraders/index.htm
- https://www.cftc.gov/MarketReports/CommitmentsofTraders/ReleaseSchedule/index.htm

CME COT context is cited only as supplemental exchange context:

- https://www.cmegroup.com/tools-information/quikstrike/commitment-of-traders.html

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
