# Q09 REQUAL-8 pair 4 Q01 build record and review handoff

- Recorded: `2026-08-31T18:32Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR4_BUILD_RECORDED_CODEX_REVIEW_PENDING`

## Outcome

Pair 4 has crossed the truthful Q01 build-record boundary. The single
task-contract smoke attempt used `run_smoke.ps1 -Terminal any -SmokeMode` and
was refused before launch with resolver `status=no_capacity`. No terminal was
started, no active T1-T10 work was interrupted, and no smoke report was
fabricated. The build result therefore uses the schema-sanctioned
`deferred_p2_smoke` disposition with the exact measured capacity evidence.

`farmctl.py record-build` recorded build task
`4e026269-a3e9-4030-8c12-7dd2da788cf4` as `done`. Its manifest-specific Q02
guard returned no enqueues and reason
`q09_requal8_review_required_before_q02`. The scheduled farm controller then
opened mechanical Codex review `a508f6f6-f798-4a6e-ad20-32947346eeef`; that
review was still `pending` at this checkpoint. No independent Claude review,
Q02 seed, hold release, or pipeline verdict is claimed.

## Artifact bindings

| Artifact | SHA-256 |
|---|---|
| MQ5 | `6da309ab85b209e5b2b3c739ffc75246d8f78447d47bb3eeff70a50f25b8e7de` |
| EX5 | `c3e6e260c14ec8b7263b35aae3380433d4c48b6b3d34199deb27b2e18eb52f10` |
| SPEC | `468522458de183162e44ad5e7ae8a97fcd81b85a6f4f8798b38cb676700f13fd` |
| Bound backtest set | `acbfe9a15d24987eb70cad5289429b671f2732a57e81c14e9ec047d1cd2612f4` |
| Compile evidence | `623f29fb3e377041412fb398821cb2da6b50b9ed0eb18605a23120c1ba920f33` |
| Build result | `6e7d2f9f8af6aa6cbc10e6fb44b4a0c958118f227b13a910ab1aa4de73dd33af` |

Build result:
`D:/QM/strategy_farm/artifacts/builds/4e026269-a3e9-4030-8c12-7dd2da788cf4.json`

Compile evidence:
`D:/QM/reports/work_items/a864683a-9f08-4904-aba3-782a71d2e5ee/QM5_41218/COMPILE_EA/compile_evidence.json`

The source, binary, SPEC, and setfile hashes are unchanged from the governed
compile checkpoint. The build result binds `QM5_41218`, magic base
`412180000`, `EURUSD.DWX H4`, and the approved manifest hash above.

## Q01 smoke disposition

Immediately before the one authorized attempt, `farmctl.py mt5-slots` recorded
at `2026-08-31T18:25:50Z`:

- `terminal64_running_count=4` including the two live terminals;
- active tester-owned work on T7 and T8;
- all T1-T10 terminal-worker daemons alive;
- no duplicate terminal workers and no orphaned terminal processes.

The exact attempt at `2026-08-31T18:27Z` exited before launch with:

`Terminal resolution returned no terminal. status=no_capacity error_code=none`

The durable build result records that resolver outcome and the immediately
preceding census in `blocked_reason`, satisfying the saturation-only waiver in
`tools/strategy_farm/prompts/SCHEMAS.md`. `smoke_report_path` remains `null`.
This is a Q01 build disposition, not runtime strategy evidence.

## Focused verification

- `validate_spec_doc.py`: `1 PASS, 0 FAIL`.
- `validate_build_guardrails.py`: MQ5 PASS and setfile PASS, zero findings,
  maximum news staleness `336` hours.
- `build_gate_hardening.py`: zero failures; three expected card-discovery
  warnings because the approved recovery card is in the runtime
  `cards_review` reservoir.
- Backtest risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Controller record timestamp: `2026-08-31T18:29:15Z`.
- Controller build state: `done`.
- Controller Q02 result: zero rows enqueued under the manifest review gate.

The controller also exposes `fail_code=smoke_failed` because the build result
truthfully carries a non-empty saturation `blocked_reason`; that classifier
label does not reverse the recorded `done` state. Acceptance of the sanctioned
waiver is evidenced by the controller subsequently opening the mechanical
Codex review for the same build generation.

## Preserved serial boundary

- Mechanical Codex review: `a508f6f6-f798-4a6e-ad20-32947346eeef`, `pending`.
- Independent Claude review: not opened.
- Pair-4 Q02 rows: zero.
- Pair-4 manifest hold `2604a1f0-4f58-4597-89ef-432af9093131`:
  `pending`, unclaimed, no verdict.
- Pairs 5-8: not advanced by this cycle.
- Protected `QM5_41162 OPT_CENSUS`: 1,085 current rows; read-only state
  snapshot SHA-256 `d7ea9090a22cbabf70cdd373805b7250b2cec2799231b5efd09993da9642be0c`.

The next exact gate is the already-open pump-owned mechanical Codex review.
Only its PASS may open the independent Claude review. Only after both reviews
approve may the manifest enqueue exactly one append-only Q02 seed and release
the exact pair-4 hold. No command in this cycle targeted, reprioritized,
cancelled, or interrupted the protected `QM5_41162` optimization program.
