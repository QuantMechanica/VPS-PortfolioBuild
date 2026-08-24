# QM5_41136 governed compile release continuation

Date: 2026-08-24

Branch: `agents/board-advisor`

Status at this receipt:
`COMPILE_RELEASED_PENDING_CLAIM_Q02_NOT_ENQUEUED_CPU_CEILING`

## Scope

This receipt continues the source-ready build recorded in
`docs/ops/evidence/2026-08-24_qm5_41136_xng_iqrmean_build_cpu_ceiling.md`.
The selected candidate remains the one new sleeve for this mission:
`QM5_41136_xng-mdaily-iqrmean-mom`, strategy ID
`MOP-MEEK-XNG-MDAILY-IQRMEAN-2026_S01`.

The card is OWNER-approved, the EA identity and slot-zero magic are active,
the MQ5/source package and sole `RISK_FIXED` backtest setfile are committed,
and no EX5 existed at the start of this continuation. The candidate is a
symmetric, monthly, oscillator-free XNG continuation rule based on the
interquartile mean of the immediately completed month's daily log returns. It
is mechanically different from certified `QM5_12567_cum-rsi2-commodity`,
which is a long-only two-day cumulative-RSI pullback above SMA(200) with a
five-bar hold. This distinction does not transfer a portfolio-correlation
claim; Q09 remains authoritative.

## Deterministic preflight

- approved card:
  `strategy-seeds/cards/approved/QM5_41136_xng-mdaily-iqrmean-mom_card.md`;
- card `g0_status`: `APPROVED`;
- registry row: `41136,xng-mdaily-iqrmean-mom,...,active`;
- magic row: `41136 / slot 0 / XNGUSD.DWX / 411360000 / active`;
- MQ5 SHA-256:
  `45dde0ab39d8e9c1b7d6ee1f69bcbb96fa0eed7a2816ddc38844e38ee0792db5`;
- card schema lint: PASS with zero missing sections and zero ML hits;
- deterministic reference suite: PASS, 16/16;
- `validate_spec_doc.py`: PASS, 1/1;
- MQ5 and setfile `validate_build_guardrails.py`: PASS with zero findings;
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero
  violations.

No MT5 terminal, tester, AutoTrading state, live artifact, portfolio gate, or
deploy/T_Live manifest was changed by these checks.

## CPU recovery observations

The prior receipt stopped after a five-sample 97.85% average and 98.46%
maximum breached the 97.0% claim ceiling. This continuation did not release
the compile hold until two fresh windows were below that ceiling:

1. `73.52, 96.51, 83.67, 71.90, 68.36` percent; average 78.79%, maximum
   96.51%.
2. `59.35, 55.54, 46.86, 55.50, 49.42` percent; average 53.33%, maximum
   59.35%.

A later five-sample decision window at `2026-08-24T00:27:03Z` remained clear:
`73.41, 69.35, 60.82, 60.16, 67.00` percent; average 66.15%, maximum 73.41%.
The configured claim ceiling is 97.0% and the resume threshold is 90.0%.

## Exact compile release

The existing source-hash-bound compile item is
`77d52009-3434-4c70-a93b-29471832c3cd`. A target-only dry run selected exactly
that row and no other row. Its expected and actual MQ5 SHA-256 both equaled
`45dde0ab39d8e9c1b7d6ee1f69bcbb96fa0eed7a2816ddc38844e38ee0792db5`.

The governed one-item release completed at `2026-08-24T00:10:13Z` with note:

`OWNER commodity/energy mission 2026-08-24: exact QM5_41136 paced compile after two below-ceiling CPU windows`

The transition ledger idempotency key is
`compile-rollout:77d52009-3434-4c70-a93b-29471832c3cd:COMPILE_EA_WORKER_ROLLOUT_PENDING`.
The release made a full SQLite backup before atomically deactivating only this
row's `COMPILE_EA_WORKER_ROLLOUT_PENDING` hold. It did not claim or execute the
row and did not launch a terminal.

## Current boundary

At the last readback in this receipt, the compile item was pending, unclaimed,
attempt zero, verdict-free, and the only released pending `COMPILE_EA` row.
The resident workers had not yet selected it; the canonical queue placed 120
downstream items ahead of it. Six worker slots were also being recycled after
their custom-history startup gate rather than claiming new work. No manual
claim, priority mutation, Factory-OFF transition, terminal restart, ad-hoc
compile, or safety bypass was attempted.

Consequently there is still no current EX5, sealed setfile, Q01 PASS, or legal
Q02 enqueue at this point. Q02 must remain absent until the governed worker
returns `COMPILE_OK` with zero errors/warnings and a current build binding.

## Binding CPU stop

At `2026-08-24T00:36:34Z`, the bounded watcher observed a 99.22% total-CPU
point sample. The resident worker contract trips at any observation above
`CPU_MAX_LOAD_PERCENT=97.0`; the mission independently requires stopping when
that backtest CPU ceiling is hit. The immediately following five-sample
confirmation was `72.17, 69.61, 69.42, 65.04, 64.87` percent, averaging
68.22% and peaking at 72.17%. That recovery does not erase the preceding
99.22% trip or authorize another attempt inside this mission.

Final readback after the trip remained pending, unclaimed, attempt zero, and
verdict-free. The canonical EX5 path was still absent. No Q02 row was inserted.
Machine-readable evidence is
`artifacts/qm5_41136_compile_release_cpu_stop_20260824.json`.

## Safety boundary

This continuation changes only the exact non-live compile-row hold and records
its evidence. It does not authorize a backtest bypass, live/demo/shadow/stress
setfile, T_Live or deploy manifest, AutoTrading, portfolio-gate change,
portfolio admission, correlation waiver, terminal control, or a second queue
row. No compile retry, dispatcher tick, tester action, or queue mutation
followed the CPU trip.
