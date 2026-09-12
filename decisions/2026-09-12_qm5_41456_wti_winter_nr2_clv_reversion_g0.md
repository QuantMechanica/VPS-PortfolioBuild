# QM5_41456 WTI Winter NR2 Close-Location Reversion - G0 Decision

- Date: 2026-09-12
- Decision owner: OWNER
- Recorded by: Codex
- Card: `strategy-seeds/cards/approved/QM5_41456_wti-winter-nr2-clv-fade.md`
- Source approval: `decisions/2026-09-12_wti_winter_nr2_clv_reversion_source_approval.md`
- Verdict: `APPROVED`
- Execution contract: `APPROVED` for branch build and non-live pipeline only

## Gate Decision

- R1 passes with completely read peer-reviewed WTI seasonality and academic commodity-reversal
  records plus governed reputable range-state lineage; the exact conjunction and weekly
  translation are untested.
- R2 passes because the November-May calendar, exact two completed weeks, strict contraction,
  strict outer-quartile settlement, symmetric reversion, durable attempt, fixed risk, frozen
  stop, and next-week exit are locked.
- R3 passes on registered native `XTIUSD.DWX` D1 history with continuous-CFD basis risk disclosed.
- R4 passes with deterministic native arithmetic and no ML, banned signal indicator, external
  runtime data, grid, martingale, scale-in, or pyramid.

The canonical scan found no exact identity. Manual review separates the opposite range-expansion
CLV fade, contraction/upper-quartile continuation, contraction/body fade, same-sign weekly-return
fade, and paired XAU/XAG contraction/CLV basket. The external Strategy Wiki was unavailable and
that limitation remains explicit. The card is approved for one fixed-risk branch build and one
paced Q02 enqueue only. Q02 owns activity and economics; unchanged Q09 alone may establish
realized portfolio correlation.

## Allocation

The atomic `farmctl reserve-ea-ids` command allocated `QM5_41456` to the approved strategy
identity on 2026-09-12. Magic allocation remains a separate build prerequisite.

## Safety Boundary

No portfolio gate, portfolio admission, live or deploy manifest, `T_Live`, AutoTrading, terminal
control, manual backtest, or live operation is authorized.
