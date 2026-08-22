# QM5_41115_wti-mthirdvote-mom - Strategy Spec

**EA ID:** QM5_41115

**Slug:** `wti-mthirdvote-mom`

**Strategy ID:** `MOP-WTI-MTHIRDVOTE-MOM-2026_S01`

**Source:** `MOP-WTI-MTHIRDVOTE-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-22

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker-calendar month,
reconstruct the two immediately preceding consecutive completed months. Each
must contain 17 through 23 unique completed sessions under one uniform
energy-label convention.

Use the parent month's chronological final close as the anchor and order all
newest-month closes chronologically. With `n` newest-month sessions, set
`a=floor(n/3)` and `b=floor(2n/3)`. Compute:

```text
block_1 = log(C[a-1] / parent_final)
block_2 = log(C[b-1] / C[a-1])
block_3 = log(C[n-1] / C[b-1])
```

Buy when at least two blocks are strictly positive and sell when at least two
are strictly negative. A zero block casts no vote. Invalid partitions,
malformed state, or no strict majority consume the month flat. Block
magnitudes do not weight the vote, and the full-month endpoint sign is not an
additional filter.

The shared boundary closes are anchors, not duplicated returns. The three
blocks therefore partition every adjacent completed close return from the
parent final close through the newest final close exactly once. The position
follows the strict block majority for one broker month, using one fixed-risk
budget and a frozen ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-month-bar execution window |
| `strategy_history_bars_d1` | 70 | bounded two-month D1 close buffer |
| `strategy_min_month_sessions` | 17 | minimum sessions per package |
| `strategy_max_month_sessions` | 23 | maximum sessions per package |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-month ownership |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline. The block count,
floor-third boundaries, zero handling, strict vote, magnitude-blind direction,
endpoint-filter absence, and hold are not parameters.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `411150000` (governed slot-0 allocation for `XTIUSD.DWX`).
- No signal, hedge, conversion, ratio, or external companion symbol exists.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two immediately completed consecutive broker-calendar months.
- Path: parent final close to every chronological newest-month close.
- Trigger: strict two-of-three sign majority across three exhaustive
  cumulative path blocks.
- Hold: until the first tick of the next normalized broker month, with a
  forty-day stale repair.

## 5. Expected Behaviour

- Approximately ten to twelve completed WTI positions per full post-warm-up
  year; Q02 retires below five.
- Symmetric direct-WTI monthly structural continuation after an internal path
  vote that can deliberately oppose the full-month endpoint direction.
- One fixed-risk position and one consumed attempt per broker month.
- Direct WTI supplies physical-energy exposure absent from the certified
  XAU/SP500/NDX/XNG book; Q09 alone owns realized portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-MTHIRDVOTE-MOM-2026/source.md`.

The paper supplies monthly own-price continuation lineage, one-month holding
tests, and explicit WTI membership. The within-month three-block vote is a
disclosed QM hypothesis; no paper or sibling result transfers to this
continuous-CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position sizing uses a frozen completed-bar
`3.5*ATR(20,D1)` stop through the V5 risk helper. Both news axes and Friday
close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or `T_Live` manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, current-month signal price,
alternate partition, daily-sign vote, endpoint-agreement filter, return-
magnitude weighting, external feed, retry, scale-in, grid, martingale,
pyramid, target, trail, break-even move, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-22 | approved build-directory identity | source approval `e3b7b5d15`; EA-ID reservation `9f2517a77`; Q00 card `7f476ea0b`; governed magic `a2dfeab7d` |
