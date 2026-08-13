# FX cointegration frontier reconciliation and paced CPU stop

Date: 2026-08-13

Branch: `agents/board-advisor`

Status: frozen 66-pair frontier exhausted; rank-58 existing logical Q02 remains
PENDING; stopped at the paced backtest CPU ceiling

## Outcome

No new FX Card or EA was created. The relationship-level audit at commit
`a80493291` accounts for all 66 relationships from
`analyze_cross_asset_v3.py --include-negative-hedges`; creating another
"next-best" sleeve would duplicate governed work.

The concrete existing-pair fallback remains scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in the approved
`QM5_1257_lemishko-fx-cointpair` basket. Its exact logical Q02 work item
`d4cd660c-c81a-41d3-8a4c-ad21d3319816` is still PENDING, unclaimed, and at
attempt zero. It was preserved without a duplicate enqueue or requeue.

This reconciliation records a material frontier change since the 03:08Z
snapshot: the former rank-65 pending relationship, `USDCHF.DWX` /
`AUDUSD.DWX`, completed exact logical Q02 as `FAIL` at 03:47:37Z under
`QM5_1156`. Rank 58 is therefore the sole remaining nonterminal relationship
in the frozen scan. The exact-identity frontier summary is now 54 PASS, ten
FAIL, one INFRA_FAIL, and one PENDING.

## Anchor triage

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has canonical Q02 PASS and Q04 PASS,
  followed by Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has canonical Q02 PASS,
  followed by Q04 FAIL.
- Neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

## Existing-pair contract

The selected fallback remains bound to the OWNER-approved Lemishko, Landi,
and Caicedo-Llano (2024) SSRN Card, with R1-R4 PASS. Its two-leg manifest uses
`GBPUSD.DWX` and `USDJPY.DWX`; its canonical H1 backtest setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The frozen rank-58 scan evidence is adverse, so Q02 remains a one-shot
cadence/economics test. No refit, new filter, banned/ML indicator, rescue
tuning, profitability claim, or strategy-mechanics change was introduced.

## Binding paced CPU ceiling

The read-only `farmctl.py mt5-slots` sample at `2026-08-13T05:03:32Z` found
five factory terminals running: `T1`, `T2`, `T4`, `T9`, and `T10`. The paced
launch gate in `D:/QM/strategy_farm/state/launch_gate_max.txt` is `1`; five
running factory jobs exceed the active ceiling. The FTMO and `T_Live`
terminals were excluded from the factory count and were not controlled.

Per the mission stop rule, no Card, EA, registry, manifest, setfile, queue,
dispatch, reservation, tester, or terminal-control mutation followed. No
manual backtest was run. AutoTrading, the T_Live manifest, portfolio
admission/KPI/Q08 contribution paths, and live artifacts were untouched.

Machine-readable evidence is in
`artifacts/fx_cointegration_frontier_cpu_stop_20260813T050332Z_board_advisor.json`.
