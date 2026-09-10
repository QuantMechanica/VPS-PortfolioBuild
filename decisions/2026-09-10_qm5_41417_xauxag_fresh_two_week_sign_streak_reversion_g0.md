# G0 Decision - QM5_41417 XAU/XAG Fresh Two-Week Sign-Streak Reversion

Date: 2026-09-10

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission on the
`agents/board-advisor` branch, bounded by
`decisions/2026-09-10_xauxag_fresh_two_week_sign_streak_reversion_source_approval.md`.

Approved card:
`strategy-seeds/cards/approved/QM5_41417_xauxag-wstreak2-rv_card.md`.

## Identity

- EA ID: `QM5_41417`, allocated by `farmctl reserve-ea-ids`
- slug: `xauxag-wstreak2-rv`
- strategy ID: `SCHWEIKERT-CME-XAUXAG-WSTREAK2-RV-20260910_S01`
- host/companion: `XAUUSD.DWX` / `XAGUSD.DWX`, D1, slots 0/1
- logical symbol: `QM5_41417_XAU_XAG_WSTREAK2_RV_D1`
- mechanic: fade the first completion of two strict same-sign weekly
  gold-minus-silver returns after one strict opposite predecessor, for one week

## Gate Findings

- R1 `PASS_WITH_WEEKLY_STREAK_REVERSION_TRANSLATION_RISK`: the record preserves
  named peer-reviewed DOI and official exchange carrier evidence while stating
  that the exact weekly fade is an untested QM hypothesis.
- R2 `PASS`: exact week anchors, synchronized endpoints, chronological signs,
  fresh-state condition, contrarian sides, attempt, aggregate risk, hard stops,
  spreads, and lifecycle are fixed.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native XAU/XAG
  D1 data provides the runtime inputs; Q02 owns history/fill sufficiency.
- R4 `PASS`: deterministic native arithmetic only; no ML, banned signal,
  external runtime feed, adaptive fit, grid, martingale, or pyramid.

## Dedup Decision

The canonical scan covered 4,897 registry rows and 1,507 repository cards,
finding no exact identity and only `QM5_41078_xauxag-wstreak3-rv` as an expected
fuzzy sibling. This card uses four endpoints and strict `-++` / `+--`; the
sibling uses five endpoints and `-+++` / `+---`. The fresh-state predecessor
makes the candidate flat when the sibling evaluates. Adjacent-two-return
siblings use magnitude ordering and do not require this older opposite sign.
Verdict: `DISTINCT_XAUXAG_FRESH_TWO_WEEK_SIGN_STREAK_REVERSION`.

## Authorization Boundary

Approved for one branch-only build, strict Q01 validation, fixed-risk
backtest presets, and one paced logical Q02 enqueue if the CPU ceiling permits.
Not approved for a manual backtest, live/demo/shadow/stress preset, optimization,
AutoTrading, `T_Live`, deploy/live manifest, portfolio-gate mutation, portfolio
admission, correlation waiver, or decorrelation/neutrality claim.
