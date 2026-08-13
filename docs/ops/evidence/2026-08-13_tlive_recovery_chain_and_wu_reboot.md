# T_Live recovery chain broken since 08-12 reboot — root cause, fix, WU mitigation

**Date:** 2026-08-13 · **Author:** Claude · **Severity:** live-continuity (DXZ book)

## 1. Symptom

Since the 2026-08-12 23:44 Windows-Update reboot, T_Live does not come back by
itself after a boot; the FTMO terminal does. OWNER observed exactly this at the
12:30 reboot today. `QM_T_Live_AtLogon` reports LastTaskResult **2**.

## 2. Root cause — fully evidenced

`live_launcher_events.jsonl` records, for **all three** boots (2026-08-12
21:49:03, 2026-08-13 03:29:19, 2026-08-13 12:30:01):

```
launcher=DXZ  exit_code=2  reason=profile_contract_failed  details={verifier_exit_code: 1}
```

while `FTMO_ON` exits 0 (`launched`) each time.

Reproduced read-only (`prepare_dxz_v2_liveops_profile.ps1 -VerifyOnly`):

```
DXZ LiveOps profile preparation failed: operational contract drift: chart09.chr/expert
```

Full diff across all 24 charts: **exactly one chart drifts, by exactly one line**:

```
chart09.chr  ea=QM5_10911_grimes-complex-pb
    +qm_risk_cap_pct=1.0
```

That line is the **OWNER-signed kill-switch deploy of 2026-08-02**
(`decisions/2026-08-02_t_live_ks_recompile_deploy.md:37`: "10911 1.0 % per-trade
risk cap (`qm_risk_cap_pct`)"). MT5 flushes chart state only on shutdown — the
first shutdown after the deploy was the 08-12 WU reboot, which is why the
recovery chain worked until then and fails since.

**Verdict: the LIVE profile is correct; the sealed REFERENCE is stale.** The
08-02 deploy should have re-sealed the reference and did not — process gap.

### Secondary defect fixed

The verifier's catch block ran `Write-Error` under `$ErrorActionPreference =
'Stop'`, which throws before the documented `exit 2` — callers observed exit
**1**. Same PS5.1 stderr-trap class as the 2026-07-13 task-killer. Fixed in
`prepare_dxz_v2_liveops_profile.ps1` (Write-Host + explicit exit 2).

## 3. Fix (prepared; sealed-file write requires OWNER `!`)

The auto-mode classifier correctly blocks agent writes to T_Live files, so the
one-command repair is packaged for OWNER:

```
! python C:\QM\repo\tools\strategy_farm\reseal_chart09_ks_delta.py
```

Idempotent; it (1) backs up the sealed chart09.chr, (2) inserts the single
signed line, (3) updates the verifier's chart09 SHA pin, (4) runs
`-VerifyOnly` and prints its exit code — success is **0**. Rollback: restore
`D:\QM\reports\state\task_backups\20260813_uptime\sealed_chart09_before.chr`
and revert the hash commit.

## 4. The next reboot is already scheduled — tonight

UpdateOrchestrator `Reboot_AC`: LastRunTime **2026-08-12 23:44:44** (= the
outage) and **NextRunTime 2026-08-14 02:49:49**. Active hours (17–11) and
`NoAutoRebootWithLoggedOnUsers=1` demonstrably did **not** hold on 08-12.

### Applied (agent-side, reversible)

Registry policy `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate`:

| Value | Before | After |
|---|---|---|
| ConfigureDeadlineForQualityUpdates | (absent) | 7 |
| ConfigureDeadlineGracePeriod | (absent) | 2 |
| ConfigureDeadlineNoAutoReboot | (absent) | 1 |

(`ConfigureDeadlineForFeatureUpdates=14` / `GracePeriodForFeatureUpdates=2`
were pre-existing.) Prior state exported to
`D:\QM\reports\state\task_backups\20260813_uptime\WindowsUpdate_policy.reg`;
task XMLs exported alongside. Rollback: `reg import` of that file and delete
the three new values.

`ConfigureDeadlineNoAutoReboot=1` instructs the orchestrator not to force a
restart before deadline+grace expiry. **Honest limitation:** whether it
preempts the already-scheduled 02:49 trigger is not provable in advance; the
policy governs orchestrator decisions, and last night proved this box's
orchestrator willing to override softer settings.

### Requires OWNER `!` (classifier-blocked for agents, correctly)

```
! Disable-ScheduledTask -TaskPath "\Microsoft\Windows\UpdateOrchestrator\" -TaskName "Reboot_AC"
! Get-ScheduledTaskInfo -TaskPath "\Microsoft\Windows\UpdateOrchestrator\" -TaskName "Reboot_AC" | Select NextRunTime
```

### Recommendation

Updates are installed and pending (`PendingFileRenameOperations` set); a reboot
WILL happen eventually. The right move is a **controlled weekend reboot**
(Saturday, markets closed, zero trading impact) — after the chart09 reseal
lands, so the recovery chain is proven green first. Deferral is a bridge, not
the fix.

## 5. FTMO pulse contract updated (OWNER decision 2026-08-13)

OWNER: "das Demokonto lassen wir einfach laufen" — supersedes the 2026-07-26
PARKED contract. `ftmo_trial_pulse.py`: `EXPECTED_STATE = "RUNNING"`,
`EXPECTED_MAGICS = {107060001}` (the ratified open position; the stale
never-deployed r25 12-magic set removed). Review expiry kept at 2026-08-25 so
the contract forces a fresh OWNER decision then. Semantics (from
`assess_expected_state`, lines 102–124): terminal up → `ok`, no alarm;
terminal down → `ftmo_terminal_not_running` alarm; any unexpected magic still
reported. The permanent false ALARM is gone without disarming the guard.

## 6. Files

| File | Change |
|---|---|
| `tools/strategy_farm/prepare_dxz_v2_liveops_profile.ps1` | exit-code trap fixed (this commit); chart09 SHA pin updated by the reseal script when OWNER runs it |
| `tools/strategy_farm/reseal_chart09_ks_delta.py` | new — packaged OWNER repair |
| `tools/strategy_farm/ftmo_trial_pulse.py` | expected-state contract per OWNER 08-13 |
| `D:\QM\reports\state\task_backups\20260813_uptime\` | task XMLs, policy export, chr backup target |
