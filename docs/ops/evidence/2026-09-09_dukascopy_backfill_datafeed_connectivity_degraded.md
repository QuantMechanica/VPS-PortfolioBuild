# Dukascopy backfill — datafeed connectivity measured degraded, production download stopped

Date: 2026-09-09 (01:27-01:32Z)

Router task: `3032534e-eaf0-5b68-b09f-2127ebb315b0` (OWNER-DEC-DUKASCOPY-BACKFILL-20260829 = YES)

Disposition: **STOPPED — measured, not a design defect. Left IN_PROGRESS for a follow-up decision.**

## What happened

The governed T1 tick-tail probe (router task `a7e1333c-9b06-45de-a6be-f14477b5f78b`,
work item `e29eab1c-044b-48ea-99ec-6eecd3aa3ea2`) completed at
`2026-09-09T01:11:08Z` with `verdict=REVIEW_REQUIRED` (expected — diagnostic,
`no_gate_verdict=true`). It produced the 37-symbol splice CSV at
`D:\QM\reports\dukascopy\splice\20260909_010553\tick_tail.csv` (SHA-256 receipt
`D:\QM\reports\dukascopy\splice\20260909_010553\probe_receipt.json`), custom-history
archive re-verified `PASS_ISOLATED` before and after
(`fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`, 3,946 files,
years 2017-2025, unchanged). Last authentic ticks cluster around 2026-04-05 to
2026-04-24 depending on symbol.

Per the CEO runbook in `docs/ops/evidence/2026-09-07_dukascopy_p1_p3_build/README.md`,
I independently re-resolved the datafeed hostname before running anything
(`Resolve-DnsName` and Python's own `socket.getaddrinfo` both returned
`194.8.15.180` fresh, matching the 2026-09-07 dry-run address — no override
needed, canonical hostname kept for TLS/SNI/Host header). I then started the
detached downloader for the full 37-symbol splice CSV exactly per the runbook:

```
python tools/dukascopy/download_bi5.py --out D:\QM\reports\dukascopy\backfill\20260909T032705Z \
  --splice-csv D:\QM\reports\dukascopy\splice\20260909_010553\tick_tail.csv --rate 5 --timeout 30 --retries 3
```

PID 10516, working directory `C:\QM\repo`, hidden window, stdout/stderr
redirected under the output root. Planned volume: 304,621 hourly URLs across the
37 symbols.

## Measurement

Over the first 4m51s of real execution (`01:27:06Z`-`01:31:57Z`), the run
completed only 6/304,621 hours (3 downloaded, 3 exhausted all 3 retries and
were recorded as errors; 0 legitimate `no_data`). Error signatures from
`download.log`, all TCP/TLS-level, none application-level (HTTP 4xx/5xx):

| Error | Count |
|---|---:|
| `WinError 10060` (connect timeout) | 4 |
| `WinError 10054` (connection forcibly closed) | 4 |
| `_ssl.c:989` handshake timeout | 2 |

Manual verification outside the tool confirmed the same pattern is
network-path-level, not a bug in `download_bi5.py`:

- Raw TCP connect to `194.8.15.180:443` alternated between instant success and
  8-10s timeouts across repeated attempts in the same minute.
- General internet egress from this host is unaffected: `www.google.com:443`
  and `1.1.1.1:443` connected instantly every time; `194.8.15.180:80` (plain
  HTTP, not used by the tool) also connected instantly every time. Only HTTPS
  to this specific Dukascopy edge IP is degraded.
- A manual `urllib` GET of one `.bi5` URL failed on attempt 1 (15s timeout) and
  succeeded on attempt 2 taking ~15s round-trip (normal successful requests
  elsewhere are sub-second).
- `Get-NetFirewallRule -Direction Outbound -Action Block` shows only the
  pre-existing `codex_sandbox_offline_*` and per-terminal `QM_DXZ_Truth_*_BlockInternet_*`
  rules (scoped to sandboxed/terminal processes) — nothing blocks `python.exe`
  outbound; this is not a local firewall regression.

Extrapolated at the measured completion rate (~1 hour-file per 47.5s net,
including retries and errors), the full 304,621-URL backfill would take
**roughly 167 days**, not the 3-5 days assumed in
`docs/ops/DUKASCOPY_BACKFILL_PLAN_2026-08-29.md`. I stopped the process
(`Stop-Process -Id 10516 -Force`) rather than leave a job running unattended
whose real completion date would silently drift by two orders of magnitude
from the plan. The download is resumable (checksum-authenticated manifest) —
re-running the identical command against the same output root
(`D:\QM\reports\dukascopy\backfill\20260909T032705Z`) continues from where it
left off; no data was lost by stopping it.

## Not done

- No production download completed (6/304,621 hours only, immediately halted).
- No conversion (`convert_to_import.py`) or reconciliation
  (`reconcile_overlap.py`) run — nothing to convert yet.
- No reviewed non-FX `price_scale`/`point_size` contract for the 9 non-FX
  symbols (GDAXI, SP500, NDX, WS30, UK100, XAUUSD, XAGUSD, XTIUSD, XNGUSD) was
  sourced this cycle; the repo's `framework/registry/dwx_symbol_matrix.csv`
  covers broker-symbol tradability, not Dukascopy tick decimal scale, so it is
  not a substitute source — deferred rather than guessed.
- No T1/T2-T10 import, no Factory_OFF/ON, no T_Live/AutoTrading action.

## Recommendation for the next cycle / OWNER awareness

This is a GRÜN measurement, not a ROT question, so no OWNER decision is
strictly required to keep investigating — but the plan's day-scale estimate is
now known to be wrong for straight-line execution from this VPS, which is
worth surfacing before more slots are spent on it. Options, undecided:

1. **Accept the slow path as a genuinely long-running background service**
   (wrap in a Scheduled Task so it survives reboots, not just a detached
   process) and let it accumulate over weeks — safe (self-throttled,
   read/write confined to `D:\QM\reports\dukascopy\`, resumable) but does not
   meet the "backfill so the tester runs through 2026-07-01" timeline anytime
   soon.
2. **Re-test at a different time of day** before concluding the degradation is
   structural — the 4m51s sample is small; Dukascopy's public feed may be
   congested at this particular UTC hour.
3. **Ask Codex to widen the retry/backoff tuning** (e.g. fewer, longer-spaced
   retries with a longer per-attempt timeout) to reduce wasted attempts without
   changing the 5-10 req/s ceiling — would raise throughput only if the
   failures are timeout-driven rather than a hard per-IP block, which the
   TCP-level evidence above suggests but does not prove for sustained load.
4. **Escalate to OWNER** only if options 2-3 do not change the measured rate —
   this stays GRÜN/GELB territory (infra repair, no verdict/threshold/T_Live
   touch) unless it turns into a spend decision (e.g. a paid alternative data
   vendor).

No Entscheidungsschlange entry added — this is not blocked on OWNER, just
slower than planned. Next cycle should re-test at a different hour before
deciding between options 1-3.

## Re-probe 2026-09-09 ~02:33-02:36Z (orchestration cycle) — TCP-connect probe is a false-positive signal; application-level downloads still fail at the same rate

A raw TCP-connect-only probe (`socket.create_connection`, no TLS, no HTTP) at
02:33:34Z showed **0/8 failures**, all sub-second (0.04-0.05s) — a large
apparent improvement over the ~50% failure rate measured at 01:27Z and
02:04Z. This looked like recovery, so before restarting the full production
job I ran a bounded 90s re-invocation of the actual downloader (resuming the
same interrupted run, same command as the original P1 launch) to check
whether the improvement held at the application level:

```
timeout 90 python tools/dukascopy/download_bi5.py --out D:\QM\reports\dukascopy\backfill\20260909T032705Z \
  --splice-csv D:\QM\reports\dukascopy\splice\20260909_010553\tick_tail.csv --rate 5 --timeout 30 --retries 3
```

Result: **2/2 attempts in the 90s window failed**, both `WinError 10060`
(connect timeout) on the two hours the resumed run reached
(`AUDCAD/2025/09/01/05h` and `06h`), the identical signature as the original
stop. The process was killed by the bounded timeout, not by design (no
retries were exhausted within the window). No new data downloaded.

**Conclusion: the TCP-connect-only probe is not a reliable recovery signal
for this host.** A bare TCP handshake to `194.8.15.180:443` can complete in
under 50ms while the subsequent TLS handshake or HTTP data phase used by the
real downloader still times out — the earlier 4/8-failing probes and this
0/8-succeeding probe most likely both undersample a path that fails
downstream of the initial connect. Future re-tests must use the actual
downloader (or at minimum a full TLS handshake + HTTP request) rather than a
raw connect, or they will report false recovery.

Disposition unchanged: **GRÜN/measurement, no OWNER decision needed, no
production job restarted.** Total factory-adjacent time spent on this
measurement across both re-probes: well under the 1h GRÜN autonomous budget.
Options 1-4 from the prior note stand unchanged; option 2 ("re-test at a
different time of day") is now more clearly not yet satisfied — this and the
prior probe are both within the same ~70-minute window and same failure
class. Next cycle should wait several hours (ideally a different UTC
session/day-part) before the next application-level re-test, and should not
trust a TCP-connect-only check as sufficient on its own.

## Re-probe 2026-09-09 ~02:04Z (orchestration cycle, +~35min) — still degraded, no download restarted

Read-only TCP connect probe only (`socket.create_connection`, no HTTP, no
downloader process launched): 8 attempts to `194.8.15.180:443`, 5s timeout,
0.5s spacing. Result: 4/8 succeeded (0.04s-3.13s — still elevated vs. the
sub-second baseline for unaffected hosts), 4/8 timed out at the full 5s. Same
roughly-50% failure signature as the 01:27-01:32Z measurement, ~35 minutes
later. This is one more data point at nearly the same hour, not the "different
time of day" re-test the prior note called for — not conclusive on its own,
but it does not show recovery either. Disposition unchanged: GRÜN/measurement,
not escalated, no download restarted, no OWNER decision needed yet. A
meaningfully later re-test (several hours out, ideally a different UTC
session) still stands as the next actionable step before choosing between
options 1-3 above.

## Re-probe 2026-09-09 ~06:37-06:38Z (orchestration cycle, +~4h) — failure signature changed from network-level timeout to application-level HTTP 503; first real downloads since the stop

Ran the same bounded application-level re-test as the two prior probes (same
resumed output root `D:\QM\reports\dukascopy\backfill\20260909T032705Z`,
`--rate 5 --timeout 30 --retries 3`, wrapped in a 100s shell timeout). Note: a
single earlier attempt from a concurrent orchestration cycle at 06:20:27Z
(visible in the shared `download.log`) still got `WinError 10060`, consistent
with the prior signature and evidence of the known scheduler pileup rather
than a new measurement of mine.

My own bounded run (06:37:07Z-06:38:34Z, ~52s of active work after resuming 9
already-completed hours) processed 4 new hour-files:

| Hour | Result |
|---|---|
| `09h` | **downloaded**, HTTP 200, 3,375 ticks decoded, sha256 recorded (attempt 1) |
| `10h` | error — `RuntimeError: HTTP 503` on all 3 attempts |
| `11h` | **downloaded**, HTTP 200, 2,697 ticks decoded, sha256 recorded (attempt 3, i.e. succeeded after two prior 503s) |
| `12h` | error — `RuntimeError: HTTP 503` on all 3 attempts |

`progress.json`: `downloaded=2, errors=2` this session (9 resumed from
before, 13 completed total). No `WinError 10060`/`10054`/TLS-handshake
timeouts this run — every failure and every success reached the application
layer (HTTP 200 or HTTP 503), a qualitatively different signature than the
01:27Z-02:36Z probes (which never got a clean HTTP response at all). This
reads as **partial recovery**: the network path/TLS handshake to
`194.8.15.180:443` now completes reliably; the remaining failures are the
server explicitly returning 503 (likely rate-limit/overload on their edge,
not a path-level block), and retries do sometimes succeed (the `11h` file
needed 2 retries).

No production job restarted from this measurement alone — a 52s, 4-file
sample is too small to re-estimate the completion timeline, and the run was
left stopped (bounded timeout expired cleanly, no process killed, confirmed
via `tasklist`/`Get-CimInstance Win32_Process` — no orphaned
`download_bi5.py`). Disposition unchanged: **GRÜN/measurement, no OWNER
decision needed**. Next cycle should run a longer bounded sample (e.g. 5-10
minutes, still well inside the 1h GRÜN autonomous budget) to get a stable
success-rate estimate under the new HTTP-503 regime before deciding whether
to accept the slow path (option 1), tune retry/backoff (option 3), or keep
re-testing.

## Re-probe 2026-09-09 11:49-11:50Z (orchestration cycle, +~5h11m) — regressed back to 0/3, still HTTP 503-dominant

Same bounded command, same output root (`20260909T032705Z`), ~70s active window.
3 hour-files attempted (`10h`, `14h`, `15h`), **0 succeeded**: `10h` and `14h`
each 3/3 `HTTP 503`; `15h` one `TimeoutError` + one `HTTP 503` before the bounded
timeout ended the process. No `WinError 10060/10054` this time — same
application-layer-only signature as the 06:37Z/06:52Z probes, just a worse
success rate (0/3 vs. 2/4). Confirms server-side rate-limit/overload
(HTTP 503), not a path-level block, but no recovery. Process ended cleanly on
the bounded timeout; verified via `wmic process` — no orphaned `download_bi5.py`.
`2f717775` (non-FX price_scale ticket) still `APPROVED`/unassigned since
01:24:20Z (~10h25m unclaimed) — Codex lane still stalled, plausible root cause
unchanged (`repo_dirty_build_guard`, `C:\QM\repo` still dirty with factory-owned
set files + one concurrent actor's in-progress `QM5_41240` edit, not touched).
No production job restarted, no ticket duplicated, no terminal action. Task
`3032534e` stays IN_PROGRESS. Given ~10 near-identical probe entries now on
this file with no qualitative change in disposition, further routine "no
recovery" probes will be logged tersely (one line) rather than in this much
detail unless the signature changes again.

## Re-probe 2026-09-09 12:19-12:25Z (orchestration cycle, +~29min) — brief clean window, then relapse; still no sustained recovery

First bounded window (12:19:15-12:20:05Z, ~50s): 3/3 downloaded, 0 errors, 0
retries — the first fully clean sample since the outage, initially read as a
possible recovery signal. A second, longer bounded window immediately after
(12:20:58-12:24:55Z, ~4min) did not hold: 2 downloaded / 3 errors (HTTP 503
x2, one hour needing all 3 attempts across 503/timeout/WinError 10060). Same
oscillating pattern as prior probes, just with a brief clean pocket — not a
structural change. `completed` 24->29 this cycle (5 more hour-files of
305,028 planned). No production job restarted, `2f717775` still
unclaimed/stalled on `repo_dirty_build_guard`. Task `3032534e` stays
IN_PROGRESS. Next cycle: continue periodic bounded probes; treat any
brief clean window as inconclusive until it holds across a >=4min sample.

## Re-probe 2026-09-09 12:33-12:34Z (orchestration cycle, +~8min) — 3/3 net downloaded, 0 errors

Bounded ~70s window, same command/output root. `completed` 29->32, `downloaded=3,
errors=0` this session (two attempt-1 failures in `download.log`, both
recovered on retry). No production job restarted, no orphaned process
(`wmic` confirmed). `2f717775` still `APPROVED`/unclaimed (~11h9m). Task stays
IN_PROGRESS; QM5_41394 gate for bb814520/dfc60103 also unchanged this cycle
(SP500/XAUUSD/XTIUSD Q02 still pending since 10:52:59Z, USDJPY now Q04
pending, EURUSD dead-ended Q02 PASS/Q04 FAIL).

## Re-probe 2026-09-09 ~13:56-13:58Z (orchestration cycle, +~1h22m) — 6/6 net downloaded, 0 errors; own bounded probe orphaned past its bound, killed

Same command/output root, intended as a ~70s bounded window
(`timeout 70 python tools/dukascopy/download_bi5.py ...`). The shell's
`timeout` did not cleanly terminate the process at 70s — `psutil` showed the
`timeout.exe`/`python.exe` pair still alive at 101s wall-clock age. Killed it
explicitly (`psutil.Process.terminate()` on all three PIDs; confirmed gone via
`pid_exists` re-check) rather than leave it running unattended, per the
"stopped rather than left running" practice established in the initial P0
stop. Net result over the full ~100s it actually ran: `completed` 30->36,
`downloaded=6, errors=0` this session — another fully clean window, similar in
character to the 12:19-12:20Z and 12:33-12:34Z clean bursts. Still an
oscillating pattern (clean windows interleaved with WinError 10060/10054
windows, e.g. the two failures logged at 12:24Z/12:34Z before this probe), not
a sustained recovery. No production job restarted. Lesson for future cycles:
verify the bounded wrapper actually killed the child (`psutil` age check, not
just "the shell command returned") before assuming a probe is bounded —
`timeout <N> cmd | tail` can let the child outlive `<N>` under this tool's
process-group semantics.

Also observed in passing: at the moment this probe was captured, `psutil`
showed a second, independent `timeout.exe`/`python.exe` pair present
alongside the first (both same ~36s-old age at first check), consistent with
this VPS's known concurrent-session pileup (multiple `claude.exe`
orchestration cycles running at once, memory: thundering-herd/duplicate
session race). Could not confirm whether that second pair belonged to a
different concurrent session's own bounded probe or was an artifact of this
tool's own process tree; not asserted as fact, flagged for awareness only. If
real, concurrent duplicate downloaders against the same vendor host at 5 req/s
each would be a plausible *additional* contributor to the observed failure
oscillation beyond pure vendor-side rate-limiting — worth a future cycle
checking `download.log` write-interleaving from two distinct PIDs before
concluding server-side 503 is the sole cause.

Codex ticket `2f717775` (non-FX price_scale) still `APPROVED`/unassigned
(~12h30m unclaimed) — Codex lane still stalled, unrelated to this measurement.
Task `3032534e` stays `IN_PROGRESS`. QM5_41394 gate for bb814520 unchanged
this cycle (SP500/XAUUSD/XTIUSD Q02 still pending since 10:52:59Z; USDJPY now
Q03 pending after its Q02 PASS at 12:17:13Z).

## Checked 2026-09-09T16:18Z (orchestration cycle) -- no downloader process running, confirms clean stop after 13:58Z window

`Get-CimInstance Win32_Process` shows no `download_bi5.py` process (only unrelated
python.exe: dev http.servers, a Q08 aggregate/neighborhood run, farmctl
health/pump) -- the 13:56-13:58Z bounded window ended cleanly as logged, nothing
orphaned since. `download_manifest.jsonl` last entry `recorded_at_utc=13:59:10Z`,
matches. No new probe run this cycle (weekly quota critical per bb814520/16:06Z
note; skipping non-essential re-probes). Task stays `IN_PROGRESS`, disposition
unchanged (GRÜN/measurement, no OWNER decision needed).

## Checked 2026-09-09T16:33Z (orchestration cycle) -- no change

No `download_bi5.py` process running (confirmed via `Get-CimInstance Win32_Process`,
no matches). No new probe run this cycle — weekly quota still critical (~85%),
same reasoning as the 16:18Z check: a bounded re-probe is non-essential spend
given the already-documented oscillating HTTP 503 pattern. Task stays `IN_PROGRESS`,
disposition unchanged.

## Checked 2026-09-09T1818Z (orchestration cycle) -- no change

No `download_bi5.py` process running (confirmed via `Get-CimInstance Win32_Process`
filter on the exact command line, no matches). No new application-level re-probe
this cycle -- weekly quota still critical (~85-87%, resets 2026-09-10T22Z), same
non-essential-spend reasoning as the 16:18Z/16:33Z checks. Concurrent-session note:
`bb814520`/`dfc60103`'s shared blocking gate (QM5_41394 SP500/XAUUSD/XTIUSD Q02) was
independently re-checked and logged by a concurrent orchestration session in their
own evidence files at this same timestamp (identical farm_health snapshot: 13
fail/17 warn/52 ok, same chronic FAIL set -- `codex_zero_activity`,
`q02_stranded_exhausted_pairs`, `phase_invalid_rate_7d`, `agent_task_state_stranded`/
`_aging_slo`, `work_item_phase_age_slo`, `pending_tail_age`,
`q09_sealed_plan_hold_age`/`_autoseal_hold_census`, `pending_artifact_binding_drift`,
`schtask:QM_EvidenceCohortWatch_Daily_0420`, `backup_calendar_continuity`,
`task_monitor_escalation`); not re-logged there by this session to avoid duplicate
entries. No ticket, rebuild, release, or verdict change on any of the three tasks.
All three remain `IN_PROGRESS`.
