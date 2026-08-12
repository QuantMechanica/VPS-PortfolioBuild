# /goal — Drive 1 EA to P8 (Walk-Forward + Stress + News + Stat-Val survived)

Paste this into the `/goal` slash command in Claude Code on the QuantMechanica VPS.
Claude (Board Advisor role) will autonomously maintain the strategy_farm pipeline
+ harvesting until the success criterion below is met, then stop.

---

## Mission

Bring at least **one EA through Phase P8** of the QM5 V5 pipeline. That means
the EA must have survived: P2 in-sample baseline → P3 parameter robustness →
P3.5 cross-symbol robustness → P4 walk-forward out-of-sample (2023-2025) →
P5/P5b/P5c stress + crisis slices → P6 multi-seed → P7 statistical validation
→ P8 news-impact stress.

No "miracle" EA needed. **Solid + manageable drawdown** is enough. Acceptance:
- Walk-forward 2023-2025 OOS Sharpe ≥ 0.6
- Max drawdown ≤ 20%
- Trade count ≥ 30 over the full OOS window
- Survives all P5/P6/P7/P8 robustness sub-gates without DEAD verdict

Stop the loop as soon as this is reached. Notify OWNER in the active operator
channel and leave a clear summary in
`D:/QM/strategy_farm/dashboards/heureka_brief.md`.

---

## Operating context

You are Claude Code on the QuantMechanica VPS, Board Advisor role.

**Canonical references:**
- `C:/QM/repo/CLAUDE.md` — operating manual + 16 hard rules
- `G:/My Drive/QuantMechanica - Company Reference/_HOME.md` — company vault
- Memory: `C:/Users/Administrator/.claude/projects/C--QM-repo/memory/MEMORY.md`
  (auto-loaded; covers all prior bugfixes + architecture decisions)

**Infrastructure already running autonomously:**
| Scheduled Task | Cadence | Role |
|---|---|---|
| `QM_StrategyFarm_Pump_5min` | 5 min | dispatch + build + review + research |
| `QM_StrategyFarm_Health_15min` | 15 min | 11-invariant watchdog → `state/health.json` |
| `QM_StrategyFarm_Repair_Hourly` | 1 h | 7 anti-orphan handlers |
| `QM_MorningBriefing_Vault` | daily 06:00 | the one daily briefing mail + Drive vault |
| `QM_StrategyFarm_RebootDiagnostic_AtStartup` | startup +5 min | one deduplicated cause/recovery mail per Windows boot |
| `QM_StrategyFarm_GmailAlarm_Hourly` | disabled | OWNER policy: no separate PIPELINE FAIL/OK mail |
| `QM_StrategyFarm_QuotaReceiver` | AT STARTUP | Tampermonkey receiver :9090 |
| `QM_StrategyFarm_Cockpit_2min` | 2 min | dashboard render |

You do NOT need to babysit these. Trust them. Intervene only when the
watchdog tells you something is broken.

**Key paths:**
- DB: `D:/QM/strategy_farm/state/farm_state.sqlite`
- Health: `D:/QM/strategy_farm/state/health.json`
- Logs: `D:/QM/strategy_farm/logs/`
- EA code: `C:/QM/repo/framework/EAs/QM5_<id>_<slug>/`
- Reports: `D:/QM/reports/work_items/<id>/QM5_<id>/<run_tag>/summary.json`
- Pipeline scripts: `C:/QM/repo/framework/scripts/p{2,3,35,4,5,5b,5c,6,7,8}_*.py`
- Cockpit: `file:///D:/QM/strategy_farm/dashboards/cockpit.html`

---

## Per-iteration work loop

Each time you wake up (cron, ScheduleWakeup, or autonomous tick), run this loop:

### 1. Check overall progress toward goal

```bash
cd C:/QM/repo && python -c "
import sqlite3
c = sqlite3.connect(r'D:/QM/strategy_farm/state/farm_state.sqlite')
for r in c.execute(\"SELECT phase, verdict, COUNT(*) c FROM work_items WHERE status='done' GROUP BY phase, verdict ORDER BY phase\"):
    print(r)
"
```

If any EA has reached P8 with PASS → check acceptance criteria above. If met,
**execute the stop sequence** (section "Stop conditions" below).

### 2. Read the health snapshot

```bash
cat D:/QM/strategy_farm/state/health.json | python -m json.tool | head -40
```

Or run `farmctl health` to refresh.

For each red invariant, decide:
- **Code bug**? Fix it (commit + push to `agents/board-advisor-session-<date>`).
- **Pipeline state issue**? Run `farmctl repair` to auto-fix where safe.
- **OWNER-class** (codex login, hardware, billing)? Report it directly in the
  active OWNER/operator channel — do not invoke the disabled pipeline mailer.

### 3. Inspect what the pipeline is doing right now

```bash
cd C:/QM/repo && python tools/strategy_farm/farmctl.py pump > /tmp/po.json 2>&1
# Inspect /tmp/po.json: codex_spawns_all, codex_research_spawns, dispatch_work_items
```

If pump shows 0 codex spawns for >15 min AND `codex_auth_broken` is FAIL →
notify OWNER in the active operator channel to run `codex login`.

### 4. Look at where the candidate EAs are

```bash
python -c "
import sqlite3
c = sqlite3.connect(r'D:/QM/strategy_farm/state/farm_state.sqlite')
c.row_factory = sqlite3.Row
for r in c.execute('''SELECT ea_id,
  SUM(CASE WHEN phase=\"P2\" AND verdict=\"PASS\" THEN 1 ELSE 0 END) p2,
  SUM(CASE WHEN phase=\"P3\" AND verdict=\"PASS\" THEN 1 ELSE 0 END) p3,
  SUM(CASE WHEN phase=\"P3.5\" AND verdict=\"PASS\" THEN 1 ELSE 0 END) p35,
  SUM(CASE WHEN phase=\"P4\" AND verdict=\"PASS\" THEN 1 ELSE 0 END) p4,
  SUM(CASE WHEN phase=\"P5\" AND verdict=\"PASS\" THEN 1 ELSE 0 END) p5,
  SUM(CASE WHEN phase=\"P6\" AND verdict=\"PASS\" THEN 1 ELSE 0 END) p6,
  SUM(CASE WHEN phase=\"P7\" AND verdict=\"PASS\" THEN 1 ELSE 0 END) p7,
  SUM(CASE WHEN phase=\"P8\" AND verdict=\"PASS\" THEN 1 ELSE 0 END) p8
  FROM work_items GROUP BY ea_id
  HAVING p2+p3+p35+p4+p5+p6+p7+p8 > 0 ORDER BY p8 DESC, p7 DESC, p6 DESC'''):
    print(dict(r))
"
```

The lead candidate is the EA with the most-advanced PASS phase.

### 5. Identify the current bottleneck

Pick ONE of these (most common in priority order):

1. **Codex auth expired**: `auth.json` >12h old, 0 codex procs, pending builds.
   → Tell OWNER in the active operator channel to run `codex login`. Wait.
2. **No P3+ progression**: lots of P2 PASS but nothing advances. Check pump
   §10c P3 promotion logic, or write recovery if MT5 reports orphaned.
3. **Orphan MT5 reports**: dispatch shows REPORT_MISSING but .htm files
   exist in `D:/QM/mt5/T*/`. Run `python tools/strategy_farm/recover_orphan_reports.py`.
4. **All EAs failing P3+**: strategy quality issue. Look at recent FAIL
   verdict reasons. If all are negative-PnL on the actual strategy (not
   infra), need to ablate further or wait for new approved cards.
5. **MT5 saturated, build queue starved**: lots of work_items pending but no
   builds. Check if synth-variant burst is overloading queue. Pause synth
   for highest-priority EA to free MT5.
6. **Codex slot starvation**: research starved by builds. Adjust
   `MAX_PARALLEL_CODEX_BUILDS` if cards_ready stagnation persists.
7. **Stale claims / dead workers**: repair handlers should catch. If not,
   run `farmctl repair` manually.

### 6. Fix the one identified bottleneck

Small focused commit. Push to `agents/board-advisor-session-2026-05-17` (or
the current dated session branch). NEVER merge into `agents/board-advisor`
without conflict-resolution review.

### 7. Wait until next iteration

Sleep ~15-30 min between iterations (cache stays warm <5 min, 1 cache-miss
buys 30 min wait). Use `ScheduleWakeup` with the same /goal prompt.

If nothing changed in 2 consecutive iterations (`status_changed` events flat
in DB) → wait 60 min before next loop. The system may be doing long MT5
backtests (~30-60 min each).

---

## Escalation rules — when to notify OWNER

`QM_StrategyFarm_GmailAlarm_Hourly` is deliberately disabled: do not send
separate PIPELINE FAIL/OK messages and do not reset its debounce state. Notify
OWNER through the active operator channel. The retained automatic mails are the
single 06:00 MorningBriefing and one cause/recovery explanation after each new
Windows boot.

Escalate immediately for:
- **Codex auth broken** (only OWNER can `codex login`)
- **Disk full** (OWNER needs to clean up — never delete `state/`, `EAs/`,
  `cards_approved/`)
- **MT5 binary missing** under `D:/QM/mt5/T*/` (corrupted install)
- **Pipeline frozen for >2h** (no `status_changed` events, no fixes work)
- **You found a P8 PASS** (the success! → see Stop conditions below)

Do NOT escalate for:
- Normal "strategy quality" FAILs (Codex Pre-Review catches them)
- Single MT5 work_item failure (inline PID check + R5 + R10 handle these)
- Slow throughput (just MT5 chewing through the queue)

---

## Stop conditions — when this /goal is COMPLETE

When ANY EA in `work_items` table has:
- `phase='P8'` AND `verdict='PASS'`
- AND that EA also has PASS verdicts on P7, P6, P5, P4, P3.5, P3, P2

→ Execute the celebration sequence:

```bash
cd C:/QM/repo
# 1. Write the heureka brief
python -c "
import sqlite3, json, datetime as dt
from pathlib import Path
con = sqlite3.connect(r'D:/QM/strategy_farm/state/farm_state.sqlite')
con.row_factory = sqlite3.Row
# Find the EA
winner = con.execute('''
SELECT ea_id, COUNT(*) phases FROM work_items
WHERE verdict='PASS' AND phase IN ('P2','P3','P3.5','P4','P5','P6','P7','P8')
GROUP BY ea_id ORDER BY phases DESC LIMIT 1
''').fetchone()
ea = winner['ea_id']
# Pull P4 OOS stats
p4 = con.execute('SELECT payload_json FROM work_items WHERE ea_id=? AND phase=\"P4\" AND verdict=\"PASS\" LIMIT 1', (ea,)).fetchone()
p4_stats = json.loads(p4['payload_json']).get('recovered_stats', {}) if p4 else {}
text = f'''# HEUREKA — {ea} survived P8

Generated: {dt.datetime.utcnow().strftime(\"%Y-%m-%d %H:%M UTC\")}

## P4 Walk-Forward OOS (2023-2025)
- Sharpe: {p4_stats.get(\"sharpe\", \"?\")}
- Net Profit: {p4_stats.get(\"net_profit\", \"?\")}
- Max DD: {p4_stats.get(\"max_dd\", \"?\")}
- Trades: {p4_stats.get(\"total_trades\", \"?\")}

## Next steps (OWNER decision)
1. Review the per-phase verdicts: \"farmctl pipeline --ea {ea}\"
2. Generate live setfile (RISK_PERCENT mode) via gen_setfile.ps1
3. T6 deployment authorization (OWNER + Board Advisor only per HR rules)
4. Live demo on Darwinex DXZ before any real capital
'''
Path(r'D:/QM/strategy_farm/dashboards/heureka_brief.md').write_text(text, encoding='utf-8')
# Also vault archive
Path(r'G:/My Drive/QuantMechanica - Company Reference/10 Morning Briefing/HEUREKA_{ea}.md'.format(ea=ea)).write_text(text, encoding='utf-8')
print('written: heureka_brief.md + vault copy')
print(text)
"

# 2. Notify OWNER in the active operator channel. Do not invoke the
# OWNER-disabled PIPELINE FAIL/OK mailer.
```

Then EXIT the /goal session. Pipeline keeps running autonomously — Board
Advisor will reactivate when OWNER explicitly asks for T6 deployment
authorization.

---

## Hard guardrails — don't violate these

From `CLAUDE.md` 16 Hard Rules + lessons from today's bugfixes:

- ❌ **Never enable AutoTrading on T_Live**. Only OWNER + Board Advisor
  may flip that — and ONLY after manifest verification + decision-log.
- ❌ **Never manually start `terminal64.exe`**. MT5 is transient
  (per-backtest spawn). Idle terminals waste RAM.
- ❌ **Never `git push --force`** on `agents/board-advisor` or `main`.
  Push session work to `agents/board-advisor-session-<date>` instead.
- ❌ **Never delete** `state/farm_state.sqlite`, `cards_approved/`, EA
  directories under `framework/EAs/QM5_*/`, or `.private/secrets/`.
- ❌ **Never bypass codex_review §A framework_corset** — that gate exists
  to catch real bugs. If Codex keeps producing the same violation, add the
  missing helper to `QM_Indicators.mqh` instead of weakening the check.
- ❌ **Never commit ML libraries** (HR14). Pure mechanical rules only.
- ❌ **Never invent commission/swap/DST values** — must come from broker
  ticker or news_calendar seed file.
- ❌ **Never run `codex login` yourself** — it's interactive. Escalate to
  OWNER if auth breaks.

---

## Useful one-liners (copy-paste during the loop)

```bash
# Where do we stand?
cd C:/QM/repo && python tools/strategy_farm/farmctl.py status

# What's currently running?
powershell.exe -Command "Get-Process -Name codex,claude,terminal64,pwsh | Group-Object Name | %% { '{0}={1}' -f \$_.Name, \$_.Count }"

# Force a health check now
python tools/strategy_farm/farmctl.py health

# Recover orphan MT5 reports
python tools/strategy_farm/recover_orphan_reports.py [--dry-run]

# Reset all stuck active work_items (last resort)
python -c "
import sqlite3; c = sqlite3.connect(r'D:/QM/strategy_farm/state/farm_state.sqlite')
c.execute(\"UPDATE work_items SET status='pending', claimed_by=NULL WHERE status='active' AND updated_at < datetime('now','-2 hours')\")
c.commit()
"

# The separate PIPELINE FAIL/OK Gmail channel is OWNER-disabled.
# Report an escalation through the active OWNER/operator channel.
```

---

## What you are NOT doing

- **Not designing new strategies from scratch** — Codex Research mines
  sources for those. You curate + adjust priorities, you don't write cards.
- **Not running backtests yourself** — pump dispatches to MT5 workers.
- **Not deciding "which strategy is good"** — that's the pipeline phases.
  You unblock the pipeline; the pipeline decides.
- **Not pushing to `agents/board-advisor`** — push to dated session
  branches. OWNER does the merge.
- **Not deploying to T_Live** — that's a separate OWNER+Board-Advisor
  authorization moment, NOT this /goal's scope. This /goal stops at "P8
  PASS achieved", T6 is a follow-up decision.

---

Mission: **drive one solid EA through P8 with manageable DD**. Pipeline is
the engine. You are the mechanic, not the engineer.

When done: write `heureka_brief.md`, notify OWNER in the active channel, exit.
