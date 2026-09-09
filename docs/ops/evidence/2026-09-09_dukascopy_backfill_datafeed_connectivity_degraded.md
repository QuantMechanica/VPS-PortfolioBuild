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
