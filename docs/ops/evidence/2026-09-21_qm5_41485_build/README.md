# QM5_41485 H-V4 revision-2 build evidence

Router task: `b56cb62c-4b5f-4a58-af76-1a49970e436d`

Implementation commit: `f8e448ff31331a3a2f5f7d385be621649e7fbac5`

## Verdict

SOURCE_COMPLETE / BUILD_CHECK_BLOCKED. The requested MQ5 source, validated
SPEC, local frozen-spec draft, three fixed-risk backtest sets, and grid/anchor
unit proof are complete. Independent hardening and build guardrails pass.

The required canonical `build_check` PASS receipt does not exist. The scoped
non-compiling command stopped at its mandatory preflight with
`BUILD_CHECK_LIVE_FACTORY_COMPILE_REFUSED` /
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` while T1-T10 backtests were active. The
guard executes even with `-SkipCompile`. The factory currently has a material
pending queue, so a short natural-idle watch did not expose a safe window.
No terminal was interrupted, no guard was bypassed, and the task's prohibited
compile/enqueue route was not used.

This artifact is therefore ready for code review but not build-check
acceptance. `build_check_blocker.json` records stable blocker facts without an
observation timestamp for no-change dedupe.

## Delivered package

- `QM5_41485_ny-preopen-range-breakout-jpy.mq5`: H-V4 revision-2 mechanical
  build on the V5 framework, source SHA-256
  `a55be9bbfbfc64954a10b8850c9ab67b799bbf501bd2e1efb8546d8b1bf71575`.
- `SPEC.md`: complete Q01-format spec; `validate_spec_doc.py` reports
  `1 PASS, 0 FAIL`.
- `docs/strategy_card.md`: local DRAFT mirror only. It is not a card approval,
  was not written to `cards_review` or `cards_approved`, and grants no phase or
  live authority.
- Three M30 backtest sets: USDJPY C2 slot 0, USDJPY C3 slot 1, and EURUSD C3
  slot 2. Each uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, PRE30_POST30/DXZ, and
  `qm_news_stale_max_hours=336`.
- `tests/test_grid_contract.py`: exact reference-simulator parity for a Friday,
  the US spring transition week, and the US autumn transition week; missing
  M30 half rejection; source OCO/news/current-SL invariants; fixed-set checks.

The source has no USDJPY/EURUSD literal and no UTC/DST arithmetic. It uses the
chart symbol and explicitly documents the approved DXZ-only fixed-clock
override. Each `:30` grid hour requires two consecutive completed M30 halves;
ATR(14) includes the predecessor close. Management, OCO cleanup, and time exits
run before the placement-only news gate. Paired stop sends fail closed, the
attempt day is persisted, and peer removal occurs on the fill transaction plus
next-tick reconciliation.

## Verification

Focused arithmetic/source/set proof:

```text
python -m pytest framework/EAs/QM5_41485_ny-preopen-range-breakout-jpy/tests/test_grid_contract.py -q
......                                                                   [100%]
6 passed
```

SPEC validation:

```text
python framework/scripts/validate_spec_doc.py framework/EAs/QM5_41485_ny-preopen-range-breakout-jpy
PASS  QM5_41485_ny-preopen-range-breakout-jpy
Summary: 1 PASS, 0 FAIL (of 1)
```

EA-scoped hardening:

```text
python tools/strategy_farm/build_gate_hardening.py --repo-root . --ea-label QM5_41485_ny-preopen-range-breakout-jpy
failures=[]
warnings=[EA_BROKER_TIME_WINDOW_OVERRIDE]
```

The warning is the intentional, source-documented DXZ fixed-server-clock
override approved by critique `afb38e9a`; it is not generalized to FTMO.

Guardrails:

```text
python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_41485_ny-preopen-range-breakout-jpy
verdict=PASS; files_checked=4; findings=[]; max_news_stale_hours=336
```

Required build-check attempt:

```text
framework/scripts/build_check.ps1 \
  -EALabel QM5_41485_ny-preopen-range-breakout-jpy \
  -RepoRoot <task-worktree> \
  -ReportRoot C:/QM/repo/docs/ops/evidence/2026-09-21_qm5_41485_build/build_check \
  -SkipCompile -SkipMagicCheck

BUILD_CHECK_LIVE_FACTORY_COMPILE_REFUSED
underlying failure: LIVE_FACTORY_AD_HOC_COMPILE_REFUSED
receipt: NONE (preflight aborts before Write-GateEvidence)
```

`-SkipMagicCheck` is required by the ticket boundary: this task may not edit
magic registries. It does not waive the mismatch described below.

## Authority and concurrent registry state

The assignment-bound revision-2 source hash is
`84362c84bffcc748953b32254bd13902226b2671a011c7363ba03d6714881984`.
The current canonical sealed source hash is
`2120bd972a80cc0abf4024f9e6bdf96717c71599e46f7a5396e1439c5bd8bcb8`;
the only diff is the manifest `critic_receipt.json` hash, not the mechanical or
falsification text.

After the task branch was forked, an approved-card artifact and two canonical
magic rows appeared concurrently: slot 0 USDJPY and slot 1 EURUSD. They do not
match the ticket's explicit three-arm mapping (slot 0 USDJPY C2, slot 1 USDJPY
C3, slot 2 EURUSD C3). This task did not create, rewrite, or reconcile those
rows. Reviewer/OWNER adjudication is required before any governed compile or
pipeline use; the source package itself remains bound to the routed payload.

## Artifact hashes

| Artifact | SHA-256 |
|---|---|
| MQ5 source | `a55be9bbfbfc64954a10b8850c9ab67b799bbf501bd2e1efb8546d8b1bf71575` |
| SPEC | `9adf0179ed401c386e6c942f0a8015d7958b284bf483f7cfbd67c0b1a1843245` |
| draft mirror | `16a8b83be4a1e782a64dcb272945b38fddd99b7bfdfc699000898ced01f53e93` |
| USDJPY C2 set | `c1aefdadb4fb05d876bd704803d427bc158b40f0bf977122552dc6b5f711a8e8` |
| USDJPY C3 set | `a160222a033708c7d0f65b69b9d1b15df2f2d445b9325cd968304ba9c1514080` |
| EURUSD C3 set | `4e1ab7452e4a68d35631f479d4749c6736fc1e452fd716cdbeacc21c5c6b2ac8` |
| unit proof | `075002ebcc3562bc1344d245e13e22c4b80bebd134df9d1e9e24ca5635e775fc` |

The set headers intentionally retain `build_hash: pending`: the authoritative
build-check never reached set validation/sealing, and manufacturing a PASS or
hash would violate the evidence contract. No `.ex5`, compile row, factory row,
card transition, backtest enqueue, FTMO action, T_Live action, or live action
was produced.
