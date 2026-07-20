# QM5_11889 diverse-FX Q02 OnInit repair and requeue

## Outcome

`QM5_11889_lien-xtreme-fade-double-bb-adx` now binds its registered EA identity
in both source and every canonical backtest setfile. A fresh EX5 compiled against
the current V5 includes with zero errors and zero warnings. The existing
`NZDUSD.DWX` and `USDCHF.DWX` Q02 infrastructure failures were reopened in place;
no duplicate work items were created and no manual dispatch was requested.

This is one funnel-throughput recovery for an approved structural M15 FX
mean-reversion strategy. The card cites Kathy Lien's *Battle Tested Forex Trading
Strategies*, specifies deterministic double-Bollinger/ADX rules, and estimates 80
trades per year per symbol. Strategy entry, exit, and risk logic were not changed.

## Selection and claim

The two pending approved build tasks were not faithful build candidates:

- `QM5_1459_as-lumber-gold` requires lumber and IEF series that are not available
  in the approved DWX matrix; its own R3 body is `UNKNOWN`.
- `QM5_1457_as-predict-bonds` requires Treasury-yield, IEF, BIL, and DBC inputs;
  it already carries the same unresolved data blocker.

The mission therefore moved to the diverse Q02 infrastructure lane.

- Farm claim: `agent_tasks.id=fc2b0463-99da-46fa-a2a7-18b95beaaf41`
- Lease: `manual:codex:agents/board-advisor:QM5_11889:q02-infra-recovery`
- Claim-time guard: no pending/active Q02-Q03 row, competing agent task, or
  competing lease existed for this EA
- Pre-claim backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11889_claim_20260720T050855Z.sqlite`

## Diagnosis

Both target rows exhausted their retries after the tester stopped during OnInit.
The retained terminal logs identify the failure precisely:

- `D:/QM/mt5/T7/Tester/logs/20260719.log:661313,661344-661345` — NZDUSD slot 6
  loaded `qm_ea_id=9999`, emitted `EA_MAGIC_NOT_REGISTERED` for magic `99990006`,
  then stopped because OnInit returned code 1.
- `D:/QM/mt5/T10/Tester/logs/20260719.log:242305,242336-242337` — USDCHF slot 4
  loaded `qm_ea_id=9999`, emitted `EA_MAGIC_NOT_REGISTERED` for magic `99990004`,
  then stopped because OnInit returned code 1.

The checked-in MQ5 default was `9999`, and all seven setfiles omitted `qm_ea_id`.
The active registry correctly assigns EA 11889 slots 0-6 and magics
`118890000`-`118890006`. Historical evidence also shows Q02 PASS on GBPUSD,
USDJPY, and USDCAD and Q03 PASS on the same three symbols, so this was a package
identity failure rather than an economic verdict.

## Repair

- Changed only the framework identity default in the MQ5: `qm_ea_id=11889`.
- Regenerated all seven M15 backtest setfiles with `gen_setfile.ps1` so each now
  explicitly binds `qm_ea_id=11889`, its registered slot, `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and the card-authorized strategy
  defaults.
- Forced a fresh strict compile. Final hashes:
  - MQ5 SHA256: `0e8cb0f8a7c4d3cbd31f0b4767fb470fd56ad4b4df8b3d445e9ffb28c1796e5f`
  - EX5 SHA256: `d5288a31ab2f0825e8d0b25d4c0ea3624b19147e5f63ebef4935e1dd5eb1fbce`

The factory's deterministic dirty-artifact sweep committed the scoped EA paths
during validation in commits `74b9556f7` and `8cf3926bb`. Commit `74b9556f7`
also contains an unrelated factory artifact; this repair claims only the
`QM5_11889_lien-xtreme-fade-double-bb-adx` paths in those commits.

## Validation

| Check | Result |
|---|---|
| Strategy Card | `g0_status: APPROVED`; R1-R4 PASS |
| SPEC validation | PASS |
| Build guardrails | PASS, no findings |
| Symbol scope | `SINGLE_SYMBOL_OK`, zero leaks |
| Active magic rows | PASS: seven rows, slots 0-6 |
| Build check | PASS, 0 failures, 0 warnings |
| Strict compile | PASS, 0 errors, 0 warnings |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260720_051333.json` |
| Strict compile log | `C:/QM/repo/framework/build/compile/20260720_051401/QM5_11889_lien-xtreme-fade-double-bb-adx.compile.log` |

No smoke or backtest was launched. The farm already had seven active work items,
the paced-fleet CPU ceiling, so runtime verification is deferred to Q02.

## Q02 handoff

| Symbol | Existing work item | State |
|---|---|---|
| `NZDUSD.DWX` | `294e270a-4f3e-434c-8dea-f8d752867ec4` | `pending`, attempt 0, unclaimed |
| `USDCHF.DWX` | `d09baa2f-81cd-4e6a-b0ba-607ea11e3e61` | `pending`, attempt 0, unclaimed |

The reset transaction required each exact prior `failed / INFRA_FAIL / unclaimed`
state, the live farm claim, and zero open Q02-Q03 duplicates. Its consistent
pre-write backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_11889_fx_q02_requeue_20260720T051516Z.sqlite`.
The two retained report roots were moved, not deleted, to sibling
`.requeued_20260720T051516Z` archives before reset.

Dispatch was not invoked. No T_Live file or process, AutoTrading setting,
portfolio gate, deploy manifest, or live setfile was touched.
