# QM Strategy Farm — Post-Reboot Restart Prompt

Paste this whole file into a fresh Claude Code session on the VPS after a
Windows-update reboot (or any unplanned VPS restart). Claude (Board Advisor
role) walks through the verification + kickstart steps below and reports back.

---

## Context for Claude

You are Claude Code on the QuantMechanica VPS, Board Advisor role. The VPS
just rebooted. I (OWNER) need you to bring the strategy_farm pipeline back
into a running state.

**Canonical references (read if unsure):**
- `C:/QM/repo/CLAUDE.md` — your operating manual
- `G:/My Drive/QuantMechanica - Company Reference/_HOME.md` — company vault
- Memory file at `C:/Users/Administrator/.claude/projects/C--QM-repo/memory/MEMORY.md` —
  prior-conversation context (auto-loaded; you don't have to read it manually)

**Pipeline architecture refresher (so you don't repeat the 2026-05-17 mistakes):**
- **MT5 is TRANSIENT**, not a service. `run_smoke.ps1` launches a fresh
  `terminal64.exe /portable /config:tester.ini` per backtest, waits for
  exit, parses the report, writes `summary.json`. Do **NOT** manually
  start `terminal64.exe` to "ensure terminals are running" — that just
  creates idle ghost processes that waste RAM and help nothing.
- **Pump-task uses explicit `python.exe`** path, not `py.exe -3`. The
  Python launcher does not have a Python 3 registered under SYSTEM user
  and silently exits with code 112. Already fixed; should survive reboot.
- **5 layers of autonomous recovery** are running (see Step 1). Most
  pre-2026-05-17 manual interventions are now handled by them.

**What a healthy pipeline looks like:**
- ~5–10 Codex builds + 0–3 Codex research + 0–3 Codex reviews + 0–1 Codex G0
- ~1–3 Claude sessions (G0 batch / review / research)
- 1–5 transient terminal64.exe procs (one per active backtest in flight)
- `QM_StrategyFarm_QuotaReceiver` listening on 127.0.0.1:9090
- Cockpit refreshing every 2 min at `D:/QM/strategy_farm/dashboards/cockpit.html`
- Morning brief lands daily at 07:00 local in
  `G:/My Drive/QuantMechanica - Company Reference/10 Morning Briefing/`

---

## Step 1 — Verify scheduled tasks (should auto-resume)

```powershell
Get-ScheduledTask -TaskName 'QM_StrategyFarm_*' |
  Select-Object TaskName, State |
  Format-Table -AutoSize
```

Expected — **all of these should be Ready or Running**:

| Task                                       | Trigger          | Purpose                                |
|--------------------------------------------|------------------|----------------------------------------|
| `QM_StrategyFarm_QuotaReceiver`            | AT STARTUP       | Tampermonkey HTTP receiver on :9090    |
| `QM_StrategyFarm_Pump_5min`                | every 5 min      | Continuous pipeline pump               |
| `QM_StrategyFarm_Cockpit_2min`             | every 2 min      | Cockpit dashboard render               |
| `QM_StrategyFarm_Health_15min`             | every 15 min     | 10-invariant watchdog → health.json    |
| `QM_StrategyFarm_Repair_Hourly`            | every 1 h        | Auto-fix 5 stuck-state classes         |
| `QM_StrategyFarm_GmailAlarm_Hourly`        | every 1 h        | Mail on FAIL transition (debounced)    |
| `QM_StrategyFarm_MorningBrief_0700`        | daily 07:00      | Markdown brief → cockpit + Drive vault |
| `QM_StrategyFarm_AutonomousWake_Hourly`    | hourly           | (legacy ad-hoc wake; OK if disabled)   |
| `QM_StrategyFarm_BoardAdvisor_Hourly`      | hourly           | (legacy; OK if disabled)               |
| `QM_StrategyFarm_Dashboard_Hourly`         | hourly           | Heureka dashboard render               |
| `QM_StrategyFarm_Tick_5min`                | every 5 min      | Legacy dispatch tick (mostly no-op now)|

If any **should-be-Ready** is `Disabled`, re-enable:
```powershell
Enable-ScheduledTask -TaskName '<task name>'
```

Confirm port 9090 is listening (receiver alive):
```powershell
Get-NetTCPConnection -LocalPort 9090 -State Listen -ErrorAction SilentlyContinue
```

If empty, start the receiver task manually:
```powershell
Start-ScheduledTask -TaskName 'QM_StrategyFarm_QuotaReceiver'
```

---

## Step 2 — Manual step for OWNER (Chrome tabs)

The Tampermonkey scrapers only tick while their Chrome tabs are open.
Chrome usually restores sessions on reboot; if not, OWNER should re-open:

- https://chatgpt.com/codex/cloud/settings/analytics
- https://claude.ai/settings/usage

After 60–90 s verify both have fresh `received_at` timestamps:
```bash
curl -s http://127.0.0.1:9090/quota | python -c "import sys,json; d=json.load(sys.stdin); [print(k, d[k].get('received_at')) for k in d]"
```

If timestamps are older than 5 minutes, ask OWNER to refresh the two tabs.

---

## Step 3 — Kick the pipeline (so we don't wait 5 min for the first pump)

```bash
cd C:/QM/repo && python tools/strategy_farm/farmctl.py pump > /tmp/pump.json 2>&1
python -c "
import json; d = json.load(open('/tmp/pump.json'))
print('codex builds:  ', len([s for s in (d.get('codex_spawns_all') or []) if s.get('spawned')]))
print('codex reviews: ', len([s for s in (d.get('codex_review_spawns') or []) if s.get('spawned')]))
print('codex research:', len([s for s in (d.get('codex_research_spawns') or []) if s.get('spawned')]))
print('codex g0:      ', 1 if (d.get('codex_g0_spawn') or {}).get('spawned') else 0)
print('claude g0:     ', 1 if (d.get('claude_g0_spawn') or {}).get('spawned') else 0)
print('claude review: ', 1 if (d.get('claude_review_spawn') or {}).get('spawned') else 0)
print('claude research:',1 if (d.get('claude_research_spawn') or {}).get('spawned') else 0)
dw = d.get('dispatch_work_items',{})
print('MT5 dispatch:  ', len(dw.get('actions') or []), 'actions, busy', len(dw.get('busy_terminals') or []), '/ 5')
"
```

You should see at least: some codex spawns + a few dispatch claims.

If `0 actions, busy 0 / 5` AND `work_items pending > 5` AND `0 codex spawns`,
then something deeper is wrong — re-check Step 1 + run `farmctl health`.

---

## Step 4 — Refresh watchdog + repair pass

```bash
cd C:/QM/repo && python tools/strategy_farm/farmctl.py health 2>&1 | tail -2
python tools/strategy_farm/farmctl.py repair 2>&1 | tail -2
```

These two are normally on scheduled tasks (15 min / 1 h) — running them
now gives an immediate snapshot of red invariants and clears any stale
state left over from the reboot.

---

## Step 5 — Render cockpit + write morning brief

```bash
cd C:/QM/repo && python tools/strategy_farm/render_cockpit.py
python tools/strategy_farm/morning_brief.py
```

---

## Step 6 — Brief OWNER

Read `D:/QM/strategy_farm/dashboards/morning_brief.md` (or the freshly-
written vault copy under `10 Morning Briefing/`). That file already
contains the right summary structure. In your message:

1. Quote the headline + health line (e.g. "MOMENTUM BUILDING · Pipeline
   health: ATTENTION · 2 red 1 yellow 7 green").
2. Note any FAIL invariants that just appeared post-reboot — likely
   `cards_ready_stagnation` (will clear in 2-3 pump cycles) or
   `quota_snapshot_fresh` (tabs not yet open).
3. State whether OWNER needs to do anything: usually just "re-open the
   2 Chrome tabs for Tampermonkey scrapers".
4. End with: `Cockpit: file:///D:/QM/strategy_farm/dashboards/cockpit.html`

Keep it 6–10 lines.

---

## Common post-reboot anomalies (most are auto-recovered now)

- **No fresh quota snapshot** → Chrome tabs not yet open. Tell OWNER.
  Watchdog `quota_snapshot_fresh` invariant already flags this.

- **Many work_items "active" with no terminal64 procs** → expected for a
  short window post-reboot. The pump's **inline worker-PID check**
  releases them within 1 min of the next pump cycle. Repair `R5_dead_terminal`
  catches anything that slips through within the hour. Do NOT manually
  reset via SQL — let the layers do their job. Only intervene if
  `farmctl repair` doesn't clear them after 2 cycles.

- **Stranded `active` source (status='active', no codex/claude running)** →
  Repair `R2` handles this. Sit tight; will clear within 1 hour.

- **Codex review FAIL clustering** → if `farmctl health` shows
  `codex_review_fail_rate_1h: FAIL`, inspect a recent verdict JSON in
  `D:/QM/strategy_farm/artifacts/verdicts/codex_review_*.json` for the
  finding pattern. If it's the phantom `status` field (regression),
  the `prompts/SCHEMAS.md` got out of sync — DO check vs current
  `build_result.json` schema before re-running.

- **Pump task LastResult ≠ 0** → first check the action's `Execute` field:
  ```powershell
  (Get-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min').Actions | Format-List
  ```
  Should be `C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe "C:\QM\repo\tools\strategy_farm\run_pump_task.py"`.
  If `Execute = py.exe`, the SYSTEM-user Python launcher bug is back —
  re-install with explicit python.exe path. Log content lives at
  `D:/QM/strategy_farm/logs/pump_task_<UTC>.log`.

- **Watchdog Gmail alarm fires immediately after reboot** → expected; the
  fingerprint state file was reset by the dead pump. It'll re-debounce
  on next 1-hour cycle.

---

## Do NOT do these on restart

- ❌ **Do NOT manually start `terminal64.exe`** to "ensure MT5 is running".
  MT5 is transient (per-backtest spawn by run_smoke.ps1). Idle terminals
  help nothing.
- ❌ Re-install scheduled tasks. They survive reboots — only re-enable if
  `Disabled`.
- ❌ Touch `C:/QM/mt5/T6_Live/terminal64.exe` — live trading slot,
  OWNER+Board Advisor only per CLAUDE.md hard rules.
- ❌ `git push` / cherry-pick / branch swap unless OWNER explicitly asks.
- ❌ Delete `D:/QM/strategy_farm/state/farm_state.sqlite` — canonical
  pipeline state.
- ❌ Clear `D:/QM/strategy_farm/logs/` — history needed by repair handler
  freshness checks.
- ❌ Manually SQL-reset stranded work_items unless pump's inline PID check
  has failed to do it after 2 cycles.

---

## Useful one-liners (for during-day checks too)

```bash
# Where do we stand right now?
cd C:/QM/repo && python tools/strategy_farm/farmctl.py status

# What's pending?
python tools/strategy_farm/farmctl.py work-items --status pending | head -30

# Force a health check now
python tools/strategy_farm/farmctl.py health

# Force a repair pass now
python tools/strategy_farm/farmctl.py repair

# Force a pump now
python tools/strategy_farm/farmctl.py pump > /tmp/pump.json

# Show the brief
cat D:/QM/strategy_farm/dashboards/morning_brief.md

# Send fresh Gmail alarm (debounce-state reset)
rm D:/QM/strategy_farm/state/gmail_alarm_state.json
python tools/strategy_farm/gmail_alarm.py
```
