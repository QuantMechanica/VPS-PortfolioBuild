# FX cointegration frontier — Factory-ON paced basket stop

Date: 2026-08-14

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; rank-58 logical Q02 remains
PENDING; stopped at the governed one-basket capacity ceiling

## Outcome

No new FX Card or EA was created. The committed sign-aware frontier
reconciliation still accounts for all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`; creating another pair
would duplicate governed research and code.

The anchor repair preference is not applicable:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker.

The non-duplicate existing-card fallback remains scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, pair slot 8 of the approved
`QM5_1257_lemishko-fx-cointpair` basket. Its exact logical Q02 row is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`. At the final read-only sample it was
PENDING, unclaimed, at attempt zero, free of active hold/quarantine, and rank
13 in the canonical pending selector. No duplicate enqueue, requeue, or
priority mutation was performed.

## Existing-pair contract

The fallback is bound to the OWNER-approved Lemishko, Landi, and
Caicedo-Llano (2024) SSRN Card with R1-R4 PASS. It is a deterministic,
low-frequency two-leg relative-value strategy with no ML, grid, martingale,
or online intramonth adaptation. Its basket manifest declares
`GBPUSD.DWX` and `USDJPY.DWX`, and its canonical H1 backtest setfile uses
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The frozen scan evidence for rank 58 is adverse, so Q02 remains a one-shot
cadence/economics test. No refit, added indicator/filter, rescue tuning, or
profitability claim was introduced.

## Binding Factory-ON capacity ceiling

Factory production is enabled: the durable Factory-OFF flag is absent and
both governed Factory tasks were enabled. This supersedes the OWNER-OFF state
recorded on 2026-08-13, but does not make a second basket admissible.

At `2026-08-14T02:23:41Z`, six work items were active. The sole active
multi-symbol item was the governed Q02 run for `QM5_13029` GBPCAD/GBPNZD,
work item `72efce53-2be9-4ada-a554-75a7e619c06c`, claimed by T4. A direct OS
sample at `2026-08-14T02:18:13Z` observed eight T1-T10 factory terminals and
ten terminal workers; `T_Live` and FTMO were observed only to exclude them.

`terminal_worker.py` serializes multi-symbol EAs to at most one active basket
farm-wide because their tick-history working sets are large. The selected
GBPUSD/USDJPY fallback is therefore not claimable while the T4 basket remains
active, irrespective of nominal idle single-symbol capacity. Per the mission
CPU-ceiling stop rule, no second basket, manual tester, reservation, dispatch,
or terminal control was attempted.

## Verification and safety

- `python -m pytest tools/strategy_farm/tests/test_fx_basket_manifests.py -q`:
  44 passed.
- The target Card, active registry rows, `.ex5`, basket manifest, and fixed-risk
  setfile were verified present.
- A static build-check attempt exceeded its 120-second observation budget after
  normalizing setfile hash headers. The process was stopped and its entire
  repository diff was reversed; no target EA or setfile change remains.
- The three unrelated untracked files present at handoff were not staged or
  modified.
- No portfolio admission/KPI/Q08 contribution path, T_Live manifest or
  terminal, AutoTrading state, live deployment artifact, registry, Card, EA,
  manifest, setfile, or external queue row was changed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_factory_on_cpu_stop_20260814T022341Z_board_advisor.json`.
