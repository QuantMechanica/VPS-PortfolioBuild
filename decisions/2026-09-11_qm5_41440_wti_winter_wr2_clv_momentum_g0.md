# QM5_41440 WTI Winter WR2 Upper-Quartile Continuation - G0 Decision

- Date: 2026-09-11
- Decision owner: OWNER
- Recorded by: Codex
- Card: `strategy-seeds/cards/approved/QM5_41440_wti-winter-wr2-clv-mom.md`
- Source approval: `decisions/2026-09-11_wti_winter_wr2_clv_momentum_source_approval.md`
- Verdict: `APPROVED`
- Execution contract: `APPROVED` for branch build and non-live pipeline only

## Gate Decision

- R1 passes with completely read peer-reviewed WTI seasonality and futures-momentum records plus
  governed reputable range-state lineage; the exact cross-source translation is untested.
- R2 passes because the November-May calendar, exact two completed weeks, strict range and CLV
  inequalities, long-only side, durable attempt, fixed risk, frozen stop, and next-week exit are
  immutable.
- R3 passes on registered native `XTIUSD.DWX` D1 history with continuous-CFD basis and label risks
  disclosed.
- R4 passes with deterministic native arithmetic and no ML, banned signal indicator, external
  runtime data, grid, martingale, or scale-in.

The canonical scan found no exact identity. Five fuzzy neighbors were manually resolved: the
WTI winter cards use monthly return signs, the XNG card uses a different carrier and symmetric
November-March rule, and the WTI WR2/CLV cards use the disjoint August-October hurricane window.
The card is approved for one fixed-risk branch build and one paced Q02 enqueue only. Q02 owns
activity and economics; unchanged Q09 alone may establish realized portfolio correlation.

## Safety Boundary

No portfolio gate, portfolio admission, live or deploy manifest, `T_Live`, AutoTrading, terminal
control, manual backtest, or live operation is authorized.
