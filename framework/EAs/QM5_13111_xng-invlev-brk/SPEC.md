# QM5_13111_xng-invlev-brk - Strategy Spec

**EA ID:** QM5_13111  
**Slug:** `xng-invlev-brk`  
**Strategy ID:** `KRISTOUFEK-XNG-INVLEV-2014_S01`  
**Source:** `KRISTOUFEK-ENERGY-LEV-2014`  
**Author:** Codex  
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a once-weekly-capped natural-gas volatility expansion on
`XNGUSD.DWX` H4. A completed H4 setup bar must form a large positive move from
the current D1 open, normalized by the prior completed D1 ATR. The immediately
following completed H4 bar must then close beyond the setup range. A break of
the high enters long and a break of the low enters short; the original positive
impulse does not dictate direction.

Setup, confirmation, and entry bars must share one broker D1 session. The stop
sits beyond the opposite setup extreme, target is 1.50R, and remaining exposure
closes after 24 hours. Runtime uses native OHLC, ATR, spread, calendar, and V5
state only. It does not run DCCA/DMCA, GARCH, Hurst estimation, an external
feed, or ML.

## 2. Parameters

| Parameter | Default | Sweep | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14, 20, 30 | Prior-D1 ATR normalization |
| `strategy_min_impulse_atr` | 0.75 | 0.60-1.00 | Positive move from D1 open |
| `strategy_min_setup_range_atr` | 0.35 | 0.25-0.50 | Minimum setup H4 range |
| `strategy_max_setup_range_atr` | 2.50 | 2.00-3.00 | Maximum setup H4 range |
| `strategy_min_setup_close_location` | 0.65 | 0.60-0.75 | Strong positive setup close |
| `strategy_break_buffer_atr` | 0.05 | 0.00-0.10 | Confirmation range-break buffer |
| `strategy_min_confirm_close_location` | 0.60 | 0.55-0.70 | Strong confirmation close |
| `strategy_stop_buffer_atr` | 0.10 | 0.05-0.20 | Stop beyond setup extreme |
| `strategy_rr_target` | 1.50 | 1.25-1.75 | Target in actual risk units |
| `strategy_max_hold_hours` | 24 | 16, 24, 32 | Stale-position exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

The positive-only setup, separate confirmation, symmetric direction,
same-session rule, and one accepted entry per broker week are locked.

## 3. Symbol Universe

- `XNGUSD.DWX` only, registered magic slot 0.
- No second leg, basket manifest, foreign symbol, or external series.

## 4. Timeframe

- Host: H4.
- Reference: current D1 open and prior completed D1 ATR.
- Entry evaluation: `QM_IsNewBar()` on H4.

## 5. Expected Behaviour

- Expected density: 8-20 completed trades/year before Q02 validation.
- Direction: symmetric long/short, discovered by the confirmation close.
- Typical hold: one to six H4 bars, capped by structural SL, 1.50R TP,
  24-hour stop, or framework Friday flatten.
- Return driver: positive-return-conditioned natural-gas volatility, not RSI,
  calendar direction, low-vol momentum, or shock fading.

## 6. Source Citation

Kristoufek, Ladislav. "Leverage effect in energy futures." *Energy Economics*
45 (2014), 1-9. DOI `10.1016/j.eneco.2014.06.009`.

The full paper reports an inverse natural-gas leverage effect, weak magnitude,
and no long-range cross-correlation. Carnero and Perez (2019), DOI
`10.1016/j.eneco.2017.12.029`, is retained as a replication caveat. Neither
paper validates this H4 breakout; Q02+ is the only strategy evidence.

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

- Card of record: `strategy-seeds/cards/xng-invlev-brk_card.md`.
- Approved build input:
  `artifacts/cards_approved/QM5_13111_xng-invlev-brk.md`.
- Build result: `artifacts/qm5_13111_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13111_q02_enqueue_20260710.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | initial build | inverse-leverage XNG volatility sleeve |

