# XAU/XAG Monthly Bisquare Reversion — Source Approval

- Date: 2026-09-05
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one market-neutral XAU/XAG card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue if the host
  CPU ceiling is clear
- Proposed slug: `xauxag-mbisquare-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MBISQUARE-RV-20260905_S01`
- Source packet:
  `strategy-seeds/sources/AI-CODEX-XAUXAG-MBISQUARE-RV-20260905/source.md`

## Authority and evidence

The current explicit OWNER mission authorizes one new reputable-source,
low-frequency commodity edge and explicitly names a market-neutral
XAUUSD/XAGUSD ratio-reversion basket. The source packet binds Schweikert's
peer-reviewed gold/silver relationship evidence, CME's exchange definition of
the opposed-leg spread, and a governed exact Tukey-bisquare estimator record.

R1 passes with disclosed synthesis risk. R2 passes for a locked monthly
conjunction: thirteen synchronized completed ratios, twelve adjacent returns,
an exact 32-step robust location, contrarian opposed legs, and fixed lifecycle.
R3 passes with registered native XAU/XAG D1 history and continuous-CFD basis
risk. R4 passes because runtime uses deterministic native arithmetic only.

## Claim and duplicate boundaries

No parent source tests this exact contrarian robust-location conjunction, CFD
mapping, fixed-risk package, economics, activity, or QM-book correlation. The
corrected-root receipt
`artifacts/qm5_xauxag_mbisquare_rv_preallocation_dedup_20260905.json` returned
`CLEAN`; manual formula review separates the card from absolute-ratio z-score,
OLS/CADF, MAD-tail, Siegel-Tukey, squared-rank, and outright-WTI bisquare EAs.
Q09 receives no waiver.

This approval excludes manual backtests, optimization, portfolio-gate changes,
portfolio admission, deployment, live manifests, `T_Live`, AutoTrading, and
live use.
