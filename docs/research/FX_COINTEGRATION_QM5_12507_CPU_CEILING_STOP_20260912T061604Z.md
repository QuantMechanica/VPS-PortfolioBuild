# FX cointegration fallback — Q02 CPU-ceiling stop

**Observed:** 2026-09-12T06:16:04Z  
**Branch:** `agents/board-advisor`  
**Outcome:** preserve the sole governed Q02 row; no duplicate enqueue or tester launch

## Selection and duplicate guard

The frozen 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains exhausted. Its
two published survivors are already built and neither has the Q02 setup defect
named by the mission:

- `QM5_12532` AUDUSD/NZDUSD: Q02 `PASS`, Q04 `PASS`, terminal Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY: Q02 `PASS`, terminal Q04 `FAIL`.

Creating another scan-derived card, EA, compile row, or Q02 row would duplicate
governed work. The selected existing-forex fallback is therefore the concrete
EURUSD/GBPUSD H1 logical basket in `QM5_12507_pair-coint-z`.

Read-only inspection found exactly one open row for this identity:

| Field | Value |
|---|---|
| Work item | `547c4fd3-f3fd-4c59-b9dc-654e96521251` |
| Logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| Phase/status | Q02 / pending |
| Attempt / claimant | 0 / null |
| Verdict / active hold | null / none |
| Priority track | true |
| Exact open identity count | 1 |

No duplicate enqueue or queue mutation was performed.

## PACER guard and fixed-risk binding

No MQ5 was generated or changed and no compile work was requested. The existing
absolute source nevertheless passed the framework-input-pin audit:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5
exit 0; ok=true; predicate=EA_FRAMEWORK_INPUT_PINNED; hit_count=0
```

The logical setfile remains in the required backtest risk mode:
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Artifact hashes were unchanged:

- MQ5: `569cc4e32cbe9b83ab4f30ce8881ff8c1ed24357f7be6503c23338087787cf0c`
- EX5: `b9baf4b48e02b9ced91b2d86d24b87245b595b506d1763b279e36bb9074ba4aa`
- basket manifest: `195cf0517e6e99649e0f40c259cea93e9af5a05cfc913fe901a33c39896fea56`
- logical setfile: `f8f7da7f72fa60ab37e4e4d1a9e64d1b83e8e122b29ee35c613feb25236bac99`

## Binding CPU stop

The fresh five-sample whole-host CPU window was `72.97%`, `76.62%`, `86.44%`,
`92.80%`, and `100%` (average `85.76%`, maximum `100%`). The maximum crossed
the binding 97% ceiling. At observation time the farm had five active and 6,265
pending work items, with T1, T4, and T9 running factory workloads.

Per the explicit ceiling rule, no enqueue, requeue, dispatch tick, tester
launch, terminal reservation, or terminal control followed. The existing
priority row remains available to the resident paced fleet.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate surface changed.
- No `T_Live` manifest, terminal, AutoTrading state, or live artifact changed.
- No card, EA source, EX5, setfile, basket manifest, registry row, magic row, work-item state, payload, priority, or verdict changed.
- Pre-existing unrelated shared-worktree changes were preserved and excluded from this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_cpu_ceiling_stop_20260912T061604Z_board_advisor.json`.
