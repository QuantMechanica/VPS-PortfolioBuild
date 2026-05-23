---
opened_utc: 2026-05-19T02:55Z
raised_by: Board Advisor (observe wake 2026-05-19T02:47:01Z)
severity: medium
class: claude-auth / pump-G0-cycles-wasted
blocks: pump-driven G0 research cadence (research still progresses via the
  hourly scheduled-task claude sessions, so pipeline is not stuck — but
  every per-minute pump claude-G0 spawn currently dies immediately)
flagged_by: autonomous wake 2026-05-19T02:36:40Z (`pump_claude_g0_broken`
  note in `autonomous_wakes.log`)
---

# Pump-spawned `claude` G0 subprocess fails Anthropic OAuth ("Not logged in")

## Pattern

The `QM_StrategyFarm_Tick_5min` pump spawns `claude` CLI processes for
Step 3 G0 research every ~minute (file pattern
`D:/QM/strategy_farm/logs/claude_g0_<UTC>.live.log`).

Sampled live logs from the last few hours:

```
claude_g0_20260519T024904.live.log     35 B  "Not logged in · Please run /login"
claude_g0_20260519T024804.live.log     35 B  "Not logged in · Please run /login"
claude_g0_20260519T024704.live.log     35 B  "Not logged in · Please run /login"
claude_g0_20260519T024604.live.log     35 B  "Not logged in · Please run /login"
claude_g0_20260519T024504.live.log     35 B  "Not logged in · Please run /login"
claude_g0_20260519T024414.live.log    316 B  (prompt-truncation symptom, NOT auth — see Secondary below)
...
```

Grep for `"Not logged in"` over `claude_g0_2026051[89]T*.live.log`
returns the head-limit cap of 100 files (actual hit count higher). The
35-byte literal `"Not logged in · Please run /login\n"` is the Claude
Code CLI's own pre-prompt OAuth-check error — the subprocess never
starts a session; it exits immediately.

## Impact

- The pump runs `farmctl tick` every 5 min; every claude-G0 spawn it
  schedules currently wastes a process slot.
- **Research is NOT blocked**: the hourly scheduled wakes
  (`QM_StrategyFarm_AutonomousWake_Hourly` and
  `QM_StrategyFarm_BoardAdvisor_Hourly`) both run with their own
  scheduled-task claude session and correctly authenticate. Step 3 G0
  research is still landing — every autonomous-wake summary in
  `autonomous_wakes.log` since 14:22:57Z shows `APPROVE ea=...` lines.
- The autonomous wake at 2026-05-19T02:36:40Z explicitly stated:
  > `pump_claude_g0_broken="claude_g0_live_log files at 02:13-02:21Z
  > all 35-110B containing only 'Not logged in - Please run /login' —
  > pump-spawned claude subprocess fails Anthropic OAuth; wake-session
  > claude auth works hence Step 3 is the WORKING G0 path until claude
  > pump auth restored (Board Advisor escalation)"`

So the pipeline is degraded but not stalled: G0 throughput is capped at
the hourly wake cadence (and the hourly wakes are batching 4-5 cards
each, so backlog is still draining).

## Relationship to existing escalations

This is a **new failure-mode bucket** that does NOT overlap the two
currently-open auth-related escalations:

- `2026-05-17_codex_auth_401_websocket.md` — Codex (OpenAI/ChatGPT)
  OAuth stale. That escalation's text explicitly reads:
  > "Claude side (research / G0 / ea-review) is unaffected — only Codex
  > is blocked."
  As of 2026-05-19T02:36Z that statement is **stale**: the pump's
  claude-G0 subprocess is also affected. (The hourly scheduled-task
  claude session remains unaffected, so the assessment that claude is
  "fully working" was based on the wake-session and missed the pump
  cohort.)
- `2026-05-17_smoke_first_run_intermittent_report_missing.md` — MT5
  tester infra, unrelated.

Two independent CLI-OAuth stacks are now stale (Codex chatgpt + Claude
Anthropic). They share the symptom shape (per-process OAuth token
refresh failing on long-running background workloads) but the auth
backends are separate, so OWNER will likely need to re-authenticate
each independently.

## Secondary anomaly (lower priority — not OAuth)

Some pump claude-G0 spawns DO authenticate successfully but receive a
truncated prompt. Example:

```
claude_g0_20260519T024814.live.log  316 B
  "The question prompt was dismissed. Your message was cut off after
   'Then for each draft card in this batch:' — please paste the list
   of cards (paths or IDs) you want reviewed..."
```

That's claude-the-model speaking after a truncated prompt — indicates
the pump is invoking `claude` with stdin/CLI args that cut off
mid-instruction. Distinct from the auth failure. Not blocking; flagging
for the same OWNER session in case the prompt-truncation root cause is
adjacent (same pump invocation path).

## Evidence

- Pump live-log directory: `D:/QM/strategy_farm/logs/claude_g0_*.live.log`
- Autonomous-wake forensic note: `D:/QM/strategy_farm/logs/autonomous_wakes.log`
  line at `2026-05-19T02:36:40Z` (search `pump_claude_g0_broken`).
- File-count evidence: `D:/QM/strategy_farm/logs/` contains 100+ files
  matching `claude_g0_2026051[89]T*.live.log` with body
  `"Not logged in · Please run /login"`. (Grep tool hit head-limit at
  100; full count higher.)

## Suggested OWNER action

Interactive RDP session on the VPS (the OAuth flow needs a browser):

```powershell
# 1. Snapshot the stale auth state before clobbering it
Copy-Item "$HOME\.claude\.credentials.json" `
          "$HOME\.claude\.credentials.json.stale-20260519T0255Z" `
          -ErrorAction SilentlyContinue

# 2. Logout and re-login claude CLI as the pump user
claude logout
claude login   # interactive OAuth — browser pops

# 3. Verify pump cohort can now authenticate
$probe = "D:\QM\strategy_farm\logs\claude_g0_postlogin_probe.log"
claude --print "echo ok" > $probe
type $probe                                    # should show 'ok'

# 4. Let one tick run and inspect the next pump-spawned claude_g0 log
Start-ScheduledTask -TaskName 'QM_StrategyFarm_Tick_5min'
# wait ~90s
Get-ChildItem D:\QM\strategy_farm\logs\claude_g0_*.live.log |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 3 |
  ForEach-Object { Write-Host $_.Name; Get-Content $_.FullName -First 5; Write-Host '---' }
```

Same caveat as the codex_auth_401 escalation: token refresh on this
host has been unreliable across both CLIs lately. The fix is OWNER
re-login, not anything Board Advisor or the pump can do.

## What Board Advisor will NOT do this wake

- No `claude logout` / `claude login` (OAuth requires interactive
  browser — OWNER-class on this VPS).
- No edits to pump invocation in `farmctl.py` or `prompts/` to "fix"
  the secondary prompt-truncation symptom — that's a Codex-side or
  prompt-rendering change outside the observe-wake scope. Flagged here
  for OWNER consideration only.
- No churn on the existing codex_auth_401 or smoke escalation files
  (per DL-046 / `no_keepalive_evidence_churn`).

This file remains the durable record until OWNER re-auths claude.
Resolution check: pump claude_g0 logs stop producing 35-byte "Not
logged in" payloads → move this file to `_resolved/` with a closure
note.
