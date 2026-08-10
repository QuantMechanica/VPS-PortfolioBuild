# QM5_10147 EURCHF repaired-INFRA Q02 enqueue

Date: 2026-08-10 (Europe/Berlin)

Branch: `agents/board-advisor`

Farm claim: `ed5649ef-2424-4976-8c5c-71267204eda4`

## Outcome

The repaired `QM5_10147_tii-momentum` EURCHF D1 canary is queued at Q02 as
work item `607bfd42-0095-4620-a4e1-3f5e65e17403`.

Immediate readback found the row pending, attempt 0, unclaimed, and without a
verdict. The enqueue is an infrastructure-recovery handoff, not a performance,
certification, correlation, or portfolio-admission result.

## Selection and non-duplication

The paced build backlog had one mechanically claimable task,
`QM5_20167_xng-spring-dualtrend`. It was not selected because another XNG
sleeve does not address the mission's instrument-diversity constraint. No
claimable approved forex, crypto, rates, beyond-XNG energy, or market-neutral
build task was present.

Priority 2 therefore selected the already-repaired but deliberately deferred
`QM5_10147` recovery:

- approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10147_tii-momentum.md`;
- fixed, closed-bar D1 TII state machine with an expected 10 trades/year/symbol;
- rare-FX canary `EURCHF.DWX` and no Q03-or-later lineage;
- no open `QM5_10147` work item and no competing in-progress agent claim;
- predecessor repair claim
  `a647d84f-4761-442c-934d-b44c0d27c57c` was terminal `APPROVED`, with its
  next action explicitly deferred until tester use fell below seven.

The predecessor diagnosis and mechanics-preserving runtime repair are recorded
in
`docs/ops/evidence/2026-08-06_qm5_10147_eurchf_q02_runtime_repair.md`.
The old Q02 row `14111248-8316-4caa-8a0c-66b1075f9871` exhausted retries as
`failed / INFRA_FAIL`; no economic verdict exists to preserve.

## Enqueue-guard repair

The first governed enqueue attempt failed closed with
`historical_artifact_binding_mismatch`: the terminal source row correctly names
the pre-repair MQ5/EX5 hashes, while the canonical directory now contains the
strictly compiled repair. The Q02 append-only path checked the historical bytes
before considering the explicitly supplied current EX5 hash, so an INFRA row
could not be retried after any source repair.

The narrow repair keeps the historical row immutable and permits replacement
artifacts only when all of these conditions hold:

1. the source row is terminal `INFRA_FAIL`, has readable evidence, and carries
   complete SHA-256 bindings for its historical MQ5, EX5, and setfile;
2. the historical symbol, period, and expert identity equal the current
   execution identity;
3. the current setfile resolves inside the canonical EA directory and passes
   `RISK_FIXED=1000`, `RISK_PERCENT=0` validation;
4. the operator supplies the exact current EX5 SHA-256 and the canonical EX5
   matches it; and
5. the historical and current EX5 hashes differ, proving this is a repaired
   binary rather than an unauthenticated retry.

The new row records `repaired_infra_rerun=true`, both old and current EX5
hashes, all current artifact hashes, the source-evidence path and payload hash,
and the append-only predecessor identity. Missing historical bindings continue
to fail closed. Regression coverage also proves the old row remains unchanged.

## Verification

- Focused regression suite:
  `python -m pytest tools/strategy_farm/tests/test_candidate_repair_enqueue.py -q`
  -> `24 passed`.
- Focused plus Q02 fanout regression suite:
  `python -m pytest tools/strategy_farm/tests/test_candidate_repair_enqueue.py tools/strategy_farm/tests/test_p2_full_dwx_fanout.py -q`
  -> `31 passed`.
- Python syntax compilation: PASS for `farmctl.py` and the modified test.
- `git diff --check`: PASS (line-ending notice only).
- Current MQ5 SHA-256:
  `a767f02c2ed31f90e2d8233fdf0cfb23a9a8c4314c7734e942fef65f3e650741`.
- Current EX5 SHA-256:
  `12fd25c63ef5aafcd6cfea88ebf76c193c8a95e0bedc5d25935113e19fbfcb2e`.
- EURCHF fixed-risk setfile SHA-256:
  `ef7e3dee6a76a6253e2f39f7fb762abb0d289a548ce7a468af0f5514b07e8ba1`.
- Pre-mutation farm DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10147_eurchf_enqueue_20260810T094042Z.sqlite`.

## Q02 receipt

The capacity sample immediately before enqueue found four running factory
terminals (`T2,T3,T5,T6`) against the ceiling of seven. The post-enqueue sample
also found four. No terminal was launched or interrupted by this work.

The exact append-only enqueue created one row and skipped none:

- Work item: `607bfd42-0095-4620-a4e1-3f5e65e17403`.
- Phase/kind: Q02 / backtest.
- Symbol/timeframe: `EURCHF.DWX` / D1.
- Setfile:
  `QM5_10147_tii-momentum_EURCHF.DWX_D1_backtest.set`.
- Source row preserved:
  `14111248-8316-4caa-8a0c-66b1075f9871`, still
  `failed / INFRA_FAIL`.
- Source EX5 SHA-256:
  `dcb983ffbe16a850bacc83117a9c1cb5ad4b97282fea6004fd425d798deabd5c`.
- Repaired EX5 SHA-256:
  `12fd25c63ef5aafcd6cfea88ebf76c193c8a95e0bedc5d25935113e19fbfcb2e`.
- Immediate state: pending, attempt 0, unclaimed, no verdict.
- Rerun rows for the exact predecessor after apply: one.

## Safety boundary

- No manual smoke test, backtest, pump, or dispatch tick was run.
- No terminal or worker process was started, stopped, reaped, or altered.
- No Strategy Card, EA mechanic, risk amount, registry, gate threshold, or
  portfolio state was changed.
- T_Live, AutoTrading, the portfolio gate, and deploy manifests were not
  touched.
