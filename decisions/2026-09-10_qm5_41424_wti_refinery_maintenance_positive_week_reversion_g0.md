# QM5_41424 WTI Refinery-Maintenance Positive-Week Reversion - G0 Decision

- Date: 2026-09-10
- Decision owner: OWNER
- Recorded by: Codex
- Card: `strategy-seeds/cards/approved/QM5_41424_wti-refmaint-posweek-fade_card.md`
- Source approval: `decisions/2026-09-10_wti_refinery_maintenance_positive_week_reversion_source_approval.md`
- Verdict: `APPROVED`
- Execution contract: `APPROVED` for branch build and non-live pipeline only

## Gate Decision

- R1 passes with official EIA refinery-maintenance context, completely read
  academic commodity-reversal lineage, and explicit weekly/CFD translation
  risk.
- R2 passes: four maintenance months, one completed positive weekly package,
  short-only reversion, durable attempt, fixed risk, stop, spread, and
  rollover are immutable.
- R3 passes on registered native `XTIUSD.DWX` D1 history.
- R4 passes: deterministic native arithmetic only, without trained signal,
  banned signal indicator, external runtime feed, grid, martingale, or
  scale-in.

The canonical receipt found no exact identity across 4,904 registry rows,
1,514 cards, and 45 Strategy Wiki nodes. Manual review resolves the two fuzzy
neighbors: `QM5_41421` admits only the mutually exclusive negative-week state
as continuation, and `QM5_41392` uses XNG, different months, and two-sided
direction. Q02 retires below five completed positions in any full post-warm-up
year or on nonpositive governed economics. No parameter rescue is authorized.

## Authorization Boundary

Approval covers deterministic magic allocation, V5 branch build, PACER pin
audit before compile enqueue, strict Q01, one fixed-risk preset, and one paced
Q02 enqueue only below the CPU ceiling. It excludes manual backtests,
portfolio admission/gate edits, correlation waivers, deployment, live
manifests, `T_Live`, AutoTrading, terminal control, and live use.
