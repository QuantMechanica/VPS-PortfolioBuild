# Factory post-start health patch: OFF-window deferral

- Router task: `c47aed35-89a1-4a26-a870-a496cd9d105d`
- Branch: `agents/board-advisor`
- Date: 2026-08-16
- Disposition: `REVIEW — DEFERRED BY CEREMONY-CRITICAL OFF-WINDOW GUARD`

## Decision

No implementation was made. The routed payload permits mutation of
`tools/strategy_farm/factory_restart_health.ps1` and the abort path in
`tools/strategy_farm/Factory_ON.ps1` only inside an existing factory OFF
window. It also explicitly forbids Codex from running Factory_OFF or
Factory_ON to create that window.

The canonical factory was ON at inspection:

- `D:\QM\strategy_farm\state\FACTORY_OFF.flag`: absent;
- all five AI quiet-zone tasks were enabled (Codex, Gemini, Claude
  orchestration, CodexFleetPacer, and AgyGovernor);
- `QM_StrategyFarm_AgentRouter_5min` and `QM_StrategyFarm_Pump_5min` were
  enabled;
- ten governed `terminal_worker.py` processes were visible: T1 through T10.
  No worker was stopped or interrupted.

The process query also saw its own short-lived shell process and therefore
reported 11 strategy-farm-related processes; only the ten `pythonw.exe`
terminal-worker rows are relevant to factory state.

Mutating ceremony code while this state is live would violate the task's
authorization boundary and could create a source/runtime mismatch before the
next OWNER/Claude OFF/ON decision is minted.

## Hash-bound unchanged files

The guarded files and their unchanged SHA-256 values at deferral were:

```text
factory_restart_health.ps1
F52E8F9DBD84C428773C3C2FAB335EF160DA8481223F9DE0C5CFB399B1036FE4

Factory_ON.ps1
890D1637F56E8FB119A8DCFD6B5B5EE0F5F39EE1766A1F4CD764FB94201B9D83

Test-FactoryRestartPostStartHealth.ps1
22600A2CDD1F47416B1488BACE025379BAF26DAC898EBFA4B51B34E87601096C
```

No dry-run of the requested ceremony-incomplete marker was attempted because
the marker implementation itself is an OFF-window mutation and does not yet
exist in the guarded source.

## Focused verification

The unchanged baseline suite was run read-only:

```text
powershell -NoProfile -ExecutionPolicy Bypass \
  -File tools/strategy_farm/tests/Test-FactoryRestartPostStartHealth.ps1
PASS Test-FactoryRestartPostStartHealth.ps1 (28 assertions)
```

This confirms the current baseline remains green and preserves the already
documented defect reproduction; it is not evidence that the requested patch
has landed.

## Exact next authorized OFF-window work

During the next OWNER/Claude-controlled OFF window, the implementer must apply
all seven points and eight regressions from
`docs/ops/evidence/8d6c7ef9_factory_post_start_health_off_window_deferral_2026-08-16.md`,
including the Router-only running-start allow-list, ignoring
`LastTaskResult` only for an accepted current Running instance, treating
`0x800710E0` as neither success nor execution failure, and naming sorted
starved tasks at the deadline.

The same OFF-window patch must also write a machine-checkable
ceremony-incomplete marker on every Factory_ON exit after the mutation point
when the AI quiet zone was not released. `farmctl health` and the cockpit must
surface that marker as CRITICAL with the message `ceremony incomplete: AI
lanes not released`; successful quiet-zone release must clear it. The required
marker-set and marker-clear dry-runs remain mandatory before the next runtime
activation decision.

## Safety and scope

- Factory_OFF and Factory_ON were not invoked.
- No scheduled-task state was changed.
- No worker, terminal, T1-T10 backtest, T_Live, or AutoTrading state was
  changed.
- No ceremony-critical source or test file was edited.
- No pipeline verdict is asserted.
