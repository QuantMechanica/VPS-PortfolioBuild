# Q09 REQUAL-8 pair 3 governed build-review checkpoint

- Recorded: `2026-08-31T07:08Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Pair: `QM5_10815 -> QM5_41217`, `GDAXI.DWX H1`
- Build task: `b958b565-e847-49e1-8ec9-6575f67b0d7f`
- Governed compile row: `24ab1d53-bff1-493c-a59b-eef83ab732f7`
- Checkpoint: `BUILD_RECORDED_REVIEW_FIRST_GATE_ACTIVE`

## Outcome

The scheduled compile worker completed the exact released `COMPILE_EA` row with
`COMPILE_OK`, zero compiler errors, zero compiler warnings, and
`build_check.result=PASS`. Focused static verification also passed. The single
task-contract smoke attempt was refused before launch with measured
`status=no_capacity`; no terminal was started manually and no active tester was
interrupted.

The build result was recorded through the canonical controller with the exact
approved manifest hash. The controller returned `new_status=done` and
`auto_q02_enqueued.enqueued=[]` with reason
`q09_requal8_review_required_before_q02`. Pair 3 therefore remains behind the
mandatory mechanical Codex review and independent Claude review. No Q02 seed,
hold release, or pipeline verdict is claimed.

## Artifact bindings

| Artifact | SHA-256 |
|---|---|
| MQ5 | `7ce436082f36df9924ec2d50bb39b05261507e52203bf255a3cbe10522e5c07e` |
| EX5 | `5f91c66cf86ffe9d607c199bc3b8ef7c033fb1071ccc8aea8703977ec2503fed` |
| Bound backtest set | `1f4d97802b02e5e352cd4d1fb2f663e6583a78755c24285731333a775fbab433` |
| Compile evidence | `bc79294cd41c8eb822e1d95b762f18e35b9d4d3a85577ca71fc398cdc6c53873` |

Compile evidence:
`D:/QM/reports/work_items/24ab1d53-bff1-493c-a59b-eef83ab732f7/QM5_41217/COMPILE_EA/compile_evidence.json`

Build-result artifact:
`D:/QM/strategy_farm/artifacts/builds/b958b565-e847-49e1-8ec9-6575f67b0d7f.json`

## Focused verification

- `validate_spec_doc.py`: `PASS`, one pass and zero failures.
- `validate_build_guardrails.py`: `PASS` for the MQ5 and bound setfile, zero findings, maximum news staleness `336` hours.
- `build_gate_hardening.py`: zero failures; the three warnings are card-discovery undecidable warnings because the approved recovery card is held in the runtime reservoir.
- Magic/symbol binding: active slot 0, magic `412170000`, exact matrix member `GDAXI.DWX`.
- Backtest risk binding remains `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- One `run_smoke.ps1 -Terminal any -SmokeMode` attempt returned `status=no_capacity` before launch. The immediately preceding `farmctl.py mt5-slots` census at `2026-08-31T07:07:47Z` found active tester-owned work on T1 and T4 and all T1-T10 terminal workers alive.

## Preserved serial boundary

The pair-3 manifest hold `57d8bacd-2805-45a6-ac51-156e22bb3a65` remains active.
Pairs 4-8 were not advanced. The protected `QM5_41162 OPT_CENSUS` program was
not queried for mutation and was not touched. The next exact gate is the
pump-owned Codex mechanical pre-review for this recorded build generation;
only a passing mechanical review may open independent Claude review, and only
approved reviews may authorize one append-only Q02 seed and the exact pair-3
hold release.
