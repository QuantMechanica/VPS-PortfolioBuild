# QM5_41459 WTI Summer WR2 Negative-Week Continuation - G0 Decision

- Date: 2026-09-12
- Decision owner: OWNER
- Recorded by: Codex
- Card: `strategy-seeds/cards/approved/QM5_41459_wti-summer-wr2-downweek-cont.md`
- Source approval: `decisions/2026-09-12_wti_summer_wr2_negative_week_continuation_source_approval.md`
- Verdict: `APPROVED`
- Execution contract: `APPROVED` for branch build and non-live pipeline only

## Gate Decision

- R1 passes with completely read peer-reviewed WTI seasonality and academic
  commodity-momentum records plus governed reputable range-state lineage; the exact conjunction
  and weekly translation are untested.
- R2 passes because the June-October calendar, exact two completed weeks, strict expansion,
  strict negative weekly body, short-only orientation, durable attempt, fixed risk, frozen stop,
  and next-week exit are locked.
- R3 passes on registered native `XTIUSD.DWX` D1 history with continuous-CFD basis risk disclosed.
- R4 passes with deterministic native arithmetic and no ML, banned signal indicator, external
  runtime data, grid, martingale, scale-in, or pyramid.

The canonical scan found no exact repository identity and reported four fuzzy family matches.
Manual review separates the unconditional and two-sign summer cards, symmetric November-May
WR2 body continuation, and closest sibling `QM5_41458`, whose strictly positive body/fade rule
is mutually exclusive with this strictly negative body/continuation rule. `QM5_41457` separately
requires contraction and a positive body. The external Strategy Wiki was unavailable and that
limitation remains explicit.
The card is approved for one fixed-risk branch build and one paced Q02 enqueue only. Q02 owns
activity and economics; unchanged Q09 alone may establish realized portfolio correlation.

The card locks `strategy_label_offset_seconds=0` from the pre-existing QM5_41457 Model-4
decision-clock recovery evidence, before this candidate is built or tested. This is an
infrastructure-label choice, not an observed-result strategy adjustment.

## Allocation

The atomic `farmctl reserve-ea-ids` command allocated `QM5_41459` to the approved strategy
identity on 2026-09-12. Magic allocation remains a separate build prerequisite.

## Safety Boundary

No portfolio gate, portfolio admission, live or deploy manifest, `T_Live`, AutoTrading, terminal
control, manual backtest, or live operation is authorized.
