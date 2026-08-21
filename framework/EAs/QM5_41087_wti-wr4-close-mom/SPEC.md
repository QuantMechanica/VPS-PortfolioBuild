# QM5_41087_wti-wr4-close-mom - Strategy Spec

**EA ID:** QM5_41087

**Slug:** `wti-wr4-close-mom`

**Strategy ID:** `CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026_S01`

**Source:** `CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-21

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
the four immediately completed, consecutive Monday-anchored broker weeks.
Each package must contain three to five sessions. Let `Oi`, `Hi`, `Li`, and
`Ci` be weekly OHLC and `Ri=Hi-Li`, with index zero the newest:

```text
body = ln(C0 / O0)
clv  = (C0 - L0) / R0
wr4  = R0 > R1 and R0 > R2 and R0 > R3

wr4 and body > 0 and clv > 0.75  => BUY
wr4 and body < 0 and clv < 0.25  => SELL
otherwise                         => FLAT
```

The current decision week is excluded. Range ties, equality at either CLV
threshold, zero body/range, invalid OHLC, nonconsecutive anchors, or
body/location disagreement consumes the week flat. The position uses one
fixed-risk budget and a frozen ATR hard stop, then exits next week.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 50 | bounded D1 weekly-OHLC buffer |
| `strategy_required_weeks` | 4 | exact consecutive completed weekly packages |
| `strategy_min_week_bars` | 3 | minimum completed sessions per week |
| `strategy_max_week_bars` | 5 | maximum completed sessions per week |
| `strategy_clv_upper` | 0.75 | strict long close-location boundary |
| `strategy_clv_lower` | 0.25 | strict short close-location boundary |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve the complete next-week hold |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Magic: `410870000`, governed slot-zero allocation.
- No signal, hedge, conversion, or external companion symbol is used.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: four consecutive completed Monday-anchored broker weeks.
- Trigger: newest week is strict widest-of-four and its own body agrees with
  its strict outer-quartile close location.
- Direction: follow the completed expansive week.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately five to eight completed positions per full post-warm-up year;
  Q02 retires below five.
- Symmetric WTI continuation only after an unusually expansive directional
  completed week.
- One fixed-risk position and one consumed attempt per broker week.
- The WTI carrier and mechanic do not prove decorrelation; Q09 alone owns
  realized portfolio correlation.

## 6. Source Citation

Crabel, T. (1990), *Day Trading with Short-Term Price Patterns and Opening
Range Breakout*, Traders Press.

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026/source.md`.

The sources supply WTI own-return-continuation and range-expansion lineages.
The exact weekly WR4/body/CLV conjunction is a disclosed QM hypothesis; no
source result transfers to this CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
The position has a frozen `3.5 * ATR(20,D1)` completed-bar stop. Both news
axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, external feed, retry,
scale-in, grid, martingale, pyramid, target, trail, break-even move, hedge,
reversal, or partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-21 | approved build-directory identity | source approval `40d5669ac`; deterministic registry reservation `3a6d5930f` |
| v1-card | 2026-08-21 | G0-approved execution contract | `strategy-seeds/cards/approved/QM5_41087_wti-wr4-close-mom_card.md` |
| v1-build | 2026-08-21 | deterministic implementation and Q01 validation | 10-test reference suite; strict compile/build PASS; static P1 PASS |
