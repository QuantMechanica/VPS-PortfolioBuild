# FX cointegration frontier — Factory-ON basket-capacity refresh

Date: 2026-08-14

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; rank-58 logical Q02 remains
PENDING; stopped at the governed one-basket capacity ceiling

## Outcome

No new FX Card or EA was created because the committed sign-aware frontier
reconciliation already accounts for all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`. A new pair would
duplicate governed research and code.

The anchor-repair preference is not applicable:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker.

The non-duplicate fallback remains scan rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, pair slot 8 of the approved and built
`QM5_1257_lemishko-fx-cointpair` basket. Its exact logical Q02 work item is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`. At the database sample it was
PENDING, priority-tracked, unclaimed, at attempt zero, free of active holds
and quarantine, and rank 5 of 1,001 rows in the canonical selector. It is
already enqueued exactly once, so no enqueue, requeue, or priority mutation
was performed.

## Existing-pair contract

The fallback is bound to the OWNER-approved Lemishko, Landi, and
Caicedo-Llano (2024) SSRN Card with R1-R4 PASS. It is a deterministic,
low-frequency two-leg relative-value strategy with no ML, grid, martingale,
or online intramonth adaptation. Its basket manifest declares `GBPUSD.DWX`
and `USDJPY.DWX`; its logical H1 backtest setfile uses `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The frozen scan evidence for rank 58 is adverse, so Q02 remains a one-shot
cadence/economics test. No refit, added filter, banned indicator, rescue
tuning, or profitability claim was introduced.

## Binding Factory-ON capacity ceiling

Factory production is enabled: the durable Factory-OFF flag is absent and
both governed Factory tasks are enabled.

At `2026-08-14T02:49:41Z`, two work items were active. The active
multi-symbol item was `QM5_20294_XAU_XAG_LOWMAX_D1`, work item
`b9bde578-9476-470f-a051-fda0a11116c6`, claimed by T4 with a 44 GB
heavy-multisymbol commit reservation. A path-aware process sample at
`2026-08-14T02:49:20Z` observed T4 and T7 factory terminals and ten terminal
workers; T_Live, FTMO, and DEV1 were excluded from the factory count and not
controlled.

`terminal_worker.py` serializes multi-symbol EAs to at most one active basket
farm-wide. The selected GBPUSD/USDJPY row therefore cannot be claimed while
the T4 basket remains active, regardless of nominal idle single-symbol
capacity. Per the mission's CPU-ceiling stop rule, no second basket, manual
tester, reservation, dispatch, or terminal control was attempted.

## Verification and safety

- Strategy Card schema lint: PASS, with no missing sections or ML hits.
- Basket-manifest regressions: 44 passed.
- The target MQ5, EX5, Card, basket manifest, and fixed-risk setfile hashes
  match the committed Q01 handoff.
- The target EA tree was clean before this evidence write.
- Existing unrelated dirty and untracked worktree files were not staged or
  modified.
- No portfolio admission/KPI/Q08 contribution path, T_Live manifest or
  terminal, AutoTrading state, live deployment artifact, registry, Card, EA,
  manifest, setfile, or external queue row was changed.

Machine-readable evidence is
`artifacts/fx_cointegration_frontier_factory_on_cpu_stop_20260814T024941Z_board_advisor.json`.
