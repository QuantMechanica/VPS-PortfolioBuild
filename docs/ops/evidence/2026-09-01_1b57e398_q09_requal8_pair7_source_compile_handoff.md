# Q09 REQUAL-8 pair 7 source seal and governed compile handoff

- Recorded: `2026-09-01T13:12Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest SHA-256:
  `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR7_SOURCE_SEALED_COMPILE_HELD`

## Outcome

Pair 7 now has a mechanically faithful new-identity source port, SPEC, and one
manifest-bound `EURUSD.DWX D1` backtest set. The source preserves the parent
OHLC squeeze, pending-stop lifecycle, range target, and capped range stop while
updating only current framework conformance: bounded `QM_ReadBar` access, the
Q08 MAE-first hook, and entry-only news blackout placement below management and
exit handling.

The exact governed compile request was enqueued once and created utility work
item `26d03ef4-cfae-4d31-9202-040d29a1e14b`. The row is pending under the
controller-created `COMPILE_EA_WORKER_ROLLOUT_PENDING` release-on-restart hold.
That hold was not bypassed or released. No direct compiler, MetaEditor,
terminal, smoke, or pipeline command ran.

Pair 7 is therefore not yet a completed build. No EX5, build-result JSON,
review, Q02 seed, hold release, or pipeline verdict is claimed. The manifest
hold for pair 7 remains active.

## Governed identity and source binding

- Parent:
  `QM5_11421_ohlc-daily-squeeze-reversal-d1`
- Successor:
  `QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8`
- Approved recovery card:
  `D:/QM/strategy_farm/artifacts/cards_review/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8.md`
- Recovery-card SHA-256:
  `6a7a6bd10ab45b9253d6a52feaa285ed2a3c61d3727a745f1a555c44fe3457e9`
- Card state: `g0_status: APPROVED`
- Target: `EURUSD.DWX`, `D1`
- Active EA registry identity: `41221 / ohlc-daily-squeeze-reversal-d1-requal8`
- Active magic slot: `0 / EURUSD.DWX / 412210000`
- Registry and generated resolver files changed by this build: zero

## Sealed build inputs

- MQ5:
  `framework/EAs/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8.mq5`
- MQ5 SHA-256:
  `ede8570a029563fadecdfb99b829331903dffa0d2e46a3bb64c6e3cf8af8e91f`
- SPEC:
  `framework/EAs/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8/SPEC.md`
- SPEC SHA-256:
  `ecd2934dfdb42576f01d5ade15f481603df6a2ba8278832ac62d2ceea770490b`
- Setfile:
  `framework/EAs/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8/sets/QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8_EURUSD.DWX_D1_backtest.set`
- Pre-compile setfile SHA-256:
  `30d264d6f8533d9f40c9833f9ed69a69d7b914a20adf0db458cd7a01b40e59cb`
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- News staleness ceiling: `qm_news_stale_max_hours=336`

The setfile's build hash remains the explicit pre-compile placeholder. The
governed compile worker owns the authoritative build-check rewrite and compile
evidence; this checkpoint does not manufacture either.

## Focused verification

- `validate_spec_doc.py`: `1 PASS, 0 FAIL`.
- `validate_build_guardrails.py`: MQ5 and setfile `PASS`, zero findings,
  maximum news staleness `336` hours.
- `build_gate_hardening.py`: zero failures. Its three warnings are the expected
  undecidable-card warnings because the approved recovery card resides in the
  runtime `cards_review` reservoir rather than a repository card-of-record
  location.
- Exact symbol is present in `dwx_symbol_matrix.csv`.
- Exact identity and magic rows are active.
- No registry or resolver file is dirty from this build.

A `build_check.ps1 -SkipCompile` attempt was refused before any gate mutation
because live terminal processes exist. The controller returned
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` and instructed use of the governed
compile queue. The exact task-bound `enqueue-compile` command was then used.

## Compile queue read-back

- Work item: `26d03ef4-cfae-4d31-9202-040d29a1e14b`
- Phase: `COMPILE_EA`
- Status: `pending`, unclaimed, attempt `0`
- Bound build task: `0f36f1bb-924b-4126-b682-c30ba1edfa41`
- Bound MQ5 SHA-256:
  `ede8570a029563fadecdfb99b829331903dffa0d2e46a3bb64c6e3cf8af8e91f`
- Queue risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Queue symbol/timeframe: `EURUSD.DWX / D1`
- No-gate utility marker: `true`
- Active hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- Hold reason: reviewed compile worker is not yet released on the full terminal
  fleet; release is restricted to the governed restart ceremony.

The compile task's `activation_held_count=1` is treated as a measured governed
hold, not as compile evidence or permission to invoke a local compiler.

## QM5_41162 strict no-touch proof

The protected `QM5_41162 / OPT_CENSUS` snapshot still contains 1,159 rows. A
canonical JSON serialization of every column ordered by work-item ID has
SHA-256
`1667eada0a31433761cf9061f8c4b9e5825233e81c8de74974afd725d553cf3a`,
identical to the pair-6 checkpoint. No protected row, artifact, evidence,
source, setfile, or process was targeted.

## Verdict

`PAIR7_SOURCE_SEALED_COMPILE_HELD`: the pair-7 source package is statically
verified and bound to exactly one governed compile work item. Completion must
wait for the reviewed compile-worker rollout hold to clear; pair-7 review,
Q02 seeding, and manifest-hold release remain forbidden until compile evidence
exists.
