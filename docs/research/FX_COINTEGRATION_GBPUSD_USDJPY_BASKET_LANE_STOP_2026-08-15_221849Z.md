# FX cointegration GBPUSD/USDJPY — occupied basket-lane stop

Date: 2026-08-16 Europe/Berlin (`2026-08-15T22:17:04Z` through
`2026-08-15T22:18:49Z`)

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; exact non-duplicate fallback remains
pending once at Q02; the farm-wide multisymbol lane is occupied

## Outcome

No duplicate Card, EA, registry row, manifest, setfile, or Q02 row was created.
The frozen sign-aware 66-pair scan remains fully mechanized. A fresh approved-
Card reconciliation found 25 filenames containing `coint` or `cointegration`,
with a matching EA directory for every parsed EA ID.

The two requested anchors remain beyond Q02 and have no open `ONINIT` or
`NO_HISTORY` repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Historical physical-leg and superseded infrastructure rows remain in the
append-only ledger, but neither anchor has an open Q02 row. Rebuilding or
requeueing either anchor would therefore be duplicate work.

The valid existing-card fallback is still frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`.

## Exact fallback state

| Field | Value |
| --- | --- |
| Work item | `d4cd660c-c81a-41d3-8a4c-ad21d3319816` |
| Logical symbol | `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1` |
| Phase | Q02 |
| Status | `pending`, unclaimed |
| Attempt count | 2 |
| Verdict / evidence | none / none |
| Exact identity rows / open rows | 1 / 1 |
| Last update | `2026-08-15T13:03:04.898529Z` |

The row remains hash-bound to the repaired repository artifacts:

- MQ5: `f1e0bc08e65c6b46eea7c1397551ebb6c17aa466b48ef1d48d67e573361b9b27`
- EX5: `cc4337c6cfc05a734cc75d30f85af6a07136739017314f27efc7535eceb65516`
- basket manifest:
  `518ac63c8b796fbf3f397fc11a59b294d940afb4ec727e64f318ce0303b3c8f3`
- logical backtest setfile:
  `f7efb0a2183acdaee85f0882a0858447014f970a2e5782227e1c4980e98298d4`

The manifest declares the two traded legs `GBPUSD.DWX` and `USDJPY.DWX`, with
`GBPUSD.DWX` H1 as host. The backtest preset remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The OWNER-approved Card retains
R1-R4 PASS and cites Lemishko, Landi, and Caicedo-Llano (2024), SSRN 4771108.
Its frozen-OLS residual-reversion mechanics are structural and contain no ML,
grid, martingale, adaptive refit, or banned indicator.

## Binding backtest ceiling

The canonical farm reported seven active work items. Its single allowed active
multisymbol working set was owned by:

- work item `c21cab69-2e64-44b6-bc67-4e7db3e5befd`;
- `QM5_20236_XAU_XAG_VOV_D1` at Q02, claimed by T8;
- declared legs `XAUUSD.DWX` and `XAGUSD.DWX`; and
- path-bound PID 4800 at `D:/QM/mt5/T8/terminal64.exe`, whose tester
  configuration contains the exact work-item UUID.

The path-aware scan found tester children on T4, T6, and T8 and no orphaned
factory terminal process. `T_Live` and the FTMO terminal were observed only to
exclude them and were not controlled.

Three CPU samples were 75%, 67%, and 70% (70.67% average), with 42.86 GiB
physical-memory headroom and 193.28 GiB free on D:. Soft resources therefore
had headroom, but the fail-safe `at most one active multisymbol` claim rule was
already saturated. That serialized basket lane is the binding backtest
capacity ceiling. No dispatch tick, manual tester, enqueue, requeue, terminal
reservation/control, or policy bypass was attempted.

## Non-duplicate delta

This state is materially different from the committed `21:33:59Z` handoff.
The sole basket owner advanced from `QM5_20016` Q05 on T4 to `QM5_20236` Q02
on T8, and total active work increased from five to seven. The exact FX row
remained pending once and all four executable bindings remained unchanged.
The correct contribution is this durable capacity handoff, not another queue
or strategy artifact.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_basket_lane_stop_20260815T221849Z_board_advisor.json`.

## Safety

No portfolio-admission path, `_kpi`, `_q08_contribution`, T_Live manifest or
terminal, AutoTrading state, live-deployment artifact, Card, EA, registry,
setfile, basket manifest, external queue row, factory process, or running
terminal was changed. Concurrent unrelated worktree changes were left
unstaged and untouched.
