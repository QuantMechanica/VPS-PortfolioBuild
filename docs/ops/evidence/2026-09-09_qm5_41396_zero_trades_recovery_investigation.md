# QM5_41396 Q02 Zero-Trades Recovery Investigation

Date: 2026-09-09 (Europe/Berlin)

EA: `QM5_41396_xng-summer-w2agree`

Work item: `bd47f2f3-b8e2-461a-8a41-84a4092d0a1c`

Classification: `IMPLEMENTATION_DEFECT / ENTRY_DECISION_PATH_UNREACHED`

Observed database verdict: `ZERO_TRADES`

Recovery action: none in this mission; preserve the bound result and add
rate-limited decision-clock diagnostics before a same-contract recovery run.

## Outcome

The Q02 harness and setup layers are valid. The run initialized successfully,
loaded the one required symbol, processed 1,163 D1 bars and 21,374,150 ticks,
and retained stable source, deployed binary, and setfile hashes. It nevertheless
emitted no `STRATEGY_STATE`, attempt, signal, order, position, or trade event.

This is not evidence that strict two-week agreement never occurred. The source
is designed to emit one `STRATEGY_STATE` event after each recognized weekly
attempt, including ineligible months, disagreement, and invalid completed-week
states. Zero such events across the complete 2018-2022 run means the decision
path did not reach that observable boundary. The first failed layer is the
entry hook, before economics.

The exact early-return branch is not proven by the current logging. The bounded
candidates are the normalized D1 decision-clock checks or the persistent weekly
attempt write immediately before `STRATEGY_STATE`. The label-offset check is a
leading hypothesis because the locked strategy value is 86,400 seconds, while
the runtime trace does not expose `current_bar.time` alongside `TimeCurrent()`.
Changing that value without runtime evidence would alter a card-bound calendar
rule and is prohibited.

No strategy threshold, month, formation window, direction, stop, holding rule,
or retry policy was changed. No recovery compile, rerun, or requeue was
performed.

## Bound Execution Identity

| Field | Observed value |
|---|---|
| Terminal | non-live `T2` |
| Actual window | `2018.07.02` through `2022.12.31` |
| Host / timeframe | `XNGUSD.DWX` / D1 |
| Model | 4, 100% real-ticks report marker |
| Expert | `QM\\QM5_41396_xng-summer-w2agree` |
| Source/deployed EX5 SHA-256 | `c0de9c7f84a945f00c8349d047bce0c92eb926090a719b2e33bcadb1ccb877df`, exact match and stable |
| Run-time MQ5 SHA-256 | `3cdfb7db6ac755a96c533c1aff2d4ee2015b20fef3ca5d887ce3f428ab93074e` |
| Source/deployed setfile SHA-256 | `de8720f427daf010fc07e8e02d122e8328fef8a04e5e8eca7007cb479eaa1177`, exact match and stable |
| Runner SHA-256 | `c55796861b1c73f80a4b0f140e48f88ca54cf42c90997023f20143e39a8733aa` |
| Report | valid HTML, 37,248 bytes, zero trades |
| Initialization | `INIT_OK`; no OnInit failure |

The report confirms `RISK_FIXED=1000`, `RISK_PERCENT=0`, the exact strategy
inputs, 100% real ticks, and the declared date window. The logger confirms
`BASKET_WARMUP` requested one and loaded one symbol. News-calendar state was
valid but all news axes were off.

## Layer Classification

### 1. Harness: PASS

- The report exists, is nonempty, and records the requested/actual dates.
- Model 4 and the 100% real-ticks marker are present.
- Source and deployed EX5 hashes match and remained stable.
- Source and deployed setfile hashes match and remained stable.
- Terminal, source, runner, report, journal, symbol, timeframe, and hashes are
  bound in `summary.json`.

### 2. Setup: PASS

- `INIT_OK` is present and no OnInit failure was detected.
- `XNGUSD.DWX` D1 is the actual route and the report lists the exact inputs.
- Symbol warm-up loaded 1/1 with 24 requested bars.
- The tester generated 1,163 bars and 21,374,150 ticks.
- There is no parameter, history, symbol, calendar, or report error that blocks
  entry-hook evaluation.

### 3. Entry hook: FAIL

- Expected weekly decision-state markers: nonzero, because all recognized
  weeks log a state even when they are outside summer or signal-flat.
- Observed `STRATEGY_STATE` markers: zero.
- Observed attempt, signal-fire, order, position, and trade events: zero.
- The failure is upstream of signal density and economics. The current artifact
  does not log individual early-return reasons, so choosing between the bounded
  clock and attempt-ledger branches requires instrumentation.

Order-path and economic layers were not reached and must not be interpreted.

## Minimal Same-Lineage Recovery

The next authorized recovery step is diagnostic only:

1. Add a default-off debug input and one rate-limited marker at each decision-
   clock early return, recording raw D1 bar time, broker time, detected label
   offset, normalized date/week keys, copied-bar count, and prior-week key.
2. Add one explicit marker if the weekly attempt global-variable write fails.
3. Re-run the PACER input-pin audit, strict compile, and the same bound
   `XNGUSD.DWX` D1 test with diagnostics enabled.
4. Repair only the proven implementation mismatch. If the 86,400-second label
   rule itself is wrong, stop for a new OWNER-approved card version rather than
   silently changing the calendar mechanic.

## Required Recovery Deliverable

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| `QM5_41396` | T2, Model 4, XNG D1, 2018-07-02 to 2022-12-31, work item `bd47f2f3-b8e2-461a-8a41-84a4092d0a1c` | Entry decision path unreached; exact early-return branch unresolved because no decision-clock marker was emitted | None; preserve economics and instrument clock/attempt gates before same-contract rerun | Q01 strict compile PASS; no post-result compile | 0 | 0 | exact entry-clock branch, trade-capability recovery, valid Q02 economics, OOS/stress, Q09 correlation |

## Evidence Hashes

| Evidence | SHA-256 |
|---|---|
| `summary.json` | `ef0a7a1c5589079466e624b35026362a716af000b2c2057c6eb2e7b0aca9566b` |
| `logger_sample.jsonl` | `2c2f2fd797eebe7a87e31c733c6699c908ce8a9570fec63f7c9def7c243e3d42` |
| tester log `20260909.log` | `1655c3e0044d926f31ffdbc473e96b5b4e9e947ce921599decd28d0fe6f736be` |
| `report.htm` | `4e03bbbf3c45b522c7e575d98a05cd041fdd3b4559741e4c15a7d04f73c9eaac` |
| `tester.ini` | `d1e3f11a6ec2e027789415559e4dbafa31e8c603d4bf2eec103a089a134e82b7` |

## Governance And Safety Boundary

The database verdict was not relabeled or deleted. The paced fleet, not this
mission, dispatched the row after it was enqueued. No work item was requeued,
no recovery terminal was started or stopped, and no strategy mechanic was
changed. No live setfile, AutoTrading toggle, `T_Live` state, deploy manifest,
portfolio gate, portfolio admission, or correlation waiver was touched.

The governed build-record call was also refused fail-closed because the build
task had already been marked `blocked` with
`duplicate_build_task_existing_pipeline_work` and one pipeline work item. That
recording refusal did not alter the completed compile or Q02 evidence.
