# R10/R10B Activation Window — CLAIM_SYMBOL_ACTIVE_CAP Rollout — 2026-08-12

Operator: Claude. Authorization: OWNER "Go, Fenster jetzt!" (interactive,
2026-08-12 ~16:20Z), executing the OFF/ON activation for the same-symbol cap
(`CLAIM_SYMBOL_ACTIVE_CAP=4`, commit b38ecf424 — see
`2026-08-12_claim_symbol_cap_and_dead_row_retirement.md`). Resident workers
carry no self-reload; only an OFF/ON window loads the new claim contract.

## Timeline (all UTC)

| time | step | outcome |
|---|---|---|
| 16:30:32 | Factory_OFF #1 | **OFF_INCOMPLETE** — processes reaped clean (2 stable null scans), but `managed Codex drain: FAILED` |
| 16:30–16:43 | bounded wait | codex exec (SYSTEM) finished its admitted unit naturally at 16:43:19 |
| 16:44–16:48 | interlude | XTI cohort blocked (below), locks/tmp swept, router tasks settled |
| 16:49:46 | Factory_OFF #2 | **FACTORY QUIESCENT**, 21-entry task map preserved |
| 16:51:08 | Mint R10 | `FACTORY_REBIND_20260812_R10_SYMBOL_CAP`, decision_sha 21b70b9c06, commit 0932d6544 |
| 16:52–17:05 | Factory_ON #1 | **FAILED CLOSED** — `RESTART_HOLDS_COMMITTED_EVIDENCE_FAILED: wal_checkpoint remained busy (log=8169, checkpointed=8166)`; flag → OFF_RECOVERY_REQUIRED, mutation lock retained |
| 17:05–17:09 | forensics + fix | see WAL section; hardening committed af2c60a38, tests 39/39 |
| 17:10:26 | Factory_OFF #3 | **FACTORY QUIESCENT**, map preserved |
| 17:11:31 | Mint R10B | `FACTORY_REBIND_20260812_R10B_SYMBOL_CAP_WAL_ENVELOPE`, decision_sha 75c100915e, commit f1b2db7be |
| 17:15–17:21 | Factory_ON #2 | **FACTORY STARTED 10/10** — WAL evidence PASS (busy=0, 33/33), nonce 36ef5a1738 consumed |
| 17:25:07+ | claims resume | first post-window claims T9 (basket QM5_20206) + T4 (Q08 QM5_11177 XAUUSD) |

## New corner #1: OFF against a live SYSTEM-context codex exec

The codex orchestration lane fired its last managed exec at 16:30:02Z — 30
seconds before the interlock asserted. `codex_fleet_pacer.py --factory-off`
running in the interactive Administrator context could not open the SYSTEM
job object `Global\QMStrategyFarmCodex_78cdc583…` (`job_open_failed`,
error=5 ACCESS_DENIED): the scheduled task runs as SYSTEM and the default
job-object ACL does not grant the interactive admin TERMINATE.

Decision: the exec was mid-flight on legitimate repo-mutating work (the
Brent→WTI reroute close-review in `C:\QM\worktrees\codex-orchestration-1`);
killing it mid-write is exactly the torn state OFF exists to prevent. A
bounded wait (max 10 min) let the admitted unit finish naturally (13 min
runtime, exit 16:43:19Z). Fallback (not needed): re-run the pacer as a
SYSTEM one-shot so the job open succeeds in the owning context. Follow-up
candidate: teach Factory_OFF to route the pacer drain through SYSTEM when
managed leases are SYSTEM-owned.

## Codex review-reject landed mid-window: XTI cohort blocked

The exec's final commit `961d4d121` (review task `ce9c3a4d`) rejected the
23-EA Brent→WTI reroute (`387b7fd00`): all 23 MQ5 sources hard-code
`_Symbol == "XBRUSD.DWX"` in the host gate, so every XTIUSD.DWX run
deterministically zero-trades (4 completed runs corroborate: verdict
ZERO_TRADES). Under the Q02 frequency floor those runs would mis-RETIRE the
cards — a setup defect, not a strategy verdict.

Action before ON (DB backup
`D:\QM\strategy_farm\state\backups\farm_state_before_xti_cohort_block_20260812T164553Z.sqlite`):

- 19 open XTIUSD.DWX Q02 rows (18 pending + 1 reap-orphaned active) →
  `status=failed, verdict=BLOCKED_STALE_BUILD_RESULT` with full
  `verdict_reason` + per-row `events` entries. The 4 done ZERO_TRADES rows
  remain as historical fact.
- Router: build task `9ad6d9c0` close-reviewed → RECYCLE → reset to TODO
  with rework instructions (fix host gates in 23 sources, serial recompile,
  guardrails, fresh Q02 enqueue). Review task `ce9c3a4d` → APPROVED
  (finding verified).

## New corner #2: WAL checkpoint persistent-reader pin (ON #1 fail)

R9's fix (14947f400) assumed transient poll readers: FULL + 12×2.5s. ON #1
exhausted that envelope with `checkpointed` frozen at 8166/8169 for the
full 30s — the signature of ONE reader holding a >30s-old snapshot (fresh
poll readers snapshot at the current WAL end and do not block FULL copying
of older frames). Probe with the fleet down: `busy=0, 8169/8169` — the
pinning reader is part of the factory lifecycle itself, not external
telemetry.

Hardening (af2c60a38): envelope 12×2.5s → 36×2.5s (90s) and the fail-closed
message now carries the distinct `(log, checkpointed)` progression plus a
self-classification — `persistent reader pin` (frozen counts) vs `moving
reader churn` (advancing counts) — so any future failure identifies its
class without a blind re-run. Tests: 39/39 including 2 new. ON #2 passed
the evidence step in one attempt (33/33). Reader identity remains an open
forensic item; the next failure's self-diagnosis narrows it.

## Verification (post ON #2)

- 10/10 `terminal_worker` daemons (process scan), FACTORY_OFF.flag removed,
  FACTORY_MUTATION.lock released, WATCHDOG_RESET_PENDING marker removed.
- `custom_history_containment_mode.json` → `enabled: false` (unchanged).
- Only T_Live and FTMO `terminal64.exe` ran through all three cycles —
  never touched by any OFF/ON step (script assertions + process scans).
- Claim ledger: first claims 17:25:07Z (T9 basket) / 17:25:13Z (T4 XAUUSD
  Q08 — the requeued pre-window run). Lane-widening measurement appended
  below.
- Pre-window staged recovery: all 5 XAU/basket actives requeued cleanly to
  pending; the killed XTI active was blocked with its cohort (above).

## Claim ramp after ON #2 — XAU lane at cap 4 within 25 seconds

Claim ledger (`claim_class_ledger` joined to `work_items`):

| claimed_at_utc | terminal | ea_id | symbol |
|---|---|---|---|
| 17:25:07 | T9 | QM5_20206 | XAU_XAG basket (multisym, 1 farm-wide — unchanged rule) |
| 17:25:13 | T4 | QM5_11177 | XAUUSD.DWX |
| 17:25:28 | T10 | QM5_11205 | XAUUSD.DWX |
| 17:25:30 | T2 | QM5_1556 | XAUUSD.DWX |
| 17:25:32 | T3 | QM5_11298 | XAUUSD.DWX |

Four XAUUSD.DWX runs across four distinct EAs active simultaneously —
exactly `CLAIM_SYMBOL_ACTIVE_CAP`; the poll monitor confirmed the lane held
at 4 (not 5) with further XAUUSD work pending, i.e. the cap binds. Under
the pre-change rule this queue shape degenerated to ONE XAUUSD slot
(`2026-08-12_claim_symbol_cap_and_dead_row_retirement.md`). The remaining
terminals fill from the recovery/priority backlog as history admission
permits.

## Commits this window (agents/board-advisor)

| commit | content |
|---|---|
| a9f4798d9 | lane-artifact absorption pre-mint (3 EA rebuilds + SPECs, 2 stress sets) |
| 961d4d121 | (codex) review-reject of the Brent→WTI reroute |
| 0932d6544 | R10 decision + sidecar |
| af2c60a38 | WAL checkpoint envelope 90s + self-diagnosing failure |
| f1b2db7be | R10B decision + sidecar |
