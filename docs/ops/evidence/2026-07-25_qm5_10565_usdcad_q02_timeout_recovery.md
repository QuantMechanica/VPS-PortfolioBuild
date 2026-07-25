# QM5_10565 USDCAD Q02 outer-timeout recovery

Date: 2026-07-25

Branch: `agents/board-advisor`

EA / symbol: `QM5_10565_mql5-rvidiff` / `USDCAD.DWX` H6

## Outcome

The existing Q02 work item
`14abad8d-2e7e-47c0-803d-be0ec1ea4f38` was reopened in place for the normal
farm worker with a 120-minute outer timeout. No duplicate work item or manual
backtest was created.

Farm coordination:

- repair task: `fcd48572-ac5a-4b1f-a233-1703ab081cb5`
- claim:
  `manual:codex:agents/board-advisor:QM5_10565:q02-usdcad-timeout-recovery`
- database backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10565_usdcad_q02_timeout_requeue_20260725T103217Z.sqlite`

## Diagnosis

The failed row had already passed far enough to start its five-year Q02 full
run. Its work-item log shows:

```text
run_smoke.stage=terminal_start ... timeout_seconds=7200
run_smoke.stage=terminal_spawn_confirmed ...
run_smoke.stage=terminal_exit ... timed_out=False valid_report_latched=False
```

The tester contract therefore allowed 120 minutes, but the farm payload still
carried `timeout_min=45`. The outer worker killed the active job after 49.07
minutes and classified it `INFRA_FAIL / ACTIVE_TIMEOUT`. No report-based
strategy verdict existed.

This is the same full-run duration mismatch that does not appear in a short
prescreen: the tester was still within its own allowed runtime when the outer
worker terminated it.

## Deterministic handoff

The failed row was reset to `pending`, with stale claim/process/result fields
removed, `timeout_min=120`, and the existing evidence-bound MQ5, EX5, setfile,
symbol, timeframe, and date-range hashes preserved. The canonical setfile
continues to use backtest risk mode (`RISK_FIXED=1000`, `RISK_PERCENT=0`).

At handoff, `farmctl mt5-slots` reported zero factory terminals. The separately
identified `T_Live` process was not touched. No AutoTrading state, portfolio
gate, deploy manifest, EA mechanics, or live artifact was changed.
