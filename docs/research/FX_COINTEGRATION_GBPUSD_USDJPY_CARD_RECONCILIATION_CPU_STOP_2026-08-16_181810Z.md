# FX cointegration GBPUSD/USDJPY — Card reconciliation and CPU stop

Date: 2026-08-16 Europe/Berlin (`2026-08-16T18:18:10Z`)

Branch: `agents/board-advisor`

Status: existing reputable-source FX basket reconciled to Q02 PASS; no Q04
enqueue because the explicit backtest CPU ceiling is binding

## Outcome

The frozen 66-pair scan remains fully mechanized, so a new Card or EA would be
duplicate work. The two requested anchors are not blocked at Q02:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, Q04 FAIL.

The governed fallback remains frozen-scan rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, pair slot 8 in the approved and built
`QM5_1257_lemishko-fx-cointpair`. Its Card is backed by Lemishko, Landi, and
Caicedo-Llano (2024), uses structural cointegration with a frozen hedge ratio,
and has no ML, online refit, grid, martingale, or rescue filter. The logical
backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

The Card's stale `Q02_PENDING` metadata was reconciled to the canonical
terminal result. Work item `d4cd660c-c81a-41d3-8a4c-ad21d3319816` completed
with Q02 PASS at `2026-08-16T17:14:14Z`: 290 Model-4 trades, no ONINIT failure,
stable binary and setfile bindings. Its adverse PF 0.65 and net result
-7,003.44 remain falsification evidence; this bookkeeping repair does not
promote or waive the economics.

## Exact downstream state

A fresh canonical `farmctl work-items --ea QM5_1257` read returned 29 Q02
rows and no Q04 row. The exact legitimate successor is therefore a single
Q04 cascade from the passing logical work item:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_1257 --phase Q04 --from-work-item-id d4cd660c-c81a-41d3-8a4c-ad21d3319816
```

That command was not run.

## Binding CPU stop

At `2026-08-16T18:17:37Z`, the path-aware factory scan found seven active
factory terminals: `T2`, `T5`, `T6`, `T7`, `T8`, `T9`, and `T10`. `T_Live`
and the unrelated FTMO terminal were observed only to exclude them; neither
was controlled.

Five subsequent two-second whole-machine CPU samples were 98.68%, 92.56%,
99.95%, 98.84%, and 100.00% (average 98.01%). The maximum crossed the explicit
97% hard ceiling. Per the mission stop condition, no Q04 row, duplicate Q02
row, tester, dispatch tick, reservation, priority mutation, or terminal action
was created.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_card_reconciliation_cpu_stop_20260816T181810Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- No EA, EX5, setfile, basket manifest, registry, magic row, or runtime queue
  row changed.
- Concurrent unrelated untracked work was left untouched.
