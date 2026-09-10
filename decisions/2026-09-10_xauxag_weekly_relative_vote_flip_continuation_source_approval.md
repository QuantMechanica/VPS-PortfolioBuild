# XAU/XAG Weekly Relative-Vote Flip Continuation — Source Approval

- Date: 2026-09-10
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency XAU/XAG card, deterministic identity and
  magic allocation, branch-only non-live build, strict Q01, and one paced Q02
  enqueue only below the hard CPU ceiling
- Proposed slug: `xauxag-wrelvote-flip-cont`
- Strategy ID: `FMR-CME-XAUXAG-WRELVOTE-FLIP-CONT-20260910_S01`
- Source packet:
  `strategy-seeds/sources/FMR-CME-XAUXAG-WRELVOTE-FLIP-CONT-20260910/source.md`
- Dedup receipt:
  `artifacts/qm5_xauxag_wrelvote_flip_cont_preallocation_dedup_20260910.json`

## Authority And Source Quality

The current OWNER PACER directive authorizes one reputable-source,
structural, low-frequency commodity/energy card and build. The bounded packet
retains the complete governed record for Fuertes, Miffre, and Rallis (2010),
*Tactical Allocation in Commodity Futures Markets: Combining Momentum and
Term Structure Signals*, Journal of Banking & Finance 34(10), 2530-2548, DOI
`10.1016/j.jbankfin.2010.04.009`, plus CME's official gold/silver-ratio spread
carrier record. The exact weekly standalone two-metal port and overlapping
relative-sign majority-flip state are disclosed QuantMechanica translations;
no source efficacy, neutrality, or diversification claim transfers.

## Locked Mechanic

At each Monday-anchored broker-week boundary, reconstruct the final
synchronized XAU/XAG closes of the five immediately completed consecutive
three-to-five-session weeks. Compute four adjacent XAU-minus-XAG relative log
returns. Require every return to have a strict nonzero sign, an older
three-return majority of at least two signs, a newer overlapping three-return
majority of at least two signs, and strict opposition between the two
majorities. Follow the new relative majority for one week with opposed
equal-notional legs. Consume the attempt before fallible gates. Use one
aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, independent frozen
`3.5*ATR(20,D1)` hard stops, no target, and native synchronized D1 history.

No oscillator, moving average, fitted center or hedge ratio, magnitude
threshold, external runtime feed, trained component, target, trail,
scale-in, pyramid, grid, or martingale is permitted.

## Duplicate Decision

The canonical checker covered 4,894 registry rows and 1,504 repository cards;
the configured Strategy Wiki root was unavailable and is not claimed as
checked. It found no exact identity and two expected fuzzy family matches.
`QM5_41372` owns the same overlap-and-vote state on the economically different
XTI/XNG carrier. `QM5_41413` uses XAU/XAG but requires exact three-return sign
alternation over four endpoints; it does not observe five endpoints or compare
overlapping three-return majorities. Monthly majority/vote cards use different
clocks, horizons, and return objects. Verdict:
`DISTINCT_XAUXAG_OVERLAPPING_THREE_WEEK_RELATIVE_MAJORITY_FLIP_CONTINUATION`.

## Authorization Boundary

Approval permits the source packet, approved card/G0 record, deterministic
identity and magic allocation, bounded V5 build, mandatory PACER framework-
input-pin audit before compile enqueue, strict Q01, fixed-risk backtest
presets, and one paced logical Q02 enqueue only below the CPU ceiling. It
excludes manual backtests, optimization, portfolio admission, correlation
waivers, portfolio-gate edits, deployment, live manifests, `T_Live`,
AutoTrading, terminal control, and live use.
