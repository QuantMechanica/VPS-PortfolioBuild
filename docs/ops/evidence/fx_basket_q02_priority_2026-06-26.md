# FX basket Q02 priority unblock - 2026-06-26

## Scope

Advanced the farm toward non-index/non-metal sleeve diversity by unblocking the two market-neutral FX basket candidates already built and logically enqueued:

- `QM5_12532` - `QM5_12532_AUDNZD_COINTEGRATION_D1`
- `QM5_12533` - `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`

No T_Live action, no AutoTrading, no portfolio gate changes.

## Findings

The retired per-leg rows were not the actionable work. Both EAs have `basket_manifest.json` plus a logical basket Q02 setfile, so Q02 must run one logical basket row rather than standalone leg rows.

The logical rows existed but were disadvantaged by the worker claim order because they did not have a prior `done/PASS` row and sat behind a large ordinary Q02 pool. `QM5_12577` was already active as a basket row, so basket serialization was also correctly preventing another heavy multi-symbol run from starting concurrently.

## Changes

- `terminal_worker.py` now ranks Q02 rows with `payload_json.portfolio_scope == "basket"` ahead of ordinary Q02 rows, while preserving explicit `priority_track` and downstream phase precedence.
- Added a regression test proving a logical basket Q02 row claims before an ordinary Q02 row from an EA with prior PASS evidence.
- Updated the farm DB pending rows for `QM5_12532` and `QM5_12533` with `priority_track=true` and reason `fx_market_neutral_basket_diversity_q02_unblock_2026-06-26`.

## Verification

```powershell
$env:QM_AGENT_ID='codex'; python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py tools/strategy_farm/tests/test_basket_work_items.py -q
```

Result: `12 passed`.

DB rows tagged:

- `e4890d77-b865-4a48-b946-315faefca920` - `QM5_12532_AUDNZD_COINTEGRATION_D1`
- `fe14e345-8ea4-4fbd-a77d-831df5fedc51` - `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`

