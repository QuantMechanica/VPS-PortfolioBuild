# XAU/XAG Monthly Hampel Reversion — Source Approval

- Date: 2026-09-05
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one market-neutral XAU/XAG card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue if the host
  CPU ceiling is clear
- Proposed slug: `xauxag-mhampel-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MHAMPEL-RV-20260905_S01`
- Source packet:
  `strategy-seeds/sources/AI-CODEX-XAUXAG-MHAMPEL-RV-20260905/source.md`

## Authority and evidence

The current explicit OWNER mission authorizes one new reputable-source,
low-frequency commodity edge and explicitly names a market-neutral
XAUUSD/XAGUSD ratio-reversion basket. The source packet binds Schweikert's
peer-reviewed gold/silver relationship evidence, CME's exchange definition of
the opposed-leg spread, and the canonical Hampel robust-statistics reference
plus author-maintained `MASS::psi.hampel` documentation and source.

R1 passes with disclosed synthesis risk. R2 passes for a locked monthly
conjunction: thirteen synchronized completed ratios, twelve adjacent returns,
an exact 32-step robust location, contrarian opposed legs, and fixed lifecycle.
R3 passes with registered native XAU/XAG D1 history and continuous-CFD basis
risk. R4 passes because runtime uses deterministic native arithmetic only.

## Claim and duplicate boundaries

No parent source tests this exact contrarian robust-location conjunction, CFD
mapping, fixed-risk package, economics, activity, or QM-book correlation. The
corrected-root receipt
`artifacts/qm5_xauxag_mhampel_rv_preallocation_dedup_20260905.json` returned
`FUZZY_MATCH`; manual formula review resolves all six candidates. In
particular, the declared twelve-return fixture makes this Hampel functional
sell while nearest `QM5_41341` bisquare buys. `QM5_41235` instead follows five
same-calendar outright-WTI returns. These are different sample objects,
weights, directions, and carriers, not renamed parameters.
Q09 receives no waiver.

This approval excludes manual backtests, optimization, portfolio-gate changes,
portfolio admission, deployment, live manifests, `T_Live`, AutoTrading, and
live use.

