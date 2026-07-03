# QM5_12998_xti-spr-relief - Strategy Spec

**EA ID:** QM5_12998
**Slug:** `xti-spr-relief`
**Source:** `EIA-SPR-RELIEF-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency WTI SPR policy-buffer sleeve on
`XTIUSD.DWX`. On each new D1 bar it inspects the prior completed D1 bar only
when that bar was Wednesday or Thursday, the usual EIA WPSR and SPR stock
release proxy window.

The EA trades only failed 126-D1 extremes. It shorts when an official
release-window bar probes above the prior 126-D1 high, rejects back inside the
level, closes in the lower part of the bar, and remains stretched above a slow
SMA. It buys the symmetric failed-low setup. Positions use ATR hard stop,
slow-SMA mean-reversion exit, max-hold exit, standard V5 news and Friday close,
and no runtime external data.

This is not `QM5_12755_wti-spr-refill-bounce`: that older sleeve is long-only
and tied to a fixed DOE refill-zone price. `QM5_12998` has no fixed USD policy
zone and trades both failed highs and failed lows around the weekly SPR stock
disclosure window.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for event sizing and stop |
| `strategy_mean_period` | 126 | 84-160 | Slow SMA policy-buffer anchor |
| `strategy_extreme_lookback` | 126 | 84-180 | Prior D1 high/low lookback excluding the signal bar |
| `strategy_min_range_atr` | 0.90 | 0.75-1.25 | Minimum event-bar range in ATR units |
| `strategy_min_probe_atr` | 0.20 | 0.10-0.40 | Required breach beyond prior high/low in ATR units |
| `strategy_min_reject_atr` | 0.25 | 0.10-0.45 | Required close back inside prior high/low in ATR units |
| `strategy_reject_close_ratio` | 0.45 | 0.35-0.50 | Close-location threshold for rejection side |
| `strategy_min_stretch_atr` | 0.75 | 0.50-1.25 | Minimum close-to-SMA stretch in ATR units |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | ATR stop distance |
| `strategy_max_hold_days` | 8 | 5-12 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.
- `XTIUSD.DWX` is present in `framework/registry/dwx_symbol_matrix.csv`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-8.
- Typical hold: several D1 bars, capped by slow-SMA reversion and max-hold
  guards.
- Regime preference: failed WTI extremes during the official weekly SPR/WPSR
  release window.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

- U.S. Energy Information Administration, "Weekly Petroleum Status Report",
  https://www.eia.gov/petroleum/supply/weekly/.
- U.S. Energy Information Administration, "Weekly U.S. Ending Stocks of Crude
  Oil in SPR",
  https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCSSTUS1.
- U.S. Department of Energy, "SPR Quick Facts",
  https://www.energy.gov/hgeo/opr/spr-quick-facts.

The sources define the official information cycle and SPR structural context.
Runtime uses Darwinex MT5 OHLC and broker calendar data only.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-03 | Initial build from card | Enqueue Q02 |
