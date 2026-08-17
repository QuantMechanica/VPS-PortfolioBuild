# D: rate/runway alarm and busy-slot scratch permanent fix (2026-08-17)

Router task: `343634fe-165b-4554-a1a1-4f57e83785a1`  
Branch: `agents/board-advisor`  
Scope: infrastructure only; no pipeline verdict, terminal restart, Factory OFF/ON,
`T_Live`, AutoTrading, report retention, source-tick data, or fleet stop.

## Outcome

The two structural gaps identified in
`2026-08-17_P0_disk_runway_agent_temp.md` are closed:

1. `tester_cache_purge.ps1` now has `All`, `IdleCaches`, and `BusyScratch`
   modes. The scheduled default is `All`: it first performs the narrow live-safe
   scratch sweep, then retains the pre-existing low-water idle-cache behavior.
2. `health.py` now registers `disk_scratch_rate_runway` in `ALL_CHECKS`. It
   evaluates both observed GB/h and projected runway, and can return blocking
   `FAIL` independently of the remaining-free-space check.
3. `q07_multiseed.py` runs the same guarded `BusyScratch` mode after a tester
   invocation returns and before the next seed starts. This bounds the residual
   scratch near the five-minute age margin instead of allowing five completed
   invocations to accumulate.

## Safety contract

Busy reclamation has three independent, mandatory guards:

- scope: only `bar*.tmp` under
  `D:\QM\mt5\T1..T10\Tester\Agent-*\temp`; `T_Live`, `Bases`, reports, and every
  other filename are outside traversal;
- age: `LastWriteTime` must be older than configurable `MinAgeMinutes` (default
  5, minimum accepted value 1);
- ownership: each exact file must open with `Open / ReadWrite / Share.None`.
  Locked files are reported and skipped. Deletion uses `-LiteralPath` without
  `-Force`; a race after the probe becomes a reported delete-error skip.

Neither `BusyScratch` nor the Q07 post-invocation call stops, kills, restarts, or
launches a terminal. The old idle-cache path remains responsible for its own
protected-terminal and OWNER-state rules.

## Rate measurement and thresholds

The health check sums the size of files modified in a trailing 20-minute window
within the exact busy-scratch scope and converts that to GB/h. This is preferred
to a sampled free-space delta because concurrent reclamation can make free space
rise while a terminal is still writing rapidly. The measurement also names the
offending terminal and never walks `Bases` source ticks or reports.

- `FAIL`: observed rate >= 80 GB/h **or** projected runway < 2 hours.
- `WARN`: observed rate >= 20 GB/h **or** projected runway < 4 hours.
- the existing absolute free-space check remains separate.

Positive control using the incident values (98 GB/h, 112 GB free) returns
`FAIL` with 1.14 hours projected runway. Live observation after implementation
returned `WARN`: 38.44 GB/h, 146.0 GB free, 3.80 hours projected runway, all
12.81 recent GB attributed to T6, and zero measurement errors.

## Why per-invocation cleanup is achievable

`q07_multiseed.py` invokes each seed through blocking `subprocess.run`; it does
not enter the next loop iteration until `run_smoke.ps1` returns. Therefore a
cleanup call can run in the serial gap between invocations. It deliberately uses
the shared PowerShell primitive rather than duplicating deletion logic. Even if
a timeout leaves a child handle alive, the age and exclusive-open guards remain
authoritative and skip anything still owned.

This establishes that an MT5 setting or agent restart is unnecessary for Q07:
an explicit post-invocation cleanup is achievable without interrupting the work
item. The periodic `All` sweep remains the safety net for other long busy phases.

## Live canary

Dry run on live T6 while `QM5_1077` XAUUSD Q07 was active:

```text
BUSY_SCRATCH terminal=T6 mode=DRYRUN candidates=4 candidate_gb=0.25 reclaimable_gb=0.25 locked_skips=0 delete_error_skips=0
BUSY_SCRATCH_SUMMARY mode=DRYRUN min_age_minutes=5 ... d_free_before_gb=157.40 d_free_after_gb=157.40
```

Apply immediately afterward (the eligible set had changed with the live clock):

```text
BUSY_SCRATCH terminal=T6 mode=APPLY candidates=2 candidate_gb=0.12 reclaimed_gb=0.12 locked_skips=0 delete_error_skips=0
BUSY_SCRATCH_SUMMARY mode=APPLY min_age_minutes=5 ... d_free_before_gb=157.71 d_free_after_gb=157.84
```

All four pre-apply process identities remained alive 20 seconds later:

| PID | Process | Alive after apply |
|---:|---|---|
| 19924 | T6 `terminal_worker.py` (`pythonw.exe`) | yes |
| 13776 | Q07 multiseed runner (`python.exe`) | yes |
| 12816 | T6 `terminal64.exe` | yes |
| 19076 | T6 `metatester64.exe` | yes |

The short post-apply observation did not see another `bar*.tmp` write because
the tester had moved beyond history-cache creation. Continued-write evidence for
this exact safety primitive is already durable in the parent P0 record: after a
28.94 GB live T6 apply with zero locked skips, the worker and multiseed runner
survived and T6 wrote four further files in the next three minutes. The new mode
uses that primitive verbatim: same scope, age rule, and exclusive-open contract.

## Verification

```text
PowerShell 5.1 parser: PASS
focused pytest: 25 passed
Q07 + health regression suite: 136 passed
git diff --check: PASS
```

Tests include the 98 GB/h blocking positive control, traversal exclusion of
`T_Live` and non-`bar*.tmp` files, registration in `ALL_CHECKS`, the PowerShell
three-layer contract, owner-state preservation, and the serial Q07 cleanup call.
