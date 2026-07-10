# QM5_13110_xng-svol-brk - Strategy Spec

**EA ID:** QM5_13110  
**Slug:** `xng-svol-brk`  
**Strategy ID:** `SUENAGA-XNG-SEASVOL-2008_S01`  
**Source:** `SUENAGA-XNG-SEASVOL-2008`  
**Author:** Codex  
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a once-weekly natural-gas volatility expansion on
`XNGUSD.DWX` H4. It trades only during the source's broad volatility windows,
May-September and November-January. A completed H4 bar must close beyond the
immediately prior completed D1 range with an ATR-scaled range and strong close.
The stop sits beyond the opposite D1 extreme, the target is fixed at 1.75R,
and remaining exposure closes after 36 hours or outside the source months.

The runtime is Darwinex-native OHLC, spread, ATR, broker calendar, and V5 state.
It does not run the source's POTS/GARCH/Kalman model and does not read futures
contracts, storage, weather, EIA, volume, open interest, CSV, API, or ML data.

## 2. Parameters

| Parameter | Default | Sweep | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14, 20, 30 | D1 ATR normalization |
| `strategy_min_reference_range_atr` | 0.20 | 0.15-0.30 | Minimum prior-D1 range |
| `strategy_max_reference_range_atr` | 2.50 | 2.00-3.00 | Maximum prior-D1 range |
| `strategy_min_signal_range_atr` | 0.30 | 0.20-0.45 | Minimum H4 impulse range |
| `strategy_break_buffer_atr` | 0.05 | 0.00-0.10 | Close-break buffer |
| `strategy_min_close_location` | 0.65 | 0.60-0.75 | Strong-close gate |
| `strategy_stop_buffer_atr` | 0.10 | 0.05-0.20 | Stop beyond D1 extreme |
| `strategy_rr_target` | 1.75 | 1.50-2.00 | Target in actual risk units |
| `strategy_max_hold_hours` | 36 | 24, 36, 48 | Stale-position exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

The calendar windows, symmetric direction, one accepted entry per broker week,
and absence of SMA/compression/inside-bar gates are locked.

## 3. Symbol Universe

- `XNGUSD.DWX` only, registered magic slot 0.
- No foreign symbol and no basket manifest.

## 4. Timeframe

- Host: H4.
- Reference: immediately prior completed D1 range and D1 ATR.
- Entry evaluation: `QM_IsNewBar()` on H4.

## 5. Expected Behaviour

- Expected density: 10-24 completed trades/year before Q02 validation.
- Direction: symmetric long/short, discovered by the completed H4 close.
- Typical hold: one to nine H4 bars, capped by structural SL, 1.75R TP,
  36-hour stop, outside-window close, or framework Friday flatten.
- Return driver: storage/demand-linked seasonal volatility expansion, not
  cumulative RSI, a fixed calendar direction, or a price-level trend filter.

## 6. Source Citation

Suenaga, Hiroaki; Smith, Aaron; and Williams, Jeffrey C. "Volatility Dynamics
of NYMEX Natural Gas Futures Prices." *Journal of Futures Markets* 28(5), 2008,
438-463. DOI `10.1002/fut.20317`.

The full paper establishes natural-gas volatility seasonality and hedge
implications, not a directional breakout return. The H4/D1 rule is the card's
explicit testable mechanization; no source performance is imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Q02+ backtest | `RISK_FIXED` | 1000 |
| Live | not configured | n/a |

`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, one position per magic, no grid,
martingale, pyramiding, partial close, trailing stop, or live setfile. This
build must not touch the portfolio gate, a deploy manifest, `T_Live`, or
AutoTrading.

## Evidence

- Card of record: `strategy-seeds/cards/xng-svol-brk_card.md`.
- Approved build input: `artifacts/cards_approved/QM5_13110_xng-svol-brk.md`.
- Build result: `artifacts/qm5_13110_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13110_q02_enqueue_20260710.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | initial build | source-seasonal XNG volatility sleeve |

