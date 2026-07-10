# QM5_13103_xti-idnr4-brk - Strategy Spec

**EA ID:** QM5_13103
**Slug:** `xti-idnr4-brk`
**Strategy ID:** `CRABEL-WTI-IDNR4-2026_S01`
**Source:** `CRABEL-WTI-IDNR4-2026`
**Author:** Codex
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a low-frequency WTI ID/NR4 contraction breakout on
`XTIUSD.DWX` D1. The setup bar must be strictly inside its predecessor and
have the smallest high-low range of the latest four completed sessions. The
immediately following completed bar must close beyond the setup extreme; entry
occurs at market on the next D1 bar. Stops sit beyond the opposite setup
extreme, targets are fixed at 2R, and stale positions close after five days.

The runtime is Darwinex-native OHLC, spread, ATR, broker time, and V5 framework
state only.

## 2. Parameters

| Parameter | Default | Sweep | Meaning |
|---|---:|---|---|
| `strategy_nr_lookback` | 4 | 4 | Fixed ID/NR4 definition |
| `strategy_atr_period` | 20 | 14, 20, 30 | ATR normalization period |
| `strategy_min_setup_range_atr` | 0.15 | 0.10-0.25 | Minimum setup range in ATR units |
| `strategy_max_setup_range_atr` | 0.90 | 0.70-1.20 | Maximum setup range in ATR units |
| `strategy_break_buffer_atr` | 0.05 | 0.00-0.10 | Close-confirmation buffer |
| `strategy_min_break_close_location` | 0.60 | 0.55-0.70 | Breakout close-location threshold |
| `strategy_stop_buffer_atr` | 0.10 | 0.05-0.20 | Stop buffer beyond opposite setup extreme |
| `strategy_rr_target` | 2.00 | 1.50-2.50 | Profit target in actual entry risk units |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, registered magic slot 0.
- No foreign symbol and no basket manifest.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe references: none.
- Bar gate: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected density: about 8-18 trades/year before Q02 validation.
- Direction: symmetric long/short.
- Typical hold: one to five calendar days, capped by structural SL, 2R TP,
  max-hold close, or framework Friday flatten.
- Regime preference: daily WTI volatility contraction followed by immediate
  range expansion.
- This is not NR7, inside-week, calendar, inventory-event, ratio, carry, RSI,
  index, or metal logic.

## 6. Source Citation

Crabel, Toby. *Day Trading with Short-Term Price Patterns and Opening Range
Breakout*. Traders Press, 1990. ISBN 9780934380171. The ID/NR4 definition and
contraction-to-breakout lineage are primary; no source performance number is
imported.

Supplement: Crabel, Toby. "Playing the Opening Range Breakout, Part 1."
*Technical Analysis of Stocks & Commodities*, Vol. 6:9, pp. 337-339, 1988.

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

- Approved card: `strategy-seeds/cards/approved/QM5_13103_xti-idnr4-brk_card.md`.
- Build result: `artifacts/qm5_13103_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13103_q02_enqueue_20260710.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | initial build | mission-directed structural WTI sleeve |
