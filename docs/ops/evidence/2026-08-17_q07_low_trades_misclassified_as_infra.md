# Q07 reports a legitimate economic FAIL as INFRA_FAIL, and the correct branch is unreachable

## How it surfaced

Two Q07 rows failed within twelve minutes with `seeds_invalid_evidence` and `exit_code=1`
per seed — QM5_1077/XAUUSD (all five seeds) and QM5_1116/EURJPY (seed 99 only). Both landed
minutes after commit `334b63686` added an in-process scratch reclaimer to `q07_multiseed.py`,
and 2 of 2 Q07 rows since that commit failed this way against a 4.5% base rate over the prior
22 rows (p ≈ 0.2% under the base rate).

**That theory is wrong, and I checked before acting on it.** Seeds 42 and 17 ran at 10:59 and
11:29 UTC — before the reclaim log's first entry at 11:48 UTC. Neither reclaimer existed
during the failures they were supposed to have caused. Had I acted on the timing I would have
reverted a correct change and left the real defect in place.

## What the evidence actually says

The evidence for these rows survives on disk, so the cause is readable rather than inferred.
`summary.json` for QM5_1077 seed 42:

| field | value |
|---|---|
| `result` | FAIL |
| `reason_classes` | `['MIN_TRADES_NOT_MET']` |
| `min_trades_required` | 45 |
| **`runs[0].status`** | **OK** |
| **`runs[0].exit_code`** | **0** |
| `oninit_failure_detected` | False |
| `log_bomb_detected` | False |
| `deterministic` | True |
| `news_calendar.status` | OK |

**The tester run succeeded.** The seed simply produced fewer than 45 trades under harsh
stress. Nothing here is an infrastructure failure.

## The defect, exactly

`framework/scripts/q07_multiseed.py:633-644`:

```python
invalid_seeds = [
    (r["seed"], r.get("invalid_reason") or f"exit_code={r.get('exit_code')}")
    for r in seed_results
    if r.get("invalid_reason") or (
        int(r.get("trades") or 0) < MIN_TRADES
        and r.get("exit_code") not in (0, "0", None)
    )
]
```

`run_smoke` exits 1 **because** its verdict is FAIL on `MIN_TRADES_NOT_MET`. So for that
outcome "low trades" and "non-zero exit" always co-occur, and this predicate always fires.
The clause was presumably meant to catch *few trades because the run broke* — but it cannot
distinguish that from *few trades, run healthy, wrapper signalling FAIL*.

The consequence is that the branch written for exactly this case, twenty lines later, can
never be reached for it:

```python
low_trades = [r["seed"] for r in seed_results if int(r.get("trades") or 0) < MIN_TRADES]
if low_trades:
    return ("FAIL", f"seed_trades_below_floor:seeds={low_trades}:floor={MIN_TRADES}", …)
```

## The information needed to fix it is already stored

`summary.json` separates the two axes without ambiguity: `runs[*].status` and
`runs[*].exit_code` describe the **tester**, while top-level `result` / `reason_classes`
describe the **economic verdict**. A broken run has a non-OK per-run status, a non-zero
per-run exit code, or `oninit_failure_detected` / `log_bomb_detected` true. A healthy run with
too few trades has `status: OK`, per-run `exit_code: 0`, and
`reason_classes: ['MIN_TRADES_NOT_MET']`. The predicate reads the wrapper's exit code instead
of either axis.

## Why it costs twice

1. **It corrupts the infra-versus-strategy statistics** that gate decisions about where the
   funnel is losing candidates — the exact classification this work is meant to get right.
2. **It burns capacity.** An `INFRA_FAIL` label attracts recovery and requeue, and
   `deterministic: True` guarantees the re-run reaches an identical outcome — five seeds at up
   to two hours each to re-derive a number already sitting in `summary.json`.

This is the same class as today's `BARS_ZERO` finding: an economic or EA-level result wearing
an infrastructure label, with the retry ladder as the price of the mislabel. Two independent
instances in one day suggests the class is worth a systematic pass, not two point fixes.

## Dispatched

Task `c6343474` at priority 96, with the fix keyed on tester health rather than wrapper exit
code, and four required controls: a healthy low-trade seed must yield
`FAIL/seed_trades_below_floor`, while non-OK run status, `oninit_failure_detected`, and
`effective_seed_mismatch` must all still yield INVALID. Without the latter three the change
is indistinguishable from deleting the guard.

Reclassification is to be **derived from the stored evidence, not re-run** — the summaries are
intact and the outcome is deterministic — and the historical sweep must name the rows whose
evidence has been purged and therefore cannot be reclassified.

## Evidence

- work item `e317cb4a-0486-4a4e-a47b-660162844345` — QM5_1077 XAUUSD.DWX Q07, 2026-08-17T12:20:50Z
- `D:\QM\reports\work_items\e317cb4a-…\QM5_1077\20260817_105929\summary.json` — seed 42
- `framework/scripts/q07_multiseed.py:633-644` (defect), `:655-659` (the unreachable branch)
- second instance: QM5_1116 EURJPY.DWX Q07, 2026-08-17T12:32:28Z, seed 99
- related: `2026-08-17_bars_zero_root_cause_closed_at_the_generator.md`
