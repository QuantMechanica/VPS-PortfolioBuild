# Factory recovery marathon — 2026-08-13 19:51Z → 2026-08-14

**Author:** Claude · **Trigger:** OWNER 21:50 local: "factory läuft nicht! Keine Backtests!"
**Live impact:** none — T_Live and the FTMO terminal traded untouched throughout.

## The five stacked causes (each masked the next)

| # | Cause | Evidence | Resolution |
|---|---|---|---|
| 1 | T8 lost three manifest-bound archives (`SP500/2020+2021.hcc`, `UK100/2022.hcc`) → custom-history gate FAIL_CLOSED fleet-wide → containment auto-engaged 19:51:09Z | worker logs `custom_history_gate_pause`, `custom_history_containment_mode.json` (`automatic_stop_condition`) | restored from canonical T1, each byte-verified against the signed manifest before AND after copy; containment released under the OWNER-signed `t8_restore` window (ramp_soak follow-up-window convention) |
| 2 | Global lease held by a dead holder (pythonw 19420, acquired 19:55:29Z mid-drain) | lease record; `tasklist` proof pid dead, zero pythonw | swept aside with the established `stale_*_dead_` suffix after re-proving holder death (OWNER `!`, classifier-gated) |
| 3 | OFF task map ≠ pinned 21-task baseline (quota governor had throttled AgyGovernor + CodexFleetPacer during the evening session-limit) | mint refusal `task map does not equal the approved preparation map`; diff exactly those two tasks | all 21 restored to the approved baseline, stale flag superseded, fresh OFF captured an exact match |
| 4 | ON's post-start health gate (1800s) structurally undersized: the clock runs while ON's own `farmctl repair` still holds DB write locks; after a heavy day repair alone ran 27+ min (WAL 34MB) and every AgentRouter_5min cycle died (`database is locked`). Standalone repair is fail-closed outside the ON window → each retry re-ran repair against the same backlog: a self-deadlock across ceremonies | ON R1/R2 gate timeouts; router logs `wall_clock_timeout` ×3 then `OperationalError('database is locked')` ×4; interactive `run_once` completed in 59.8s in a commit gap; repair pid 11492 alive 22:52→23:23 | budget 1800→3600s (d912c7769) + ValidateRange ceiling aligned (75198b85a) — gate success criteria unchanged, early success still exits early |
| 5 | Two long-lived writers kept starving the DB anyway: an **orphaned `farmctl pump`** (pid 14000, 50 min, outlived ON R4, scheduler cap would be 10 min) and a **respawned SYSTEM codex supervisor** (pid 17036, second of the night) whose job object the pacer cleanup cannot open (error 5) | process listings; OFF `pacer_cleanup_ok:false` with `job_open_failed` | pump stopped (transactions roll back atomically); supervisor ended via `schtasks /End` + Stop-Process; OFF then exact schema-v2 with pacer_cleanup_ok=true |

## Ceremony ledger

| Round | Decision | Outcome |
|---|---|---|
| R1 | RTA-2026-08-13-T8RESTORE (39821f179) | gate timeout 1800s — router starved by repair |
| R2 | (same flag chain) | gate timeout — same cause, router errors now visible (`database is locked`) |
| R3 | RTA-…-R3 (7f753958e) | my error: budget raised without the ValidateRange ceiling → fast fail-closed abort |
| R4 | RTA-…-R4 | gate timeout — orphan pump (50 min) + fresh SYSTEM supervisor starved the window |
| R5 | RTA-2026-08-14-T8RESTORE-R5 (659dbda1a) | running at time of writing; cleanest conditions of the night |

Every abort was fail-closed with a preserved task map; nothing was forged past a
guard. Two shortcuts were considered and rejected: hand-setting QM_WORK_ITEM_ID
(defeats the isolation gate's guarantee) and a decoy process to latch the health
gate via the skip path (masks a genuinely dead router; the auto-mode classifier
also blocked it, correctly).

## Hardenings committed tonight

- `run_agent_router_task.py`: faulthandler stack dump before the wall-clock kill
  (49f497880) — the watchdog was destroying the only evidence of each freeze.
- `Factory_ON.ps1` health budget 3600s with full evidence chain (d912c7769).
- `factory_restart_health.ps1` ValidateRange ceiling aligned (75198b85a).

## Structural findings for the day shift (Codex cross-review before surgery)

1. **Repair belongs before the ceremony, not inside it.** The guarded window
   re-runs repair from scratch each attempt while the health clock runs. Either
   start the health window after repair completes, or give `farmctl repair` a
   verified quiesced-OFF admission (checks OFF state + zero terminals + zero
   workers itself, instead of refusing blanketly).
2. **The pump must not be able to outlive its cap.** A 50-minute orphan escaped
   the PT10M scheduler bound (spawn path unclear — find it). A wedged pump
   starves every other DB writer.
3. **SYSTEM-context supervisors vs. session-context cleanup** (error 5) is now a
   twice-in-one-night pattern. The pacer cleanup needs a SYSTEM-capable stop
   path, or RestoreOnReset must not respawn during a guarded window.
4. **Router freeze class remains instrumented but unexplained** for the 600s
   variant (the fast variant was `database is locked`). Next freeze self-writes
   its stack to `*.freeze_stack.txt`.

## Open forensics (unstarted, deliberately)

Who deleted the three T8 archive files (~19:09 local)? The 14:29 reboot's
interrupted copy-on-claim is the prime suspect; a cache/purge path is second.
Owed a proper investigation once the factory produces again — it can recur.
