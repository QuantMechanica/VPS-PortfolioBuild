# Runbook — controlled VPS reboot, Saturday 2026-08-15

**Authorised by:** OWNER, 2026-08-13 ("Go")
**Why:** Windows updates are installed and pending (`PendingFileRenameOperations`
set). They will reboot this machine eventually. Doing it at a chosen time with
markets closed converts an uncontrolled outage into a planned five-minute stop,
and gives us the first real-world test of the recovery chain repaired today.

**Why it is safe now and was not yesterday:** the T_Live recovery chain was
broken from 2026-08-12 23:44 until 2026-08-13 ~19:00 (sealed-profile drift, see
`docs/ops/evidence/2026-08-13_tlive_recovery_chain_and_wu_reboot.md`). It is
repaired and independently verified (`VERIFIED … EXITCODE=0`, commit f037bdbaa).

**Timing:** Saturday, any time. Broker is closed from Fri ~23:00 to Sun ~23:00
broker time, so no trade can be missed. Do NOT do this on a weekday.

---

## Roles

| Step | Who |
|---|---|
| Quiesce factory, mint activation decision, all verification | Claude |
| The reboot itself, and any `!` command | OWNER |
| T_Live AutoTrading, if it ever needs touching | OWNER + Claude only |

---

## Phase 0 — preflight (Claude, ~10 min before)

1. **No live positions open.** Weekend flat is expected, but verify rather than
   assume — read the T_Live account monitor journal, not a screenshot.
2. **Tree clean, including untracked.** Other agents leave in-flight files in
   this checkout; the activation decision refuses to mint on a dirty tree.
   Do NOT commit foreign in-flight files — wait or park them.
3. **Record the before-state** so the after-state can be compared, not guessed:
   running terminals with paths, worker count, `farmctl status` task counts,
   free space on C: and D:.
4. **Confirm `Reboot_AC` is still Disabled** — if the orchestrator re-enabled
   it, that is itself worth knowing before we hand it a reboot.

## Phase 1 — quiesce the factory (Claude)

```
Factory_OFF.ps1        # echo '' | pipes past its Read-Host
```

Then **wait for drain**: no `terminal64.exe` under `D:\QM\mt5\T*`. Do not
proceed while a backtest is mid-run — killing one mid-flight is how
Custom-History archives end up inconsistent under copy-on-claim.

`T_Live` and the FTMO terminal keep running through this. Factory_OFF does not
touch them.

## Phase 2 — reboot (OWNER)

```
! shutdown /r /t 60 /c "QM controlled maintenance reboot"
```

Expect ~3-6 minutes. The AT_STARTUP task stays `Disabled` — that is normal, the
watchdog brings the workers up.

## Phase 3 — verification (Claude), in this order

The order matters: live first, factory last.

1. **T_Live is up and self-recovered.** `terminal64.exe` under
   `C:\QM\mt5\T_Live\MT5_Base`, and — the actual proof — a fresh
   `exit_code: 0, reason: "launched"` DXZ record in
   `D:\QM\reports\state\live_launcher_events.jsonl`.
   **This is the whole point of the exercise.** Anything other than exit 0 means
   the reseal did not hold and we stop and diagnose before restarting the factory.
2. **FTMO terminal is up** (it self-recovered on all three prior boots).
3. **`ftmo_trial_pulse`** reports `condition: ok` under the new RUNNING contract.
   A `ftmo_terminal_not_running` alarm here is real and must be actioned.
4. **Windows Update state**: `PendingFileRenameOperations` should be gone. If it
   is still set, the updates did not finish and another reboot is queued —
   find out before restarting the factory.
5. **Workers**: 10 terminal workers cycling, no orphans, no stale locks.

## Phase 4 — restart the factory (Claude)

Fail-closed chain, in this exact order — every step of it exists because
skipping one has cost us a day before:

1. Tree clean again (the OFF-flag change is itself a repo change).
2. `python tools/strategy_farm/build_runtime_activation_decision.py --decision-id RTA-2026-08-15-MAINT`
3. Commit decision + sidecar.
4. **PS 5.1 host only** — pwsh 7 is rejected fail-closed:
   ```
   & "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass `
     -File "C:\QM\repo\tools\strategy_farm\Factory_ON.ps1" -CanonicalRuntimeHost -NoPause
   ```
5. Verify: OFF-flag gone, workers claiming, first work item picked up.

**Abort semantics:** "ABORTED before mutation" = nothing changed, the decision
stays valid, fix and re-run. Flag left at `OFF_RECOVERY_REQUIRED` = it aborted
*after* the mutation point → run `Factory_OFF` again, then **re-mint** (the
decision is bound to the flag state and is now stale).

## Phase 5 — close out (Claude)

Evidence doc `docs/ops/evidence/2026-08-15_controlled_reboot.md` with the
before/after state, the launcher journal line proving self-recovery, and the
total live downtime in minutes.

---

## If T_Live does NOT come back (the one scenario that matters)

Do not improvise, and do not reboot again.

1. Read `live_launcher_events.jsonl` — the `reason` field names the exact abort
   path (`profile_contract_failed`, `already_running`, `launch_mutex_timeout`, …).
   Every exit path in `T_Live_ON.ps1` writes one; this is a solved diagnosis.
2. If `profile_contract_failed` again: run the verifier `-VerifyOnly` directly;
   its message names the drifting chart and field. Today's cause was a signed
   deploy delta never re-sealed — the same class can recur from any input change.
3. Manual bring-up is available and safe:
   `! powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\tools\strategy_farm\T_Live_ON.ps1`
4. Only if all of that fails: OWNER opens the terminal in the interactive
   session. AutoTrading stays OWNER + Claude.

---

## Standing process rule this incident established

**Any signed T_Live deploy that changes EA inputs must re-seal the reference
profile and its SHA table in the same window.** MT5 flushes chart state only at
shutdown, so the drift stays invisible until the next reboot — then the recovery
chain fails weeks later, far from its cause. Add the reseal to the go-live
procedure in the Vault (`08 Current State`), step 3.
