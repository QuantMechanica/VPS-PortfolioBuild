# QM5_41092_wti-wbody-dominance-mom - Strategy Spec

**EA ID:** QM5_41092

**Slug:** `wti-wbody-dominance-mom`

**Strategy ID:** `MOP-WTI-WBODY-DOMINANCE-MOM-2026_S01`

**Source:** `MOP-WTI-WBODY-DOMINANCE-MOM-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-21

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, aggregate the
OHLC of the exact immediately completed Monday-anchored broker week. The
package must contain three to five unique completed sessions under one uniform
energy-label convention.

Compute the absolute open-to-close real body and the complete high-low range.
Buy when `3*abs(close-open) > 2*(high-low)` and the completed body is positive;
sell when the same strict inequality holds and the body is negative. Threshold
equality, body equality, incomplete packages, nonadjacent anchors, and
malformed history consume the week flat. Hold one broker week with fixed-
dollar risk and a frozen completed-bar ATR hard stop.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_label_offset_seconds` | 86400 | uniform raw-to-energy-session label offset |
| `strategy_entry_lateness_minutes` | 180 | first-week-bar execution window |
| `strategy_history_bars` | 16 | bounded D1 weekly OHLC buffer |
| `strategy_required_weeks` | 1 | exact immediately completed package |
| `strategy_min_week_bars` | 3 | minimum sessions in the package |
| `strategy_max_week_bars` | 5 | maximum sessions in the package |
| `strategy_body_numerator` | 3 | exact left-side body multiplier |
| `strategy_range_multiplier` | 2 | exact right-side range multiplier |
| `strategy_atr_period` | 20 | completed-bar risk range |
| `strategy_atr_stop_mult` | 3.5 | frozen hard-stop distance |
| `strategy_stale_calendar_days` | 10 | stale-position repair |
| `strategy_max_spread_points` | 1500 | WTI entry cost guard |
| `qm_friday_close_enabled` | false | preserve full-week ownership |
| `qm_friday_close_hour_broker` | 21 | locked inactive framework input |

All strategy parameters are frozen for the Q02 baseline.

## 3. Symbol Universe

- Host and traded symbol: exact `XTIUSD.DWX`, D1.
- Symbol slot: 0.
- Magic: `410920000`.
- No signal, hedge, conversion, ratio, or companion symbol exists.

## 4. Timeframe And Lifecycle

- Signal and execution timeframe: D1.
- Formation: the exact immediately completed broker-week OHLC package; the
  current week contributes no signal price.
- Trigger: strict two-thirds real-body dominance plus strict own-body side.
- Hold: until the first tick of the next broker week, with ten-day stale repair.
- Attempt: persist the current Monday anchor before every fallible signal or
  execution gate; never retry within that week.

## 5. Expected Behaviour

- Approximately ten to twenty-five completed WTI positions per full post-
  warm-up year; Q02 owns the binding activity verdict.
- Symmetric direct-WTI weekly structural continuation after a directional
  completed auction.
- One fixed-risk position and one consumed attempt per broker week.
- A different carrier and mechanic do not establish decorrelation; Q09 owns
  the realized portfolio-correlation verdict.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

Canonical bounded source packet:
`strategy-seeds/sources/MOP-WTI-WBODY-DOMINANCE-MOM-2026/source.md`.

The paper supplies own-price continuation lineage and includes WTI. Weekly
OHLC aggregation and the strict two-thirds real-body condition are disclosed
QM hypotheses; no paper result transfers to this standalone continuous-CFD
implementation.

## 7. Risk Model And Scope

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
Position sizing uses a frozen completed-bar `3.5*ATR(20,D1)` stop through the
V5 risk helper. Both news axes and Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, AutoTrading,
`T_Live`, deploy manifest, portfolio admission, correlation waiver,
portfolio-gate change, parent-week comparison, current-week signal price,
separate wick gate, range rank, close-location threshold, external feed,
retry, scale-in, grid, martingale, pyramid, target, trail, break-even move, or
partial exit.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-21 | approved build-directory identity | source approval `06f2ed136`; source packet `069b4af00`; EA-ID reservation `1a02d01dd`; Q00 card `6d185e5bc`; planned governed magic `410920000` |
| v1 | 2026-08-21 | Q01 implementation PASS | exact one-week body-dominance implementation; 11 reference checks; strict compile 0/0; static build check 0 failures; backtest-only fixed-risk preset |
| v2 | 2026-08-21 | paced Q02 handoff | exact target-only `XTIUSD.DWX` D1 item `1c0dcc3a-69cf-46dc-96fb-e8f111c949ac` queued pending below CPU and terminal ceilings; no dispatcher or tester launch |
