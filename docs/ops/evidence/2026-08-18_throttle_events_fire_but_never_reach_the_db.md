# The throttles fire constantly and never reach the database — my monitoring round has been structurally blind

v6 §7 carries a standing item: *"Die Drosselung emittiert unter sieben verschiedenen Namen — sieben
`cpu_ceiling`-Ereignisnamen, jeder genau einmal überhaupt gefeuert, kein einziges `ram_low`, keines
für `claim_spacing`."*

That item, and every "throttle-class events: 0" line in my monitoring rounds this session, rest on
the same query: a `SELECT ... FROM events`. **The throttles do not write there.**

## What actually happens

`terminal_worker.py:4435` emits the pause as JSON on **stdout**:

```python
print(json.dumps({"event": "ram_low_pause", "terminal": terminal, ...
```

That lands in `D:\QM\strategy_farm\logs\terminal_worker_T*.log` — per-terminal files, ~105 MB each
— and never in the `events` table. Counting distinct pause events across those logs:

| event | occurrences (all-time, across the worker logs) |
|---|---:|
| `commit_headroom_low_pause` | 31,716 |
| `custom_history_gate_pause` | 22,449 |
| `cpu_high_pause` | 7,144 |
| **`ram_low_pause`** | **6,323** |
| `disk_low_pause` | 1,723 |
| `watchdog_reset_pending_pause` | 1,507 |

**These are all-time counts, not a rate.** A first attempt to scope them to a two-hour window did
not actually filter by time — the label was wrong and the numbers it produced were the same
all-time figures over a different file set. The rate is not established here and should not be
quoted from this document.

## What this corrects

**My own instrument.** "throttle-class events: 0" appeared in every monitoring round this session.
It was never a measurement of quiet — it was a query against a table the throttles do not use. Any
conclusion I drew about the factory being unthrottled is withdrawn.

**The v6 §7 framing.** The item reads as "the throttle barely emits, and under inconsistent names".
The reality is the opposite: six distinct, consistently-named pause events fire in the thousands.
The defect is not sparse emission — it is that **emission never reaches a queryable surface**, so no
dashboard, no health check and no monitoring round can see it. That is a different repair: a bridge
from the worker's stdout to `events`, not a renaming exercise.

## The occasion for finding it

Free RAM dropped to 9.7 GB of 63.1 GB while 9 Q08 runs were active. Eleven `terminal64` processes
were running, but they hold only 0.9 GB between them — the memory is in **8 `metatester64`
processes totalling 30.6 GB**, one of them alone at 11.1 GB. That is the tester under load, not a
leak.

Two RAM gates exist and both behave correctly at that level:

| gate | threshold | reservation | scope |
|---|---:|---:|---|
| general (`terminal_worker.py:4432`) | 6.0 GB | 8 GB | every claim, with hysteresis and the `ram_low` latch |
| multisymbol (`:1924`) | 12.0 GB | 44 GB | basket / multi-symbol items only |

At 9.7 GB free the multisymbol gate is **already biting** — no new baskets start, while the running
one finishes and ordinary single-symbol Q08 claims continue. Exactly the designed behaviour, and it
matches the observed dispatch.

The eleven terminals also reconcile cleanly: nine factory terminals matching nine active claims,
plus **T_Live** and the **FTMO terminal** — the two the path-anchored selection rule exists to
exclude. No orphans.

## Consequence

Until the bridge exists, throttle state must be read from the worker logs, not from `events`. I have
added that to the monitoring round; reporting "0 throttle events" from the database is worse than
reporting nothing, because it reads as a healthy silence.

## Evidence

- `tools/strategy_farm/terminal_worker.py:121` (`_RESOURCE_LATCH`), `:1924-1926` (multisymbol RAM
  gate), `:4432-4441` (general gate, hysteresis, `ram_low_pause` emission)
- constants at `:101` `RAM_MIN_FREE_GB = 6.0`, `:143` `MULTISYMBOL_RAM_MIN_FREE_GB = 12.0`,
  `:138` `ORDINARY_COMMIT_RESERVATION_GB = 8.0`, `:154` `MULTISYMBOL_COMMIT_RESERVATION_GB = 44.0`
- `D:\QM\strategy_farm\logs\terminal_worker_T*.log`
