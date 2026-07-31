# MNT-003 R2 scheduled-task launch diagnosis

Date: 2026-07-31  
Role: Codex review / diagnosis  
Scope: five maintenance tasks named in the MNT-003 minimal task-contract plan  
Change authority exercised: one triggerless temporary probe task only; no production task was changed

## Verdict

The R1 `0x00000002` result is caused by literal apostrophes around the value passed to `run_in_console_session.ps1 -Arguments`. The planned task action is parsed directly by `powershell.exe -File`; it does not receive the additional PowerShell parsing layer that exists when the working `QM_TesterCachePurge` task builds an argument array inside a script. The helper therefore launches Python with an argument whose first and last characters are apostrophes. Python cannot find that path and exits with code 2.

Confidence: high. The exact R1 action reproduced exit 2, while a candidate differing only by removal of the literal apostrophe wrappers exited 0 under the same SYSTEM-to-`qm-admin` launch path.

The corrected five-task proposal is [2026-07-31_mnt003_minimal_plan_v2.json](2026-07-31_mnt003_minimal_plan_v2.json). It remains a proposal: this review did not apply it to any production task.

## Controlled reproduction

The temporary task `QM_TMP_MNT003_PROBE` was registered without a trigger as SYSTEM / ServiceAccount / Highest. Its first action was the exact R1 Agy proposal:

```text
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\QM\repo\tools\strategy_farm\run_in_console_session.ps1" -Exe "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe" -Arguments '"C:\QM\repo\tools\strategy_farm\agy_governor.py"' -WorkDir "C:\QM\repo" -TargetUser "qm-admin" -WaitSeconds 240
```

Observed evidence:

- Task Scheduler result: `0x00000002`; TaskScheduler Operational event 201 returned decimal `2147942402`.
- Helper stdout: `LAUNCHED pid=18136 ... pythonw.exe" 'C:\QM\repo\tools\strategy_farm\agy_governor.py'` followed by `WAIT_EXIT pid=18136 code=2`.
- The apostrophes are visible in the actual child command line; they are data, not quoting syntax.
- Candidate action: change only the `-Arguments` value to `"C:\QM\repo\tools\strategy_farm\agy_governor.py"`.
- Candidate stdout: `LAUNCHED pid=15564 ... pythonw.exe" C:\QM\repo\tools\strategy_farm\agy_governor.py` followed by `WAIT_EXIT pid=15564 code=0`.
- The candidate run reached the governor's HTTP request and logged HTTP 401 rather than a Windows Credential Manager lookup error. The stale token is independent of this task-launch defect; the governor completed according to its current domain behavior.

The durable reproduction harness is [2026-07-31_mnt003_r2_probe_harness.ps1](2026-07-31_mnt003_r2_probe_harness.ps1). Its machine-readable run capture is `D:\QM\reports\state\mnt003_r2_probe_harness.json` (SHA-256 `30B78667F442D90B161171584355E3ED364BD7337C735F6A1B7A312A5DB56E32`). The launched-user environment capture is `D:\QM\reports\state\mnt003_r2_probe_child.json` (SHA-256 `D094F7D99D03954E00EAF6A8AE8FE1BEEB08E651E5A90A8E4A21ECFA72720ACC`).

## Hypothesis results

### H1 — launched-user environment block

Not causal in the observed failure.

The root task ran as `NT AUTHORITY\SYSTEM` in session 0 with the system profile. The helper-launched diagnostic child ran as `WIN-B95G5LPSJ1O\qm-admin` in console session 1, with:

- `USERPROFILE=C:\Users\Administrator`
- `LOCALAPPDATA=C:\Users\Administrator\AppData\Local`
- `APPDATA=C:\Users\Administrator\AppData\Roaming`
- the user PATH, including `C:\Users\Administrator\AppData\Local\agy\bin`
- working directory `C:\QM\repo`

This demonstrates that `CreateEnvironmentBlock` produced the `qm-admin` environment on the tested path. `run_in_console_session.ps1` does not check the API's Boolean return; adding that check would improve diagnostics, but it is not required to close this reproduced defect.

### H2 — path visibility or ACLs

Not causal.

SYSTEM and the launched `qm-admin` child both resolved the helper, `pythonw.exe`, `agy_governor.py`, and `C:\QM\repo`. The user child also resolved its local Agy executable. The corrected invocation used the same executable, script, work directory, token path, and helper and exited 0.

### H3 — quoting / argument construction

Confirmed root cause.

The R1 plan copied a shell-like single-quote wrapper into a Task Scheduler action. In a raw scheduled action, the single quotes survive and become part of Python's script pathname. `QM_TesterCachePurge` is not a counterexample: it invokes the helper from an already-running PowerShell script using variable-bound arguments, so its apostrophe characters are parsed before process creation rather than forwarded literally.

## Corrected minimal plan

`2026-07-31_mnt003_minimal_plan_v2.json` retains the R1 schema and all five exact before-state task XML snapshots and hashes. The only contract correction is removal of the literal apostrophe wrappers. Each target command's script path and flags contain no spaces, so its complete child argument string can safely be supplied as one double-quoted `-Arguments` value.

Read-only verification with the existing apply tool:

```text
Apply-Mnt003MinimalPlan.ps1 -Mode WhatIf -PlanPath ...\2026-07-31_mnt003_minimal_plan_v2.json
```

Result:

- exit code 0;
- all five live production task before-state hashes matched the plan;
- five proposed action diffs were rendered;
- tool reported `WHATIF_ONLY: no Register-ScheduledTask or Set-ScheduledTask call executed.`

Before any future apply, the operator should re-run WhatIf and require the same exact-hash match. Apply and validation remain separately authorized actions.

## Safety and cleanup

- `QM_TMP_MNT003_PROBE` was disabled immediately after each controlled run and then unregistered.
- A final lookup confirmed that the probe task no longer exists.
- No production task was registered, modified, disabled, started, or stopped by this diagnosis.
- The production Agy task remained `qm-admin` / Interactive with its original direct `pythonw.exe` action after the probe.
- The five production task definitions continued to match the exact before-state hashes during the v2 WhatIf check.
- No terminal process, AutoTrading setting, or T_Live state was touched.

## Recommendation

Approve the v2 plan for the separately controlled MNT-003 apply step. Preserve the SYSTEM/helper architecture and change only the `-Arguments` serialization shown in v2. Treat the observed HTTP 401 as a distinct Agy credential/token maintenance item, not as a reason to broaden the scheduled-task repair.
