# XAU/XAG Weekly Alternation Reversion — Source Approval

- Date: 2026-09-10
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency XAU/XAG relative-value card,
  deterministic allocation, branch-only non-live build, strict Q01, and one
  paced Q02 enqueue below the hard CPU ceiling
- Proposed slug: `xauxag-walt3-rv`
- Strategy ID: `SCHWEIKERT-CME-XAUXAG-WALT3-RV-20260910_S01`
- Source packet:
  `strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-WALT3-RV-20260910/source.md`
- Dedup receipt:
  `artifacts/qm5_xauxag_walt3_rv_preallocation_dedup_20260910.json`

## Authority And Source Quality

The current OWNER PACER directive explicitly names gold/silver ratio reversion
as an allowed commodity sleeve and authorizes one reputable-source card and
build. The bounded packet preserves a completely read peer-reviewed
gold/silver cointegration record and CME exchange ratio/spread record. The
exact weekly alternation interaction is untested and no efficacy, neutrality,
or diversification claim transfers.

## Locked Mechanic

At each Monday-anchored broker-week boundary, reconstruct four consecutive
synchronized completed-week XAU/XAG endpoints and the three chronological
XAU-minus-XAG relative log returns. Require strict `+,-,+` or `-,+,-`
alternation and fade the newest relative winner as one opposed-leg,
equal-notional-target package for one week. Consume the attempt before
fallible gates. Use one aggregate `RISK_FIXED=1000` budget, independent frozen
`3.5*ATR(20,D1)` hard stops, no target, no retry, and native zero-offset D1
labels.

No oscillator, moving average, fitted center, magnitude threshold, external
runtime feed, learned component, target, trail, scale-in, pyramid, grid, or
martingale is permitted.

## Duplicate Decision

The canonical checker covered 4,890 registry rows, 1,500 repository cards,
and 45 configured Strategy Wiki nodes. It found no exact identity and returned
five expected fuzzy family matches. Manual review separates the XTI/XNG
carrier analogue, two-return XAU/XAG magnitude states, and the disjoint fresh
same-sign streak. Verdict:
`DISTINCT_XAUXAG_THREE_WEEK_STRICT_RELATIVE_SIGN_ALTERNATION_NEWEST_WINNER_FADE`.

## Authorization Boundary

Approval permits the approved card/G0 record, deterministic identity and magic
allocation, bounded V5 build, mandatory PACER framework-input-pin audit before
compile enqueue, strict Q01, fixed-risk basket presets, and one paced logical
Q02 enqueue below the CPU ceiling. It excludes manual backtests, optimization,
portfolio admission, correlation waivers, portfolio-gate edits, deployment,
live manifests, `T_Live`, AutoTrading, terminal control, and live use.
