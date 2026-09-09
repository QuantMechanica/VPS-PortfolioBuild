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
