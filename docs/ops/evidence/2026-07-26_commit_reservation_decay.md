# Commit-reservation decay against measured usage — 2026-07-26 (Claude)

OWNER directive after the starvation incident: implement the reservation that decays
with measured consumption instead of a flat hold.

## The problem, stated precisely

A claim becomes visible in SQLite before its child process has allocated anything, so
without a reservation every worker reads the same unchanged OS headroom and they all
admit work into the same gap. The reservation closes that race. But the OS commit
measurement **already contains** whatever a job has actually allocated, so continuing to
reserve its full expected peak double-counts the moment it starts growing.

Both failure modes are real and were both observed today:

| window | behaviour | observed failure |
|---|---|---|
| 300 s flat (original) | expires while a multisym is still growing | 17:45 — jobs admitted into the balloon phase, pagefile storm, workers killed |
| 3600 s flat (`d88a89392`) | double-counts 44 GB for an hour | 18:49 — effective headroom 20.4 GB against 64.5 GB real, whole fleet pinned, no work admitted at all (reverted `347859ad3`) |

## The fix (`d2a19449f`, logging follow-up `5f5d294c8`)

```
reservation = max(0, expected_peak - measured_subtree_private_bytes)
```

- **Measurement**: `_process_private_snapshot()` — Toolhelp32 process enumeration plus
  `GetProcessMemoryInfo` (`PrivateUsage`, i.e. private commit, the same quantity the
  headroom probe reports) through ctypes. Cached 3 s. **8 ms cold, 0.4 µs cached**, versus
  hundreds of ms for `farmctl`'s PowerShell probes — usable in the per-poll admission path.
- **Subtree walk**: from the payload `pid` down a children map built from every process's
  parent id, not from live parent links. Phase drivers routinely leave a `run_smoke`/pwsh
  child running after their Python parent exits; Windows keeps the dead parent's id in the
  child's PPID field, so the lineage stays discoverable. Verified live: the 26 GB
  `metatester64` sits three levels below the recorded pid
  (`metatester64 ← terminal64 ← pwsh ← python`).
- **Fail-safe semantics**: probe failure or a pid that cannot be parsed returns `None` →
  the **full** reservation is kept (never assume zero usage). A lineage with no live
  process returns `inf` → reservation drops to 0 (nothing left to grow into). No pid yet →
  full reservation, which is exactly the launch race the mechanism exists for.
- **Windows**: multisym 3600 s (its balloon phase), ordinary unchanged at 300 s. The long
  window is only safe *because* of the decay — a flat hold over the same window is what
  starved the fleet.
- **Observability**: the logged `commit_headroom_low_pause` event now carries
  `commit_reservation_detail` — per claim the expected peak, the measured usage and the
  residual. The previous failure was silent starvation that looked identical to a busy
  fleet; this makes the arithmetic readable in the field.

## Tests

`tools/strategy_farm/tests/test_commit_reservation_decay.py` — 13 cases: unspawned job
reserves its full peak; decay by measured usage; job at/above peak reserves nothing (with
an explicit assertion that 64.5 GB of real headroom stays available, i.e. the incident
cannot recur); probe failure stays conservative; vanished lineage releases; per-lineage
windows; expiry; and the incident's exact shape asserted on the admission verdict.
Together with the existing atomic-claim suite: **64 passed**.

## Live verification

Deployed by worker restart 19:07 / 19:08 (restart does not kill running backtests — a
worker adopts an active claim whose process tree is alive).

Decay observed on the live fleet within a minute of deploy, on the same job that caused
the incident:

| time | QM5_13059 measured | resulting reservation |
|---|---|---|
| 19:07 | 1.32 GB (between neighborhood param points) | ~42.7 GB held — correct, it is about to spawn another tester |
| 19:08 | **30.11 GB** (tester at peak) | ~13.9 GB held — the flat rule would still have held 44 GB |

At 19:08, 7 of 9 workers held claims and were working; before the revert, all nine were
pinned. Aggregate at one sample: 5 active reservations totalling 43.9 GB, where a flat
rule would have reserved 44 + 4×8 = 76 GB.

Note the two guards are independent and measure different things: commit headroom (58.6 GB
at 19:08) includes the 60 GB pagefile, while free **physical** RAM was 2.3 GB. The RAM
floor (`RAM_MIN_FREE_GB` 4.0) is the operative brake in that regime, not the commit gate.
That is pre-existing behaviour, unchanged here, and it is the reason the memory-capacity
question in ticket `213aa9c3` still stands on its own.

## What this does not solve

The box remains undersized for a 26 GB multisym plus several 8-11 GB ordinary jobs
(ticket `213aa9c3`), and workers still die silently when physical RAM is exhausted rather
than idling through it (ticket `4e8bcf47`). The decay stops the admission arithmetic from
*causing* either, but it cannot make 63 GB of RAM into more.
