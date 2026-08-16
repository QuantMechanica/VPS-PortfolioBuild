# FX cointegration GBPUSD/USDJPY — Q04 enqueued and CPU-ceiling stop

Date: 2026-08-16 Europe/Berlin (`2026-08-16T21:17:05Z`)

Branch: `agents/board-advisor`

Status: existing reputable-source FX basket advanced exactly once to Q04;
the explicit backtest CPU ceiling is binding

## Outcome

The signed reconciliation of the frozen 66-pair scan still accounts for all
66 relationships, so a new Strategy Card or EA would duplicate governed
work. The two requested anchors remain beyond Q02 and have no open `ONINIT`
or `NO_HISTORY` repair:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, Q04 FAIL.

The selected non-duplicate fallback is frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, pair slot 8 in approved and built
`QM5_1257_lemishko-fx-cointpair`. It is a structural, low-frequency,
fixed-hedge-ratio cointegration basket backed by Lemishko, Landi, and
Caicedo-Llano (2024), with no ML, grid, martingale, online refit, or rescue
filter. Its backtest binding remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Non-duplicate advancement

The repaired logical Q02 work item
`d4cd660c-c81a-41d3-8a4c-ad21d3319816` remains terminal `PASS`: 290 Model-4
trades, no ONINIT failure, PF 0.65, and net profit -7,003.44. The adverse
economics remain falsification evidence rather than a promotion claim.

Canonical automation subsequently created exactly one Q04 successor:

- work item: `d48dfb37-d28b-4e9d-aebe-376b7afe12dd`
- logical symbol: `QM5_1257_GBPUSD_USDJPY_COINTEGRATION_H1`
- status: `pending`, unclaimed, attempt 0
- created: `2026-08-16T20:41:38Z`
- promotion source: `pump_q04_early_probe`
- lineage: `promoted_from_work_item=d4cd660c-c81a-41d3-8a4c-ad21d3319816`
- host: `GBPUSD.DWX` H1
- basket: `GBPUSD.DWX`, `USDJPY.DWX`

No enqueue or requeue command was issued in this session. The approved Card's
stale `Q02_PASS` front matter was reconciled to `Q04_PENDING`; no rules,
thresholds, risk settings, setfiles, EA source, binary, manifest, registry, or
queue payload changed.

## Binding CPU stop

At `2026-08-16T21:16:55Z`, the path-aware process scan found six active
factory terminals: `T1`, `T3`, `T5`, `T8`, `T9`, and `T10`. The separately
observed T_Live and FTMO terminals were excluded and untouched.

Five two-second whole-machine CPU samples were 100%, 100%, 100%, 100%, and
99%, averaging 99.8% with a 100% maximum. This crosses the explicit 97% hard
ceiling. Per the mission stop condition, no dispatch tick, tester, queue
mutation, priority/timestamp write, terminal reservation, Factory transition,
or process control followed.

This is distinct from the preceding Card-reconciliation stop: that evidence
found no Q04 row; the canonical successor now exists exactly once and the Card
metadata now reflects it.

Machine-readable evidence is
`artifacts/fx_cointegration_gbpusd_usdjpy_q04_enqueued_cpu_ceiling_stop_20260816T211705Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- No EA, EX5, setfile, basket manifest, registry, magic row, or runtime queue
  row changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
