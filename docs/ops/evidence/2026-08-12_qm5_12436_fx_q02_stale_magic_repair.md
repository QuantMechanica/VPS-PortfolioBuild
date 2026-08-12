# QM5_12436 FX Q02 stale-magic repair

Date: 2026-08-12

Branch: `agents/board-advisor`

EA: `QM5_12436_ea31337-wpr`

Scope: one-EA Q02 infrastructure repair and append-only canary handoff; no strategy-logic change

## Outcome

`QM5_12436` was blocked at Q02 by a stale compiled magic resolver, not by an
economic result. The unchanged approved WPR implementation was rebuilt against
the current registry, passed strict compilation and the target build gate, and
was re-enqueued as one fixed-risk EURUSD Q02 canary. The historical failed row
was preserved.

## Selection and farm claim

- This is a structural, closed-bar H1 Williams Percent Range reentry strategy
  with an expected cadence of 35 trades/year/symbol. It contains no ML,
  martingale, grid, or adaptive PnL sizing.
- The approved card has durable source ID
  `041e0d5c-bf76-501d-bee2-31c0f4a6e233` and exact public source pointer
  `EA31337/Strategy-WPR/Stg_WPR.mqh`.
- Its portable universe adds three FX hosts to the index/metal/energy-heavy
  survivor cohort: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, plus XAUUSD.DWX.
- Farm claim: `5cb237ff-9872-4c4f-b9cf-8fd7052f33f1`, assigned to
  `codex:agents/board-advisor` after an atomic competing-claim/open-work check.
- Pre-claim SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12436_q02_stale_ex5_claim_20260812T085640Z.sqlite`.

## Root cause

The authenticated EURUSD predecessor
`fbb69146-726f-4a58-a20a-474903d8fe8a` staged and verified EX5 SHA-256
`4a2ebc944e6ff7f578892a8a904478d58aa3339205fcecef7cb85769636334ea`,
then ended `INFRA_FAIL` with `ONINIT_FAILED;INCOMPLETE_RUNS`. Independent tester
journals repeatedly recorded the exact initialization refusal, including:

```text
D:\QM\mt5\T7\Tester\logs\20260811.log:87943
EA_MAGIC_NOT_REGISTERED: ea_id=12436 slot=0 magic=124360000

D:\QM\mt5\T7\Tester\logs\20260812.log:122
EA_MAGIC_NOT_REGISTERED: ea_id=12436 slot=3 magic=124360003
```

The canonical registry contains all four active tuples:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | EURUSD.DWX | 124360000 |
| 1 | GBPUSD.DWX | 124360001 |
| 2 | USDJPY.DWX | 124360002 |
| 3 | XAUUSD.DWX | 124360003 |

The generated resolver advertises registry SHA-256
`09bb78b4779b1ce52479d95b6de44e7da8afe285c581a93db3836805262bf79b`,
which matches `framework/registry/magic_numbers.csv`. The failed EX5 predates
that current resolver state, classifying the blocker as stale binary
infrastructure rather than strategy mechanics or missing history.

## Repair and verification

- MQ5 logic remained byte-identical:
  `ae78b3a62081cc20a823ffe4ccddb1ec4249d6997ab0337b9b231c8476db28d2`.
- Repaired EX5:
  `001a02c6c5d2e199c6d06e72631c99a470c0f82b915b7bd597acf9f615634b85`.
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log: `framework/build/compile/20260812_090215/QM5_12436_ea31337-wpr.compile.log`
  - Log SHA-256:
    `0eba30f0345a183aa8a9d8efa3cd41c6047814add3b63afe040a80c35152a409`
- Target build gate: PASS, 0 failures, 0 warnings.
  - Report: `D:\QM\reports\framework\21\build_check_20260812_090258.json`
  - Report SHA-256:
    `2a7f5ad5bc93a218c29915005892bd7fbf7768726609ffa88513b6af0e66550d`
- `validate_spec_doc.py`, `validate_build_guardrails.py`, and
  `validate_symbol_scope.py --fail-on-leak` all passed for this EA.
- The build gate refreshed only the `build_hash` comments in all eight portable
  presets. Every preset retains `RISK_FIXED=1000` and `RISK_PERCENT=0`.

One shared-worktree race was contained by the governed enqueue guard: a
concurrent paced process moved the branch head and restored the target EX5 to
the stale tracked bytes after the first rebuild. The first enqueue attempt was
refused with `current_ex5_hash_mismatch`; it created no work item. After that
process exited, the EA was rebuilt again and the final enqueue was bound to the
hash above.

## Append-only Q02 handoff

The governed enqueue was restricted to the exact failed EURUSD row and current
binary:

- Successor work item: `84709116-4ea5-47a3-b07c-49d5f2d0f438`
- Phase / symbol / timeframe: `Q02` / `EURUSD.DWX` / `H1`
- Immediate readback: `pending`, attempt 0, unclaimed, no verdict
- Predecessor preserved:
  `fbb69146-726f-4a58-a20a-474903d8fe8a` (`INFRA_FAIL`)
- Bound EX5 SHA-256:
  `001a02c6c5d2e199c6d06e72631c99a470c0f82b915b7bd597acf9f615634b85`
- Bound setfile SHA-256:
  `58f670672b1bc2df74a0e52ac9c0213084a904a99429198215c7799d216ddad4`
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Priority track: retained

Immediately before handoff, the path-anchored factory sample found four active
T1-T10 tester processes against the ceiling of seven. Separate host CPU samples
were already 95.7-99.5%, so no local smoke test, dispatch tick, or terminal
launch was issued; runtime remains scheduler-controlled. This is a Q02 handoff,
not a Q02 result.

No T_Live file, AutoTrading setting, portfolio gate, or deploy manifest was
changed.
