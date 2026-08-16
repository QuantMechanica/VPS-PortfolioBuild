# QM5_1257 compact-basket Q02 selector repair

**Date:** 2026-08-16 17:24 Europe/Berlin

**Branch:** `agents/board-advisor`

**Outcome:** existing rank-58 GBPUSD/USDJPY sleeve advanced without a duplicate queue row

## Mission reconciliation

The checked-in sign-aware reconciliation covers all 66 relationships in the
frozen FX cointegration scan, so there is no unbuilt pair left to mechanize.
The preferred anchors are already beyond Q02 and have no open `ONINIT` or
`NO_HISTORY` blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The non-duplicate fallback remains frozen-scan rank 58,
`GBPUSD.DWX` / `USDJPY.DWX`, implemented as pair slot 8 in the approved and
built `QM5_1257_lemishko-fx-cointpair` basket. Its exact logical Q02 work item
is `d4cd660c-c81a-41d3-8a4c-ad21d3319816`.

## Defect and repair

The work-item payload is valid compact JSON and contains
`"portfolio_scope":"basket"`. The canonical pending selector classified a
Q02 basket with a whitespace-sensitive `LIKE` expression that required
`"portfolio_scope": "basket"`. This gave the real two-leg row
`_basket_q02_rank=1`, the ordinary single-symbol rank, and left it at selector
rank 40 despite its already-governed priority-track status.

`pending_claim_order_sql()` now checks `portfolio_scope` with SQLite JSON
functions after `json_valid()`, normalizes surrounding whitespace and case,
and fails closed for malformed payloads. No work-item priority, timestamp,
strategy parameter, or execution binding was changed.

A regression test binds a compact JSON Q02 basket and requires
`_basket_q02_rank=0`. The production database remains unmodified; a fresh
read-only evaluation of the corrected selector at `2026-08-16T15:24:20Z`
placed the exact QM5_1257 row at rank 4 of 977 eligible pending rows.

## Validation

```text
python -m py_compile tools/strategy_farm/farmctl.py tools/strategy_farm/tests/test_ultracode_wsa_claim.py
python -m pytest tools/strategy_farm/tests/test_ultracode_wsa_claim.py -q
29 passed
python -m pytest tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py -q
65 passed
python -m pytest tools/strategy_farm/tests/test_basket_work_items.py -q
16 passed
git diff --check
PASS
```

## Queue and resource boundary

At the final read-only database sample, the row remained PENDING, unclaimed,
and at `attempt_count=2`, with one exact identity and one exact open row. Six
other work items were active and none was multisymbol. No enqueue or requeue
was issued because that would duplicate the existing governed identity.

Five two-second whole-machine CPU samples were 87.45%, 96.54%, 91.26%,
89.65%, and 84.33% (89.85% average, 96.54% maximum), below the 97% hard
backtest ceiling. No tester or dispatch tick was launched: the resident paced
workers retain ownership of claim timing, resource hysteresis, terminal
selection, and the single-basket lane. The code repair takes effect through
the governed worker lifecycle; no running worker or Factory state was
interrupted to force it.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution path changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- No Strategy Card, EA, EX5, setfile, basket manifest, registry, magic row, or
  work-item payload changed.
- No backtest, terminal control, Factory transition, enqueue, requeue, priority
  restamp, or timestamp mutation was performed.
- Concurrent unrelated worktree changes were left unstaged and untouched.
