# Combined Q10_NEWS scheduling cap (2026-08-25)

Router task: `427f8014-c199-4ed1-9b9a-9e56ad50b0f2`.

## Result

The fleet-wide claim selector now caps all active Q10_NEWS work at four rows,
standard and expanded combined. The existing expanded-matrix subcap remains
two, and the existing Q07/Q08 combined cap remains two. Skipped candidates stay
`pending`; no row, verdict, gate criterion, or priority is rewritten.

| Claim class | Fleet-wide active cap |
|---|---:|
| Q10_NEWS, standard + expanded combined | 4 |
| Q10_NEWS expanded subset | 2 |
| Q07 + Q08 combined | 2 |

The number four is the bounded correction to the 2026-08-25 14:20Z snapshot:
seven of nine available test terminals were simultaneously occupied by
standard Q10_NEWS rows running for roughly 7–8 hours and slowing one another at
full CPU load. The throughput forensics in commit `e88c8e9b0` found that fewer
parallel long runners produced more completions. With ten terminals, a total
news cap of four plus a Q07/Q08 cap of two makes the short-flow floor concrete:
`10 - 4 - 2 = 4` terminals remain available to ordinary gates and compile
work. The stricter expansion cap of two prevents 29-cell parents from consuming
the entire news allowance.

Implementation:

- `longrun_scheduling_policy.active_longrun_counts()` counts every active news
  row in `total_news_parent` and additionally counts an expanded row in
  `expanded_news_parent`.
- `should_skip_for_longrun_cap()` applies both constraints to expanded
  candidates and the total constraint to standard candidates. The specific
  expansion subcap is checked first for an auditable skip reason.
- `terminal_worker.claim_atomic()` uses one fleet snapshot inside its existing
  `BEGIN IMMEDIATE` transaction, so concurrent workers cannot both observe a
  free final slot. The existing wiring now enforces all three caps.

## Before/after claim simulation

The simulation uses the production `terminal_worker.claim_atomic()` path
against a temporary `farmctl.init_db()` database. Four standard Q10_NEWS rows
are already `active`; a fifth standard row is `pending`.

Rollback / prior behavior (`QM_DISABLE_LONGRUN_SCHEDULING_CAP=1`):

```json
{
  "claimed": true,
  "item_id": "pending-standard-5"
}
```

Policy enabled, fifth standard row is the only pending candidate:

```json
{
  "claimed": false,
  "reason": "no_pending_claimable",
  "longrun_cap_skipped": [{
    "item_id": "pending-standard-5",
    "longrun_class": "total_news_parent",
    "active_count": 4,
    "fleet_cap": 4
  }]
}
```

Policy enabled, with the same fifth news row plus ordinary `pending-short` Q03:

```json
{
  "claimed": true,
  "item_id": "pending-short"
}
```

The existing expansion simulation remains green: with two expanded news rows
active, a third expansion stays pending with
`longrun_class=expanded_news_parent`, `active_count=2`, `fleet_cap=2`.

## Verification and rollback

- `python -m pytest -q tools/strategy_farm/tests/test_longrun_scheduling_policy.py`
  → `19 passed in 14.86s`.
- `python -m pytest -q tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py`
  → `68 passed in 52.98s`.
- Coverage includes the fifth-row cap boundary, fourth-row admission, expansion
  subcap, real atomic claim selection, short-row floor, and rollback flag.

Rollback remains `QM_DISABLE_LONGRUN_SCHEDULING_CAP=1` in the terminal-worker
environment. `policy_enabled()` reads it on every claim attempt. Removing or
unsetting it restores the cap.

## Activation boundary

The source change takes effect when terminal workers next restart and import
the updated module. This task does not restart workers: six T1–T10 backtests
were active during implementation, and interrupting them is outside the
authorized scope. The operator should let the current work finish and use the
next normal worker restart window. No terminal, T_Live, AutoTrading, or live
setting was touched.
