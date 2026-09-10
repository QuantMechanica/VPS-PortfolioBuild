# WTI Weekly Alternation Continuation — Source Approval

- Date: 2026-09-10
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency WTI card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `wti-walt3-cont`
- Strategy ID: `KWON-WTI-WALT3-CONT-20260910_S01`
- Source packet:
  `strategy-seeds/sources/KWON-WTI-WALT3-CONT-20260910/source.md`
- Dedup receipt:
  `artifacts/qm5_wti_walt3_cont_preallocation_dedup_20260910.json`

## Authority And Source Quality

The current OWNER PACER directive authorizes one reputable-source,
structural, low-frequency commodity/energy card and build. The bounded packet
preserves the fully reviewed peer-reviewed Kwon-Kang-Yun weekly commodity
momentum record, including its exact one-week formation/holding horizon and
explicit light-sweet-crude membership. The standalone WTI time-series map and
three-week alternation gate are disclosed QM translations; no source efficacy
or diversification claim transfers.

## Locked Mechanic

At each Monday-anchored broker-week boundary, reconstruct the three immediately
completed adjacent three-to-five-session WTI weeks and each week's first-open
to final-close log return. Require strict `+,-,+` or `-,+,-` alternation and
follow the newest completed-week sign for one week. Consume the attempt before
fallible gates. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
`3.5*ATR(20,D1)` hard stop, no target, no retry, and native zero-offset D1
labels.

No oscillator, moving average, fitted center, return-magnitude threshold,
volume state, external runtime feed, trained component, target, trail,
scale-in, pyramid, grid, or martingale is permitted.

## Duplicate Decision

The canonical checker covered 4,891 registry rows and 1,501 repository cards;
the configured Strategy Wiki root was unavailable and is not claimed as
checked. It found no exact identity and five expected fuzzy family matches.
Manual review separates pure one-week continuation (`QM5_41375`), the
two-close-to-close-return fresh handoff (`QM5_41065`), the fresh same-sign
three-week streak (`QM5_41074`), same-sign seasonal agreement, and weekly OHLC
geometry filters. This card uniquely joins three complete WTI weekly
open-to-close packages, exact three-sign alternation, newest-sign continuation,
and a one-week lifecycle. Verdict:
`DISTINCT_WTI_THREE_COMPLETED_WEEK_OPEN_CLOSE_STRICT_ALTERNATION_NEWEST_SIGN_CONTINUATION`.

## Authorization Boundary

Approval permits the approved card/G0 record, deterministic identity and magic
allocation, bounded V5 build, mandatory PACER framework-input-pin audit before
compile enqueue, strict Q01, one fixed-risk preset, and one paced Q02 enqueue
only below the CPU ceiling. It excludes manual backtests, optimization,
portfolio admission, correlation waivers, portfolio-gate edits, deployment,
live manifests, `T_Live`, AutoTrading, terminal control, and live use.

