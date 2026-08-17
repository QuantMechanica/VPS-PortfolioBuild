# Q02 summary_missing/UNCLASSIFIED ~90min run-abandonment - root cause - 2026-08-16

Router task `d91f8163-9989-4ade-bd85-ea45fd92727e` (priority 90, triage_failure).
Read-only diagnosis; no claim-path code changed, no Factory OFF/ON, no T_Live.

## Symptom

Q02 `full` runs for tick-heavy symbols die at ~90 minutes with
`final_failure=summary_missing_retries_exhausted`, `failure_class=UNCLASSIFIED`,
`failure_class_evidence="no terminal_exit signature and no discriminating token"`,
`run_smoke_exit_code=None` - well inside the 7200s (120min) budget the payload
itself records as `timeout_seconds`.

## Measured instances (work_items table, `D:/QM/strategy_farm/state/farm_state.sqlite`)

| id | EA | symbol | claimed_at | started_at | updated_at (failed) | runtime | terminal | attempt_count |
|---|---|---|---|---|---|---|---|---|
| `da89eae6-ff01-45bf-a60a-5455db5b8e6c` | QM5_20178 | XAUUSD.DWX | 19:07:41Z | 19:09:51Z | 20:40:01Z | 89m08s (from spawn) | T9 | 2 |
| `7771ffb7-55d9-4c13-b525-0edb299096c8` | QM5_20176 | XAUUSD.DWX | 17:15:17Z | 17:16:34Z | 18:46:45Z | 89m27s | T2 | 2 |
| `55837f3f-fa1a-4760-8ff2-24e3f9043fd0` | QM5_20178 | NDX.DWX | 19:40:57Z | 19:43:42Z | 21:13:55Z | 92m58s | T7 | 2 |
| `70a8f002-c927-4ac6-bedf-b5d0bf4790b2` | QM5_20178 | WS30.DWX | (not in router payload) | - | 23:40:58Z | same signature, attempt_count=2 | - | 2 |

All four: `run_smoke_exit_code: null`, `terminal_stopped_on_release: true`,
`timeout_seconds: 7200` (payload), `failure_class: UNCLASSIFIED`, no
`post_exit_watchdog_killed`/`reap_reason` key present. `70a8f002` was in the router
payload's `affected_rows_to_requalify_after_the_fix` list but not in its
`measured_instances`; verified here to carry the identical signature.

The router payload also listed `73285c18-edc6-4010-b83c-79bd3cad0634` as affected.
**That row is a different failure mode** - see "Second, related finding" below; it is
not part of this UNCLASSIFIED/summary_missing class and needs a separate fix.

Independently corroborated (payload evidence from the router task, not re-derived
here): the T9 tester journal for the QM5_20178 XAUUSD run in this exact window shows
116 buy / 115 sell deals and ~1745 successful position modifies with no error class
- the run was healthy and actively trading when it stopped, not hung or stalled.

## Root cause: two independently-configured timeout layers, never reconciled

QuantMechanica runs Q02 "full" backtests under **two separate timeout nets** that
are computed from different, disconnected sources:

**Inner net - run_smoke.ps1's own `-TimeoutSeconds`.** `farmctl._p2_full_timeout_seconds`
(`tools/strategy_farm/farmctl.py:4778-4809`) computes the real per-item budget - for a
single-symbol non-basket Q02 full run this floors at `P2_FULL_TIMEOUT_MIN_SECONDS = 7200`
(`farmctl.py:4445`, 120 minutes), the exact value recorded in `payload["timeout_seconds"]`
for all four rows above. That computed value is passed straight to the child process as
`"-TimeoutSeconds", str(timeout_seconds)` (`farmctl.py:5913`) - run_smoke.ps1's own
internal budget. It is also copied into `payload["timeout_seconds"]` **after** spawn,
purely as descriptive metadata (`terminal_worker.py:4152-4156`).

**Outer net - the Python monitor's watchdog deadline.** `terminal_worker.py`'s poll loop
(`_monitor_spawned_work_item`, `terminal_worker.py:3621-3789`) kills the process tree
(`farmctl._stop_pid_tree`, `Stop-Process -Force`, `farmctl.py:7470-7522`) once
`time.monotonic() >= deadline`. That `deadline` is computed by `_monitor_deadline_monotonic`
(`terminal_worker.py:3602-3618`) from a `default_timeout_seconds` argument that traces back
through `_run_claimed_item`'s own `timeout_seconds` parameter
(`terminal_worker.py:3859`, `4168`, `4487`, `4634`, `4640`) to `run_loop`'s CLI flag
`--timeout-minutes`, **default `90.0`** (`terminal_worker.py:4589`) - a single global value
per worker process, set once at worker startup and identical for every phase and symbol.
`start_terminal_workers.py` does not pass an override, so every T1-T10 worker runs with
the 90-minute default.

The only way to raise the outer deadline above that 90-minute default is
`payload.get("timeout_min")`, read inside `_monitor_timeout_seconds`
(`terminal_worker.py:3581-3599`) and mirrored on the farmctl side by
`_payload_timeout_floor_seconds` (`farmctl.py:4763-4776`, explicitly documented at
`farmctl.py:4798-4801`: *"The payload `timeout_min` override already governs the worker
watchdog; honor it here too so one field budgets both nets"*). This is an **opt-in**
key - nothing in the automatic Q02-full dispatch path
(`_p2_full_timeout_seconds`/the Q02 branch at `farmctl.py:5776-5784`) ever writes
`payload["timeout_min"]` for a plain single-symbol heavy run; it only exists for a caller
that pre-sets it (e.g. a manually-tuned basket). So the 120-minute budget the code
*computed and gave to the inner net* never reaches the outer net.

**Net effect:** the outer Python watchdog kills the still-healthy run_smoke.ps1 ->
terminal64.exe tree at ~90 minutes, 30 minutes before run_smoke.ps1's own 120-minute
inner `-TimeoutSeconds` would ever fire. Because the kill is external
(`Stop-Process -Force`, walking the live process tree bottom-up), run_smoke.ps1 never
executes its own exit-logging path and never writes a `terminal_exit` line to its log.
`farmctl.classify_summary_missing_run` (`farmctl.py:3978-4051`) reads that log looking for
an authoritative signature (`timed_out=True`, `valid_report_latched`, `log_bomb`, an
explicit token); finding none - because the process was murdered before it could log
anything - it falls through every branch to the fail-open default at
`farmctl.py:4049-4051`: `UNCLASSIFIED` / `"no terminal_exit signature and no
discriminating token"`. This is an exact, mechanical match for the observed
`failure_class_evidence` on all four rows; it is not a guess.

## Which symbols are actually affected (corrected against the DB - do not trust the
## router payload's symbol list without checking; it undercounted)

A full Q02 survey of both EAs (`work_items` where `phase='Q02' AND ea_id IN
('QM5_20176','QM5_20178')`) shows this is broader than "XAUUSD and NDX only":

- `QM5_20176` (lighter EA): only `XAUUSD.DWX` hits the mismatch; `EURUSD`, `GBPUSD`,
  `NDX`, `USDJPY`, `WS30` all reached `verdict=PASS`.
- `QM5_20178` (heavier EA, same family): `GBPUSD.DWX`, `NDX.DWX`, `WS30.DWX` and
  `XAUUSD.DWX` **all** show the identical `UNCLASSIFIED` / `summary_missing_retries_exhausted`
  signature (`attempt_count=2`, `run_smoke_exit_code=null`). Only `EURUSD.DWX` passed
  cleanly; `USDJPY.DWX` is still mid-retry.

So the discriminator is not one or two "heavy" symbols - it is genuine real-tick Q02
runtime exceeding 90 minutes, which depends on **both** how tick-dense the symbol's
`.DWX` history is (XAUUSD/NDX are the densest in the universe, matching the existing
note at `farmctl.py:375`, *"tick-heavy XAU EAs need ~90min"*) **and** how expensive the
EA's own per-bar logic is (`QM5_20178` trips on 4 of 5 symbols, `QM5_20176` on 1 of 5).
The bug is latent for any symbol/EA combination whose genuine runtime falls between the
90-minute outer default and whatever the inner net was actually budgeted for (120
minutes here, more for baskets) - it is not intrinsically limited to XAUUSD/NDX, and the
next EA with heavier logic will trip on more symbols, not fewer.

## Second, related finding: `73285c18` is a different bug in the external reaper

`73285c18-edc6-4010-b83c-79bd3cad0634` (`QM5_20178` `XAUUSD.DWX`, a later retry of the
same pair, `enqueued_by: claude_sweep_enqueue_2026-06-10.stranded_infra_fail`) does
**not** carry `failure_class`/`summary_missing_retries_exhausted` at all. Its payload
instead shows `verdict_reason: ACTIVE_TIMEOUT`, `reap_reason: NO_FORWARD_PROGRESS`,
`timeout_min: 130`, `inner_budget_min: 120`, `absolute_ceiling_min: 130`,
`active_age_min: 29.65`. This is a **third, independent** timeout mechanism -
`farmctl._detect_active_age_timeout` (`farmctl.py:8062-8199`), an external reaper sweep
over `status='active'` rows (not the in-process worker watchdog above) - and for this
row it did the ceiling math *correctly*: `_active_timeout_min_for_work_item`
(`farmctl.py:8278-8311`) reads `payload["timeout_seconds"]` (unlike the worker watchdog)
and derives `absolute_ceiling_min = 130` = 120min inner budget + `ACTIVE_OUTER_HEADROOM_MIN`
(10min, `farmctl.py:395`) - exactly the number in the payload. The row was killed anyway,
at only ~30 minutes of active age, far short of that 130-minute ceiling, because a
*separate* stall detector fired: `progress_stalled` (`farmctl.py:8133-8143`) trips
`reap_reason=NO_FORWARD_PROGRESS` whenever `_terminal_progress_evidence`
(`farmctl.py:7606-7699`) sees no `AutoTesting processing NN%` line in the MT5 terminal
log for `ACTIVE_PROGRESS_STALL_MIN` (20 minutes, `farmctl.py:394`), independent of the
ceiling. Whether this is a genuine hang or a false positive (real-tick XAUUSD/NDX runs
may legitimately go >20 minutes between MT5's own percent-progress log lines on a
tick-dense multi-year window) is **not established here** - it needs its own read-only
check against a currently-running heavy XAUUSD/NDX Q02 terminal log before anyone touches
`ACTIVE_PROGRESS_STALL_MIN`. Flagging as a separate follow-up item, not folded into the
fix below.

## Not a stale-claim / duplicate-work bug

The router task's own working hypothesis (repeated ~90min inter-attempt spacing implying
a stale-claim reclaim while the old run_smoke stays alive) does not hold up against the
row data: `attempt_count=2` on all four failed rows with `terminal_stopped_on_release:
true` and no `claim_transferred`/`external_release_observed` markers. `_stop_pid_tree`
(`farmctl.py:7470-7522`) re-enumerates the live `Win32_Process` tree from the tracked PID
at kill time and force-stops every descendant bottom-up before the row is marked failed,
so there is no orphaned terminal64.exe/run_smoke.ps1 left running after the row updates -
consistent with `farmctl.py health` showing `active_row_age: OK` (0 rows beyond phase
timeout) and `mt5_worker_saturation: 10/10` with no stuck terminals at the time of this
diagnosis. No evidence of invisible duplicate work.

## Proposed fix (not a blanket timeout raise)

Do not raise the 90-minute CLI default - it is the correct floor for the overwhelming
majority of Q02 runs (the comment at `farmctl.py:372` notes typical Q02 H1 runs finish in
5-20 minutes). Instead, reconnect the two nets so the outer watchdog can never fire before
the inner net's own documented budget:

- In `terminal_worker.py:4152-4168` (fresh spawn), pass
  `max(timeout_seconds, spawn_timeout_seconds)` as the `default_timeout_seconds` argument
  to `_monitor_spawned_work_item`, instead of the bare CLI `timeout_seconds`.
- In `terminal_worker.py:3895-3922` (adopted/orphan-rejoin path), the same fix applies
  using `existing_payload.get("timeout_seconds")` instead of only the CLI default.

This makes the Python watchdog structurally consistent with whatever budget
`_p2_full_timeout_seconds`/`_payload_timeout_floor_seconds` already computed and handed to
run_smoke.ps1, for every phase, without a second place to remember to configure it.

## Verification / requalification after the fix lands

- Re-run `QM5_20176 XAUUSD.DWX`, `QM5_20178 XAUUSD.DWX`, `QM5_20178 NDX.DWX` Q02 and
  confirm either a real verdict inside the 120-minute inner budget, or - if genuinely
  still too slow - a `terminal_exit timed_out=True` signature (transient/retryable) rather
  than `UNCLASSIFIED`.
- Requalify Q02 once the fix is verified for the four confirmed same-signature rows:
  `da89eae6`, `7771ffb7`, `55837f3f`, `70a8f002` - their current `INFRA_FAIL` verdicts
  are an artifact of this bug, not evidence about the EAs.
- `73285c18` requalifies separately once the NO_FORWARD_PROGRESS question above is
  resolved - it is not fixed by the change proposed here.

No factory OFF/ON, no T_Live, no claim-path code edited as part of this diagnosis.

## Prospective confirmation (2026-08-17 02:25Z)

The diagnosis was tested forward rather than only backward. On 2026-08-17 01:10Z —
before the outcome — the reading of the QM5_20176 XAUUSD rerun `c7a4351f` was fixed in
writing (`docs/ops/evidence/2026-08-16_noop_sltp_modify_storm.md`, commit `70b5c6683`):
completion would credit the no-op SLTP fix, while a death near 90 minutes would be this
watchdog and would say nothing about it.

Measured:

| | |
|---|---|
| claimed | `2026-08-17T00:53:54Z` |
| process started | `2026-08-17T00:55:43Z` |
| released back to `pending` | `2026-08-17T02:25:52Z` |
| elapsed from process start | **90 min 09 s** |
| `timeout_seconds` in payload | `7200` (120 min) |
| `run_smoke_exit_code` | `None` |
| `prior_failure` | `summary_missing` |

A run with a 120-minute inner budget, killed at 90 minutes and 9 seconds, with no exit
code — the predicted signature to the second, on a row chosen in advance. A diagnosis
that predicts is worth more than one that explains, and this one now has both.

Two consequences:

1. **The no-op SLTP modify fix remains unverified.** Its discriminator could not run to
   a verdict. Verification now depends on the QM5_10000 canary (`78979d0f`, pending) or
   on any bound run that finishes, whichever comes first after the watchdog fix is live.
2. **The waste is self-sustaining.** `c7a4351f` returned to `pending` with
   `attempt_count=1` rather than terminating, so it will be re-claimed and killed again.
   The five QM5_20178 Q02 runs in flight at the time of writing are in the same loop.
   Only deploying `e607a1bc3` — which requires a Factory OFF/ON, because
   `terminal_worker.py` is resident from worker start — breaks it.
