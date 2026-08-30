# Q09 REQUAL-8 serial execution — pair 2 build-review handoff

- Recorded at: `2026-08-30T21:09:10Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER decision: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest: `docs/ops/evidence/2026-08-30_8709bc0f_q09_requal8_manifest.json`
- Manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Serial pair: `QM5_12989 -> QM5_41216`, `XAUUSD.DWX`, `H4`
- Build task: `5f5da824-916d-4d37-b12c-0fcb642f5508`
- Governed compile row: `f2ee1f09-1233-4165-b1f1-b828b2d59555`
- Decision-bound hold: `1cff016c-d25c-4723-a892-6bc53bfafa0b`
- Verdict: **PAIR 2 COMPILE AND STATIC BUILD GATES PASS; Q01 SMOKE CAPACITY-DEFERRED; HAND OFF TO MANDATORY REVIEW; NO Q02 SEED; HOLD NOT RELEASED**

## Governed compile result

The exact compile row released by the Orchestrator was claimed by the normal
worker on `T9` and completed at `2026-08-30T20:47:01Z` with
`COMPILE_OK`. Its durable evidence is:

`D:/QM/reports/work_items/f2ee1f09-1233-4165-b1f1-b828b2d59555/QM5_41216/COMPILE_EA/compile_evidence.json`

The evidence reports `compile_one.result=PASS`, zero compile errors, zero
compile warnings, and `build_check.result=PASS`. The artifact bindings were
recomputed from the canonical checkout and match the evidence exactly:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `86ca7542f43cbff111adb6fe96fa6e1a1e13e100196cfa57f71365e86b66deb2` |
| EX5 | `a061e1b0a9a18ea7da98793f8f2d3ea5dad95cfcfa1f83154f8ef50f638f07c6` |
| Append-only bound set | `92fa6ab14f8ee2297dd529dbdc8874dd6759aa04ddfcca7bbb3ab0727b6453c7` |

The pump committed the governed EX5 in `8d316127c`; the worker-owned set
binding was committed with the one-path commit `9d4140c08`. The historical
setfile and its earlier immutable build binding were not changed.

## Focused verification

Verification against the exact current source and append-only set produced:

- `validate_spec_doc.py`: `PASS` (`1 PASS, 0 FAIL`);
- `validate_build_guardrails.py`: `PASS` for MQ5 and set, no findings, maximum
  news staleness `336`;
- `build_gate_hardening.py`: zero failures; three normal undecidable-card
  warnings because the recovery card is in the runtime `cards_review` store;
- symbol registry: exact `XAUUSD.DWX` match and active magic `412160000`;
- backtest risk binding: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- SQLite `PRAGMA quick_check`: `ok`.

No stale-news ceiling, risk convention, strategy mechanic, registry row, or
historical evidence binding was weakened or overwritten.

## Single Q01 smoke attempt and capacity receipt

After a read-only `farmctl.py mt5-slots` census, the one build-contract smoke
attempt used the exact bound set, `XAUUSD.DWX`, `H4`, year 2024, Model-4 smoke
mode, minimum one trade, and `-Terminal any`. The dispatcher refused before an
EA/tester launch:

```text
Terminal resolution returned no terminal. status=no_capacity error_code=none message=No message.
```

The immediately preceding census was recorded at
`2026-08-30T21:07:20Z`: `terminal64_running_count=5`; tester-owned processes
were active on `T1`, `T4`, and `T5`; and all ten normal terminal workers
`T1`–`T10` were alive. The resolver's exact `status=no_capacity` is the
sanctioned `deferred_p2_smoke` capacity evidence under the shared build-result
schema. No smoke report exists because dispatch refused before launch. The
attempt was not retried, and no active terminal, reservation, worker, or test
was interrupted.

## Review and serial boundaries

This record is a build-review handoff only. It does not claim a mechanical
Codex review, independent Claude review, Q02 seed, pipeline verdict, or hold
release. The build-result object is stored beside this evidence as
`2026-08-30_1b57e398_q09_requal8_pair2_build_result.json` and is copied to the
runtime build-result target for `farmctl.py record-build`.

The final read-only census before handoff found:

- zero Q02 rows for `QM5_41216`;
- all eight decision-bound holds still `pending`, unclaimed, with no verdict or
  evidence path;
- pair-2 hold `1cff016c-d25c-4723-a892-6bc53bfafa0b` unchanged;
- pairs `QM5_41217` through `QM5_41222` still card-only;
- protected `QM5_41162` `OPT_CENSUS` still exactly 1,085 rows.

Pair 2 may append exactly one manifest-authorized Q02 seed only after the
required reviews approve this exact artifact generation. Its hold may be
released only after that seed is verified. Pair 3 remains untouched until
pair 2 reaches that terminal serial outcome.

Verdict: `PAIR2_BUILD_READY_FOR_MANDATORY_REVIEW_SMOKE_CAPACITY_DEFERRED`;
zero Q02 seeds, zero hold releases, zero pipeline verdicts, and zero terminal
disruption.
