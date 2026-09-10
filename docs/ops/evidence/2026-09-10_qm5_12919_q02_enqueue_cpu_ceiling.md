# QM5_12919 Q02 enqueue stopped at CPU ceiling

Date: 2026-09-10  
Branch: `agents/board-advisor`  
Router task: `c204bef5-7dec-4a95-b16e-dc8e795e516a`  
Disposition: `READY_FOR_Q02; NOT_ENQUEUED_CPU_CEILING`

## Outcome

`QM5_12919_amp-value-momentum-xasset` remains the highest-diversity,
non-duplicate recovery that can be advanced without changing approved strategy
mechanics. It is a monthly, low-frequency, peer-reviewed cross-asset
value/momentum strategy spanning four FX pairs and four equity indices. Its
accepted repair in commit `99c0b8a5b005f0d786fdd0ebaaa931bf0d57e39a` has never
received the required hash-bound Q02 requalification because the original
enqueue was refused while `FACTORY_OFF` was active.

The factory-off flag is now absent, the repaired artifacts are clean, and no
pending or active QM5_12919 work item existed at selection time. The exact Q02
enqueue was nevertheless refused locally before mutation because the mandatory
fresh capacity sample reached the CPU ceiling. No successor work item was
created.

## Non-duplicate selection audit

- The newest approved diversity build, `QM5_41149`, was excluded because its
  AUDUSD Sydney-session sell/open-to-close mechanic, ATR(14) 1.5x stop, and
  session cadence duplicate the already-built `QM5_1333_chan-fx-local-hours`.
- Apparent Q02/Q03 INFRA candidates were checked against their complete
  lifecycle. `QM5_12918`, `QM5_12919`'s old INFRA rows, and
  `QM5_11478` had later valid or deeper-gate evidence; stale historical rows
  were not treated as current blockers.
- `QM5_12919` is actionable only because its accepted source repair and newer
  compiled artifact have not re-earned Q02. This handoff completes no strategy
  change and does not duplicate the repair.

## Claimed unit

- Router task: `c204bef5-7dec-4a95-b16e-dc8e795e516a`
- Task type/state at execution: `triage_failure / IN_PROGRESS`
- Assigned lane: `codex`
- Exact predecessor: `1226a3d4-6c54-4123-b31e-1b9da87b56da`
- Exact target: `USDJPY.DWX / M30 / Q02`
- Prior accepted repair evidence:
  `docs/ops/evidence/2026-08-14_qm5_12919_usdjpy_q02_basket_history_recovery.md`

## Artifact and guard verification

| Item | Result |
|---|---|
| MQ5 SHA-256 | `c729116f626f7c6b2d930a160a070b3319f198f2a565ad5310c4d49dfa53526a` |
| EX5 SHA-256 | `6e915491196f60baf3d4fa98d900495be6aed295dd37605d3b6c65a6024383f9` |
| USDJPY M30 set SHA-256 | `02f18620b8b7044e462194632e6bbe9eb7c42860cbbf44aa2a80c0dca3445e0d` |
| Framework input-pin audit | PASS, zero `EA_FRAMEWORK_INPUT_PINNED` findings |
| Focused history-readiness tests | PASS, 2 tests |
| Setfile risk mode | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Factory-off flag | absent |

The input-pin audit was run against the absolute MQ5 path before any possible
compile enqueue. No compile enqueue was needed or issued because the accepted
repair already includes a strictly compiled EX5 bound above.

## Capacity refusal

Immediately before the intended queue mutation, five fresh `_Total` CPU
samples were collected at `2026-09-10T04:18:59.8309448Z`:

`97%, 98%, 90%, 89%, 84%` (average `91.6%`, maximum `98%`).

The strict admission ceiling is 97%; the observed maximum exceeded it. The farm
also reported six active work items: one Q04 job and five OPT_CENSUS jobs. Per
the paced-fleet order, processing stopped without calling
`farmctl enqueue-backtest` and without creating a Q02 row.

## Exact resume action

After a fresh five-sample CPU check remains strictly below 97% and the active
work count remains below the fleet ceiling, enqueue one append-only successor:

```text
python C:/QM/repo/tools/strategy_farm/farmctl.py enqueue-backtest \
  --ea QM5_12919_amp-value-momentum-xasset \
  --phase Q02 \
  --append-only-rerun-of 1226a3d4-6c54-4123-b31e-1b9da87b56da \
  --rerun-reason "Requalify accepted basket-history readiness repair 99c0b8a5b after prior FACTORY_OFF refusal; preserve predecessor" \
  --expected-current-ex5-sha256 6e915491196f60baf3d4fa98d900495be6aed295dd37605d3b6c65a6024383f9
```

Revalidate the artifact hashes, input-pin audit, absence of an existing
successor, and fixed-risk setfile immediately before executing that command.

## Safety boundary

No EA, setfile, strategy mechanic, terminal, portfolio gate, `T_Live` manifest,
deploy manifest, or AutoTrading state was changed. No compile or backtest was
started, and no pipeline verdict was created.
