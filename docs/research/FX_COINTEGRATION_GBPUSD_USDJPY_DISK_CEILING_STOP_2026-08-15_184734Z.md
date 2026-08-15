# FX cointegration GBPUSD/USDJPY — D: volume ceiling stop

Date: 2026-08-15

Branch: `agents/board-advisor`

Sample window: `2026-08-15T18:47:06Z` through `2026-08-15T18:47:34Z`

## Outcome

The frozen sign-aware 66-pair scan remains fully mechanized, so a new Card or
EA would duplicate existing work. The two requested anchors remain beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback remains the repaired rank-58 `GBPUSD.DWX` /
`USDJPY.DWX` basket in `QM5_1257_lemishko-fx-cointpair`. Its exact logical Q02
work item is still pending once and unclaimed. No second row was created, and
the existing row was not requeued, restamped, or reprioritized.

## Exact Q02 identity

| Field | Value |
| --- | --- |
| Work item | `d4cd660c-c81a-41d3-8a4c-ad21d3319816` |
| Logical symbol | `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1` |
| Status | `pending`, unclaimed |
| Attempt count | 2 |
| Open rows for exact identity | 1 |
| Last update | `2026-08-15T13:03:04.898529Z` |
| Entry repair | `751cb391d8f388f5b61641ba3299011cdf9a09ed` |
| Exit repair | `f9ef37c1c` |

Fresh repository hashes still match the repaired execution binding:

- MQ5: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- basket manifest: `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- logical RISK_FIXED setfile: `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`

The setfile remains the logical H1 backtest preset with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No strategy threshold, pair
binding, or risk contract changed.

## Binding resource ceiling

The canonical farm reported five active Q02 work items, with path-bound tester
children on T2, T3, T4, T7, and T9. The path-aware scan found no orphaned
factory terminal. `T_Live` was observed separately only so it could be excluded;
it was not controlled.

The contemporaneous operating-system samples measured 68% CPU load and 5.18
GiB free of 63.12 GiB physical memory. More importantly, both CIM and the .NET
drive API reported only **454,656 bytes free** on the 1,024,192,409,600-byte D:
volume. D: hosts the canonical Strategy Farm runtime, reports, and custom-history
inputs. A new tester or dispatch cannot safely create bound evidence in that
state.

This is the mission's explicit backtest resource-ceiling stop. No dispatch tick,
tester, enqueue, requeue, terminal reservation or control, containment mutation,
disk cleanup, Factory recovery, or process cleanup followed. The existing paced
worker queue retains ownership after capacity is restored.

## Non-duplicate delta

This record is materially different from the `17:50:25Z` memory-ceiling handoff.
Free physical memory recovered from 0.40 GiB to 5.18 GiB, five Q02 items are now
actively path-bound, and the independently measured D: free space fell to
454,656 bytes. The selected repaired basket remains pending under the same one
governed identity, so duplicating or manually dispatching it would still be
incorrect.

Machine-readable evidence:
`artifacts/fx_cointegration_gbpusd_usdjpy_disk_ceiling_stop_20260815T184734Z_board_advisor.json`.

## Safety

No portfolio-admission path, `_kpi`, `_q08_contribution`, T_Live manifest or
terminal, AutoTrading state, deploy artifact, Card, EA, registry, setfile,
basket manifest, external queue row, history archive, runtime containment state,
or factory process was changed. Concurrent factory-generated QM5_10782 working-
tree changes were left unstaged and untouched.
