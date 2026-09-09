# QM5_41335 FX Q02 priority advance

Date: 2026-09-09

Branch: `agents/board-advisor`

Scope: one non-live, non-portfolio, non-duplicate advancement of an existing
forex card

## Result

The frozen 66-pair FX cointegration frontier has no unbuilt relationship left
to mechanize. Its two admitted anchors are not blocked at Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 `PASS`, Q04 `PASS`, then
  Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 `PASS`, then Q04 `FAIL`.

The mission therefore used its explicit existing-card fallback. The already
enqueued `QM5_41335_fx-usd-exhaustion-reversal-opt` AUDUSD.DWX D1 Q02 row
`ff75b1c3-4930-419d-a2fe-49bd37eadc4d` was atomically marked as priority-track.
The resident factory then claimed that same row on T5 at
`2026-09-09T06:05:59+00:00`; it is `active`, attempt zero, and without a
verdict. No new work item was inserted and no manual dispatch or tester launch
occurred.

The priority reason stored on the row is:

> OWNER 2026-09-09 FX portfolio mission: advance the already-enqueued
> QM5_41335 AUDUSD D1 structural forex fallback through Q02; no duplicate work
> item, no manual dispatch, no portfolio/live mutation.

## Eligibility and bindings

The approved card is
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_41335_fx-usd-exhaustion-reversal-opt.md`.
It records `g0_status: APPROVED`, R1-R4 `PASS`, D1 frequency, an expected five
trades per year, and fixed deterministic rules with no ML, grid, martingale, or
online adaptation.

| Artifact | SHA-256 |
|---|---|
| Approved card | `7826e575a21600cfcc48e7ba03e6fa38bfe8faf91e4db3978f430a49e69dc1aa` |
| MQ5 | `d7eec6373be1b7b865902cd8420b2a3fe305c7a7e026603e9baef9e32ee1e7bc` |
| EX5 | `f17045107715b1ee127011f14ee60ad36e6ad23e8dbfc372819a27d4bb596280` |
| Backtest set | `6ed5b4fe7549362276fa8812bcbf9450f6aca2b3b03fd169336a89799874bd47` |

The Q02 row is bound to compile predecessor
`08440065-e8fb-4400-aa99-674eb2693924`, which is terminal
`done / COMPILE_OK`. Its stored EX5 and setfile hashes match the current files.
The backtest set remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The binding PACER audit was run read-only against the absolute MQ5 path:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41335_fx-usd-exhaustion-reversal-opt/QM5_41335_fx-usd-exhaustion-reversal-opt.mq5"
```

It exited zero with `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, and zero
findings. No source was written and no compile command or compile enqueue was
performed.

## Capacity and safety

The immediate pre-apply five-sample whole-host CPU series was `78.7144`,
`71.3328`, `71.8451`, `73.9288`, and `80.2776` percent (average `75.2198`,
maximum `80.2776`), below the binding 97 percent ceiling. Five farm rows were
active when the candidate was selected.

The `mark-priority-track --dry-run` returned
`already_priority_track=false` before the apply call. The apply call returned
`applied=true`. A read-only SQLite reread after the resident-worker claim
confirmed one exact open Q02 row for the selected identity with
`priority_track=true`, `status=active`, and `claimed_by=T5`.

No EA source, binary, setfile, card, registry, magic row, portfolio-admission,
portfolio KPI, Q08 contribution, portfolio gate, T_Live manifest or process,
deploy artifact, AutoTrading state, stored verdict, work-item status, terminal
claim, or tester process was changed. The normal factory owns execution and the
eventual Q02 verdict.

Machine-readable companion:
`artifacts/qm5_41335_fx_q02_priority_advance_20260909T060453Z.json`.
