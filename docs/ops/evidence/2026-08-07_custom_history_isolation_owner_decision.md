# Custom-history isolation migration — OWNER decision package

Date: 2026-08-07 (Europe/Berlin)  
Router task: `fe1d5968-85b5-4499-85ab-1f10b7399c53`  
Parent evidence: `2026-08-06_error32_history_sharing_violation_class.md`  
Status: DESIGN ONLY / OWNER DECISION REQUIRED / NO RUNTIME CHANGE

## Decision requested

Approve an OWNER-quiesced migration to **Variant A**: a physical
`Bases\Custom` directory for every T1-T10 runner, private writable current-year
history and cache state per terminal, and content-verified read-only hardlinks
for archive-year `.hcc` and `.tkc` files. Keep **Variant D**, a single global
Custom-history execution lease, as containment during migration and rollback.

Do not approve full physical copies of the current 43.211 GiB store. Nine
additional copies need about 388.899 GiB and do not fit. Do not prune real-tick
archive data merely to make copies fit: governed runs use MT5 Model 4 and the
Q-only pipeline needs 2017-2025 history.

This document makes no filesystem, scheduler, Defender, terminal, queue, or
AutoTrading change. It does not touch T_Live.

## Measured baseline

Read-only measurement at approximately 00:20 local:

| Item | Files | Bytes | GiB |
|---|---:|---:|---:|
| Whole `D:\QM\mt5\T1\Bases\Custom` | 4,329 | 46,397,736,133 | 43.211 |
| Archive-year `.hcc` + `.tkc` (2017-2025) | 3,946 | 44,231,653,718 | 41.194 |
| Current-year `.hcc` + `.tkc` (2026) | 259 | 1,862,963,397 | 1.735 |
| `.hc`, `.dat`, and other metadata/cache state | 124 | 303,119,396 | 0.282 |
| D: free | n/a | 93,039,255,552 | 86.650 |

The extension split is 36.751 GiB `.tkc`, 6.178 GiB `.hcc`, 0.263 GiB
`.hc`, and 0.019 GiB `.dat`. Current-year tick files are 1.647 GiB; a design
that isolates only current-year `.hcc` would therefore leave the dominant
current-year mutable class shared.

The farm disk-health floor is 25 GiB. Current usable headroom above that floor
is 61.650 GiB. All capacity numbers below use binary GiB and the current free
space, not the earlier 190-220 GB planning estimate.

The existing topology auditor reports the shared T1 target as a
cross-terminal mutable-store collision. Existing `mt5_history_isolation.py`
checks directory identities; Variant A also needs the file-identity and
archive-immutability checks specified below because distinct directories can
still contain hardlinks to the same file record.

## Variant comparison

| Variant | Incremental physical data | Projected D: free | Throughput effect | Principal risk | Decision |
|---|---:|---:|---|---|---|
| A. Private mutable year + immutable archive hardlinks | 18.153 GiB measured floor for T2-T10 | 68.497 GiB | No intended steady-state serialization | MT5 may attempt to rewrite an archive file; gate and staged soak must catch this | **Recommend** |
| B. Per-assignment selective private symbol store | about 11.08 GiB for ten average one-symbol closures; 21.02 GiB for average host + EURUSD; 40.17 GiB for NDX + EURUSD | 75.57 / 65.63 / 46.48 GiB respectively, while retaining the 43.211 GiB source | Copy/provision delay per assignment; basket closures can erase the saving | Hidden conversion/basket dependencies make host-only provisioning unsafe | Later optimization only |
| C. Prune + full physical isolation | safe cache-only prune still requires about 386.36 GiB for nine extra stores | Does not fit by about 299.71 GiB | No serialization after migration | Only an unsafe real-tick/history retention reduction makes it fit | Reject under current contracts |
| D. One global Custom-history lease | negligible | unchanged | Ten-slot theoretical service capacity falls 90%; measured mixed-workload estimate falls about 83% | Backlog growth and stale-lease failure modes | Interim containment / rollback mode |

### Variant A — capacity-feasible physical working trees

Each terminal gets a real, non-reparse `Bases\Custom` directory. Every
current-year `.hcc` and `.tkc`, plus `.hc`, `.dat`, and any file without a
provably immutable archive-year classification, is a private file record.
Files for years before the current calendar year may be hardlinked from a
versioned immutable archive manifest because ten links are well below NTFS's
per-file hardlink limit and consume no duplicate payload blocks.

The measured incremental floor is:

`9 * (1.735 GiB current year + 0.282 GiB metadata/cache) = 18.153 GiB`.

That leaves 68.497 GiB free, or 43.497 GiB above the 25 GiB health floor. A
20% contingency on the duplicated mutable slice still leaves about 64.866 GiB
free. Linear extrapolation of the 2026 current-year payload from early August
to year-end adds roughly 1.2 GiB per terminal; even an approximately 12 GiB
fleet-wide growth allowance leaves more than 56 GiB free. At year rollover,
2026 files must not remain as ten writable archive copies indefinitely: after
an OWNER-quiesced hash comparison, deduplicate identical closed-year files
into the immutable archive and start new private 2027 files.

Hardlink safety is conditional, not assumed. Archive files must be bound to a
manifest containing relative path, size, SHA-256, year, file ID, and link
count. The archive ACL must deny writes to the runner service identity; each
terminal view must resolve to the manifest file ID; and any attempted archive
write is a fail-closed migration finding. If MT5 legitimately needs to mutate
one historical file, break that terminal's link by copying it to a new private
file during a quiesced maintenance step. Never make the shared inode writable.

### Variant B — selective provisioning by dependency closure

The average complete symbol footprint is 43.211/39 = 1.108 GiB. EURUSD is
1.019 GiB, NDX is 2.998 GiB, and NDX + EURUSD is 4.017 GiB. Keeping the
43.211 GiB archive source and provisioning ten private workers therefore needs
approximately:

- 11.08 GiB for ten average one-symbol closures;
- 21.02 GiB for ten average host-plus-EURUSD closures; or
- 40.17 GiB for ten NDX-plus-EURUSD closures.

At an explicitly assumed sustained copy rate of 100-250 MiB/s, not yet
benchmarked on this host, an average symbol is about 4.5-11.3 seconds,
host-plus-EURUSD about 8.6-21.5 seconds, NDX-plus-EURUSD about 16.5-41.1
seconds, and the whole store about 3.0-7.4 minutes. The 24-hour completed-run
median was 6.47 minutes, so full-store per-assignment staging can equal a large
fraction of execution time.

Provisioning must use a declared dependency closure, never only the work-item
host symbol. The closure includes the host, deposit-currency conversions,
card/build-declared basket symbols, and every statically or dynamically
selected symbol. Unknown/dynamic closure fails closed or routes to a fully
provisioned Variant-A slot. QM5_9107 demonstrates why: a GBPCAD-hosted basket
held EURUSD history and also included NDX. Selective provisioning is therefore
an optimization after dependency manifests are complete, not the first
remediation.

### Variant C — prune and copy the whole store

Deleting only `.hc`/`.dat` cache-like state would save at most 0.282 GiB per
store and leaves about 42.929 GiB to copy. Nine additional stores then require
about 386.36 GiB, far beyond the 86.650 GiB free.

Deleting archive `.tkc` data would reduce a store to roughly 8.1 GiB and make
ten copies look arithmetically possible, but it violates the evidence
contract: `run_smoke.ps1` accepts only Model 4 and authenticates the real-ticks
marker; Q02 uses 2017-2022 and later gates use 2023-2025. No retention or model
change is authorized by this infrastructure repair. Compression or moving an
archive to another volume may be evaluated separately, with measured latency
and pipeline equivalence, but is not a prerequisite for Variant A.

### Variant D — global containment lease

The lease key covers the entire Custom-history class, not a host symbol, and
is held from before terminal spawn/history preflight until the terminal has
exited and artifacts are sealed. Conversion and basket dependencies make a
per-symbol lease insufficient.

Serialization changes the theoretical concurrency ceiling from ten to one,
a 90% service-capacity reduction. A read-only 24-hour database sample found
533 completed governed items with 15.87 minutes mean service time and 6.47
minutes median. At the observed mix, one serialized server can complete about
90.7 items/day using the mean, versus 533 observed completions/day: an
approximately 83% reduction. The median-implied upper bound is about 222/day,
but is not the capacity planning value because long runs consume service time.
For Q02 non-infrastructure completions alone, 278 items averaged 9.56 minutes,
so a serialized server is about 151/day before queue and staging overhead.

The lease needs a heartbeat and process-identity binding. Expiry alone never
authorizes killing a terminal. Recovery may release a stale lease only after
the recorded PID/creation identity is absent, the terminal is inactive, and
the worker claim is reconciled. This is safe containment but too expensive as
the steady state.

## Startup fail-closed gate

Before a runner worker can claim or spawn any governed MT5 job:

1. Run `tools/strategy_farm/mt5_history_isolation.py` for every eligible
   runner terminal and the protected T_Live/T5 roots. Require
   `PASS_ISOLATED`; a missing directory, reparse alias, ancestor overlap, or
   protected-root overlap blocks dispatch.
2. Extend the audit to enumerate file IDs for current-year `.hcc`/`.tkc`,
   `.hc`, `.dat`, and unclassified files. No such file ID may appear in more
   than one terminal tree.
3. Permit a cross-terminal file ID only when its path/year exists in the
   signed archive manifest, all terminal SHA-256 values equal the manifest,
   and the effective ACL is read-only for every runner identity.
4. Record the audit JSON and SHA-256 in the worker-start evidence. Re-run a
   scoped gate immediately before each dispatch; topology or manifest drift
   fails closed before terminal spawn.
5. Keep the global lease engaged until the new gate, migration verification,
   and staged soak have all passed review.

The gate belongs in the governed worker startup/claim boundary. It must not
start `terminal64.exe`, toggle AutoTrading, repair a path automatically, or
silently downgrade a finding to a warning.

## OWNER-quiesced migration runbook

### Preconditions

1. OWNER signs the exact window, variant, terminal list, archive manifest, and
   rollback authorization. T_Live is explicitly out of scope.
2. Stop new claims through the normal factory control, then allow active
   T1-T10 work to finish. Do not interrupt a backtest. Verify zero active
   work-items and no runner `terminal64.exe`/`metatester64.exe` process.
3. Enable and verify the global Custom-history lease before changing topology.
4. Capture: junction targets, ACLs, volume/file IDs, file counts, sizes, and
   SHA-256 manifest of the existing T1 store. Take a recoverable backup of
   topology metadata and the farm database. Require at least the calculated
   migration headroom plus the 25 GiB floor.

### Build and cutover

5. Build versioned physical staging directories beside, not inside, each
   live `Bases\Custom` path. Populate private current-year and unclassified
   files by copy; populate archive years only from the immutable manifest.
6. Verify every staged file's size/SHA-256, private versus shared file-ID
   rules, ACL, year classification, and that every top-level Custom directory
   is physical rather than a junction.
7. With runners still quiesced, rename the old topology to a timestamped
   rollback name and atomically place the staged physical directories at the
   expected paths. Do not delete the rollback tree in this window.
8. Run the enhanced isolation audit twice from independent fresh processes.
   Both JSON artifacts must be identical in substance and `PASS_ISOLATED`.

### Controlled restart and soak

9. Resume only through the governed scheduler: first one slot, then two, then
   five, then ten. Never start a terminal manually. At each step run one
   representative real-tick Q02 smoke including EURUSD, NDX, a non-USD host
   needing conversion, and a declared basket dependency closure.
10. Abort ramp-up on any error `[32]`, history synchronization error, archive
    write attempt, history hash drift, missing real-ticks marker, or isolation
    gate failure. Preserve artifacts; do not reinterpret an infrastructure
    failure as a strategy verdict.
11. Acceptance soak: at least 24 continuous hours and at least 500 governed
    MT5 runs, with at least 80% aggregate runner occupancy for a sustained
    four-hour interval. Require zero history error `[32]`, zero history
    synchronization aborts, zero cross-terminal mutable file IDs, stable
    archive hashes, and no increase in history-related infrastructure-failure
    rate. Evidence must be independently reviewed before removing containment.

### Rollback

12. On a cutover or soak stop condition, close new claims and let active tests
    finish; never terminate an unrelated run. With all affected runners
    quiesced, move the new directories to a retained failure-analysis path and
    restore the timestamped original T1 directory and T2-T10 junction map.
13. Re-run manifest/topology checks. Because the restored topology is known
    shared and unsafe at concurrency, leave the global Custom-history lease
    enabled before any work resumes. Resume at serialized capacity only after
    the rollback evidence is reviewed.
14. Retain both migration and rollback manifests until the soak and review are
    closed. Delete neither copy as part of the migration task.

## Acceptance and non-claims

This package is ready for an OWNER choice; it is not deployment approval.
Operational remediation still requires the parent incident's five close-out
criteria: isolated topology, high-concurrency error-32-free soak,
multi-attempt sidecar authentication, pre-dispatch EX5 verification, and
independent evidence review. No Q-phase verdict or live-use verdict follows
from this design.
