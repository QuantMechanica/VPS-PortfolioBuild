# Evidence Receipt — Scheduled-Task run-as repair (SYSTEM → qm-admin)

**Date:** 2026-09-15 (~20:30–20:45 UTC)
**Author:** Kimi (interim operator, OWNER_DIRECT_SESSION_DELEGATION)
**Class:** P5 factory repair — low/medium risk, reversible (re-run installers with prior parameters to revert)

## Symptom
Heartbeat listed recurring scheduled-task failures: `QM_StrategyFarm_KimiOrchestration_15min` rc=1,
`QM_StrategyFarm_StrategyWikiSync_60min` rc=1, BookEvolution suite + `QM_MonthlySleeveCalendar_Refresh`
rc=267011 (0x41303 = never ran since registration).

## Root causes (both proven, not assumed)
1. **Run-as = SYSTEM** (`S-1-5-18`) for tasks registered 2026-09-15 by the CBE Phase-I installers.
   SYSTEM has **no G: drive mapping** — Google Drive File Stream maps per-user. Probe task
   `QM_TMP_KimiSysProbe_20260915` (created, run, deleted) printed `G_MISSING` under SYSTEM.
   The wiki sync writes the vault at `G:\My Drive\QuantMechanica - Company Reference` → instant failure.
   Healthy precedent `QM_Live_MT5_SessionSupervisor` runs as `qm-admin` / InteractiveToken.
2. **Literal TAB in action path**: `install_strategy_wiki_sync_scheduled_task.ps1` built
   `"$RepoRoot` + backtick-t TAB + `ools\strategy_farm\lineage_map.py"` (PowerShell `` `t `` escape
   inside the double-quoted -Argument), so action 1 pointed at `C:\QM\repo<TAB>ools\...`.
3. Kimi orchestration lane additionally needs the **console-session hop** (`run_in_console_session.ps1`,
   MNT-003 v2 pattern, same as the gemini lane): the kimi CLI credential lives in the qm-admin
   profile; the installer's "plain SYSTEM branch unless a probe shows otherwise" probed = fails rc=1.

## Fix (canonical installers edited, then re-run)
- `tools/strategy_farm/install_strategy_wiki_sync_scheduled_task.ps1`
  - added `-TaskUser` param (default `qm-admin`), principal = InteractiveToken;
  - fixed the lineage_map path to `` `"${RepoRoot}\tools\strategy_farm\lineage_map.py`" ``.
- `tools/strategy_farm/install_book_evolution_scheduled_tasks.ps1`
  - added `-TaskUser` param (default `qm-admin`), principal = InteractiveToken (5 tasks re-registered).
- `tools/strategy_farm/install_agent_orchestration_scheduled_tasks.ps1`
  - KimiOrchestration now routed through the MNT-003 v2 console-session hop to qm-admin
    (same branch as GeminiOrchestration); stale "unless a probe shows" comment replaced with the
    2026-09-15 probe result.

## Verification (all observed, this session)
- WikiSync task manual run → `D:\QM\reports\state\strategy_wiki_sync.json` regenerated
  `20:41:49Z`, `STRATEGY_WIKI_SYNC: GREEN`, 3820 canonical records / 5265 nodes.
- KimiOrchestration task manual run → Last Result **0** (22:39:49 local).
- BookEvolution weekly suite re-registered for Fri 23:15 / Sat 06:00 / Sun 09:00 / Mon 06:30 local;
  first live firing due Friday 2026-09-18 (watch item for Fable).

## Not touched (deliberate)
- `QM_NewsCalendar_Refresh` — fails on a **data** guard (`news_calendar_2015_2025.csv registry pin
  does not continue from the receipt-chain tail`, REFUSED), independent of run-as; under separate
  investigation (gates ~200 NEWS-tainted work items).
- `QM_WorkItemLogPruner_Daily_0310` rc=1 and `QM_EvidenceCohortWatch_Daily_0420` rc=3
  (documented exit 3) — causes not yet diagnosed.
- `QM_MonthlySleeveCalendar_Refresh` (monthly cadence; its installer already supports `-RunAs`).
- Codex/Gemini/Claude orchestration tasks re-registered identically (no functional change; all were
  and remain Enabled).

## Blast radius / rollback
Re-registering tasks only; no pipeline/gate/live-state writes. Rollback: re-run the previous
installer versions from git history (they are committed; my edits are the working-tree delta).
