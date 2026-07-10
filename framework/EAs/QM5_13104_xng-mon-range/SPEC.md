# QM5_13104_xng-mon-range - Strategy Spec

**EA ID:** QM5_13104
**Slug:** `xng-mon-range`
**Strategy ID:** `MU-XNG-MONVOL-2007_S01`
**Source:** `MU-XNG-MONVOL-2007`
**Author:** Codex
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a once-weekly natural-gas Monday volatility expansion on
`XNGUSD.DWX` H4. Friday's completed D1 range must be compressed relative to
D1 ATR, Monday must open inside that Friday range, and a completed Monday H4
bar must close beyond the Friday extreme. Entry follows the confirmed break,
the stop sits beyond the opposite Friday extreme, the target is fixed at 2R,
and any remaining position closes when Monday ends or after 30 hours.

The runtime is Darwinex-native OHLC, spread, ATR, broker calendar, and V5
framework state only. It does not run the source's GARCH model.

## 2. Parameters

| Parameter | Default | Sweep | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 20 | 14, 20, 30 | D1 ATR normalization period |
| `strategy_min_friday_range_atr` | 0.15 | 0.10-0.25 | Minimum valid Friday range |
| `strategy_max_friday_range_atr` | 0.85 | 0.65-1.05 | Friday compression ceiling |
| `strategy_break_buffer_atr` | 0.05 | 0.00-0.10 | Monday close-break buffer |
| `strategy_min_close_location` | 0.60 | 0.55-0.70 | H4 breakout close-location gate |
| `strategy_stop_buffer_atr` | 0.10 | 0.05-0.20 | Stop buffer beyond Friday range |
| `strategy_rr_target` | 2.00 | 1.50-2.50 | Target in actual entry risk units |
| `strategy_max_hold_hours` | 30 | 18, 24, 30 | Stale-position exit |
| `strategy_max_spread_points` | 2500 | 1500-3500 | Entry spread cap |

## 3. Symbol Universe

- `XNGUSD.DWX` only, registered magic slot 0.
- No foreign symbol and no basket manifest.

## 4. Timeframe

- Host timeframe: H4.
- Structural reference: completed/current D1 bars for Friday range and Monday
  open; D1 ATR for normalization.
- Entry gate: `QM_IsNewBar()` on H4.

## 5. Expected Behaviour

- Expected density: about 8-20 trades/year before Q02 validation.
- Direction: symmetric long/short.
- Typical hold: one to six H4 bars, capped by structural SL, 2R TP, Tuesday
  flatten, 30-hour stop, or framework Friday close.
- Regime preference: compressed Friday followed by Monday information-driven
  natural-gas range expansion.
- It is not cumulative RSI2, a fixed weekday-direction anomaly, a weekend gap,
  a storage event, long-horizon trend/reversal, or a basket.

## 6. Source Citation

Mu, Xiaoyi. "Weather, Storage, and Natural Gas Price Dynamics: Fundamentals and
Volatility." *Energy Economics* 29(1), 2007, pp. 46-63.
DOI `10.1016/j.eneco.2006.04.003`. Complete primary-author working paper,
December 2004, pp. 1-30 and Tables 1-5.

The source establishes a statistically significant Monday conditional-
volatility effect, not a trading rule. The Friday-compression/H4 expansion rule
is the card's explicit testable mechanization; no source performance is
imported.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Q02+ backtest | `RISK_FIXED` | 1000 |
| Live | not configured by this build | n/a |

`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, one position per magic, no grid,
martingale, pyramiding, reversal sizing, partial close, or live setfile. This
build must not touch the portfolio gate, a deploy manifest, `T_Live`, or
AutoTrading.

## Evidence

- Approved card: `strategy-seeds/cards/approved/QM5_13104_xng-mon-range_card.md`.
- Build result: `artifacts/qm5_13104_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13104_q02_enqueue_20260710.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | initial build | mission-directed structural XNG sleeve |

