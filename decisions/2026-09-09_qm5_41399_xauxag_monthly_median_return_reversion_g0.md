# QM5_41399 XAU/XAG Monthly Median-Return Reversion — G0 Decision

- Date: 2026-09-09
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- Card: `strategy-seeds/cards/approved/QM5_41399_xauxag-medret-rv_card.md`
- EA ID: `QM5_41399`
- Slug: `xauxag-medret-rv`
- Strategy ID: `SCHWEIKERT-CME-MOP-XAUXAG-MEDRET-RV-20260909_S01`
- Source ID: `SCHWEIKERT-CME-MOP-XAUXAG-MEDRET-RV-20260909`
- Host / slot 0: `XAUUSD.DWX`, D1, intended magic `413990000`
- Second leg / slot 1: `XAGUSD.DWX`, D1, intended magic `413990001`

## Source Decision

The source approval was committed before extraction at `a68d6ec421`. The
bounded packet preserves peer-reviewed gold/silver relationship evidence,
official CME spread construction, and a complete-read peer-reviewed monthly-
return source with durable retrieval evidence. The exact ordinary-median
relative-return reversal conjunction and continuous-CFD implementation remain
untested translations.

R1 is `PASS_WITH_MEDIAN_DIRECTION_AND_CFD_TRANSLATION_RISK`. No source or
sibling return, significance, density, neutrality, cost, drawdown, CFD-
equivalence, or correlation claim transfers.

## Mechanical Decision

R2 is `PASS`. On the first genuine synchronized broker-month D1 boundary the
card consumes the month before fallible gates, reconstructs thirteen
consecutive completed XAU/XAG monthly endpoints, calculates twelve adjacent
gold-minus-silver log-ratio changes, sorts all twelve changes, and takes the
ordinary even median from indexes five and six.

It sells XAU/buys XAG only above `+1e-12`, buys XAU/sells XAG only below
`-1e-12`, and consumes the epsilon interior flat. Equal target notionals must
match within 20%. Two frozen `3.5*ATR(20,D1)` stops share one aggregate fixed-
dollar budget; failed second-leg submission immediately flattens leg one. The
package closes at the next broker-month boundary; 40 days is stale repair.
There is no optimization surface or retry.

## Data And Determinism

R3 is `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_RISK`. Registered native
XAU/XAG D1 history, broker time, quotes, symbol metadata, positions, deals,
and terminal-global attempt state provide every runtime field.

R4 is `PASS`. The signal uses dates, completed prices, logarithms, sorting,
arithmetic, and comparisons; ATR is risk plumbing only. No trained output,
banned signal component, external runtime feed, grid, martingale, scale-in,
or pyramid is permitted.

## Non-Duplicate Decision

The pre-allocation checker found no exact identity across 4,879 registry rows
and 1,490 cards; its missing configured Wiki root is explicit. Manual review
separates the three fuzzy results and the closest median family:

- `QM5_41389` sorts four chronological three-change means, not twelve raw
  changes;
- `QM5_41356` uses a two-per-tail Winsorized mean;
- `QM5_41357` uses that Winsorized statistic on XTI/XNG;
- `QM5_20263` trades current ratio-level deviation from median/MAD;
- `QM5_41104` compares old-six and recent-six medians; and
- `QM5_20269` follows the raw-return median on outright WTI.

The result is
`DISTINCT_XAUXAG_ORDINARY_MONTHLY_RETURN_MEDIAN_REVERSION_AFTER_FAMILY_REVIEW`.

## Portfolio Intent And Falsification

This opposed-leg gold/silver relative-value package is intended to reduce the
common outright-metal factor and add a distinct commodity relationship to the
XAU/SP500/NDX/XNG book. Market-neutral-style construction is not a realized
correlation result; unchanged Q09 alone owns portfolio overlap.

Q02 retires on zero trades, fewer than five completed packages in any full
post-warm-up year, nonpositive governed economics, or any clock,
synchronization, endpoint, return, sort, median, side, attempt, notional,
risk, stop, spread, atomicity, lifecycle, or determinism defect. No parameter
or mechanic may change after results to rescue it.

## Authorized Scope

This approval permits deterministic two-slot magic allocation, one branch-
only V5 build, one exact logical-basket `RISK_FIXED` backtest setfile plus
required per-leg sets, strict compile/Q01, and one paced Q02 enqueue only
below the hard CPU ceiling and only after the binding PACER input-pin audit
passes.

It does not permit a manual backtest, terminal control, live/demo/shadow/
stress/optimization preset, AutoTrading, `T_Live`, deploy or live manifest,
portfolio-gate mutation, portfolio admission, or a correlation waiver.
