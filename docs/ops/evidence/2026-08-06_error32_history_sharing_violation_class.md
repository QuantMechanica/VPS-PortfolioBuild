# Error [32] history sharing-violation class — mechanism identification 2026-08-06

Author: Claude (evening triage, 23:00–23:40 local)
Status: MECHANISM IDENTIFIED, root-cause attribution OPEN → Codex forensics ticket

## Trigger

Q09_NEWS gen-3 rerun `ad3d6327-044c-5685-ada7-ee71ea30cb3e` (QM5_11421/EURUSD,
transient-victim rerun of `13860911`) adjudicated INVALID_EVIDENCE
(`cell_receipt_invalid`, 39/40 cells never ran). Cell
`control_off__m0__c0__s42` accumulated SIX failure artifacts
(`cell_failure.json` … `cell_failure_6.json`, 11:22 → 23:16 local), every
attempt: "Q09 selection run_smoke exited with code 1 without a fresh run_smoke
summary or cell receipt". Predecessor gen-2 died the identical way
(`enqueue_receipt.json` → `transient_predecessor_failures`). Two generations ×
6+ attempts × 12 h = NOT self-healing for this cell.

## Mechanism (evidence)

`run_smoke.log` (23:16 attempt, T3): terminal spawns (PID 17212), exits with
EMPTY exit code, `valid_report_latched=False`, zero logger files →
run_smoke.ps1:2574 throws "Required fresh structured logger sample was not
authenticated".

T3 terminal journal `D:\QM\mt5\T3\logs\20260806.log` at the same second:

```
23:16:31-33  History  'EURUSD.DWX' file opening or reading error [32]   (x10)
23:16:34     Tester   last test passed with result "some error after pass finished" in 0:00:00.000
23:16:35     Terminal exit with code 0
```

Error [32] = ERROR_SHARING_VIOLATION on the terminal's history base. The NEXT
test on T3 (QM5_1536/USDJPY work item `caeae308`, 23:17) died the same way —
EURUSD.DWX sync error at 23:19:38 (needed as conversion rate), "some error
after pass finished", instant INFRA_FAIL.

## Blast radius (today, per-terminal journal grep "error [32]")

| Terminal | hits | first | last | dominant symbols |
|---|---:|---|---|---|
| T1 | 504 | 02:26 | 22:11 | EURUSD 291, NDX 72, USDCAD 48, USDJPY 47 |
| T2 | 36 | 12:25 | 20:41 | AUDUSD 18, USDCAD 9, AUDCAD 9 |
| T3 | 366 | 01:52 | 23:19 | EURUSD 297, NDX 41, GBPUSD 28 |
| T4 | 661 | 02:44 | 23:14 | EURUSD 607 |
| T5 | 24 | 07:52 | 07:53 | EURUSD 24 |
| T6 | 618 | 04:43 | 22:55 | EURUSD 351, NDX 201 |
| T7 | 971 | 02:30 | 23:14 | EURUSD 849 |
| T8 | 119 | 02:35 | 23:02 | USDCAD 42, EURUSD 35 |
| T9 | 1139 | 00:03 | 21:13 | EURUSD 745, NDX 306 |
| T10 | 1219 | 00:01 | 23:16 | EURUSD 1020, NDX 104 |

Historic counts (T3/T7/T9/T10): 08-03: 321/381/519/354 · 08-04: 150/36/18/0 ·
08-05: 274/606/649/543. → CHRONIC class, present for days, NOT caused by the
08-06 03:52 host crash (first hits today precede it). Fatal rate scales with
load: 08-04 (low counts) was a low-pressure day; today's 100% CPU produced the
INFRA_FAIL storm (53 Q02 INFRA_FAILs in 6h; 11353 full fan-out 2 waves, 9107
family, 1536, 11311, 9575, 9940, 10369, 10574).

Most error-32 incidents are non-fatal (terminal retries; 46 Q02 PASS in the
same 6h window). Fatal outcome = collision lands during tester agent history
handoff → "history synchronization error" → instant test abort.

## Secondary finding: adjudicator receipt mismatch

Aggregate `details.invalid_cells[0]`: "cell failure artifact SHA-256 mismatch:
expected ff58bae6…, got 299acbca…" — neither hash matches any of the six
on-disk `cell_failure*.json` raw hashes (5c4a57e1/239b7833/5789d816/73cf6ef8/
f89914fd/005019ed). The numbered-retry failure artifacts (sidecar-retry fix
d22dfee9e) and the receipt/adjudicator disagree about which artifact is
authoritative. Needs a look — fail-closed direction is correct, but the
mismatch obscures the true error class in aggregates.

## Tertiary finding: stale stage on T2

`D:\QM\mt5\T2\...\QM5_11421_ohlc-daily-squeeze-reversal-d1.ex5` = 0f7c8ff9…
(360,466 B) vs required 9dd7facd… (367,114 B, verified correct on T1/T3/T4/T5).
Worker-staged deploys skip re-copy (`deploy_skip=worker_staged`); a T2 attempt
would fail EX5 verification or run a stale binary if verification is bypassed.

## Open questions for Codex forensics (root-cause attribution)

1. WHO holds the no-sharing handle on per-terminal history bases? Candidates:
   the terminal's own paired process during agent handoff (MT5-internal race),
   `tester_cache_purge.ps1` (20-min cadence) touching bases mid-test, Windows
   Defender real-time scan on freshly-written base files, worker history
   import/staging path. Per-terminal bases make cross-terminal contention
   implausible — verify.
2. Why do EURUSD.DWX/NDX.DWX dominate ~10:1? (Busiest symbols/biggest bases,
   or a specific shared source artifact?)
3. Mitigation design: history-sync retry-with-backoff in run_smoke/worker
   before declaring the run dead; Defender exclusion audit for
   `D:\QM\mt5\*\bases`; purge-vs-active-test interlock audit.
4. Adjudicator vs numbered failure artifacts (secondary finding above).
5. T2 stale-stage sweep: verify staged EX5 hashes across T1–T10 for active
   pipeline EAs; restage divergents.

## Operational decisions taken (Claude, tonight)

- NO third blind gen-rerun of 11421 tonight: at the CPU ceiling the fatal
  probability for exactly this cell profile is proven ~1.0. Gen-4 rerun goes
  into the 05:07 low-load window (same recipe, alongside 11422 round 11) —
  low-load is precisely the medicine for a collision-probability mechanism.
- Tonight's INFRA_FAIL stragglers stay deferred to the dawn window (unchanged).
- No config or process changes at peak; no terminal restarts (would kill
  active sealed-matrix cells).
