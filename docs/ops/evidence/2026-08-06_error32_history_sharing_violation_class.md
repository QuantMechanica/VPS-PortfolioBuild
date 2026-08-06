# Error [32] history sharing-violation class — mechanism identification 2026-08-06

Author: Claude (evening triage, 23:00–23:40 local)
Status: ROOT CAUSE CONFIRMED, mitigation design recorded, no runtime change

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

## Codex forensics resolution (2026-08-06 23:41–23:59 local)

Verdict: **ROOT_CAUSE_CONFIRMED / MITIGATION_DESIGN_READY / NO_RUNTIME_ACTION**.
The primary mechanism is cross-terminal contention on one shared, mutable
Custom history store. T2–T10 do not have independent Custom bases: their
Bases\Custom entries are NTFS junctions to T1. During a live sample, T8's
terminal64.exe held the canonical EURUSD current-year history file with
incompatible sharing while T6 logged error 32 against that same shared store.

This establishes the causal class, but does not claim that PID 7336 caused
every historical occurrence. Other MT5 terminal processes can take the same
role at other times. The durable defect is the shared mutable topology.

### 1. Filesystem topology disproves the per-terminal premise

Read-only LinkType/Target inspection found:

| Logical path | Filesystem object | Resolved target |
|---|---|---|
| D:\QM\mt5\T1\Bases\Custom | physical directory | D:\QM\mt5\T1\Bases\Custom |
| D:\QM\mt5\T2\Bases\Custom through T10\Bases\Custom | NTFS junctions | D:\QM\mt5\T1\Bases\Custom |

The repository's read-only topology auditor independently rejected the
configuration:

    python tools/strategy_farm/mt5_history_isolation.py --mt5-root D:\QM\mt5 --terminal T1 --terminal T2 --terminal T3 --terminal T4 --terminal T5 --terminal T6 --terminal T7 --terminal T8 --terminal T9 --terminal T10

Relevant result:

- status: FAIL_CLOSED
- code: CROSS_TERMINAL_MUTABLE_STORE_COLLISION
- component: bases/custom
- resolved identity: d:\qm\mt5\t1\bases\custom
- terminals: T1–T10
- audit SHA-256:
  0f811d1c71d8d0ffbd856034464d1fa6b7491c75ff10c27b9463948b00157013

This is the residual exception from the July Bases de-junctioning work:
Darwinex-Live was isolated, while Custom was retained as a presumed read-only
shared tree. Current-year .hcc history is not operationally read-only; MT5
takes exclusive or otherwise incompatible handles during synchronization and
tester handoff. The earlier statement above that per-terminal bases make
cross-terminal contention implausible is therefore corrected.

### 2. Direct handle-owner attribution

All times below are Europe/Berlin local on 2026-08-06.

1. At 23:46:59, a read-only Windows Restart Manager query for shared Custom
   history resources identified PID 7336, process terminal64.exe, executable
   D:\QM\mt5\T8\terminal64.exe, as using
   D:\QM\mt5\T1\Bases\Custom\history\EURUSD.DWX\2026.hcc.
2. At 23:49:21, a read-open probe requesting the maximum normal sharing flags
   (read, write, and delete sharing) still failed on EURUSD's and NDX's 2026
   .hcc files with the Windows sharing-violation class. Their M1 cache-file
   probes were openable at that instant.
3. From 23:50:12.970 through 23:50:42.025, 100 consecutive EURUSD .hcc probes
   failed: 100/100, HRESULT 0x80070020. Restart Manager named the same T8 PID
   on every sample. NDX was not caught in an exclusive-handle window during
   this 30-second sample.
4. Inside that exact window, the independent T6 journal
   D:\QM\mt5\T6\logs\20260806.log recorded three
   "'EURUSD.DWX' file opening or reading error [32]" events at 23:50:21.754.

Restart Manager identifies a process using a resource; the failed
maximum-sharing open establishes that an incompatible handle existed. Together
with T6's simultaneous error, this is direct cross-terminal attribution:
T8's MT5 process held the physical T1 Custom history file while T6 accessed it
through its junction.

Candidate adjudication:

| Candidate | Determination | Evidence |
|---|---|---|
| MT5 terminal on another runner slot | **Confirmed primary class** | Shared resolved path plus T8 owner and simultaneous T6 victim |
| Same terminal's own tester handoff | Possible contributor to individual incidents | Not needed to explain the observed cross-terminal collision |
| tester_cache_purge.ps1 | Ruled out as direct holder/deleter for this path | It deletes only T*\Tester\bases\* and T*\Tester\Agent-*; it does not touch T*\Bases\Custom |
| Microsoft Defender | Ruled out as primary cause in this observation | D:\QM\mt5 is excluded, as are terminal64.exe and metatester64.exe; real-time monitoring remains enabled globally |
| Worker history import/staging | No direct ownership evidence | No worker process owned the sampled .hcc handle |

The purge task actually runs every 10 minutes, not the 20 minutes in the open
question. Its active-terminal protection was observed working, and its log
showed protected slots being skipped. Low-disk purge/relaunch churn can increase
the number of overlapping terminals indirectly, but it is not the file owner
or direct path mutator in this incident.

### 3. EURUSD/NDX concentration

A second journal snapshot at 23:47:59 counted 6,000 error-32 lines for
2026-08-06:

| Symbol class | Hits | Share |
|---|---:|---:|
| EURUSD.DWX | 4,543 | 75.72% |
| NDX.DWX | 801 | 13.35% |
| All other symbols | 656 | 10.93% |

EURUSD:NDX is 5.67:1, not literally 10:1. EURUSD plus NDX versus all other
symbols is 8.15:1, which explains the approximate “10:1 dominance” shorthand.
Together they account for 89.07% of the observations.

EURUSD is both a direct basket member and the dominant deposit-currency
conversion dependency for non-USD instruments. NDX is a frequent index/Q09
target and also appears in multi-symbol basket engines. The live owner sample
supports this explanation: T8 was assigned QM5_9107 on GBPCAD.DWX, but that
EA's full-basket source includes EURUSD and NDX, and the T8 process held
EURUSD's .hcc. Thus the journal symbol is often an implicit dependency rather
than the work item's host symbol. MT5 retry bursts also mean line counts are
not one-to-one workload counts.

### 4. Mitigation design (proposal only)

No runtime, filesystem, scheduler, Defender, terminal, or task configuration
was changed during this investigation.

#### Required structural correction

The durable fix is to stop sharing writable Bases\Custom state across runner
terminals. Preferred end state:

1. Give every T1–T10 runner its own physical Bases\Custom working tree.
2. Provision immutable historical inputs into each tree before the terminal is
   eligible, then let only that terminal mutate its current-year history/cache.
3. Run mt5_history_isolation.py as a deployment/startup fail-closed gate and
   require zero CROSS_TERMINAL_MUTABLE_STORE_COLLISION findings.
4. Capacity-plan and perform the migration only in an OWNER-approved quiesced
   window. Do not relink or copy while any affected terminal/test is active.

A shared archive may remain a provisioning source, but must not be mounted as
the mutable MT5 working path. If physical isolation cannot be deployed
immediately, the safe temporary containment is a single global
custom-history-run lease held from before terminal spawn through terminal exit.
That deliberately serializes Custom-history consumers; a per-host-symbol lease
is insufficient because conversion and basket dependencies are implicit.

#### Bounded retry/backoff

Add a narrow infrastructure retry policy only after the topology is isolated,
or behind the global containment lease:

- Match the exact class: no authenticated report/receipt, terminal journal
  contains error [32] or history synchronization error, and the run ended
  before strategy execution.
- Preserve each attempt's journal/log/manifest under an immutable attempt path.
- Release the slot, then use bounded delays of 2, 5, 10, 20, and 40 seconds
  with ±20% jitter; cap at five retries.
- Reacquire the history lease and re-run preflight before the next attempt.
- After the cap, emit INFRA_FAIL/HISTORY_SHARING_VIOLATION with owner/topology
  diagnostics. Never reinterpret it as a strategy verdict.
- Never retry after an authenticated test report exists, and never use this
  policy for INIT failures, ordinary EA errors, or strategy/pipeline failures.
- Never terminate or restart an unrelated active T1–T10 process to obtain the
  lease.

Backoff alone is not a durable fix for a permanently shared mutable tree; under
load it merely changes collision probability.

#### Defender and purge controls

- Defender audit: PASS for the relevant scope. D:\QM\mt5 is already in
  ExclusionPath and terminal64.exe/metatester64.exe are in ExclusionProcess.
  Do not broaden exclusions. Periodically verify effective policy and Defender
  operational events instead.
- Purge audit: direct scope is correct and active slots are protected. Add an
  explicit invariant that the purge may never traverse top-level
  T*\Bases\Custom, log protected/cleared terminal counts, and coordinate the
  maintenance cycle with the same terminal-activity/maintenance lease. If all
  or most slots are protected, record a deferred purge instead of adding
  startup churn.

### 5. Failure-sidecar/adjudicator reconciliation

The aggregate's expected ff58bae6… and observed 299acbca… are not hashes of
the six cell_failure*.json sidecars. They are hashes of the same mutable
runs\selection\run_smoke.log at different times:

- cell_failure.json embeds run_smoke.log SHA-256 ff58bae6… from attempt 1.
- cell_failure_6.json embeds run_smoke.log SHA-256 299acbca… from attempt 6.
- the current run_smoke.log is 299acbca….
- execution_failure.json points to cell_failure_6.json, whose raw SHA-256 is
  005019ed9b….
- raw sidecar SHA-256 prefixes, in occurrence order, are
  5c4a57e1, 239b7833, 5789d816, 73cf6ef8, f89914fd, and 005019ed.

The writer correctly preserves the first sidecar and emits numbered immutable
siblings for later failures. However, every sidecar authenticates the same
mutable run_smoke.log path, which each retry overwrites. The collector then
hard-codes authentication of the first cell_failure.json rather than following
execution_failure.json to the terminal occurrence. Attempt 6 therefore
invalidates attempt 1 by construction.

The existing INVALID_EVIDENCE outcome is fail-closed and correct under the
current authentication contract. The reason cell_receipt_invalid is
misleading: there is no cell receipt to invalidate; the failure manifest's
referenced log changed.

Proposed correction:

1. Snapshot every attempt's run_smoke log and related artifacts into a unique
   attempt-numbered or content-addressed path before writing its sidecar.
2. Make execution_failure.json the authoritative pointer to the terminal
   failure occurrence; authenticate that sidecar and its immutable artifacts.
3. Optionally authenticate the full numbered occurrence chain for chronology,
   without treating a valid later occurrence as a mutation of the first.
4. Emit cell_failure_manifest_invalid for a failure-sidecar mismatch and reserve
   cell_receipt_invalid for an actual receipt.
5. Add a regression fixture with at least two failed attempts and different
   logs; both sidecars and the terminal execution_failure pointer must remain
   authentic after collection.

Artifact locations inspected:

- D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805\refresh_v3\
  ad3d6327-044c-5685-ada7-ee71ea30cb3e\q09_plan\cells\
  control_off__m0__c0__s42
- D:\QM\reports\work_items\ad3d6327-044c-5685-ada7-ee71ea30cb3e\
  QM5_11421\Q09_NEWS\EURUSD_DWX

### 6. EX5 fleet-hash sweep

Snapshot: 2026-08-06 23:58 local. “Expected” is the SHA-256 of the canonical
repository EX5. “Active” comes from farmctl work-items --status active at the
snapshot. No EX5 was copied, deleted, or restaged.

| EA | Active terminal | Expected SHA-256 | Active result | Fleet result |
|---|---|---|---|---|
| QM5_11165 | T2 | b109a902f98f305b7436b9ec1c02105a57b497c67db297ffb6232372f5088281 | MATCH | Match T1/T2/T3/T4/T8/T10; divergent T5/T6/T7/T9 |
| QM5_12567 | T5 | 8d901924fe7dd2cd00c61dac6db78871fdfe34f73e0f003393196992d5143e04 | MATCH | Match T1/T2/T3/T4/T5/T7/T8; divergent T6/T9/T10 |
| QM5_20243 | T1 | abbf719e3b7bf4ac2ad56745c4d8987e4d7d02a38a9626649b0c25459e830567 | MATCH | T1 match; T2–T10 missing |
| QM5_9107 | T8 | b9821cc0d55cec82828c741d840d7013976cf743aa44280fa799de498d3e7721 | MATCH | T1–T10 all match |
| QM5_11421 | none | 9dd7facd1da7e2c6564929b92a2e4a62e65bc40b99a03edd729030f72d18924b | n/a | Match T1/T3/T4/T5/T6/T10; divergent T2/T7/T8/T9 |

QM5_11421 divergence details:

| Terminal | Observed SHA-256 |
|---|---|
| T2 | 0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7 |
| T7 | 0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7 |
| T8 | 03455d533ffbf1cc35482dc8de487b04d997bea328ee8505d0f5bb0d591a7415 |
| T9 | 2f7dcb1d51180ccb877631bd513eae6688309207d2e63e950e8066b596ee62b7 |

Every terminal claimed by an active work item had the canonical hash at this
snapshot. Dormant divergent/missing copies are staging hygiene findings, not
pipeline verdicts. Before any future dispatch, deployment must copy and verify
the exact required EX5 or fail closed; worker_staged/deploy-skip must never
bypass hash verification. QM5_11421 must not be routed to T2, T7, T8, or T9
until that normal controlled staging check succeeds. This investigation did
not restage them.

### Close-out acceptance criteria

The incident class is not considered operationally remediated until:

1. the topology audit passes for T1–T10 with no shared mutable Custom identity;
2. a representative high-concurrency soak has no error-32 history failures;
3. the multi-attempt failure-sidecar regression authenticates every occurrence;
4. the active-terminal EX5 pre-dispatch hash gate passes; and
5. evidence from those checks is reviewed. No pipeline or live-use verdict is
   asserted by this forensics note.
