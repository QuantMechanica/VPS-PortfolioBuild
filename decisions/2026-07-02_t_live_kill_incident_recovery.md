# T_Live Kill Incident + Recovery — 2026-07-02

**Severity:** Hard-Rule-grade incident, self-inflicted, recovered in ~31 seconds.

## Timeline (UTC)
- 12:08:14 — Claude ran a T5 tester-cleanup before launching the T-WIN v3 backtest:
  `Get-CimInstance ... | Where-Object { $_.CommandLine -match 'T5' } | Stop-Process`.
  PowerShell `-match` is case-insensitive; the pattern `T5` matched the substring
  `t5` inside `C:\QM\mt5\...` and `D:\QM\mt5\...` — i.e. EVERY MT5 terminal on the
  box, including **T_Live (PID 19028)**. Killed: T_Live, one stale factory dispatch
  terminal (T4), and the intended v2exit leftovers.
- 12:08:45 — Claude relaunched T_Live: `C:\QM\mt5\T_Live\MT5_Base\terminal64.exe /portable`.
- 12:09:05 — Journal verified: account 4000090541 authorized on Darwinex-Live,
  terminal synchronized **0 positions / 1 order** (identical to the pre-kill sync at
  13:43 local — no open positions existed during the outage window), all 13 sleeve
  EAs loaded successfully, "trading has been enabled - hedging mode". No
  "automated trading disabled" lines — algo trading state persisted ON.

## Impact
- ~31s terminal downtime. Server-side state (positions/orders) lives at the broker
  and was untouched; 0 open positions during the window; the 1 pending order synced
  back intact. No trades missed (no sleeve signals in the window).

## Root cause
Substring process-matching against MT5 command lines. `'T5'` ⊂ `'mt5'`
case-insensitively. The same class of bug as the watchdog/purge scoping issues
fixed earlier today — process selection MUST be path-anchored.

## Remediation (binding)
- NEVER select terminal processes by bare `T<n>` substring. Anchor the path:
  `-match '\\mt5\\T5\\'` (factory root only) AND exclude live explicitly:
  `-notmatch 'T_Live'` — both, always (defense in depth; this is the same pattern
  Factory_OFF.ps1 uses).
- Authority note: restart + verification performed under OWNER+Claude T_Live
  authority; no AutoTrading toggle change was needed (state persisted).

## Evidence
- `C:\QM\mt5\T_Live\MT5_Base\logs\20260702.log` — kill at 14:08 local, restart,
  reconnect, 13 EA loads, sync 0/1.
