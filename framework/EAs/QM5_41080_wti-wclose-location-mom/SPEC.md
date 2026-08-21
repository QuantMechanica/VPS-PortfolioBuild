# QM5_41080_wti-wclose-location-mom - Strategy Spec

**EA ID:** QM5_41080

**Slug:** `wti-wclose-location-mom`

**Strategy ID:** `MOP-WTI-WCLOSE-LOCATION-MOM-2026_S01`

**Source:** `MOP-WTI-WCLOSE-LOCATION-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-21

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
the immediately completed broker week and its consecutive parent week. Let
`C0`, `H0`, and `L0` be the newest week's final close, high, and low, and let
`C1` be the parent week's final close. Compute:

```text
r   = ln(C0 / C1)
clv = (C0 - L0) / (H0 - L0)

r > 0 and clv > 0.80  => BUY
r < 0 and clv < 0.20  => SELL
otherwise              => FLAT
```

Both completed weeks require three to five sessions and exact consecutive
Monday anchors. Equality, zero range, invalid endpoints, malformed history,
or return/location disagreement consumes the week flat. The position uses
one fixed-risk budget and a frozen ATR hard stop, then exits next week.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_entry_grace_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 30 | bounded D1 weekly-OHLC buffer |
| `strategy_required_weeks` | 2 | exact consecutive completed weekly packages |
| `strategy_min_week_bars` | 3 | minimum completed sessions per week |
| `strategy_max_week_bars` | 5 | maximum completed sessions per week |
| `strategy_clv_upper` | 0.80 | strict long close-location boundary |
| `strategy_clv_lower` | 0.20 | strict short close-location boundary |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_max_hold_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve the complete next-week hold |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are locked for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1, slot 0.
- Magic: `410800000`, governed slot-zero allocation.
- No signal, hedge, conversion, or external companion symbol is used.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: two consecutive completed Monday-anchored broker weeks.
- Trigger: newest strict close-to-close return sign agrees with the newest
  completed week's strict own-range close location.
- Direction: follow the completed week.
- Hold: until the first tick of the next broker week, with ten-day repair.

## 5. Expected Behaviour

- Approximately ten to twenty-five completed positions per full post-warm-up
  year; Q02 retires below five.
- Symmetric WTI continuation only after a directional completed-week close.
- One fixed-risk position and one consumed attempt per broker week.
- The WTI carrier and mechanic do not prove decorrelation; Q09 alone owns
  realized portfolio correlation.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-WCLOSE-LOCATION-MOM-2026/source.md`.

The source supplies own-return-sign continuation and WTI membership. The
weekly horizon and completed-week close-location confirmation are disclosed
QM hypotheses; no source result transfers to this CFD implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
The position has a frozen completed-bar ATR stop. Both news axes and Friday
close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, decorrelation
claim, correlation waiver, portfolio-gate change, external feed, retry,
scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-21 | approved build-directory identity | source approval `123294145`; deterministic registry reservation in the commit containing this spec |
| v1-card | 2026-08-21 | G0-approved execution contract | `strategy-seeds/cards/approved/QM5_41080_wti-wclose-location-mom_card.md` |
| v1-build | 2026-08-21 | deterministic implementation and Q01 validation | 10-test reference suite; strict compile/build PASS; static P1 PASS |
