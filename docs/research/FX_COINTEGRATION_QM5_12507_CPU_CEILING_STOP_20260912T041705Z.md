# FX cointegration fallback — Q02 CPU-ceiling stop

**Observed:** 2026-09-12T04:17:05Z  
**Branch:** `agents/board-advisor`  
**Outcome:** preserve the existing non-duplicate Q02 row; no enqueue or tester launch

## Selection

The OWNER-requested 66-pair scan is exhausted. The frozen research result admits
only `QM5_12532` (AUDUSD/NZDUSD) and `QM5_12533` (EURJPY/GBPJPY) under the
original positive-hedge criterion. The sign-aware extension is also fully
represented by existing builds. The repository duplicate guard records all 66
relationships as represented and all seven strict qualifiers as built.

The two anchor baskets do not need Q02 repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, then Q04 PASS and Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Creating another card or EA from that scan would therefore be duplicate work.
The valid existing-forex fallback remains the concrete EURUSD/GBPUSD H1 sleeve
inside `QM5_12507_pair-coint-z`.

## Existing Q02 row

Read-only inspection of
`D:/QM/strategy_farm/state/farm_state.sqlite` found exactly the already-governed
logical-basket row selected by the prior handoff:

| Field | Value |
|---|---|
| work item | `547c4fd3-f3fd-4c59-b9dc-654e96521251` |
| EA | `QM5_12507` |
| pair | EURUSD.DWX / GBPUSD.DWX |
| logical symbol | `QM5_12507_EURUSD_GBPUSD_COINTEGRATION_H1` |
| phase | Q02 |
| status | pending |
| attempt count | 0 |
| claimed by | null |
| priority track | true |
| basket symbol count | 4 |

No successor was appended because that would duplicate the pending attempt-zero
row. The basket manifest legitimately declares EURUSD, GBPUSD, NDX, and WS30:
the unchanged EA warms all four declared symbols before evaluating its active
host pair. Relabeling it as a two-symbol payload without splitting and
recompiling the strategy would be false resource metadata.

## PACER and risk checks

The source was not generated or changed in this mission, and no compile work was
enqueued. As an additional fail-closed check, the binding PACER audit was run
against the existing absolute source path:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"
ok=true
predicate=EA_FRAMEWORK_INPUT_PINNED
hit_count=0
hits=[]
```

The logical-basket backtest setfile remains in the required fixed-risk mode:
`RISK_FIXED=1000` and `RISK_PERCENT=0`. The source SHA-256 is
`569CC4E32CBE9B83AB4F30CE8881FF8C1ED24357F7BE6503C23338087787CF0C`.

## Binding CPU stop

A five-point host sample produced `77, 100, 100, 100, 97` percent CPU,
average `94.8%`, maximum `100%`. The governed backtest ceiling is `97%`; the
maximum breached it. Per the mission's explicit CPU-ceiling instruction, no Q02
enqueue, dispatch, tester launch, terminal reservation, or queue mutation was
attempted after that finding.

## Safety

- No portfolio-admission, KPI, or Q08-contribution file was touched.
- No `T_Live` manifest, terminal, AutoTrading state, or live artifact was touched.
- No EA, card, registry, magic row, setfile, or basket manifest was changed.
- No existing work-item status, verdict, priority, payload, or attempt count was changed.

Machine-readable evidence:
`artifacts/fx_cointegration_qm5_12507_cpu_ceiling_stop_20260912T041705Z_board_advisor.json`.
