# QM5_41319 Q01 Compile Recovery And Review Handoff

Date: 2026-09-06
Branch: `agents/board-advisor`
Router task: `b930e8c1-9022-48a8-9dfc-405613e4189a`
Build-task binding: `cd3a3f60-895d-49cc-850c-c2c42f09cc9d`
Status: compile and static checks PASS; code review pending; Q02 not enqueued

## Outcome

The existing G0-approved `QM5_41319_wti-madf-persist-tr` source was recovered
as a complete review artifact. The Q01 spec now exposes the seven canonical
sections, the source version is `5.1`, the sole fixed-risk backtest set is
bound to the governed build generation, and a fresh EX5 exists.

This record advances only the build artifact to review. It does not assert a
Q01 gate verdict, activity, economics, robustness, or portfolio correlation.

## Authority And Identity

- Approved card:
  `strategy-seeds/cards/approved/QM5_41319_wti-madf-persist-tr_card.md`
  (`status`, `execution_contract_status`, and `g0_status` are `APPROVED`).
- Active EA registry identity: `41319,wti-madf-persist-tr`.
- Active magic row: slot `0`, `XTIUSD.DWX`, magic `413190000`.
- The EA-local card copy is byte-identical to the approved card.
- The build remains direct WTI, D1, low frequency, mechanical, and non-live.

## Durable Artifact

- Source:
  `framework/EAs/QM5_41319_wti-madf-persist-tr/QM5_41319_wti-madf-persist-tr.mq5`
  - SHA-256:
    `d18cd0b5f7e5f935b43c95cfc20df5e669b3d24c35587c4dd326ca41c365bcbc`
- Binary:
  `framework/EAs/QM5_41319_wti-madf-persist-tr/QM5_41319_wti-madf-persist-tr.ex5`
  - SHA-256:
    `cfc816a7e3f82c9a882451ec38638af7bda46678ade63d542c45f3a44829cec1`
- Sole set:
  `framework/EAs/QM5_41319_wti-madf-persist-tr/sets/QM5_41319_wti-madf-persist-tr_XTIUSD.DWX_D1_backtest.set`
  - SHA-256:
    `14fa066f5cddc7e86d438837d41e62b6c179a17a912d5976b3111272a3fbe8ca`
  - Locked risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
    `PORTFOLIO_WEIGHT=1`.
- Spec: `framework/EAs/QM5_41319_wti-madf-persist-tr/SPEC.md`.

## Focused Verification

The governed compile work item
`495314e5-bffc-4cbd-a11b-68dbede08c4e` ran on claimed terminal T9 and is
hash-bound to the source above. Its immutable receipt reports:

- compile `PASS`, zero errors, zero warnings;
- strict build check `PASS`, zero failures, zero warnings;
- one generated backtest set;
- EX5 SHA-256 matching the durable binary above;
- no gate verdict (`no_gate_verdict=true`).

Primary receipt:
`D:/QM/reports/work_items/495314e5-bffc-4cbd-a11b-68dbede08c4e/QM5_41319/COMPILE_EA/compile_evidence.json`.
The static-check receipt is
`D:/QM/reports/framework/21/build_check_20260906_045731.json`.

Additional checks in this handoff cycle:

- `python -m pytest framework/EAs/QM5_41319_wti-madf-persist-tr/docs/test_wti_madf_persist_tr_reference.py -q`
  returned `9 passed`.
- `validate_build_guardrails.py` returned `PASS` over the EA directory with
  two files checked and zero findings. The stale-news ceiling remains `336`.
- Receipt/source, receipt/binary, card-copy, and sole-set assertions all
  returned true.
- `git diff --check` returned no findings after the spec cleanup.

A later ad-hoc compile recheck was refused before compilation with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because protected terminals were alive.
No retry was attempted, no terminal was interrupted, and the authoritative
result remains the earlier governed, hash-matching receipt.

## Card-To-Framework Alignment

- `Strategy_NoTradeFilter` locks identity, symbol/timeframe, magic, risk,
  news, Friday-close, stress, and all baseline parameters.
- Bounded helpers reconstruct sixty completed consecutive month endpoints,
  exclude the current month, and compute the exact 58-row centered OLS with
  residual degrees of freedom `55`.
- The month attempt is persisted before all fallible entry gates.
- `Strategy_EntrySignal` applies the inclusive ADF boundary, strict 12-month
  side, spread/quote checks, completed-D1 ATR, and frozen hard stop.
- `Strategy_ManageOpenPosition` owns malformed-state repair, next-month exit,
  and the 40-day stale repair; there is no intramonth discretionary exit.

## Safety Boundary

No Q02 row or backtest was launched. No `T_Live` artifact, deploy manifest,
portfolio gate, or live surface was changed. AutoTrading was not toggled and
no terminal was started, stopped, or manually controlled. Review is the next
state; this handoff does not self-approve or move the EA into the pipeline.
