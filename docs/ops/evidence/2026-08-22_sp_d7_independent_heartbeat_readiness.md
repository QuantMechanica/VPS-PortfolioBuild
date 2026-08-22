# SP-D7 independent heartbeat monitor — readiness gate

Date: 2026-08-22  
Router task: `a484d91e-3f5d-4ff0-b431-8fa80f10a930`  
Verdict: **NOT READY — the required independent end-to-end monitor does not exist yet**

## Measured production state

- `QM_StrategyFarm_SilentFailureMonitor` runs as `SYSTEM` every 15 minutes and last returned `0`. It is independent of terminal workers, but its documented contract explicitly produces health evidence only and never sends mail.
- `QM_Live_AlarmMailer_1min` runs as `SYSTEM` every minute and last returned `0`. Its input schema is intentionally limited to `T_Live_Watchdog` terminal conditions (`missing`, `duplicate`, `launch_failed`, `probe_unknown`, `stale`, `unexpected_running`, `contract_expired`).
- `QM_StrategyFarm_HourlyMonitor_60min` runs as `SYSTEM`, but consumes `farmctl health` and therefore is not independent of the factory/health chain required by SP-D7.
- The Codex, Claude, and Gemini lane heartbeat files were all fresh at measurement time. The silent-failure monitor checks scheduler health and generic state freshness, but it has no explicit missing-agent-lane alarm with delivery.
- The DXZ account snapshot was fresh and reported `free_margin=99095.26`, `margin=0`, `write_ok=true`. The deployed v1 snapshot contains no `reconciliation_complete` field and no quote/tick timestamp, so reconciliation and quote-age cannot be proven by an external consumer.
- `C:/QM/mt5/T_Live/MT5_Base/config/common.ini` currently reported `[Experts] Enabled=1`. Existing live tooling observes terminal state, but no independent SP-D7 producer binds AutoTrading state, account snapshot freshness, margin, reconciliation, and calendar state into one alarm transition.
- The canonical and `FILE_COMMON` news-calendar manifests were byte-equivalent at measurement time and both declared bundle `news-calendar-2e098799...`, generated `2026-08-22T03:30:05Z`. No independent alert path currently compares those manifests and their horizon.

## Acceptance-gap matrix

| Required signal | Existing source | Independent detection | Independent alarm delivery | Gate |
|---|---|---:|---:|---|
| Terminal/session | `T_Live_Watchdog` / `live_alarm_state.json` | yes | yes | PASS |
| AutoTrading state | DXZ `common.ini` | no consolidated detector | no | FAIL |
| Agent-lane gap | `lane_*_heartbeat.json` | partial scheduler coverage | no | FAIL |
| Quote age | no timestamp in deployed v1 account snapshot | no | no | BLOCKED |
| Calendar freshness/parity | canonical + `FILE_COMMON` manifests | no independent comparison | no | FAIL |
| Account reconciliation | requires v2 AccountMonitor (`reconciliation_complete`) | unavailable in deployed v1 | no | BLOCKED |
| Margin/free margin | deployed account snapshot | read by other controls | not in independent alarm path | FAIL |
| Delivery self-health | live mailer task/result | terminal-alarm channel only | narrow | FAIL |

## Safe next implementation boundary

The deployable unit should be a single-run, read-only `SYSTEM` task outside the factory worker/dashboard chain. It must read exact source files directly, publish a transition-deduplicated sidecar, and send only transitions/recoveries through the proven SMTP helper. It must never invoke `farmctl`, start a terminal, or write terminal configuration. Quote-age and reconciliation checks must fail closed until the separately governed v2 AccountMonitor deployment makes those fields observable.

No scheduled task, terminal, `T_Live`, or AutoTrading state was changed during this review. Claiming SP-D7 acceptance now would be a false positive because two required inputs are absent and the existing independent monitor has no alarm transport.

## Verification commands

```powershell
Get-ScheduledTask -TaskName QM_StrategyFarm_SilentFailureMonitor,QM_Live_AlarmMailer_1min,QM_StrategyFarm_HourlyMonitor_60min
Get-Content D:/QM/strategy_farm/state/lane_codex_heartbeat.json
Get-Content C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/account_snapshot.json
Get-Content D:/QM/data/news_calendar/news_calendar_bundle_manifest.json
Get-Content C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/news_calendar_bundle_manifest.json
```
