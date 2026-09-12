# QM5_10038 multi-FX Q02 stale-binary requalification

Date: 2026-09-12

Branch: `agents/board-advisor`

EA: `QM5_10038_ff-4x25ema-mtf-h4`

Farm repair task: `19a2692f-020e-4d5c-a0fd-76011c9b51f4`

Outcome: **three append-only current-binary Q02 successors enqueued; repair task completed**

## Selection and collision control

A fresh read-only farm census found no claimable approved greenfield build with
both no EX5 and no governed work item. The already-claimed priority-2 repair for
QM5_10038 was therefore the highest-value actionable diversity unit. It restores
three low-frequency H4 FX lanes without changing strategy mechanics.

Immediately before enqueue, the repair claim still belonged to
`codex:agents/board-advisor`. None of the three failed identities had an existing
pending or active Q02 successor. The unrelated historical EURUSD Q04 row was not
touched.

## Bound infrastructure cause

The immutable predecessors all ended `INFRA_FAIL` with
`ONINIT_FAILED;INCOMPLETE_RUNS`:

| Symbol | Failed work item | Magic slot |
|---|---|---:|
| `NZDUSD.DWX` | `447bd7e4-7176-483a-8df6-1ed6c4ea68c2` | 7 |
| `USDCAD.DWX` | `d49c771b-bc51-474b-a968-7b4633f56b10` | 10 |
| `USDCHF.DWX` | `50ffaa26-5159-4804-accf-cdd1f92a997a` | 11 |

They bind old EX5 SHA-256
`61833c537bb10b731ea9c63717ccea8b720d91cf8c671fa469d2ebe06a313891`,
compiled before those slots were added to the magic registry. The governed
current binary binds:

- MQ5 SHA-256: `a2ab7f4f493be1528312f7b649febf7da0e61cebb504a60d0ec280c652fbbb66`;
- EX5 SHA-256: `bbd1786046941d20cb33f618bf1143c537058aad14f900ede5dcb6428fa1b0b3`;
- compile work item: `d80e2fca-2cf4-40b8-883d-846c5fc2c5d5`, `COMPILE_OK`;
- current-binary Q02 proof: `5599a328-80cf-465d-bcf1-b4fbfc54843a`,
  `AUDUSD.DWX`, `PASS`.

This is stale compiled-resolver infrastructure, not a missing-history or
strategy-efficacy verdict.

## PACER guard and admission

Before the queue mutation, the absolute-path source audit returned exit 0:

```text
predicate=EA_FRAMEWORK_INPUT_PINNED
ok=true
hit_count=0
```

All three `requalify-q02 --dry-run` checks returned `eligible=true`,
`would_enqueue=true`, and `parameter_change_count=0`. Their setfiles retain
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and the registered magic offsets.

The immediate five-sample whole-host CPU window was `37.620715%`,
`30.449682%`, `25.300634%`, `23.679511%`, and `19.287563%`: average
`27.267621%`, maximum `37.620715%`. Both were below the binding `97%`
ceiling. The concurrent process census showed two governed testers and no
duplicate terminal workers or orphaned tester processes.

## Append-only Q02 handoff

| Symbol | Successor work item | Receipt SHA-256 |
|---|---|---|
| `NZDUSD.DWX` | `3048cb88-7393-4e37-ace6-e2803825db45` | `1307c9b7fec313fccf1365a1cef0f7bbc4f8a39f8d80eb2a47ec2609fc013d4b` |
| `USDCAD.DWX` | `fa198f7f-0999-4001-a4d5-3b52d9c76aaa` | `ba17f5338dc7346b3f6b787b3e5675e85a1d847d6ad6ca8bd260bda55d5937f3` |
| `USDCHF.DWX` | `6a4db2d4-04d0-4191-a9e0-229755fae422` | `6eb84eaf49bdbe899a9a8261a60f8cfdead3003a78bdee56c590f50f7b275872` |

All three rows were created pending, unclaimed, with zero attempts and exact
current MQ5/EX5/setfile bindings. The failed predecessors remain immutable.
The farm repair task was closed `done` under a compare-and-swap check after an
online SQLite backup:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10038_repair_close_20260912T135013Z.sqlite`

Backup SHA-256:
`7dab50e589df569ee3944edd738aa278018a4c9a04094481fec331f343c79bc7`.

No tester was manually dispatched. No EA source, setfile, strategy parameter,
registry row, compile row, portfolio gate, deploy manifest, `T_Live` state, or
AutoTrading setting was changed.
