# QM Strategy Farm — Post-Reboot Restart Prompt

Paste this whole file into a fresh Claude Code session on the VPS after a
Windows-update reboot (or any unplanned VPS restart). Claude (Board Advisor
role) then walks through the verification + kickstart steps below and
reports back.

---

## Context for Claude

You are Claude Code on the QuantMechanica VPS, Board Advisor role. The VPS
just rebooted (Windows Update / unscheduled). I (OWNER) need you to bring the
strategy_farm pipeline back into a running state.

**Canonical references (read if unsure):**
- `C:/QM/repo/CLAUDE.md` — your operating manual
- `G:/My Drive/QuantMechanica - Company Reference/_HOME.md` — company vault
- Memory file at `C:/Users/Administrator/.claude/projects/C--QM-repo/memory/MEMORY.md` —
  prior-conversation context (auto-loaded; you don't have to read it manually)

**What the pipeline normally looks like when healthy:**
- ~5 Codex builds and ~1 Codex research running in parallel
- 1–2 Claude sessions (G0 batch / review / research)
- 5 MT5 terminals (T1–T5) running for backtests
- `QM_StrategyFarm_QuotaReceiver` listening on 127.0.0.1:9090
- Cockpit refreshing every 2 min at `D:/QM/strategy_farm/dashboards/cockpit.html`

---

## Step 1 — Verify scheduled tasks (should auto-resume)

These tasks should self-recover after reboot. Confirm state:

```powershell
Get-ScheduledTask -TaskName 'QM_StrategyFarm_*' |
  Select-Object TaskName, State |
  Format-Table -AutoSize
```

Expected:
- `QM_StrategyFarm_QuotaReceiver`         → **Running** (AT STARTUP trigger)
- `QM_StrategyFarm_Pump_5min`             → **Ready** (fires every 5 min)
- `QM_StrategyFarm_Cockpit_2min`          → **Ready** (fires every 2 min)
- `QM_StrategyFarm_AutonomousWake_Hourly` → **Ready**
- `QM_StrategyFarm_BoardAdvisor_Hourly`   → **Ready**
- `QM_StrategyFarm_Dashboard_Hourly`      → **Ready**
- `QM_StrategyFarm_Tick_5min`             → **Ready**

If any are **Disabled** that should be Ready/Running, re-enable:

```powershell
Enable-ScheduledTask -TaskName '<task name>'
```

Confirm the receiver actually bound to port 9090:

```powershell
Get-NetTCPConnection -LocalPort 9090 -State Listen -ErrorAction SilentlyContinue
```

If port not listening, start the receiver task manually:
`Start-ScheduledTask -TaskName 'QM_StrategyFarm_QuotaReceiver'`

---

## Step 2 — Launch MT5 terminals T1–T5

MT5 does NOT auto-start on boot. Spawn all 5 factory terminals:

```powershell
foreach ($t in 'T1','T2','T3','T4','T5') {
  Start-Process -FilePath "D:/QM/mt5/$t/terminal64.exe"
}
```

**Do NOT touch** `C:/QM/mt5/T6_Live/terminal64.exe` — live trading, OWNER+Board
Advisor only per CLAUDE.md hard rules.

Wait 30 s, then confirm all 5 are up:

```powershell
Get-Process -Name terminal64 |
  Select-Object Id, @{N='Path';E={$_.Path}} |
  Format-Table -AutoSize
```

You should see 5 rows, one per T1–T5 path.

---

## Step 3 — Manual step for OWNER (Chrome tabs)

The Tampermonkey scrapers only tick while their Chrome tabs are open. After
reboot, Chrome typically restores the previous session — but if not, OWNER
should re-open these two tabs:

- https://chatgpt.com/codex/cloud/settings/analytics
- https://claude.ai/settings/usage

After 60–90 s, the quota snapshot at
`D:/QM/strategy_farm/state/quota_snapshot.json` should have fresh
`received_at` timestamps. Verify:

```bash
curl -s http://127.0.0.1:9090/quota | python -c "import sys,json; d=json.load(sys.stdin); [print(k, d[k].get('received_at')) for k in d]"
```

If timestamps are older than 5 minutes, ask OWNER to refresh the two tabs.

---

## Step 4 — Kick the pipeline

Run one pump manually to immediately resume work (instead of waiting up to
5 min for the scheduled trigger):

```bash
cd C:/QM/repo && python tools/strategy_farm/farmctl.py pump 2>&1 | head -120
```

Read the JSON output. Expected:
- `codex_spawns_all`: 0–10 entries (newly-spawned or "live log activity"-skipped)
- `codex_research_spawn.spawned`: true (if no fresh codex_research log)
- `claude_g0_spawn` / `claude_review_spawn` / `claude_research_spawn`: depending
  on draft / done-no-review state
- `build_records`: 0+ (completed builds the pump just recorded)
- `dispatch`: MT5 work-item claims

---

## Step 5 — Render cockpit + status snapshot

```bash
cd C:/QM/repo && python tools/strategy_farm/render_cockpit.py
python tools/strategy_farm/farmctl.py status 2>&1 | head -40
```

---

## Step 6 — Brief OWNER

Reply with a short status summary covering:

1. **Scheduled tasks:** all Ready/Running ✅ — or list which ones are off.
2. **MT5 fleet:** 5/5 terminals up — or which are missing.
3. **Quota receiver:** port 9090 listening, last codex/claude snapshot ages.
4. **Pipeline state:** how many builds active, research in flight, draft
   cards waiting on G0, approved cards on disk, pending sources.
5. **First anomaly seen since reboot (if any):** failed builds, orphaned
   procs, blocked tasks, stale work_items.
6. **What OWNER needs to do:** typically just "re-open the 2 Chrome tabs
   for Tampermonkey scrapers" — nothing else.

Format: 6–10 lines, no fluff. Cockpit link at the bottom:
`file:///D:/QM/strategy_farm/dashboards/cockpit.html`

---

## Common post-reboot anomalies

- **No fresh quota snapshot** → Chrome tabs not yet open. Tell OWNER.
- **Stale codex/python procs leftover from pre-reboot** → unlikely (reboot
  killed them), but if `Get-Process codex` shows procs with very old
  StartTime, those are zombies — `Stop-Process -Id <pid> -Force` them.
- **Stale `live_log` files marked < 60s but no actual process** → can
  cause pump's "live log activity within 60s" skip. Touch them to reset,
  OR just wait one more pump cycle and they'll age out.
- **work_items stuck in 'active' with no terminal claimed** → orphan from
  pre-reboot MT5 worker. `farmctl.py` has no built-in reset; check
  `claimed_by` and clear via SQL if needed:
  ```bash
  python -c "
  import sqlite3; c = sqlite3.connect(r'D:/QM/strategy_farm/state/farm_state.sqlite')
  c.execute(\"UPDATE work_items SET status='pending', claimed_by=NULL WHERE status='active'\")
  c.commit()
  "
  ```
- **Active source claimed by codex/claude with no live process** → similar
  recovery. Check `sources WHERE status='active'` against running procs; if
  no matching live_log activity within 5 min, reset:
  ```bash
  python -c "
  import sqlite3; c = sqlite3.connect(r'D:/QM/strategy_farm/state/farm_state.sqlite')
  c.execute(\"UPDATE sources SET status='pending', assigned_worker=NULL WHERE status='active'\")
  c.commit()
  "
  ```

---

## Do NOT do these on restart

- Re-install scheduled tasks (they survive reboots — only re-enable if Disabled)
- Touch T6_Live MT5 terminal
- git push / cherry-pick / branch swap unless OWNER explicitly asks
- Delete `D:/QM/strategy_farm/state/farm_state.sqlite` (canonical pipeline state)
- Clear `D:/QM/strategy_farm/logs/` (history needed for last_lines tail)
