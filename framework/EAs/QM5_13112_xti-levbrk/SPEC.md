# QM5_13112_xti-levbrk - Strategy Spec

**EA ID:** QM5_13112  
**Slug:** `xti-levbrk`  
**Strategy ID:** `KRISTOUFEK-XTI-LEV-2014_S02`  
**Source:** `KRISTOUFEK-ENERGY-LEV-2014`  
**Author:** Codex  
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a once-weekly-capped WTI downside continuation on
`XTIUSD.DWX` H4. The prior completed D1 candle must be a large bearish impulse
relative to ATR measured before the impulse. During the immediately following
broker D1 session, a completed bearish H4 candle must close below the impulse
low before the EA enters short.

The stop sits above the impulse high plus an ATR buffer, target is 1.75R, and
remaining exposure closes after 48 hours. Runtime uses native OHLC, ATR,
spread, calendar, and V5 state only. It does not run DCCA/DMCA, GARCH, Hurst
estimation, an external feed, or ML.

## 2. Parameters

| Parameter | Default | Sweep | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14, 20, 30 | Pre-impulse D1 ATR normalization |
| `strategy_min_impulse_atr` | 0.60 | 0.50-0.75 | Minimum bearish D1 body |
| `strategy_min_impulse_range_atr` | 0.75 | 0.60-1.00 | Minimum impulse range |
| `strategy_max_impulse_range_atr` | 2.75 | 2.25-3.25 | Maximum impulse range |
| `strategy_max_impulse_close_location` | 0.35 | 0.25-0.40 | Weak D1 close location |
| `strategy_break_buffer_atr` | 0.00 | 0.00-0.10 | H4 break below impulse low |
| `strategy_max_confirm_close_location` | 0.35 | 0.25-0.40 | Weak H4 confirmation close |
| `strategy_stop_buffer_atr` | 0.10 | 0.05-0.20 | Stop beyond impulse high |
| `strategy_rr_target` | 1.75 | 1.50-2.00 | Target in actual risk units |
| `strategy_max_hold_hours` | 48 | 24, 48, 72 | Stale-position exit |
| `strategy_max_spread_points` | 1200 | 800-1800 | Entry spread cap |

The negative-only D1 setup, next-session H4 confirmation, short-only side,
weekly gate, and lack of calendar/compression/mean-reversion filters are locked.

## 3. Symbol Universe

- `XTIUSD.DWX` only, registered magic slot 0.
- No second leg, basket manifest, foreign symbol, or external series.

## 4. Timeframe

- Host: H4.
- Reference: prior completed D1 impulse and ATR shifted before that impulse.
- Entry evaluation: `QM_IsNewBar()` on H4.

## 5. Expected Behaviour

- Expected density: 6-14 completed trades/year before Q02 validation.
- Direction: short only after a negative D1 impulse and later downside close.
- Typical hold: one to twelve H4 bars, capped by structural SL, 1.75R TP,
  48-hour stop, or framework Friday flatten.
- Return driver: negative-shock crude-oil downside expansion, not RSI,
  seasonality, slow symmetric momentum, compression, or shock fading.

## 6. Source Citation

Kristoufek, Ladislav. "Leverage effect in energy futures." *Energy Economics*
45 (2014), 1-9. DOI `10.1016/j.eneco.2014.06.009`.

The full paper reports a standard WTI return/volatility leverage effect,
stronger at longer scales, but no long-range cross-correlation. It does not
validate this H4 short breakout; Q02+ is the only strategy evidence.

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

- Card of record: `strategy-seeds/cards/xti-levbrk_card.md`.
- Approved build input: `artifacts/cards_approved/QM5_13112_xti-levbrk.md`.
- Build result: `artifacts/qm5_13112_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13112_q02_enqueue_20260710.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | initial build | negative-impulse WTI downside sleeve |

