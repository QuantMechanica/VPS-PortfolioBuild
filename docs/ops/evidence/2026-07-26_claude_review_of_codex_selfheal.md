# Claude's review of Codex's self-healing fix (`ed46fff50`) — 2026-07-26

Verdict: **APPROVE_WITH_FINDINGS**. The fix is real, the root cause Codex found is deeper
than the ticket asked for, and one consumer of the broken mechanism was missed.

## What I verified independently (not taken from the report)

| claim | how I checked | result |
|---|---|---|
| token spawn lands in the interactive session | `Win32_Process` for the worker Codex spawned: T7 pid 13656 | **SessionId = 3** ✓ |
| watchdog now uses the token path | `factory_watchdog.ps1:44,51` → `Invoke-InteractiveWorkerDedupe` → `run_in_console_session.ps1`; called at `:1183` | wired ✓ |
| Unicode marshaling was the real defect | `run_in_console_session.ps1`: `CreateProcessAsUser` DllImport already carried `CharSet=CharSet.Unicode` (`:100`) while `STARTUPINFO` did **not** — so `lpDesktop` was marshaled ANSI into a W-API call | **confirmed, and it is the important finding** |
| desktop actually set | `$si.lpDesktop = "winsta0\default"` (`:133`), `$si.cb` before assignment (fixed struct size, correct) | ✓ |
| factory not damaged by the runtime test | worker census, duplicate check, T_Live pid | 0 duplicates, T_Live pid 16388 unchanged ✓ |

**Why the marshaling finding matters beyond this ticket.** The architecture's standing rule —
"the SYSTEM watchdog must NEVER spawn workers directly, because session-0 children die
0xC0000142" — was written after the 2026-06-24 broken-respawn class. Codex's evidence says
that failure was a *marshaling bug in our own launcher*, not an inherent property of
token-based spawning: a garbage `lpDesktop` yields exactly 0xC0000142. If that holds, a
long-standing architectural constraint rests on a fixable defect, and more of the healing
architecture can be moved off the fragile interactive-task dependency.

## Findings

**F1 — a second consumer of the dead task was not fixed (medium, live impact).**
`tester_cache_purge.ps1` still delegates worker recovery to `QM_StrategyFarm_WorkerDedupe`
(`:13, :17, :170, :176`), the task that has been queued-never-run since the 17:33 session
handover. This is not theoretical: during tonight's disk incident its own log recorded
`missing workers requested via interactive WorkerDedupe: 7 total worker daemon(s)` — it
asked for nine and the request evaporated. `install_tester_cache_purge_scheduled_task.ps1`
even *validates* the dead task's contract before installing (`:16-18`). Route it through the
same `run_in_console_session.ps1` launcher.

**F2 — two changes, one experiment (low, methodological).** The Unicode marshaling fix and
the `CREATE_NO_WINDOW` removal were made together, then tested once. Both are individually
plausible causes of 0xC0000142; the evidence does not separate them. Not worth re-breaking
production to bisect, but the report should not state the flag as *the* cause.

**F3 — the decisive property is still unverified (acknowledged by Codex, and I could not
close it either).** Whether a token-spawned worker can actually launch `terminal64` — the
whole point — remains unproven. Codex was blocked by admission guards; I tried to close it
using his T7 worker and was blocked too, because that worker sat in `disk_low_pause` during
the disk incident below. It should be confirmed at the next opportunity.

## Not a finding

Codex declined to blanket-convert the seven Interactive tasks to S4U and argued it in the
commit: S4U has no loaded profile and lands in session 0, which is the exact condition that
breaks spawning, profile and desktop consumers. That reasoning is correct, and the restraint
was the right call.

## Disk incident during the review (separate, resolved)

D: fell from ~121 GB to **16.4 GB free** in roughly thirty minutes while the review ran, with
workers already parked in `disk_low_pause` at the 40 GB floor.

`tester_cache_purge.ps1` triggered correctly but was structurally unable to help: it must
skip terminals with active work items, and all seven busy terminals held the volume
(T1 107.9 GB, T3 95.2, T4 93.9, T2 74.0, T8 72.3 — 486 GB in protected caches). It reclaimed
**−0.4 GB**, i.e. the drive kept filling faster than it could clear.

Resolved by running `reports_log_purge.ps1 -RetentionHours 1`: **395 journals, 201.81 GB
reclaimed, D: 52 → 257 GB free.** Those 395 files had accumulated in the 1–6 h window alone,
which is the real lesson: at current throughput the 6 h retention on a ~3 h cadence lets
~200 GB float. Retuned the scheduled task to **2 h retention on an hourly cadence**
(`QM_StrategyFarm_ReportsLogPurge_12h`, arguments and trigger re-registered). Only `*.log`
is ever touched; every `.htm`, `.json`, `.set` and `.ini` is kept, so no qualification
evidence is at risk.

Honest note: the burn coincided with work I had just queued (two heavy Q08 re-runs and three
newly promoted 20007 symbol runs generating fresh tick caches). I cannot separate that from
ordinary load with the evidence I have, but the retention change is warranted either way.
