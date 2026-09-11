# QM5_41441 WTI Winter NR2 Close Breakout - G0 Decision

- Date: 2026-09-11
- Decision owner: OWNER
- Recorded by: Codex
- Card: `strategy-seeds/cards/approved/QM5_41441_wti-winter-nr2-breakout_card.md`
- Source approval: `decisions/2026-09-11_wti_winter_nr2_breakout_source_approval.md`
- Verdict: `APPROVED`
- Execution contract: `APPROVED` for branch build and non-live pipeline only

## Gate Decision

- R1 passes with completely read peer-reviewed WTI seasonality and governed reputable range-state
  records; the exact cross-source and horizon translation is untested.
- R2 passes because the November-May calendar, exact two completed weeks, strict contraction,
  delayed completed-close breakout, symmetric sides, durable attempt, fixed risk, frozen stop, and
  next-week exit are immutable.
- R3 passes on registered native `XTIUSD.DWX` D1 history with continuous-CFD basis and label risks
  disclosed.
- R4 passes with deterministic native arithmetic and no ML, banned signal indicator, external
  runtime data, grid, martingale, or scale-in.

The canonical scan found no exact identity. Two fuzzy neighbors were manually resolved:
`QM5_41439` uses the XNG carrier and shorter November-March window, while `QM5_41440` uses the WTI
winter interval but opposite range state, immediate upper-quartile confirmation, and long-only
entry. The same chronology on WTI exists only in the disjoint August-October hurricane window as
`QM5_41437`. The external Strategy Wiki was unavailable and that limitation remains explicit.
The card is approved for one fixed-risk branch build and one paced Q02 enqueue only. Q02 owns
activity and economics; unchanged Q09 alone may establish realized portfolio correlation.

## Safety Boundary

No portfolio gate, portfolio admission, live or deploy manifest, `T_Live`, AutoTrading, terminal
control, manual backtest, or live operation is authorized.
