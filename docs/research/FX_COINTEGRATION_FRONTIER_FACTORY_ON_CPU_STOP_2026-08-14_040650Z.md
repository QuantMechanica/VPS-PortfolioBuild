# FX cointegration frontier — paced-fleet capacity stop refresh

Date: 2026-08-14

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; rank-58 logical Q02 remains
PENDING; stopped at the governed one-basket capacity ceiling

## Decision

No new FX Card or EA was created. The committed sign-aware reconciliation of
`analyze_cross_asset_v3.py --include-negative-hedges` covers all 66 scan
relationships, so a new pair would duplicate governed research or an existing
basket implementation.

The requested anchor repair is not applicable:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS, followed by
  Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS, followed by Q04
  FAIL.
- Neither anchor has an open Q02 ONINIT or NO_HISTORY blocker.

The non-duplicate fallback remains frozen-scan rank 58, `GBPUSD.DWX` /
`USDJPY.DWX`, pair slot 8 of the approved and built
`QM5_1257_lemishko-fx-cointpair` basket. Its exact logical Q02 work item is
`d4cd660c-c81a-41d3-8a4c-ad21d3319816`. At `2026-08-14T04:06:50Z` it was
PENDING, priority-tracked, unclaimed, at attempt zero, free of active holds
and quarantine, and rank 5 of 1,007 eligible rows in the canonical selector.
It is already enqueued exactly once; no enqueue, requeue, or priority mutation
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

## Binding capacity ceiling

Factory production is enabled: `FACTORY_OFF.flag` is absent and the governed
Factory tasks and all ten terminal workers are running.

At the database sample, three work items were active. The active multi-symbol
item was `QM5_20294_XAU_XAG_LOWMAX_D1`, work item
`b9bde578-9476-470f-a051-fda0a11116c6`, claimed by T4 with a 44 GB
heavy-multisymbol commit reservation. The process scan at
`2026-08-14T04:06:51Z` observed T4, T5, and T10 factory terminals; T_Live and
FTMO were excluded from the factory count and were not controlled.

`terminal_worker.py` serializes multi-symbol EAs to at most one active basket
farm-wide. The selected GBPUSD/USDJPY row therefore cannot be claimed while
the T4 basket remains active. Per the mission's CPU-ceiling stop rule, no
second basket, manual tester, reservation, dispatch, or terminal control was
attempted.

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
`artifacts/fx_cointegration_frontier_factory_on_cpu_stop_20260814T040650Z_board_advisor.json`.
