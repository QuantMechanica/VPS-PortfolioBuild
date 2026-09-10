# XAU/XAG Weekly Relative-Vote Flip Reversion — Source Approval

- Date: 2026-09-10
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency market-neutral-intent commodity card,
  deterministic allocation, branch-only non-live build, strict Q01, and one
  paced logical Q02 enqueue only below the hard CPU ceiling
- Proposed slug: `xauxag-wrelvote-flip-fade`
- Strategy ID: `FMR-CME-XAUXAG-WRELVOTE-FLIP-FADE-20260910_S01`
- Source packet: `strategy-seeds/sources/FMR-CME-XAUXAG-WRELVOTE-FLIP-FADE-20260910/source.md`
- Dedup receipt: `artifacts/qm5_xauxag_wrelvote_flip_fade_preallocation_dedup_20260910.json`

## Authority And Source Quality

The current OWNER PACER directive authorizes one reputable-source,
structural, low-frequency commodity/energy card and build and explicitly
offers an XAU/XAG market-neutral basket. The bounded packet preserves the
complete local record for Fuertes, Miffre, and Rallis (2010), *Tactical
Allocation in Commodity Futures Markets*, *Journal of Banking & Finance*
34(10), 2530–2548, DOI `10.1016/j.jbankfin.2010.04.009`, plus CME Group's
official gold/silver ratio and intermarket-spread definition. The exact weekly
vote-flip fade is disclosed as an untested QM translation; no source efficacy,
neutrality, or diversification claim transfers.

## Locked Mechanic

At each Monday-anchored broker-week boundary, reconstruct five consecutive
synchronized completed XAU/XAG week-ending close pairs and their four adjacent
XAU-minus-XAG relative log returns. Require every relative return to be strict
nonzero and require the sign majority of the overlapping older three-return
window to oppose the majority of the newer three-return window. Fade the newer
majority for one week: a newer XAU majority sells XAU/buys XAG; a newer XAG
majority buys XAU/sells XAG. Consume the attempt before fallible gates. Use one
aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, equal absolute notional,
independent frozen `3.5*ATR(20,D1)` hard stops, no target, and the governed
logical-basket recipe.

No oscillator, moving average, fitted center, magnitude threshold, external
runtime feed, trained component, target, trail, scale-in, pyramid, grid, or
martingale is permitted.

## Duplicate Decision

The canonical checker covered 4,896 registry rows and 1,506 repository cards;
the configured Strategy Wiki root was unavailable and is not claimed as
checked. It found no exact identity and three expected fuzzy family matches.
`QM5_41414` follows the same newly flipped relative majority; this candidate
fades it. Direction is the complete economic hypothesis and is load-bearing,
not a parameter variant. `QM5_41372` uses the economically different XTI/XNG
carrier. `QM5_41413` requires exact three-return alternation and only four
endpoints, rather than two overlapping majority windows over five endpoints.
Verdict: `DISTINCT_XAUXAG_RELATIVE_MAJORITY_FLIP_REVERSION`.

## Authorization Boundary

Approval permits the approved card/G0 record, deterministic identity and magic
allocation, bounded V5 basket build, mandatory PACER framework-input-pin audit
before compile enqueue, strict Q01, fixed-risk logical/component presets, and
one paced logical Q02 enqueue only below the CPU ceiling. It excludes manual
backtests, optimization, portfolio admission, correlation waivers,
portfolio-gate edits, deployment, live manifests, `T_Live`, AutoTrading,
terminal control, and live use.
