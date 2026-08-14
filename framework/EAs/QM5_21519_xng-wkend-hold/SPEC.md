# QM5_21519_xng-wkend-hold - Strategy Spec

**EA ID:** QM5_21519
**Slug:** `xng-wkend-hold`
**Source:** `TGIF-XNG-WEEKEND-2017_S04`
**Author of this spec:** Codex
**Last revised:** 2026-08-14

## 1. Strategy Logic

This EA implements one low-frequency natural-gas weekend-information sleeve
on `XNGUSD.DWX`. It consumes at most one attempt per framework broker week on
the genuine Friday 21:00 H1 boundary, buys XNG with fixed-dollar risk, holds
through the closed-market weekend, and closes at the matching Monday 21:00
cutoff. The first Tuesday-through-Thursday tick repairs a missed Monday exit,
and 96 elapsed hours is the absolute stale limit.

The source paper reports positive Monday-labelled natural-gas close-to-close
returns; EIA supplies weather-sensitive demand context. The exact H1 cutoff,
Darwinex CFD translation, ATR stop, and lifecycle are falsifiable QM choices.
This differs from `QM5_12567` cumulative-RSI pullback, Monday-open weekday
systems, and realized Monday-gap systems because the position is established
before and deliberately held through the closed-market interval.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_entry_hour_broker` | 21 | 21 | Friday H1 entry boundary |
| `strategy_entry_grace_minutes` | 5 | 5 | Maximum late-attach delay |
| `strategy_exit_hour_broker` | 21 | 21 | Monday matching-cutoff exit |
| `strategy_atr_period_d1` | 20 | 20 | Completed-D1 ATR period |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_hours` | 96 | 96 | Absolute stale guard |
| `strategy_max_spread_points` | 1000 | 1000 | Entry spread ceiling |

All parameters, weekdays, long-only direction, weekly attempt state, fixed
risk, no-target lifecycle, and later-week repair are locked. There is no
baseline sweep.

## 3. Symbol Universe

- `XNGUSD.DWX` only, slot 0, magic `215190000`.
- No companion symbol, hedge leg, external file, API, weather series, storage
  number, futures curve, portfolio state, or analyst forecast is used.

## 4. Timeframe

- Host and decision clock: H1.
- Risk estimator: completed D1 `ATR(20)` at shift 1.
- Attempt key: current framework `PERIOD_W1` start, persisted before fallible
  entry gates.

## 5. Expected Behaviour

- Maximum cadence: one consumed setup per broker week.
- Expected completed trades: approximately 45-51/year as a sequencing prior;
  Q02 retires the candidate below five/year.
- Direction: long only from Friday 21:00 through Monday 21:00.
- Exit: Monday cutoff, first later-week repair tick, 96 hours, malformed-state
  repair, broker hard stop, or framework kill switch.
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## 6. Source Citation

Hoelscher, Seth A., Cedric L. Mbanga, and Walt A. Nelson (2017), "TGIF? The
Weekend Effect in Energy Commodities," *Journal of Finance Issues* 16(1),
47-68, DOI `10.58886/jfi.v16i1.2264`; U.S. Energy Information Administration,
"Factors affecting natural gas prices."

The complete governed parent reviews and translation boundary are preserved
in `strategy-seeds/sources/TGIF-EIA-XNG-WKEND-2026/source.md`. No source
performance or correlation statistic is imported into QM.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | `RISK_FIXED` | 1000 |
| Backtest percentage risk | `RISK_PERCENT` | 0 |
| Backtest portfolio weight | `PORTFOLIO_WEIGHT` | 1 |
| Live, if ever approved later | `RISK_PERCENT` | separate OWNER portfolio decision |

The framework Friday flatten is deliberately disabled because weekend
exposure defines the signal. Risk is bounded by one position per magic, a
frozen `3.5 * ATR(20,D1)` server stop, Monday/later-week/96-hour closure, the
framework kill switch, and fail-closed identity/history/quote checks. Weekend
gap-through-stop risk remains and is a first-order Q02 kill risk.

This is a non-live build. It creates no live/demo/shadow/stress preset and has
no deploy, portfolio-admission, `T_Live`, AutoTrading, or gate-change authority.
