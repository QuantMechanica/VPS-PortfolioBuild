# Q02 stranded exhausted pairs — reissued live disposition

Date: 2026-09-12 09:04 UTC
Router task: `af3eac6e-9745-4e35-9171-0517221e15c9`

## Corrected result

**REVIEW — three pairs dispositioned; one prior governed canary failed before
MT5 at the compile gate; no second canary or requeue.** A fresh read-only
classifier regenerated the artifact after the two review returns. The live
cohort is three pairs / 41 terminal INFRA_FAIL rows, not the earlier claimed
3 -> 2 improvement.

All three pairs are evidence/implementation defects. None has an authenticated
zero-trade aggregate, so none may be routed to the RETIRE/frequency-floor lane.

| Pair | Rows | Row-bound evidence | Current disposition |
|---|---:|---|---|
| `QM5_10505 / XAUUSD.DWX` | 15 | `cc347183` summary SHA `697d26e8...ecbe1` and worker log exist; result `ONINIT_FAILED; INCOMPLETE_RUNS` | Prior single canary `7f4fb7d4` was claimed on T8, passed private-history and EX5 staging, then failed `spawn_refusal:compile_gate:COMPILE_FAILED`. Keep in compile-gate evidence repair; do not requeue here |
| `QM5_12582 / XNGUSD.DWX` | 13 | `ae468d0f` summary SHA `be8bb2a1...e9ca3d` exists; worker log absent; result `ONINIT_FAILED; INCOMPLETE_RUNS`; historical lock-storm overlay | Evidence recovery/implementation preflight. Fresh classifier nominates it as the next theoretical candidate, but the task's at-most-one canary budget was already consumed; no requeue |
| `QM5_20143 / EURUSD.DWX` | 13 | row reason `NO_HISTORY; ONINIT_FAILED; INCOMPLETE_RUNS`; bound summary and worker log both absent | History-coverage plus evidence recovery. No canary or requeue without exact-window coverage and restorable evidence |

Fresh machine-readable artifacts:

- `docs/ops/evidence/2026-09-12_q02_stranded_pairs_classification_reissue.json`
  — SHA-256 `132b85102bf62ac5ae7dcba097c50f41553b04173e8207bd7c4d6c8c12b68f0a`;
- `docs/ops/evidence/2026-09-12_q02_stranded_pairs_classification_reissue.csv`
  — SHA-256 `12750f24f450062f0920b1da56a1d506a975d3e4a7b67fade2a8cd7f1a088a39`.

The snapshot classification is `INVALID_EVIDENCE_DEFECT=3`, with primary
causes `ONINIT_FAILED=2` and `NO_HISTORY_TRANSIENT=1`. It contains 0 valid
zero-trade rows and 0 retire draft rows. The older classification files and
commits remain untouched as historical evidence.

## Prior canary outcome, bound to the live row

The only task canary is append-only row
`7f4fb7d4-4fa0-4233-b1d1-f3c912ea12ff`, whose payload binds source row
`cc347183-5365-427e-b815-3879639c0d42`, EX5 `cc702479...3bbb`, setfile
`d13392b7...67a9`, `RISK_FIXED=1000`, and `RISK_PERCENT=0`. Its live terminal
state is:

- `status=failed`, `verdict=INFRA_FAIL`;
- `evidence_path=EVIDENCE_UNAVAILABLE:spawn_refusal:compile_gate:COMPILE_FAILED`;
- claimed by T8 at 06:16:30 UTC;
- custom-history admission/copy-on-claim passed for 108 private XAUUSD files;
- no MT5 report exists because the compile gate refused before spawn.

This is an infrastructure/compile preflight result, not a strategy frequency
measurement. It does not terminally disposition the pair outside the health
cohort. The separate compile-gate cluster ticket may repair that shared cause;
this task neither duplicates it nor spends a second canary.

## Verification

- direct read-only `health.chk_q02_stranded_exhausted_pairs`: `FAIL value=3`;
- focused health contract: **11 passed**;
- fresh classifier: 3 pairs / 41 rows, 3 invalid evidence defects, 0 valid
  zero-trade, 0 retire candidates;
- historical rows and their verdict/evidence paths are unchanged;
- no T_Live/FTMO, terminal launch, active-backtest interruption, or queue
  mutation in this reissue.

The three-pair acceptance is met by an honest per-pair disposition plus the
recorded one-canary result. Health is intentionally still 3 until the named
evidence/compile/history defects produce a non-infra terminal disposition.

## Orchestrator addendum 2026-09-12 (holds question, DB-verified)

No governed evidence-repair hold is created for QM5_12582/XNGUSD.DWX (9 done, 4 failed, 0 pending) or
QM5_20143/EURUSD.DWX (10 done, 3 failed, 0 pending): every row of both pairs is terminal, so there is no pending
row a hold could act on. A successor for either pair is gated by the compile-gate cluster ticket 57fc8b42 (source
of the rework builds does not compile today) and must be enqueued append-only (`farmctl enqueue-backtest
--append-only-rerun-of`) once a COMPILE_OK receipt exists; the cause-group abort clause stands (no second canary).
