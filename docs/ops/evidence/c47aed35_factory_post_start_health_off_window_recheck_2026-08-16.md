# Factory post-start health gate — OFF-window recheck (task c47aed35)

Date: 2026-08-16

Router task: `c47aed35-89a1-4a26-a870-a496cd9d105d`
(re-routed to claude after a stale `codex` release; predecessor task
`8d6c7ef9-dd06-4d16-9654-8a0cb2b3b154` already established the same guard and
patch contract — see
`docs/ops/evidence/8d6c7ef9_factory_post_start_health_off_window_deferral_2026-08-16.md`)

Verdict: `REVIEW — STILL DEFERRED BY LIVE FACTORY GUARD`

## Guard result (this cycle)

The payload marks `tools/strategy_farm/factory_restart_health.ps1` and the
abort path in `Factory_ON.ps1` as ceremony-critical, to be implemented
**only** inside an OFF window, and explicitly instructs the handling agent
not to trigger Factory_OFF/Factory_ON itself for the purpose of landing this
patch — it is to be "minted into the next runtime-activation decision"
instead, i.e. piggybacked on an OFF window that occurs for other reasons.

Re-checked now:

- check time: `2026-08-16T12:39:35Z`
- `D:\QM\strategy_farm\state\FACTORY_OFF.flag`: absent (factory is ON)
- `QM_StrategyFarm_AgentRouter_5min`: `Ready` (enabled)
- `QM_StrategyFarm_Pump_5min`: `Ready` (enabled)
- worker/terminal processes visible: 18
- `farmctl health`: `mt5_worker_saturation` 10/10 terminal_worker daemons
  alive; `mt5_dispatch_idle` 985 pending / 5 active

Nothing has changed since the predecessor deferral: the factory is still
live and running active backtests. Per the routed gating and the hard rule
against interrupting active T1–T10 work without an OWNER-directed OFF
decision, this task remains not actionable from an unattended cycle.

## Focused verification (no mutation)

Baseline suite re-run from `C:\QM\repo` (unchanged, read-only):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File tools/strategy_farm/tests/Test-FactoryRestartPostStartHealth.ps1
```

Result: `PASS Test-FactoryRestartPostStartHealth.ps1 (28 assertions)` — confirms
the pre-change baseline is still green and the defect described in the
predecessor evidence doc is unchanged.

No source, scheduled task, worker, terminal, T_Live setting, or AutoTrading
setting was changed. Active T1–T10 work was not interrupted.

## Disposition

The 7-point patch contract and 8 regression cases from
`8d6c7ef9_factory_post_start_health_off_window_deferral_2026-08-16.md` remain
the authoritative implementation spec. This task stays queued for the next
authorized OFF window (OWNER/Claude-driven ceremony scheduled for another
reason, or an explicit OWNER go-ahead to open one for this patch
specifically) rather than being force-scheduled by a headless cycle.
