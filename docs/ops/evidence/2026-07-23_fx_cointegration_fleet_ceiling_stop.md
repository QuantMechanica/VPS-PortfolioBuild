# FX cointegration fleet audit — CPU-ceiling stop

**Date:** 2026-07-23
**Branch:** `agents/board-advisor`
**Scope:** read-only frontier, Q02-state, and factory-capacity audit
**Outcome:** `STOP_CPU_CEILING` — no duplicate build or queue item created

## Requested lane

Grow the certified V5 book with a new, low-frequency, market-neutral FX
cointegration basket. Prefer repairing `QM5_12532` or `QM5_12533` if either is
still blocked at Q02; otherwise mechanize one unbuilt successor from the
66-pair scan, or advance an existing FX card.

## Deterministic findings

1. `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` records only two
   survivors of the original 66-pair screen:
   `QM5_12533` EURJPY~GBPJPY and `QM5_12532` AUDUSD~NZDUSD.
2. Neither survivor is blocked at Q02. The farm database contains later-gate
   evidence; in particular, `QM5_12532` has Q05 handoffs and `QM5_12533` has
   post-Q02/Q04 operational evidence.
3. All 29 additional OWNER-approved `edgelab-*-cointegration` cards currently
   present under `strategy-seeds/cards/` already have matching compiled EA
   folders under `framework/EAs/`. Every FX-only compiled basket manifest also
   has an existing farm work-item lineage. Building or enqueueing one again
   would therefore be duplicate work.
4. The live read-only `farmctl.py mt5-slots` scan at
   `2026-07-23T03:30:43Z` found five paced factory tests active:

   | Terminal | EA | Gate | Symbol |
   |---|---|---|---|
   | T1 | QM5_1230 | Q05 | XAUUSD.DWX |
   | T3 | QM5_12402 | Q02 | SP500.DWX |
   | T8 | QM5_10503 | Q02 | GBPUSD.DWX |
   | T9 | QM5_9575 | Q02 | WS30.DWX |
   | T10 | QM5_10485 | Q02 | USDJPY.DWX |

   `farmctl.py reconcile-mt5` reported no duplicate workers, no orphaned
   work-item processes, and no safe repair actions.

## Decision

The paced backtest CPU ceiling is occupied. No terminal was started, no
existing work item was duplicated, and no queue priority was altered. This is
the required stop condition from the mission.

## Boundaries observed

- No `T_Live` or AutoTrading action.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or live-manifest
  change.
- No strategy mechanics, indicators, registry rows, setfiles, or EA binaries
  changed.
- No Q02 work was enqueued while the five-slot paced ceiling was occupied.

## Next safe action

After one paced factory slot clears, select an already-approved low-frequency
FX candidate that has no pending/active Q02 work item at that time. Re-run the
same manifest/work-item deduplication check immediately before enqueueing.
Do not reopen a cointegration lineage that already has a terminal gate verdict.
