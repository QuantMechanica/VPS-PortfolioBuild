# Codex adversarial review of commit-reservation decay — 2026-07-26

## Verdict: REJECT

The decay equation is sound **only if** `measured_subtree_private_bytes` belongs to
the reserved work item and is complete. `d2a19449f` does not establish either
condition. It can attach an unrelated process after PID reuse, and it treats a
partially unreadable/missing target lineage as "gone" whenever any other process
was readable in the system snapshot. Both cases silently release reservation.
The 13 tests mostly assert mocked arithmetic and do not exercise these failure
modes.

Reviewed commits: `d2a19449f`, `5f5d294c8`, `3455bcf2b`, and revert
`347859ad3` of `d88a89392`. I also ran the advertised focused suites: **64
passed in 38.70 s**.

## Findings

### F1 — `PrivateUsage` is the right numerator, with an important scope caveat

For ordinary private allocations, yes. Microsoft documents
`PROCESS_MEMORY_COUNTERS_EX.PrivateUsage` as the process's **Commit Charge**,
the total private memory committed for it. That is the correct materialized
quantity to subtract from a forecast of that same process tree's eventual
private-commit peak.

Source:
[PROCESS_MEMORY_COUNTERS_EX](https://learn.microsoft.com/en-us/windows/win32/api/psapi/ns-psapi-process_memory_counters_ex).

The headroom side is less exact than the write-up says. `ullAvailPageFile` is
the maximum the **calling process** can commit and is less than or equal to
system-wide available commit. Microsoft says exact system headroom is
`GetPerformanceInfo().CommitLimit - CommitTotal`. A normal 64-bit worker is
unlikely to have a tighter per-process constraint, so the current value is
usually conservative, but the report should not call the two APIs the "same
quantity."

Source:
[MEMORYSTATUSEX](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/ns-sysinfoapi-memorystatusex).

Shared file-backed pages do not consume private commit and therefore should not
be subtracted. Shared committed sections can consume system commit without
appearing as each process's `PrivateUsage`; that leaves an unnecessarily large
residual reservation, which is conservative. The approach does not protect
physical RAM from shared working sets, locked/AWE memory, large-page residency,
or filesystem cache pressure. That is a separate physical-capacity gate, not a
reason to substitute working set for `PrivateUsage`.

### F2 — overlapping roots can double-count one subtree

`_commit_admission_snapshot` measures every active reservation independently.
There is no disjointness check. If two active payload PIDs are ancestor and
descendant, the descendant's private commit is subtracted from both expected
peaks. Normal claim serialization may make that unusual, but stale/adopted
claims and data defects are exactly where a safety gate must fail closed.

Conversely, shared committed sections are missed by the private sums, but that
is conservative for commit admission. The dangerous miss is an unreadable
process in a target tree: the code silently omits it from `private`.

Required correction: build one identity-qualified forest, reject overlapping
reservation roots as unknown (or allocate each PID's measured commit to exactly
one claim), and make any inaccessible member of a target lineage force that
claim to full reservation.

### F3 — PID reuse makes the lineage attribution unsafe

The snapshot records only `(pid, ppid)`. It records neither process creation
time nor a durable process handle/sequence number. Windows explicitly reuses
PIDs, and Microsoft warns that a stored parent PID can incorrectly refer to a
new process that reused the identifier. Over a 3600-second reservation this is
not hypothetical.

Sources:
[Process handles and identifiers](https://learn.microsoft.com/en-us/windows/win32/procthread/process-handles-and-identifiers),
[Windows process event ParentId warning](https://learn.microsoft.com/en-us/windows/win32/etw/process-v0-typegroup1).

There are two bad cases:

1. The payload root PID is reused. The new process and all its descendants are
   counted as the old work item.
2. The root is dead, but an unrelated live process retains or acquires a PPID
   numerically equal to it. The children-map walk marks the lineage found even
   though the actual parent no longer exists.

Either silently increases `measured_gb`, reduces the reservation, and can
over-admit. The fix must stamp root creation time at spawn and validate
`(pid, creation_time)` on every sample. Descendant edges also need temporal
validation: child creation must be after its validated parent and the chain
must originate from that identity. On sufficiently new Windows,
`SYSTEM_BASICPROCESS_INFORMATION.SequenceNumber` exists specifically to detect
PID reuse; creation time via `GetProcessTimes` is the portable alternative.

### F4 — `inf` is valid only for a positively identified dead lineage

If a validated tree is truly gone, releasing its reservation is correct: dead
processes cannot grow. A work item stranded `active` is a state-machine defect,
but retaining 44 GB for a nonexistent tree would recreate fleet starvation.
The stale claim must also be promptly requeued/failed so it cannot later be
relaunched without a fresh reservation window.

That is not what the implementation proves. `_process_private_snapshot` skips
every process it cannot open or query. `_measured_subtree_gb` returns `inf`
whenever the global `private` map is nonempty but none of the target lineage was
measured. Thus "target exited," "root PID was inaccessible," "root disappeared
between Toolhelp and OpenProcess," and "every target query failed" collapse to
the same release-reservation result.

Required semantics:

- positively validated identity and confirmed no live members: release and
  atomically mark/requeue the stranded active item;
- identity mismatch, partial target read, race, or probe error: `None`, retain
  full reservation;
- no PID stamped yet: retain full reservation.

### F5 — the load-cost claim is materially overstated

`_process_snapshot_cache` is a Python module global inside each worker daemon.
It is **not shared across nine workers**. Each daemon can independently perform
a Toolhelp enumeration plus roughly 220 `OpenProcess` /
`GetProcessMemoryInfo` calls every three seconds: about 660 process queries per
second fleet-wide before retries.

Worse, `_commit_admission_snapshot` runs after the SQLite `BEGIN IMMEDIATE` in
the claim path. A cold scan therefore holds the farm's global write lock. On a
quiet box the measured 8 ms is tolerable; under paging pressure, process opens
and memory queries can stall, serializing every worker behind the slowest scan.
If a snapshot throws, the cache timestamp is not advanced, so the same worker
can retry cold on its next poll.

The ctypes declarations also set no `argtypes`/`restype` for handle-returning
Win32 functions. Relying on ctypes' default C `int` return type is not a valid
64-bit HANDLE declaration, even if current handle values happen to fit.

Required correction: one out-of-transaction sampler (or one shared snapshot
service/file) with bounded age, explicit Win32 signatures, duration/error
telemetry, and admission fail-closed when the sample is stale. Measure p50,
p95, and max on the paging box; the quiet-box mean is not acceptance evidence.

### F6 — the 13 tests pin the formula, not the incident's mechanisms

Ten tests monkeypatch `_measured_subtree_gb` to return the exact desired scalar.
They prove `max(0, expected - measured)` and the configured windows. The
"incident" test supplies both 64.5 and 26.4 itself, then checks the subtraction;
it cannot detect wrong Windows accounting or wrong ownership.

The three probe tests only show that the current process returns a positive
number and a guessed nonexistent PID returns `inf`. Missing coverage:

- reused root PID and stale/reused PPID;
- process creation-time validation;
- inaccessible root or descendant and partial snapshots;
- a process exiting between enumeration and query;
- overlapping reservation roots;
- two real simultaneous trees with independent known allocations;
- shared-section behavior;
- cache isolation across worker processes;
- cold-probe latency while paging and SQLite lock-hold time;
- ctypes HANDLE correctness on 64-bit Windows;
- stranded-active cleanup coupled to reservation release.

So the suite would pass an ownership-invalid implementation, which is the
central risk.

### F7 — exit tracer is useful but its conclusion is too strong

`3455bcf2b` improves evidence: an orderly Python shutdown should emit
`worker_exit`, while `TerminateProcess` will not run Python handlers. But
absence of the line does not uniquely prove an external hard kill. It also
covers interpreter/native crashes, fail-fast termination, power/session loss,
stdout failure/blockage during `atexit`, and termination before tracer
installation. Treat it as "not observed orderly," then correlate with Event
4689/WER and start PID/time; do not label every silent exit external.

## Capacity recommendation

The current gates are unsafe for the measured machine. A 63 GB box cannot
reliably host a 30 GB multisymbol tester plus several 8–11 GB ordinary testers
and the OS. A 4 GB physical floor reacts after the working sets have already
materialized; commit headroom backed by a 60 GB pagefile does not predict that
failure.

Adopt these concrete limits:

1. **Quiet-fleet multisym admission:** admit a multisym item only with
   **at least 40 GB available physical RAM and zero other active/running tester
   payloads**. Forty gives a measured 30 GB peak about 10 GB of immediate
   physical margin.
2. **While multisym is active:** allow **at most one ordinary tester** and only
   if forecast free physical RAM after its 11 GB reservation remains
   **at least 12 GB**. On this 63 GB host, multisym 30 + one ordinary 11 +
   roughly 6–10 GB OS/factory leaves 12–16 GB; two ordinary 11 GB jobs leave
   only 1–5 GB and reproduce the incident regime.
3. **Q08 neighborhood runner:** enforce **one metatester child at a time** and a
   **34 GB private-commit ceiling** for its entire Job Object/tree. At 32 GB
   (measured peak 30 GB) normal variance leaves too little margin; 34 GB gives
   about 13%. Crossing 34 GB should terminate/requeue that parameter point as a
   capacity failure, not let the host page until workers disappear.
4. Keep the existing 12 GB pre-admission multisym floor only as a secondary
   guard; it is not sufficient by itself. Record free physical RAM, tree
   private commit, and tree working set at admission and every sample so these
   constants can be revised from distributions rather than a single peak.

This intentionally sacrifices ordinary-job concurrency during a multisym run.
The alternative already demonstrated lower throughput: page thrash, worker
death, and fleet-wide pauses.

## What I could not verify

I did not induce paging, PID reuse, inaccessible-process reads, shared-section
allocation, large-page/AWE allocation, or a live 34 GB cap on the running
factory. I did not touch T_Live, AutoTrading, factory isolation, session state,
or running worker processes. The accounting conclusions above use Microsoft
API contracts and static code inspection; the load/capacity recommendations
still require a controlled non-live acceptance run.
