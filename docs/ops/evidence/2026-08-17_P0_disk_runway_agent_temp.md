# P0 — D: had 69 minutes of runway, and the purge was structurally unable to help (2026-08-17)

## The rate, not the threshold

| Time (UTC) | D: free |
|---|---:|
| 10:52 | 153.5 GB |
| 11:07 | 128.6 GB |
| 11:22 | 112.5 GB |

**−41 GB in 30 minutes.** Measured directly rather than inferred: files under `D:\QM` modified
in the trailing 20 minutes summed to **32.7 GB**, i.e. **98 GB/h**. Against 112 GB free that is
a **runway of about 69 minutes** — shorter than the interval between two monitoring rounds.

"Still above the gates" was correctly measured and was the wrong conclusion. A gate fires on a
threshold; runway is a rate.

## The cause, named with numbers

Growth by directory over the trailing 20 minutes:

| Directory | Files | GB |
|---|---:|---:|
| **`D:\QM\mt5\T6`** | **470** | **29.19** |
| `D:\QM\mt5\T10` | 119 | 1.75 |
| `D:\QM\mt5\T5` | 80 | 1.04 |
| `D:\QM\strategy_farm\logs` | 19 | 0.47 |
| everything else | — | < 0.2 |

**One terminal accounted for 89% of the growth: 29.19 GB in 20 minutes ≈ 87 GB/h.**

Drilling in: `T6\Tester\Agent-127.0.0.1-3003\temp` held **646 `bar*.tmp` files totalling
40.4 GB**, each exactly 64 MB, written continuously. T6 was running `QM5_1077` XAUUSD **Q07**
since 10:58:38 — a Wave-1 canary. A Q07 multiseed is five sequential tester invocations on the
heaviest symbol, and each leaves its bar-cache scratch behind.

## Why the existing purge could not fix it

`tools/strategy_farm/tester_cache_purge.ps1` targets **exactly this directory** —
`D:\QM\mt5\T<n>\Tester\Agent-*` is named in its header. It ran at 13:20 local with
`result=0`. And it was powerless, by design:

> *"When it acts: stop only **idle** factory slots -> clear their caches -> start only missing
> workers. Because MT5 agents read these caches mid-run, the factory MUST be stopped first."*

So the purge clears idle slots and skips busy ones — correctly, because clearing a live agent's
scratch would corrupt the run. **The consequence is that the terminal causing the fill is
permanently exempt while it causes it.** A Q07 multiseed can hold a slot for many hours across
five seeds, and throughout that time its scratch is untouchable by the only mechanism designed
to reclaim it.

Two gaps, and the second is the real one:

1. **No rate component.** The gate triggers below 150 GB free. At 98 GB/h that leaves under
   90 minutes, and the gate has no notion of how fast the floor is approaching.
2. **No path to a busy slot.** Even when triggered, the purge cannot touch the offender.

## Immediate action taken, and why it was safe

Deleted `bar*.tmp` older than 20 minutes from agent temp directories, with three independent
safety layers:

1. **scope** — only `bar*.tmp` under `Tester\Agent-*\temp`, regenerable scratch, never source
   tick data (`T<n>\Bases`) and never reports;
2. **age** — only files older than 20 minutes; the live seed's files are recent (the newest five
   were under 5 minutes old);
3. **lock test** — each file opened `Open/ReadWrite/None` before deletion; anything the agent
   still holds raises and is **skipped, never forced**.

A dry run first reported 455 candidates / 28.44 GB with **zero locked**, confirming the agent had
released all of them. Applied:

```
T6 Agent-127.0.0.1-3003: 463 candidates, 28.94 GB freed, 0 locked skipped
D: free 112.1 GB -> 152.5 GB   (+40.4 GB)
```

The gain exceeds the 28.94 GB deleted because crossing back above the 150 GB low-water let the
regular purge do its own work on idle slots.

**The canary was verified unharmed after the fact**, which was the whole point of not simply
killing the run: T6's worker (`pythonw` 19924), its multiseed runner (`python` 13776, started
12:58:38 local = the 10:58:38 UTC claim) and a newer seed runner (12496) are all alive, and T6
wrote 4 further files in the following 3 minutes. The run continues.

Only T6 showed the pattern; the other nine terminals had no candidates older than the cutoff.

## What must change permanently

1. **A rate alarm alongside the threshold gate.** Free space alone is not a health signal when
   a single run can consume 87 GB/h. Alarm on GB/h and on projected runway, not only on the
   remaining floor. Runway under ~2 hours is the actionable condition.
2. **A busy-slot reclaim path.** The age-plus-lock test used here is exactly the primitive the
   purge lacks: it reclaims released scratch from a running slot without touching anything the
   agent still holds. That belongs in `tester_cache_purge.ps1` as a second mode, not in a
   scratch script.
3. **Investigate why the scratch survives a completed seed at all.** Each of five sequential
   tester invocations leaves ~6 GB behind. If MT5 can be made to clean per-invocation, the
   accumulation disappears rather than being periodically swept.

## Coordination note

This interacts with the log-retention item: raising `ReportsLogPurge` retention from its
effective 2 hours costs disk on the same volume. Any retention increase must be sized against
this consumption profile, not against a quiet baseline. The two decisions belong together.

## Evidence

- growth measurement: files under `D:\QM` with `LastWriteTime` in the trailing 20 minutes,
  grouped by directory
- `tools/strategy_farm/tester_cache_purge.ps1` header (idle-only scope) and `:113` (threshold)
- `QM_StrategyFarm_TesterCachePurge` last run 13:20 local, `result=0`
- reclaim dry-run and apply output as quoted above
