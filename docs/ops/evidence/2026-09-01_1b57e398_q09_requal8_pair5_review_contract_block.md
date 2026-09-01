# Q09 REQUAL-8 pair 5 review-contract block

- Recorded: `2026-09-01T06:12Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Pair: `QM5_12567 -> QM5_41219`, `XAUUSD.DWX D1`
- Canonical branch: `agents/board-advisor`
- Verdict: `PAIR5_Q02_REVIEW_CONTRACT_BLOCKED`

## Outcome

Pair 5 remains build-clean, but the canonical Q02 enqueue contract has no
admissible farm review predecessor. Mechanical Codex review
`572faf34-4117-48d8-b350-212358b1d9e9` is `done/PASS`, and the router's latest
Orchestrator close-out also calls the build PASS and directs the serial chain to
continue. The farm `ea_review` row for the same build,
`a3db9bf9-5556-4599-b099-d1862b12b56e`, is nevertheless
`done/REJECT_REWORK`.

The Claude rejection is authority-only: it treats the reservation card's
compile disclaimer as controlling. The canonical controller has an explicit
hash-bound exception that accepts the approved REQUAL-8 manifest as build
authority, and all mechanical/build findings pass. That disagreement does not
permit this worker to overwrite the historical Claude verdict or manufacture a
new `APPROVE_FOR_BACKTEST` row.

The manifest's exact supported command was attempted once with the only farm
`ea_review` row:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest --review-task-id a3db9bf9-5556-4599-b099-d1862b12b56e --phase Q02
```

It returned without enqueueing:

```json
{
  "enqueued": false,
  "reason": "Review verdict was 'REJECT_REWORK', not APPROVE_FOR_BACKTEST"
}
```

No fallback SQL insert, review rewrite, auto-Q02 bypass, hold release, or pair-6
build was attempted. The serial boundary is therefore intact.

## Build and review bindings

- Build task: `da8e6083-8e62-43a7-85f4-68d009383e96`, `done`
- Build commit: `a9767089d9`
- MQ5 SHA-256: `cd2a0ac6e3f4a677cbb30197e23eaeb8338f06f69d66341eeedfc45cb68746b3`
- EX5 SHA-256: `e9670141e89249aff7df44a10a2402e2103aa4cecf8d0a35a8cd6d6babedf108`
- SPEC SHA-256: `15ba5e9758af5ef557c1877dfac8a91441d7c7e44e1655c0956807e12b2f8eda`
- Backtest-set SHA-256: `297081b5b1e8aa70e76246b1cdaafdd38807305c5e8d05db59e5d63998fa180a`
- Mechanical Codex verdict artifact SHA-256:
  `42d1160581f8b67bf2e553082ce04d18aa84288678e5aacf25395c460b00fee6`
- Claude verdict artifact SHA-256:
  `7364860a3960c652e9b7308b35761d577e0586fe1de961a8fba0dc793d528d50`

## Focused verification

- `validate_spec_doc.py`: `1 PASS, 0 FAIL`.
- `validate_build_guardrails.py`: source and setfile both `PASS`, zero
  findings, maximum news staleness `336` hours.
- `build_gate_hardening.py`: zero failures; only the three expected warnings
  caused by the approved recovery card residing in the runtime `cards_review`
  reservoir.
- Backtest risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Compile evidence remains `COMPILE_OK`, zero errors and zero warnings, at
  `D:/QM/reports/work_items/ed5f9b8f-8804-4678-8908-621aa97aa985/QM5_41219/COMPILE_EA/compile_evidence.json`.
- SQLite `PRAGMA quick_check`: `ok`.

Final read-back:

- pair-5 manifest hold `7bbeef66-becf-4bd3-aa5c-1d00bde262d8`:
  active, unreleased;
- pair-5 Q02 rows: `0`;
- pair-6 `QM5_41220` work items: `0`;
- pair-6 farm tasks: `0`;
- protected `QM5_41162 OPT_CENSUS` rows: `1,159`; read-only selected-state
  snapshot SHA-256
  `38e40cc3a902ae6ad67661906bfa1b5581c78836d91917ea9a88bc3fcdf9fa99`.

## Required continuation

Before pair 5 can seed Q02, an authorized controller/reviewer must append a
supported farm `ea_review` adjudication with `APPROVE_FOR_BACKTEST`, or land a
governed append-only bridge that consumes the existing Orchestrator review.
The rejected Claude row must remain historical evidence. Only after the
canonical enqueue creates and verifies exactly one pair-5 Q02 row may the exact
manifest hold be released and pair 6 begin.

No terminal was started manually, no active T1-T10 test was interrupted, and
neither AutoTrading nor `T_Live` was changed. The Company Reference drive `G:`
returned access denied in this headless session; the task payload, local charter,
profitability-track contract, manifest, registries, database, and canonical
evidence were used without guessing missing policy.
