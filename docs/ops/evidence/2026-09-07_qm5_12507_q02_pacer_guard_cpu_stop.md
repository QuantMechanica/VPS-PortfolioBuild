# QM5_12507 logical FX basket Q02 pacer-guard CPU stop

Date: 2026-09-07

Branch: `agents/board-advisor`

Outcome: the approved FX cointegration card frontier has no unbuilt member, the
named anchors are not Q02-blocked, and the unique existing fallback is already
queued. No new work item was inserted because the paced fleet was above its
binding CPU ceiling.

## Non-duplicate selection

A repository reconciliation found 134 approved cards whose content identifies
a cointegration strategy and zero without an EA folder. The two named anchors
already have logical-basket Q02 PASS evidence:

- `QM5_12532`: Q02 PASS work item
  `e4890d77-b865-4a48-b946-315faefca920`, later Q05 FAIL.
- `QM5_12533`: Q02 PASS work item
  `76cb11ee-7e9d-4d75-be9d-626c205bca62`, later Q04 FAIL.

The fallback is the already-built, reputable-source, structural
`QM5_12507_pair-coint-z` EURUSD/GBPUSD H1 basket. Its logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` is pending, unclaimed, attempt zero,
and already `priority_track=true`. The row targets
`QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1`, binds the basket manifest and the
approved custom-history archive, and carries `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Creating or reprioritizing another
row would be duplicate work.

## Binding PACER build guard

Before considering any compile or Q02 action, the exact source was audited:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
```

Result: exit 0, `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, one source,
zero hits. The source therefore passes the binding input-pin audit; no
`EA_FRAMEWORK_INPUT_PINNED` finding was suppressed.

Recorded build identity:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c` |
| EX5 | `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa` |
| `basket_manifest.json` | `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56` |
| logical Q02 setfile | `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99` |

## CPU ceiling

Canonical read-only sampling used:

```powershell
python tools/strategy_farm/farmctl.py mt5-slots
```

At `2026-09-07T13:01:38+00:00`, eight factory terminals were running:
`T2`, `T4`, `T5`, `T6`, `T7`, `T8`, `T9`, and `T10`. This exceeds the binding
seven-terminal ceiling. The separately observed `T_Live` and FTMO processes
were excluded from the factory count and were not controlled.

Per the mission stop rule, no Q02 or compile row was enqueued, no existing row
was mutated, no tester was dispatched, and no terminal process was changed.

## Safety and durable evidence

- No Strategy Card, EA, setfile, registry, or basket manifest changed.
- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No `T_Live` manifest changed and AutoTrading was not toggled.
- Existing unrelated dirty-worktree files were left untouched.
- Machine-readable record:
  `artifacts/qm5_12507_q02_pacer_guard_cpu_stop_20260907T130138Z_board_advisor.json`.

