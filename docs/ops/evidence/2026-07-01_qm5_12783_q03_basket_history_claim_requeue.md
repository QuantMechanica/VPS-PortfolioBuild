# QM5_12783 Q03 Basket History-Claim Requeue

Date: 2026-07-01
Branch: `agents/board-advisor`

## Scope

- Mission: grow/advance the FX market-neutral cointegration basket funnel.
- Target advanced: `QM5_12783_edgelab-audusd-audjpy-cointegration`.
- Logical basket: `QM5_12783_AUDUSD_AUDJPY_COINTEGRATION_D1`.
- Host: `AUDUSD.DWX`, `D1`.
- Basket history symbols: `AUDUSD.DWX`, `AUDJPY.DWX`, `USDJPY.DWX`.
- Backtest risk mode: RISK_FIXED via the existing backtest setfile.

No `T_Live` files were touched, AutoTrading was not changed, and no portfolio
gate files were edited.

## Scan Exhaustion Check

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` plus the local
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py` logic remain the
controlling source for the 66-pair FX cointegration scan.

Read-only rerun of the local scan logic found 29 positive-hedge rows and zero
unbuilt positive-hedge rows. The strict survivors remain already built and not
Q02-blocked:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, later Q05 INFRA_FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, later Q04 FAIL.

Per the mission fallback, this pass advanced an existing FX basket rather than
minting a duplicate or weaker card.

## Repair

Prior `QM5_12783` state:

| Phase | Work item | State |
|---|---|---|
| Q02 | `1a2e412b-1229-4b97-a627-9491e264af63` | PASS |
| Q03 | `ab3c2b44-f749-407b-8a56-b38c0d368fe7` | INFRA_FAIL |
| Q04 | `16267df3-00b5-4ede-abbb-75dfcadedc14` | INFRA_FAIL |

The Q03 retry failed as `NO_HISTORY`/`INCOMPLETE_RUNS` even though the logical
basket Q02 had passed. The terminal claim guard only checked the host history
symbol. For basket work items, this allowed a terminal to be selected without
verifying every manifest-declared history symbol.

Changed `tools/strategy_farm/terminal_worker.py` so claim eligibility now builds
the required history set from `host_symbol` plus `basket_symbols[]` and skips a
terminal if any declared `.DWX` member lacks history for the work item's period.

Also refreshed the stale log-bomb test hook from the removed
`_find_oversized_journal` helper to the current `_journal_bomb` function.

## Queue Mutation

SQLite backup before mutation:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12783_q03_basket_history_claim_requeue_20260701T030838Z.sqlite`

Reopened the existing Q03 row in place:

| Field | Value |
|---|---|
| Work item | `ab3c2b44-f749-407b-8a56-b38c0d368fe7` |
| Parent task | `c7afca44-6c60-4d56-acd6-8e92117e3417` |
| Status before | `done` |
| Verdict before | `INFRA_FAIL` |
| Status after | `pending` |
| Verdict after | `NULL` |
| Duplicate pending/active Q03 rows | `1` |
| Requeue reason | `basket_manifest_history_claim_guard_patch` |

Verification:

```text
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12783
Q02 done PASS; Q03 pending; Q04 done INFRA_FAIL.
```

No manual MT5 backtest was launched. The paced terminal workers own the Q03 run.

## Validation

```text
python -m py_compile tools/strategy_farm/terminal_worker.py tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py
python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q
```

Result: `24 passed`.
