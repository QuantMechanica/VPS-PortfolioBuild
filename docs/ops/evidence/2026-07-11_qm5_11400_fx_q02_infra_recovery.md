# QM5_11400 Diverse-FX Q02 Infrastructure Recovery

## Outcome

`QM5_11400_davey-big-range-momentum-d1` now has a current-framework strict
binary, synchronized setfile build hashes, and three existing Q02 rows pending
again for `AUDUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX`. No work-item row was
inserted and no backtest was launched.

This is a priority-2 funnel-throughput unit. The approved-card audit found
2,974 unique approved card IDs and zero without a matching EA directory, so
the mission moved to a diverse-instrument Q02 infrastructure recovery. The
selected D1 FX sleeve adds an instrument class absent from the current
index/metal/energy Q08 FAIL_SOFT cohort.

## Strategy And Source

- Approved card: `QM5_11400`, G0 `APPROVED`, R1-R4 `PASS`.
- Source: Kevin J. Davey, *My 5 Favorite Entries*, Entry #1, Momentum and Big
  Range.
- Edge: completed D1 range greater than its trailing mean plus two standard
  deviations, with close-direction momentum confirmation and ATR brackets.
- Expected cadence: 12 trades/year/symbol.
- Rule class: deterministic structural range-expansion momentum; no ML,
  martingale, grid, or banned indicator was introduced.
- Backtest risk: every setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Claim And Non-Duplication Guard

- Agent task: `20285037-c663-40c9-bb3e-d8d3eb42d3dd`.
- Lease: `manual:codex:agents/board-advisor:QM5_11400:q02-infra-recovery`.
- Claimed by: `codex:agents/board-advisor`.
- Claim backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11400_q02_recovery_20260711T184050Z.sqlite`.

Before mutation, each selected row was `failed / INFRA_FAIL`, attempt 2,
unclaimed, and ended `summary_missing_retries_exhausted`. Guards confirmed no
open row for the EA, no behavioral Q02 verdict for the selected carrier, no
downstream row for the carrier, and no competing active farm task.

## Diagnosis And Repair

The historical worker logs and summaries for the three selected rows are no
longer present, so a more specific terminal cause cannot be recovered. This is
not evidence of a strategy failure: the same checked-in EA family produced a
real-tick EURUSD Q02 PASS in work item
`8b0e4343-c78d-4cee-b0d4-fe52beb7e1e1` with 72 trades, no OnInit failure, and a
complete report.

The package was rebuilt from a clean detached worktree at repository HEAD,
avoiding unrelated changes in the shared working tree. The EA source and rule
logic were not changed. The refreshed `.ex5` differs from the historical
binary, and the four canonical D1 setfiles now carry their generated build
hashes while retaining fixed-risk inputs.

| Artifact | SHA256 |
|---|---|
| MQ5 source | `1B9CB377059AE04BC80A2BCA8FB529860E181369E68C16B7D120CC72FA6AEAF6` |
| Prior EX5 | `515EFA6EECE6A0BB0C8D53EC81977CF33240EE3717F467CA83A4133184370E7A` |
| Refreshed EX5 | `F35B73E2BDDEBA4B7DAB3BD5723A5D19EEE1233FE483A58C6B992C394E26573F` |

## Validation

| Check | Result |
|---|---|
| Build guardrails | PASS, zero findings |
| Build check | PASS, zero failures, one advisory |
| Strict compile | PASS, 0 errors, 0 warnings |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260711_185325.json` |
| Compile summary | `D:/QM/reports/compile/20260711_qm5_11400_recovery/20260711_184251/summary.csv` |
| Preserved compile log | `D:/QM/reports/compile/20260711_qm5_11400_recovery/20260711_184251/QM5_11400_davey-big-range-momentum-d1.compile.log` |
| Real EURUSD Q02 proof | `D:/QM/reports/work_items/8b0e4343-c78d-4cee-b0d4-fe52beb7e1e1/QM5_11400/20260624_145513/summary.json` |

The advisory is `EA_PERF_UNGATED_BAR_DATA` for `CopyRates` at source line 136.
It is non-blocking under the build gate, but remains the principal Q02 runtime
risk to watch if a carrier again loses its report.

## Q02 Handoff

At `2026-07-11T18:48:45.043509+00:00`, an atomic guarded transaction reset the
three claimed rows in place:

| Symbol | Existing work item | Post-state |
|---|---|---|
| `AUDUSD.DWX` | `87be4bef-f7d1-41a1-99e0-bb8661b4a3f6` | pending, attempt 0, unclaimed |
| `GBPUSD.DWX` | `a9dafc08-65e5-4594-8c7a-23b23033bf02` | pending, attempt 0, unclaimed |
| `USDJPY.DWX` | `47816a7b-eee2-43d9-b068-f890fc238a43` | pending, attempt 0, unclaimed |

The consistent pre-write backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11400_fx_q02_requeue_20260711T184845Z.sqlite`.
Global pending count moved from 3,662 to 3,665; the three pre-existing active
rows were not modified.

## Runtime And Safety

`FACTORY_OFF.flag` remained active. A pre-handoff snapshot already contained
three MetaTester and six terminal processes, so this unit did not launch,
wait on, or interrupt any tester/terminal process and added no backtest CPU
load. The pending rows will dispatch only under normal farm control after the
OFF flag is removed by an authorized operator.

No portfolio gate, `T_Live` path or manifest, AutoTrading setting, or live
setfile was touched.

Machine-readable evidence:
`artifacts/qm5_11400_fx_q02_infra_recovery_20260711.json`.
