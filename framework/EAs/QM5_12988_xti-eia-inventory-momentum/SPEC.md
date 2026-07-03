# QM5_12988_xti-eia-inventory-momentum - Strategy Spec

**EA ID:** QM5_12988
**Slug:** `xti-eia-inventory-momentum`
**Source:** `EIA-WPSR-2W-MOM-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
On each new D1 bar it treats the prior closed bar as a WPSR proxy only when the
broker-calendar day is Wednesday or Thursday. It then finds the prior weekly
WPSR proxy bar. Entries require both WPSR proxy bars to have the same
close-minus-open direction, the latest close to move beyond the prior event
close by an ATR-scaled amount, and the latest close to confirm a D1 Donchian
breakout in the same direction with SMA trend alignment.

The strategy is intentionally distinct from existing WTI event sleeves:

- `QM5_10319_eia-oil-momo`: intraday M30 release-window momentum.
- `QM5_12579_eia-wti-aftershock`: one-bar event aftershock.
- `QM5_12590_eia-wti-wpsr-fade`: one-bar event exhaustion fade.
- `QM5_12592_eia-wti-prewpsr`: pre-event positioning.
- `QM5_12752_eia-wti-wpsr-idbrk`: post-event inside-bar breakout.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14-30 | ATR period for event move and stop |
| `strategy_trend_period` | 80 | 50-120 | SMA trend filter |
| `strategy_breakout_lookback` | 20 | 15-30 | Donchian lookback excluding the signal bar |
| `strategy_event_search_bars` | 10 | 7-12 | Search window for the previous WPSR proxy bar |
| `strategy_min_event_gap_days` | 4 | 3-5 | Minimum calendar gap between event bars |
| `strategy_max_event_gap_days` | 10 | 8-12 | Maximum calendar gap between event bars |
| `strategy_min_event_move_atr` | 0.50 | 0.25-0.75 | Required event-to-event close move in ATR units |
| `strategy_atr_sl_mult` | 2.75 | 2.0-3.5 | Stop distance multiplier |
| `strategy_max_hold_days` | 10 | 7-15 | Calendar-day time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.
- `XTIUSD.DWX` is present in `framework/registry/dwx_symbol_matrix.csv`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 5-12.
- Typical hold: several D1 bars to about two weeks.
- Regime preference: persistent crude-oil repricing across consecutive weekly
  EIA information cycles.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration, "Weekly Petroleum Status Report", URL
https://www.eia.gov/petroleum/supply/weekly/. Release schedule URL
https://www.eia.gov/petroleum/supply/weekly/schedule.php. Structural
petroleum-market supplement:
https://www.eia.gov/energyexplained/oil-and-petroleum-products/.

The sources define the official information cycle and crude-oil market
structure only. Runtime uses Darwinex MT5 OHLC and broker calendar data only.

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

