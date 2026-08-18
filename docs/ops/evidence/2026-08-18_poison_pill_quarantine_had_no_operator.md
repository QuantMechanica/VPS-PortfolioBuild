# The poison-pill quarantine has been written exactly once in its life — its only caller is dead code

## The observation that started it

`QM5_11287 / Q04` has failed with `INFRA_FAIL / stream_and_selfreport_missing` five consecutive
times on GBPUSD and six on USDJPY, with no merit run ever. The quarantine threshold is five. It was
not quarantined. I predicted the mechanism's behaviour wrongly three times in earlier rounds —
first by checking too early, then by blaming `scan()`'s pending-row filter, then by blaming
`_single_observation_pending()`. **All three were wrong**, and I checked none of them against the
mechanism itself.

Running the mechanism instead of reasoning about it settles it in one call:

```
QM5_11287/GBPUSD.DWX/Q04  eligible=True  streak=5  successes_ever=0
QM5_11287/USDJPY.DWX/Q04  eligible=True  streak=6  successes_ever=0
QM5_9122 /XAUUSD.DWX/Q04  eligible=True  streak=6  successes_ever=0
QM5_20235/…_XAU_XAG_ES_D1/Q02 eligible=True streak=6 successes_ever=0
```

`scan()` returns **4 eligible triples right now**. The gate is not refusing them. Nothing is
asking.

## The table has one write event in its entire history

| | |
|---|---:|
| rows in `poison_pill_quarantine` | **184** |
| active | 184 |
| **distinct `updated_at` values** | **1** |
| that value | `2026-08-17T10:59:52+00:00` |

All 184 rows share one timestamp. `refresh_pending()` upserts `quarantined_at` and `updated_at` on
conflict, so a row that were re-confirmed would carry a newer stamp. None does. The table was
populated by a single invocation — a hand-run CLI — and never touched again.

## Why: the only production caller is inside a function nothing calls

Repo-wide, `refresh_pending()` has exactly one call site:

- `farmctl.py:9867`, inside `dispatch_work_items()`
- `terminal_worker.py:1844` — a **comment**, not a call

And `dispatch_work_items()` is dead:

- no `add_parser("dispatch")` — it is not reachable as a subcommand
- no scheduled task invokes it (checked all 79 `QM_*` task action strings)
- the pump **explicitly disables it**:

```python
result["dispatch_work_items"] = {
    "disabled": True,
    "reason": "per-terminal worker daemons own work_item dispatch",
}
```

Worse, the call sat behind two unrelated gates inside that function — `if free_terminals and
calendar_gate_open:` — so even had it run, quarantine bookkeeping would have been conditional on
spare terminal capacity and on the news calendar being current. Neither has anything to do with
sealing a poison pill.

## The two halves of the defect are individually reasonable

`terminal_worker.py:1844` declines to refresh, and its reasoning is sound:

> do NOT refresh the poison-pill table here. Measured cost … ~413ms … this point is inside BEGIN
> IMMEDIATE. Nine workers claiming every ~2s would demand ~3.7s of write lock per 2s window and
> serialise the whole fleet. … farmctl's dispatch path already refreshes it every pump cycle in
> its own transaction.

Every sentence is correct except the last, and the last is the one it depends on. The dispatch path
was retired when the worker daemons took over claiming; the comment describing it was not. **This
is a handover that moved the work but left the premise behind** — the same shape as the Q09_NEWS dam
found on 08-17, where `bind-q09-plan` was a hand-operated CLI with no scheduled caller. Two
instances now make it a class worth naming: *a fail-closed mechanism inherits its operator from
whatever called it, and a refactor that retires the caller retires the mechanism silently.*

## Measured cost

Deterministic failures that a live quarantine would have sealed, last 48h, one EA:

| triple | re-runs | terminal-minutes |
|---|---:|---:|
| QM5_11287 / GBPUSD / Q04 | 4 | 45.8 |
| QM5_11287 / USDJPY / Q04 | 5 | 52.4 |
| **total** | **9** | **98 (1.6 terminal-hours)** |

Each run re-fails for the same reason after ~11 minutes of a terminal slot, while the 91-pair Q08
batch queues behind it. The waste is unbounded, not one-off: nothing in the current wiring ever
stops it.

## Fix — at the level of the cause

v6 §4: *a repetition limit sits at the level of the cause.* The cause is not the worker (it is right
to decline) and not `scan()` (it works). It is that the refresh lost its operator. So the refresh
gets an operator, at the frequency the limit needs and no higher:
`_pump_unlocked()` now calls `refresh_pending()` once per pump cycle, in its own transaction,
outside any claim lock, wrapped in `_with_sqlite_write_retry` and a catch-all so bookkeeping can
never abort the pump. That restores exactly the premise `terminal_worker.py:1844` already states.

## Controls, run before the change went live

On an in-process `sqlite3.backup()` snapshot of the live DB — a plain file copy of a WAL-mode
database yields `database disk image is malformed`, which is how the first attempt failed:

- **positive**: `refresh_pending()` wrote 184 → 187 rows, sealing the three unsealed triples
  (QM5_20235 upserted in place); 5 pending rows become unclaimable through the claim query's
  `NOT EXISTS` on the quarantine primary key
- **negative**: **0** triples of the running 91-pair Q08 batch are affected. `MERIT_VERDICTS` is
  `{PASS, FAIL}` and every pool pair carries a prior Q08 verdict, so `successes_ever > 0` for the
  ones that passed; and no batch pair holds a 5-long `INFRA_FAIL` streak. The change cannot
  contaminate the pre-registered experiment.
- `sealed_pending_rows = 0` for all four: none is of the `summary_missing_retries_exhausted`
  graveyard class, so no `work_items` row is mutated. Quarantine here is visible and reversible —
  the pending rows simply stop being claimable.

## Correction to my own reporting

1. In the previous round I reported the quarantine table as **empty**. It holds 184 rows. My query
   carried `ORDER BY rowid DESC LIMIT 10` and I read the truncation as the population.
2. I offered three explanations for the missing quarantine across three rounds and did not test any
   of them against `diagnose_triple()`, which answers the question in one call and was available
   throughout.

## Evidence

- `tools/strategy_farm/poison_pill_quarantine.py` — `scan()` :108, `diagnose_triple()` :69,
  `refresh_pending()` :191
- `tools/strategy_farm/farmctl.py` — dead `dispatch_work_items()` :9532, old call site :9867,
  pump disable + new call site in `_pump_unlocked()` :14842
- `tools/strategy_farm/terminal_worker.py:1844` — the stale premise
- live DB `D:\QM\strategy_farm\state\farm_state.sqlite` (read-only), snapshot control in scratchpad
