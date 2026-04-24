# T6 Live MT5 Automation Runbook

Purpose: allow Fabian to steer and approve live/demo deployments without manually dragging EAs onto charts.

## Architecture

One VPS hosts six MT5 portable terminals:

| Terminal | Purpose | Owner | Hard rule |
|---|---|---|---|
| T1-T5 | Research, backtests, sweeps, source-card validation | Pipeline-Operator | Never trade live |
| T6 | DarwinexZero Demo/Live execution only | LiveOps | Never run Strategy Tester |

T6 is a separate portable MT5 install with its own data directory, logs, profiles, templates, and MQL5 files. Pipeline-Operator has no write authority over T6.

## DarwinexZero Operating Model

DarwinexZero is the primary live-test portfolio and public proof engine. Treat it with live-money discipline even though it is subscription-funded and not external client capital.

Operational language:
- Use "DarwinexZero live test", "public track record", or "live-test portfolio".
- Avoid calling it a "hedge fund" in public copy unless Fabian has legal/compliance review.
- Every money-at-risk action traces to a deploy manifest and Fabian approval.
- Profitability on DarwinexZero becomes the investor-facing proof signal for the business.

## Risk Of Same-VPS Co-Location

Putting factory and live trading on one VPS reduces cost and friction, but adds resource-coupling risk. Mitigations are mandatory:

- T6 terminal process gets higher priority than T1-T5.
- T1-T5 sweeps pause if CPU, disk, or memory threatens T6.
- No optimizer or Strategy Tester ever runs inside T6.
- T6 has its own backup and log export path.
- LiveOps alarms if T6 ping, journal, or Darwinex connection degrades.
- Any money-at-risk action requires Fabian approval by manifest.

## Deploy Manifest

Fabian approves a manifest, not a manual chart action.

Example:

```yaml
manifest_id: DEPLOY-2026-04-21-001
environment: demo
terminal: T6
approved_by: Fabian
approved_at: null
account:
  broker: Darwinex
  account_type: demo
global_limits:
  max_risk_per_trade_pct: 0.50
  daily_loss_halt_pct: 3.0
  portfolio_dd_alarm_pct: 5.0
  portfolio_dd_halt_pct: 10.0
placements:
  - ea_id: SM_221
    ea_file: SM_221_SilverBullet_v5.ex5
    symbol: AUDUSD
    timeframe: M15
    setfile: SM_221_AUDUSD_M15_demo.set
    magic: 2210001
    risk_percent: 0.25
    source_card: SRC001_S01
```

## Automation Levels

### Level 0 - Template/Profile automation

Prefer MT5 templates and profiles where possible. A prepared T6 profile can contain the right charts, and templates can reduce or eliminate repetitive drag-and-drop steps. This is more robust than raw mouse movement.

### Level 1 - File automation

LiveOps copies `.ex5`, `.set`, templates, and manifest to T6. Fabian or LiveOps manually opens charts if needed.

### Level 2 - Chart bootstrap automation

LiveOps uses scripted chart setup:
- open T6 terminal
- open target symbols/timeframes
- apply templates or load saved profiles
- verify Experts and Journal logs

### Level 3 - UI automation

LiveOps uses calibrated Windows UI automation to attach EAs and import setfiles. This is acceptable only after a dry run on demo.

This is the "Codex Computer" class of operation: mouse and keyboard actions against the MT5 GUI. It is possible, but it is the least stable layer, so every run needs screenshot and log proof before it is trusted.

### MT5 GUI Steps Covered By UI Automation

When templates/profiles cannot cover the placement, LiveOps automation must be able to:

1. Open Market Watch and show the required symbol.
2. Drag or open the symbol as a chart on the main workspace.
3. Set the timeframe from the manifest.
4. Open Navigator, scroll to the required EA, and attach it to the chart.
5. Load the manifest setfile or input values.
6. Confirm common settings, including algo trading permission only when approved.
7. Save screenshot proof.
8. Check Experts and Journal logs.

## Verification Contract

No placement is considered complete until LiveOps verifies:

- T6 terminal is the active target, not T1-T5.
- Symbol and timeframe match the manifest.
- EA name on chart matches manifest.
- Setfile timestamp and hash match manifest.
- Magic number is visible in inputs or log.
- AutoTrading state matches target environment.
- Experts log has no load errors.
- Journal log has no trade-context or authorization errors.
- Screenshot proof is archived.

## Fabian's Role

Fabian does:
- approve or reject the deploy manifest
- approve live-money transition separately
- monitor dashboard and alerts

Fabian does not:
- drag EAs onto charts
- manually import setfiles during normal operation
- reconcile magic numbers by hand
- inspect logs unless an alarm asks for a decision

## Abort Conditions

LiveOps aborts immediately if:

- any chart opens on the wrong terminal
- wrong symbol/timeframe is detected
- setfile hash does not match manifest
- magic number collision exists
- T6 AutoTrading turns on before approval
- T1-T5 load causes T6 degradation
- Darwinex connection is unstable
- UI automation cannot prove the exact chart/EA/setfile state

## First Implementation Task

Before any real deployment, build and test a demo-only dry run:

1. Create one harmless demo EA or use a non-trading logging EA.
2. Create one manifest for `EURUSD M15`.
3. Execute placement automation on T6 with AutoTrading OFF.
4. Archive screenshot and logs.
5. Only after this passes, allow real EA demo manifests.
