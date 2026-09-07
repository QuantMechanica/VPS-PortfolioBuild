# Tester-cache purge / claim-lock race closure — 2026-09-07

Task: `7da8b9e6-2889-481b-8d6b-876de9284e06`  
Disposition: implementation complete; leave in `REVIEW`  
Scope: purge worker protection, orphan mutation-lock recovery, focused tests  
Non-actions: no terminal state, threshold, queue verdict, `T_Live`, or AutoTrading change

## Incident proof

The scheduled purge log records the following UTC sequence in
`D:/QM/reports/state/tester_cache_purge.log` (SHA-256 at inspection:
`02F662D698884E87C9B99FD852C29243E0EB35473FA80FC2885ED8DC4239B9F3`):

- `01:30:16` — disk trigger at 59.79 GB free.
- `01:30:17` — idle-cache preflight found 39 targets / 20.636 GB.
- `01:30:20` — owner state captured; T3 was not in the protected set.
- `01:30:28` — idle worker slots were stopped.
- `01:30:30` — T3 cache targets were deleted.
- `01:30:50` — missing workers were relaunched.

The lock hold journal records T3 worker PID 18520 acquiring
`FACTORY_MUTATION.lock` at `01:30:20.260060Z`, nonce
`ec5bcaf6e04d4aa78d5edf37433eb14d`, owner
`terminal_worker.claim_atomic:T3`, with no matching orderly release. T3's live
worker log then records peer-visible lock refusals at `01:31:24.974742Z` and
`01:32:04.561440Z`, still attributing the lock to dead PID 18520.

The durable reap journal proves that T7 finally reaped that exact nonce at
`01:32:25.815351Z`: PID state `dead`, lock age 125.560 seconds, stale threshold
120 seconds. This closes the causal chain: the purge's active-row / terminal64
snapshot missed a worker inside pre-claim mutation, force-stopped that worker,
and left the fleet behind the age gate.

## Implemented closure

`tools/strategy_farm/tester_cache_purge.ps1` now:

- detects a `terminal_worker.claim_atomic:Tn` holder from the readable lock
  record or, while the Windows no-share handle is live, from a bounded recent
  unmatched ACQUIRED hold-journal receipt;
- independently authenticates that PID as a live `python.exe` / `pythonw.exe`
  process whose command line is `terminal_worker.py --terminal Tn`;
- adds that terminal to the existing protected set before cache sizing and
  re-checks inside every worker kill pass, including immediately before each
  `Stop-Process`;
- logs `LOCK_HOLDER_PROTECTED` when the additional protection is applied; and
- treats observation only as a one-way safety input: ambiguity retains cache or
  follows the pre-existing protection rules, never authorizes a kill.

`tools/strategy_farm/factory_mutation_lock.py` now checks the nonce-bound
record's PID identity before the ordinary 120-second age gate. A `dead` or
`reused` owner can therefore be reaped immediately through the existing
exclusive-open, byte-for-byte content-CAS delete and durable audit path. Live,
unknown, unreadable, invalid, or ownership-changed records remain fail-closed.
The age threshold remains the fallback gate when PID liveness has not proved an
orphan. Reap evidence now distinguishes `owner_pid_liveness` from
`stale_age_and_owner_pid_liveness`.

The terminal worker already installs orderly SIGTERM/SIGINT handlers. A graceful
signal raises `SystemExit`, unwinding the active `FactoryMutationLock` context
manager and releasing its exact nonce-owned file. Windows `Stop-Process -Force`
uses `TerminateProcess`, for which no Python signal/finally hook can run; the
purge-side holder protection and immediate dead-PID reap cover that hard-kill
class.

## Verification

Focused command:

```text
python -m pytest -q \
  tools/strategy_farm/tests/test_factory_mutation_lock.py \
  tools/strategy_farm/tests/test_tester_cache_purge_owner_state.py
```

Result: `17 passed in 5.34s`.

An expanded regression run added claim-lock cost, watchdog launcher, and
resource-headroom coverage; result: `33 passed in 16.43s`.

`git diff --check` passed for all four implementation/test files. The PowerShell
5.1 parser test is included in the focused suite. Added coverage proves a fresh
dead holder reaps below the 120-second threshold, the audit records the liveness
trigger, and the purge contains both bounded journal fallback and repeated
pre-kill holder protection.

## Separate accounting finding

The same purge run reported `expected_deleted_bytes=177221420` while free space
moved from 59.79 GB to 80.36 GB, producing
`TELEMETRY_ERROR reason=implausible_free_space_gain`. This is preserved as a
separate accounting observation. This task does not alter reclaim accounting,
disk thresholds, terminal enablement, or any pipeline verdict.
