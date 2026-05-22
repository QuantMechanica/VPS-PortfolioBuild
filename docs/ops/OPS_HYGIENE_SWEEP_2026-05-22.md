# Ops Hygiene Sweep

Date: 2026-05-22
Task: `14a78e79-d112-42e8-a790-d7e6624102eb`
Status: REVIEW

## Morning Briefing Task

`QM_MorningBriefing_Vault` was enabled but pointed at a missing script:

`C:\QM\repo\.scratch\morning_briefing_autogen.py`

Action taken:

Repointed the scheduled task to the maintained Strategy Farm brief generator:

`C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe C:\QM\repo\tools\strategy_farm\morning_brief.py`

The task is still enabled and scheduled daily at 06:00 local. It remains under
the existing `qm-admin` task principal.

## Build-Failed Triage

Current `farmctl pipeline` state shows 48 EAs at `build_failed`.

Grouped latest build failure reasons:

| Class | Count | Verdict |
|---|---:|---|
| `zero_trade_smoke` | 34 | Per-EA / strategy trade-generation failures; not a framework regression |
| `codex_review_fail` | 2 | Per-EA code/review rejection; not a framework regression |
| `card_path_orphaned_dup_allocation_reassigned_to_QM5_1643_pending_G0` | 1 | Resolved allocation/orphan lineage; no rebuild action here |
| `unknown_failed_payload` | 11 | Stale/legacy failed rows with no useful failure payload; not enough evidence for a framework fix |

Sampled EAs confirm the dominant class is zero-trade smoke, not compile or
template breakage. No blanket rebuild was started.

`build_failed` EAs observed:

`QM5_1045`, `QM5_1046`, `QM5_1050`, `QM5_1053`, `QM5_1060`,
`QM5_1062`, `QM5_1065`, `QM5_1067`, `QM5_1068`, `QM5_1070`,
`QM5_1081`, `QM5_1087`, `QM5_1090`, `QM5_1091`, `QM5_1093`,
`QM5_1094`, `QM5_1095`, `QM5_1103`, `QM5_1104`, `QM5_1121`,
`QM5_1122`, `QM5_1132`, `QM5_1133`, `QM5_1134`, `QM5_1149`,
`QM5_1159`, `QM5_1168`, `QM5_1195`, `QM5_1213`, `QM5_1236`,
`QM5_1237`, `QM5_1385`, `QM5_1395`, `QM5_1400`, `QM5_1440`,
`QM5_1443`, `QM5_1448`, `QM5_1510`, `QM5_1619`, `QM5_2001`,
`QM5_2002`, `QM5_2003`, `QM5_2004`, `QM5_2005`, `QM5_2006`,
`QM5_2007`, `QM5_2010`, `QM5_9011`.

## Disabled Task Audit

Observed disabled `QM_*` tasks are legacy Paperclip/V4/superseded jobs. The
active Strategy Farm replacement family is enabled:

- `QM_StrategyFarm_AgentRouter_5min`
- `QM_StrategyFarm_CodexOrchestration_15min`
- `QM_StrategyFarm_ClaudeOrchestration_15min`
- `QM_StrategyFarm_GeminiOrchestration_15min`
- `QM_StrategyFarm_Pump_5min`
- `QM_StrategyFarm_Health_15min`
- `QM_StrategyFarm_TerminalWorkers_AT_STARTUP`
- dashboard, cockpit, repair, Gmail alarm, quota receiver, and morning brief tasks

No disabled legacy task was re-enabled. The disabled `QM_MT5_Worker_T1` through
`QM_MT5_Worker_T5`, `QM_GateEvaluator_5min`, `QM_Phase_Orchestrator`,
`QM_PipelineHealth_Watchdog`, and old dashboard/export tasks are superseded by
the Strategy Farm queue, pump, terminal-worker daemon, health, and dashboard
tasks listed above.

## Verification

- `schtasks /query /tn QM_MorningBriefing_Vault /v /fo LIST`: task target now
  points to `tools/strategy_farm/morning_brief.py`.
- `farmctl pipeline`: 48 `build_failed` EAs grouped as above.
- `schtasks /query /fo CSV /v`: disabled legacy task audit recorded; active
  Strategy Farm replacements present.

No T_Live or AutoTrading action was taken. No terminal was started manually.
