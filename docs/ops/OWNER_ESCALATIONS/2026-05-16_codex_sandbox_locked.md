# Codex Windows sandbox account locked out — strategy_farm builds frozen

**Detected:** 2026-05-16 ~08:25Z (autonomous wake at 08:17Z)
**Severity:** Pipeline-blocking. No new EA builds can succeed until this clears.
**Scope:** Every `farmctl build-ea` Codex invocation. Affects all approved cards
in `D:/QM/strategy_farm/artifacts/cards_approved/` until restored.

## What's broken

Codex CLI v0.125.0 (per the local catalog memory) uses `CreateProcessWithLogonW`
for its Windows sandbox subprocesses (config `~/.codex/config.toml` →
`[windows] sandbox = "elevated"`). On this 08:17Z wake's QM5_1046 build attempt,
every subprocess call from Codex returned:

```
ERROR codex_core::exec: exec error: windows sandbox: CreateProcessWithLogonW failed: 1326
... (many)
ERROR codex_core::exec: exec error: windows sandbox: CreateProcessWithLogonW failed: 1909
```

- `1326` = `ERROR_LOGON_FAILURE` — sandbox virtual account's password is wrong/expired
- `1909` = `ERROR_ACCOUNT_LOCKED_OUT` — account locked after the failed attempts

Codex itself runs (CPU active, prompt parsed, JSON emitted to stdout). What
fails is every child `pwsh.exe` invocation Codex needs for build-check / compile
/ smoke. Codex then emits a `blocked_reason` JSON describing the failure.

## Root-cause window

- 06:17Z wake's Codex (QM5_1045) **succeeded** end-to-end and wrote ff2e7934.json
  at 07:01Z with `blocked_reason="SP500/SPY required..."` — sandbox was healthy.
- 07:17Z wake's Codex (QM5_1047, task 076cab30) **never wrote a build_result**.
  Wake also never logged `WAKE_EXITED` in autonomous_wakes_invocation.log.
  Almost certainly the same lockout hit during that wake; lockout likely
  triggered by the high subprocess count of the 06:17Z wake.
- 08:17Z wake (this one): confirmed lockout — full error trail in
  `D:/QM/strategy_farm/logs/codex_QM5_1046_ad4eeb34_v2.log`.

## What the 08:17Z wake did

1. Patched `QM5_1046_maroy-intraday-vwap-exit.md` to use `NDX.DWX` primary
   (SPX500.DWX unavailable in DWX feed, per OWNER 2026-05-16 ruling). The
   patch is good — re-build will use the corrected card once sandbox is back.
2. Recorded `ad4eeb34` (QM5_1046) and `076cab30` (QM5_1047) as `blocked` with
   the sandbox-lockout reason, so the DB is consistent and no stale `pending`
   row blocks future Step-1 review on those EAs.
3. Wrote `feedback_spx500_card_port_before_build.md` memory so future wakes
   patch 1047/1048/1049 cards (still SPX500-primary) before invoking Codex.

## What OWNER needs to do

The sandbox lockout is OS-Controller territory (CLAUDE.md "What This Role IS NOT"
→ Not OS-Controller: no agent hire / pause / unpause / model swap). I am not
touching `~/.codex/config.toml` or the locked Windows account from this wake.

Options for OWNER:

**A. Restore the elevated-sandbox virtual account credentials.**
   Likely steps: identify the sandbox-account name in Windows User Accounts,
   unlock it (Computer Management → Local Users and Groups, or `net user
   <name> /active:yes`), reset its password, and update Codex's stored
   credential. Without the codex-internal credential-store layout I cannot
   give the exact command.

**B. Switch Codex sandbox mode to a non-elevated alternative.**
   Edit `~/.codex/config.toml` from `[windows] sandbox = "elevated"` to a
   mode that does not use `CreateProcessWithLogonW` (e.g. `none` or
   `workspace-write` — exact names from `codex exec -s --help`). This trades
   sandbox isolation for build availability. Acceptable for the strategy_farm
   factory pipeline since Codex's task is constrained by the build prompt
   and the EA framework's `build_check.ps1` gate, not by OS isolation.

**C. Pass `--dangerously-bypass-approvals-and-sandbox` on each `codex exec`.**
   Same trade-off as B but per-invocation. Would require editing
   `tools/strategy_farm/prompts/autonomous_loop.md` Step 2 to add the flag
   to the suggested codex command, and the autonomous wake itself.

## Disable the hourly wake until fixed?

Not strictly necessary. With both blocked tasks recorded, the next 09:17Z wake
will see no Step-1 review work, walk Step 2 → next approved card without a
task (QM5_1048 Estrada or QM5_1049 McConnell), try to build, hit the same
lockout, escalate again. That's wasted Codex tokens + a third escalation file.

If you don't intend to fix today: disable temporarily

```powershell
Disable-ScheduledTask -TaskName 'QM_StrategyFarm_AutonomousWake_Hourly'
```

The :47 Board Advisor observe wake is unaffected (it doesn't invoke Codex).

## Evidence files

- `D:/QM/strategy_farm/logs/codex_QM5_1046_ad4eeb34.log` (v1 — stdin-hang)
- `D:/QM/strategy_farm/logs/codex_QM5_1046_ad4eeb34_v2.log` (v2 — full sandbox error trail)
- `D:/QM/strategy_farm/artifacts/builds/ad4eeb34-c502-4007-a93a-0e1c9d06b7c7.json`
- `D:/QM/strategy_farm/artifacts/builds/076cab30-3b2a-41d1-a430-02c596e6bcad.json`
- `D:/QM/strategy_farm/logs/autonomous_wakes_invocation.log` (gap pattern: 07:17Z and 08:17Z without WAKE_EXITED)
