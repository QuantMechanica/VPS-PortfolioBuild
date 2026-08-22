# Diverse FX Q02 capacity handoff — 2026-08-22

## Disposition

`CAPACITY_STOP_NO_ENQUEUE`. The final pre-enqueue check found the backtest farm at its CPU ceiling, so this paced-fleet turn did not start an eighth tester or append a Q02 work item.

- Branch: `agents/board-advisor`
- Released agent task: `5f3f72bc-09b3-486d-85a9-0d03cd62d23c`
- Released task state: `FAILED`
- DB backup before release: `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12486_claim_release_20260822T011308Z.sqlite`

## Capacity evidence

The farm had seven `terminal64` factory processes and seven `metatester64` processes active on T1, T2, T3, T4, T6, T7, and T8. Five CPU samples were `97.61`, `97.78`, `98.39`, `96.99`, and `98.93` percent, averaging `97.94%`. No tester was launched after this observation.

## Backlog and claim disposition

The approved build backlog did not contain a valid, unexercised high-diversity build target. The apparent candidates were stale or ineligible: QM5_11483 had already traversed Q02–Q07, QM5_11735 was Q02-excluded as high-frequency, QM5_32007 had already passed Q02 and failed Q04, and the apparent rates/lumber cards lacked the required R3 approval.

QM5_12486 GBPUSD D1 was claimed as an infrastructure recovery candidate. Inspection showed that its lifecycle correction required a new binary. Direct compilation correctly stopped on `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`, while the governed compile queue rejected the existing compiled/evidenced identity and remained held under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. The tentative source change was reverted; QM5_12486 has no repository diff and no Q02 row was enqueued.

## Next distinct diversity lane

The highest-confidence resumable lane is `QM5_12538_nnfx-canonical-stack2-st-vortex` on `GBPUSD.DWX` D1:

- Its approved card has R1–R4 PASS. The R1 basis is the public No Nonsense Forex methodology and community-vetted fixed components.
- It is structural and low-frequency: fixed McGinley, SuperTrend, Vortex, ADX, and ATR logic on D1, with no ML, adaptive optimizer, grid, or martingale mechanics.
- The GBPUSD backtest set fixes risk at `$1,000` with `RISK_FIXED=1000`.
- The current repaired source/binary pair already passed strict compile and build checks, recorded in `docs/ops/evidence/2026-08-11_qm5_12538_fx_q02_perf_recovery.md`.
- The current repaired binary has Q02 observations on EURUSD and EURJPY only. GBPUSD has not exercised this binary, so the lane is non-duplicate.
- The canonical GBPUSD source row `c423351a-f0cc-4f60-b639-5f6de967b8e6` is a real-MT5 `INFRA_FAIL` for `NO_HISTORY;INCOMPLETE_RUNS`, with evidence at `D:\QM\reports\work_items\c423351a-f0cc-4f60-b639-5f6de967b8e6\QM5_12538\20260626_065554\summary.json`.

Immutable identities verified during this turn:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `061a979cb6fc1ac5f681b7faeb82c686fab29643e304ffd4d44f4d280a8bcaf2` |
| EX5 | `0157749c0fc7e8ead324238468b2489b45b641f32e5a2b24be25dff300f4cd20` |
| GBPUSD D1 setfile | `8f8b4e84e2ddd94bb618d90f99169f3776e915787339c40a1821bf32b2f2af46` |

After capacity becomes available and an atomic DB claim confirms the lane is still unclaimed, resume through the public identity-binding command:

```powershell
python tools/strategy_farm/farmctl.py seed-fresh-q02 --ea QM5_12538 --old-work-item-id c423351a-f0cc-4f60-b639-5f6de967b8e6 --requal-reason "capacity-deferred GBPUSD D1 lane; current repaired binary untested on GBPUSD; prior row was infrastructure-only" --expected-current-ex5-sha256 0157749c0fc7e8ead324238468b2489b45b641f32e5a2b24be25dff300f4cd20
```

## Safety attestation

This turn did not touch T_Live, AutoTrading, the portfolio gate, or the T_Live manifest. It did not launch a tester, enqueue Q02, or leave an EA/setfile mutation behind.
