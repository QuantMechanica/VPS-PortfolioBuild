# Evening Factory-OFF window — 2026-07-26 (Claude)

Purpose: activate the multisymbol commit-reservation fix (`d88a89392`) and close out the
runbook's evening activation appendix. T_Live book deployment stays **DEFERRED** (OWNER);
FTMO stays **parked** (OWNER, this evening) — no live-book or FTMO step was executed.

## Pre-check: the activation appendix was already done (afternoon)

Verified against the filesystem, not the runbook text:

| appendix step | evidence | state |
|---|---|---|
| 2 — 10 workstream merges | `ac2477ca5` wsa2, `071aa489b` wsc1, `ed36909fe` wsc2, `1fe631e85` wsd2, `b442f9a11` wse1, `e3b993f0b` wse32, `a6701f813` wse42, `6f4c2eebc`+`53de64a74` wsg2, `003db998b` wsf3, `6eca15cb9` wse23 | DONE |
| 3 — WS-E1 activation edge | `D:\QM\reports\state\live_alarm_state.json`, refreshed 18:23 | LIVE |
| 4 — requeue canary-50 | `D:\QM\reports\state\requeue_canary50_journal_20260726.json`, applied 10:38:30Z | DONE |
| 5 — recovery classifier | `recovery_class_manifest_20260726.json` (batch `ultracode_recovery_20260726`); **1 654 / 2 188 pending rows carry `recovery_class`** (runbook estimated ~1 678) | APPLIED |
| 6–8 — deploy stamp, AutoTrading | deferred by `91752a516` | NOT RUN |

## Executed tonight

1. **Factory_OFF** 18:20. Reported `daemons=0 terminals=4` — the known gap: OFF does not
   reap phase runners.
2. **Manual reap, path-anchored** (17 processes): 5 × python phase scripts
   (`q07_multiseed` ×3, `q08_davey/aggregate`, `q08_5_neighborhood_runner`),
   4 × `run_smoke.ps1` pwsh, 4 × `metatester64` (T1/T3/T6/T7),
   4 × `terminal64` (T1/T3/T6/T7). Selection anchored on `ExecutablePath -like 'D:\QM\mt5\*'`
   and `framework\scripts\(q0|run_smoke)` so T_Live (`C:\`) and the always-on health task
   could not be hit.
3. **Quiescence proven by process scan**: terminal64 = 1 (T_Live PID 16388 only),
   metatester64 = 0, worker daemons = 0, phase runners = 0.
4. **Canary-50 evaluation** (gate for a further tranche) — of the 50 requeued at 10:38Z:
   18 finished, 29 still pending, 3 active. Of the finished: **6 PASS, 1 real
   `FAIL_DD_PORTFOLIO_REVIEW`, 11 re-failed `INFRA_FAIL`**.
   → **Decision: no second tranche tonight.** A 61 % infra re-fail rate among completed
   items means the stranded population needs classifier-driven triage, not more volume;
   the queue is 2 194 deep, so the factory is not starved either. 7/18 real verdicts is a
   genuine recovery yield and justifies continuing the programme — gated on triage.
5. **Factory_ON -NoPause** 18:29: 9/9 daemons in session 3, `farmctl repair` one-shot
   reconciled the 8 orphaned actives, respawn/always-on tasks re-enabled.

## Verification

- **Multisym fix live (the point of the window).** Re-claim of the same multisymbol item
  after restart: `QM5_13059 Q08 claimed=16:29:15Z resv=44.0 until=17:29:15Z` — **3 600 s**,
  while ordinary jobs claimed in the same second hold 300 s (`16:29:11Z → 16:34:11Z`).
  Old behaviour was 300 s for both.
- Workers started 18:29:05 > `terminal_worker.py` mtime 18:17:30 → new code loaded.
- **T_Live untouched**: same process (PID 16388) before, during and after; count never
  left 1.
- Autostart repairs survived the cycle: `AllowDemandStart` still True on
  `QM_T_Live_AtLogon` and `QM_FTMO_AtLogon`; `QM_StrategyFarm_FactoryON_AtLogon` re-enabled
  by Factory_ON.
- `FACTORY_OFF.flag` cleared; 4 testers already running post-restart.

## Cost

8 in-flight backtests were killed by the OFF (the 13059 Q08 multisym had ~55 min invested;
three Q07 multiseed runs, four Q02/Q04). All were reconciled by `farmctl repair` and are
back in the queue — 13059 re-claimed within seconds of restart.

## Post-restart finding: workers die silently in the pause loop (ticket `4e8bcf47`)

Within a minute of Factory_ON, T6 and T10 vanished at 18:29:47 / 18:29:53 with
`commit_headroom_low_pause` (effective 19.8 GB < 24 GB, reserved 92 GB over 7
reservations) as their last log line and **no traceback in `.log.err`** — identical
signature to the 17:45 deaths of T4/T9/T10 (which logged `ram_low_pause`), i.e. the defect
predates tonight's change. The claim path returns cleanly on a low-headroom verdict and the
poll loop should just retry, so the processes are being terminated externally or exit
through an unlogged path. Manual `start_terminal_workers.py --dedupe` restored 9/9; stable
2 minutes later.

Second defect in the same evidence: `QM_StrategyFarm_FactoryWatchdog_15min` reported
`workers=9` at 16:30:04Z while a direct WMI scan seconds later showed 7 — the census that
decides whether a heal fires disagrees with process truth, which is why the dedupe-heal has
never actually respawned a worker today (three manual restorations were needed).

The pause behaviour itself is correct and must not be reverted: the 92 GB of reservations
is exactly the over-admission brake that was missing at 17:45. Enqueued as ops ticket
`4e8bcf47` (priority 85).

## Open

- Silent worker deaths + watchdog census mismatch — ticket `4e8bcf47`.
- T5 remains in `disabled_terminals.txt` (Factory_ON warns about it) — rebuild ticket
  `61cfbaf3` in the Codex lane.
- Stranded-INFRA triage: run the classifier's output against the re-fail population before
  releasing tranche 3.
- Runbook steps 6–8 stay blocked on the deferred book deployment.
