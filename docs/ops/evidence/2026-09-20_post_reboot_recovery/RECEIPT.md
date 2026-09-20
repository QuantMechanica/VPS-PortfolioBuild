# Post-reboot recovery — 2026-09-20 15:23–16:20Z (Fable)

Reboot cause: OWNER RDP timeout while the VPS was up (port 54321 open from three external check-host nodes, local
X.224 handshake OK, TermService running) — the session subsystem was wedged (`qwinsta`, `query user`, `Get-CimInstance`,
`Get-ScheduledTask`, `wevtutil` all hung; graceful `shutdown /r` hung too). Kernel reboot at 15:23Z with markets closed,
factory idle, FTMO demo flat. Resume packet: `docs/ops/FABLE_RESUME_2026-09-20.md`.

## Verification after boot (all at-logon tasks rc=0 except Factory_ON)

| Surface | Result |
|---|---|
| T_Live | `T_Live_ON.ps1` launched 15:23:59Z exit 0; 21 sleeve logs touched since boot; `live_uptime_watchdog` healthy 15:24Z |
| FTMO demo | `FTMO_ON.ps1` launched 15:24:09Z; verifier VERIFIED (governor + 6 SHA-pinned D2g6 sleeves, risk 1.71875 %); pulse OK 6/6, equity 99 813, 0 open |
| Factory | `QM_StrategyFarm_FactoryON_AtLogon` rc=1 (Task Scheduler history disabled, cause not recoverable); `FactoryWatchdog_15min` healed at 15:25Z (`worker_dedupe_heal`) → 10/10 workers by 15:35Z |
| Session | OWNER RDP `rdp-tcp#0` active; env allowlist (NDX programs) persisted (Machine scope) |
| Guard | one blocking entry (QM5_41155 source drift, see below) → cleaned; `blocked:false` |

## Findings and fixes

1. **Worktree janitor reverts governed rebuilds.** `run_worktree_clean_task.py` runs `clean_repo_worktree.ps1
   -RestoreTrackedEx5` every 30 min; any modified tracked `.ex5` not committed inside that window is restored to HEAD.
   QM5_41347's 08:01Z rebuild (COMPILE_OK 20cce28d, ex5 862045c6, Q02 PASS + 18 MEASURED cells) was replaced at
   08:30:14Z by the 2026-09-05 slot-0-only binary → 8× `EA_MAGIC_NOT_REGISTERED ea_id=41347 slot=1` → poison-pill
   quarantine of the remaining 1059 census cells. The same mechanism explains the QM5_41155 source drift (rebuilt
   09:30Z, binary reverted, source+setfiles left dirty, guard blocked 6 h; patch preserved in
   `2026-09-20_qm5_41155_uncommitted_source_drift/`). Fix `cb53061862`: the janitor now commits any modified tracked
   `.ex5` whose bytes a COMPILE_OK receipt binds (plus that EA's restamped setfiles) before cleanup; 1 test.
2. **41347/NDX recovery.** Second append-only rebuild authority (`router_ops_issue:14a9cbf1…`, stale rows 245ee112 +
   20cce28d, evidence `2026-09-20_dl089_11294_ndx_census_stall/rebuild_authority_14a9cbf1.json`) → COMPILE_OK
   76273f26 (ex5 54f30e5a) → binary committed under its receipt (`d4493bc561`, guard PASS) → quarantine released
   15:47Z → census resumed: 4 cells MEASURED on 54f30e5a within 20 min, L=2. The 8 INFRA_FAIL cells are not Q12
   rows (service recovery refuses them); they stay as evidence, the level closes on the service's own maintenance.
3. **Continuous retention failed closed since 2026-09-17** (`WinError 3` on a MAX_PATH Q09 pass-anchor cell file under
   a listable directory): 157 SQLite backups / 53.6 GB accumulated, D: fell to 81 GB, and the cold-restart worker cap
   (`(disk-40)/8`) dropped to 5. Fix `f79309bb35` (long file paths yielded with the `\\?\` prefix, unreadable files
   skipped, 15 tests); first run deleted 32 backups / 40.3 GB → D: 96 GB free.
4. `compile_work_items`: the on-disk `.ex5` sha is what makes an old COMPILE_OK "usable current" again after a revert —
   registrations must list every receipt whose binary could reappear, not only the newest.

## Open

- Factory_ON at-logon rc=1 without history (Task Scheduler operational log disabled) — enable the log or write a
  Factory_ON result file so the next reboot is diagnosable.
- 8 INFRA_FAIL census cells of 41347/NDX: level completion depends on the matrix service maintaining them; check at
  the next watch that the program advances past 1081/1089.
