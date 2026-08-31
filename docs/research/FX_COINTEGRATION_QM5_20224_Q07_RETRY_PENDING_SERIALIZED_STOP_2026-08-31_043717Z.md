# FX cointegration fleet — QM5_20224 Q07 recovery bound / serialized stop

Date: 2026-08-31 UTC (`2026-08-31T04:37:17Z`); 06:37 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `bb3d5a3f1eaa349ed9253c0e81773b5d2f9a5a6c`

Status: the frozen 66-pair FX frontier has no eligible unbuilt identity, both
preferred anchors are past Q02, and the most advanced existing FX fallback now
has exactly one append-only Q07 recovery pending. A different multi-symbol item
owns the serialized basket lane, so no duplicate queue or tester action was
taken.

## Frontier and preferred-anchor reconciliation

The controlling research record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its published survivor
bar admitted only `QM5_12533` EURJPY/GBPJPY and `QM5_12532` AUDUSD/NZDUSD. The
durable sign-aware coverage audit in
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 pair relationships and their existing implementations. A
fresh approved-card/EA census found no scan-derived FX cointegration card with
a missing EA source or compiled EX5. Creating another Card, registry identity,
EA, basket manifest, or Q02 row would be duplicate work.

Neither preferred anchor has the Q02 infrastructure blocker named by the
mission:

| EA | Canonical chain |
|---|---|
| `QM5_12532` | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | Q02 PASS; Q04 FAIL |

## Existing FX fallback and recovery ownership

The concrete fallback remains frozen-scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. Its chain is Q02 PASS, Q03 PASS,
Q04 PASS_SOFT, Q05 PASS, Q06 PASS, then Q07 INFRA_FAIL on work item
`9ba93eb9-4973-4759-9efa-f7ff224f1494` because the seed-2026 native report was
materialized while its terminal log was only at 58% progress.

Since the preceding `03:53:05Z` handoff, the governed farm appended exactly one
recovery row:

| Field | Value |
|---|---|
| Work item | `b38e2753-1d57-45d9-8562-3cafc0e105a0` |
| Phase/status | `Q07` / `pending` |
| Logical symbol | `QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1` |
| Predecessor | Q06 PASS `d13cf596-44a4-429d-92a7-2de6b1a3e7f0` |
| Terminal evidence preserved | Q07 INFRA `9ba93eb9-4973-4759-9efa-f7ff224f1494` |
| Recovery mode | append-only; historical item preserved |
| Priority | `priority_track=true` |
| Open recovery count | exactly one |

This row pre-existed this wake. It was verified, not recreated or edited.

## Sealed implementation verification

- Approved card:
  `strategy-seeds/cards/approved/QM5_20224_eurusd-eurjpy_card.md`.
- Card schema lint: `status=ok`, no missing sections, no ML hits.
- Basket manifest: EURUSD.DWX and EURJPY.DWX are traded; USDJPY.DWX is the
  conversion-history dependency; host period is D1.
- Registry: active EA identity plus active magic slots 0 and 1.
- Logical backtest setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- MQ5 SHA-256:
  `7eda37af63f23e00dcb930d71eb07afe4bef97e30875ec7f83bf5d234f668129`.
- EX5 SHA-256:
  `d534838d2c9c993db151500c836f4e38088d961b2fe90e820defb0d31a34ae5b`.
- Logical setfile SHA-256:
  `397181311f649d5416044d36d6aa70023390ea8b14f97cb75e7fb8818b144254`.
- Basket manifest SHA-256:
  `f7207377d90fb4fb3447425597f4ec4b2c2709838e0bd44cf4d851f70bb97725`.
- Free D: capacity: 97.824 GiB, above the phase preflight floor.

The pending row binds the same MQ5, EX5, and setfile identities. No strategy
threshold, risk rule, pair definition, binary, setfile, or manifest changed.

## Capacity and ownership stop

A fresh five-sample whole-host CPU window returned 81.256182%, 90.770029%,
79.705690%, 66.713846%, and 73.070229%. Average CPU was 78.303195% and maximum
CPU was 90.770029%, both below the 97% hard ceiling.

The binding stop is serialized multi-symbol ownership: Q03 item
`eb3993b7-e477-4236-9cb6-385c1a8e7392` for
`QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1` is active on T3. The resident paced
farm owns dispatch after that lane clears. Launching or claiming the pending
QM5_20224 recovery manually would violate the serialized basket contract.

The prior seed-2026 fault belongs to tester/report completion binding, not the
EA. The `qm-run-pipeline-phase` skill explicitly reserves
`framework/scripts/*` changes for framework maintainers, so this wake did not
patch `q07_multiseed.py` or `run_smoke.ps1`. The append-only recovery remains
the governed path; its result must be classified without rewriting the old raw
evidence.

## Exact continuation contract

1. Do not enqueue a second QM5_20224 Q07 recovery.
2. Let the paced worker claim
   `b38e2753-1d57-45d9-8562-3cafc0e105a0` only after the serialized
   multi-symbol lane is free.
3. Require the recovered seed report to bind to a completed tester run; a
   report/structured-log contradiction remains infrastructure evidence.
4. Only after terminal Q07 PASS may the autonomous verdict chain create a
   downstream row.
5. Keep priority successor QM5_20240 Q03 pending; do not dispatch it in
   parallel with QM5_20224.

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, T_Live manifest or terminal, AutoTrading state,
live/deploy manifest, Card, EA, EX5, setfile, basket manifest, registry row,
magic row, or farm queue row was changed by this wake. Unrelated shared
worktree changes were preserved.

Machine-readable evidence is in
`artifacts/fx_cointegration_qm5_20224_q07_retry_pending_serialized_stop_20260831T043717Z_board_advisor.json`.
