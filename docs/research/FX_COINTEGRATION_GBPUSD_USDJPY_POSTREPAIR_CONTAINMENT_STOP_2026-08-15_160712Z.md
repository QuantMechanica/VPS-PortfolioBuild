# FX cointegration GBPUSD/USDJPY — post-repair containment stop

Date: 2026-08-15  
Branch: `agents/board-advisor`  
Sample: `2026-08-15T16:07:12.798376Z`

## Outcome

No duplicate Strategy Card, EA, registry row, basket manifest, setfile, or Q02
work item was created. The frozen sign-aware 66-pair scan remains fully
mechanized, and the two requested anchors remain beyond Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The mission fallback therefore remains the approved rank-58
`GBPUSD.DWX` / `USDJPY.DWX` basket in
`QM5_1257_lemishko-fx-cointpair`. Its entry and exit implementation repairs
are already compiled and bound to the one governed logical Q02 row. That row
is pending once and has not produced post-repair evidence yet.

## Exact Q02 state

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

Fresh repository hashes exactly match the expected bindings stored in the
work-item payload:

- MQ5: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- RISK_FIXED setfile: `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`
- Basket manifest: `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`

The logical preset remains H1 with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No strategy threshold, pair binding, or risk contract
was changed.

## Binding resource ceiling

The fleet's single multisymbol lane is occupied by active Q04 basket work item
`2b2f3c8b-3d1e-49c1-b414-a28573be3b2c`,
`QM5_20016_XTI_XNG_MON_RV_D1`, claimed by T3 at
`2026-08-15T15:55:12Z`. The same sample measured 82.56% total CPU and 54.34
GiB free of 63.12 GiB physical memory. Although the global 97% CPU ceiling is
not crossed, the deliberate one-basket-at-a-time guard prevents a competing
multisymbol Q02.

Signed Custom-history containment is also enabled. Its record was written at
`2026-08-15T15:33:12.328993Z` with reason
`custom_history_isolation_gate_failure`, authorization SHA-256
`61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`,
and file SHA-256
`82082949011bf67e60acb543eb9ce218147d4ca31dff4ce6e99eceeb27f20ebd`.

This is the mission's explicit backtest resource-ceiling stop. No dispatch
tick, tester, enqueue, requeue, priority mutation, terminal reservation or
control, containment mutation, factory recovery, or process cleanup followed.
The paced worker retains ownership of execution after both guards clear.

## Non-duplicate delta

This snapshot is materially later than the committed exit-repair refresh. At
that refresh, `QM5_20202` owned the basket lane. The current owner is
`QM5_20016` Q04, and a newer signed containment record independently blocks
new claims. The target row and all four execution bindings remain unchanged,
which proves the repaired basket has not been duplicated or silently run under
drifted artifacts.

Machine-readable evidence:
`artifacts/fx_cointegration_gbpusd_usdjpy_postrepair_containment_stop_20260815T160712Z_board_advisor.json`.

## Safety

No portfolio-admission path, `_kpi`, `_q08_contribution`, T_Live manifest or
terminal, AutoTrading state, deploy artifact, Card, EA, registry, setfile,
basket manifest, history archive, or runtime containment state was changed.

