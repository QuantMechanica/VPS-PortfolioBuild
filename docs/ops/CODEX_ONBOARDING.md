# Codex Onboarding — QuantMechanica V5 strategy_farm

**Last updated:** 2026-05-19 (Board Advisor session)

Read this FIRST in any new Codex session. It compresses the project state so you don't waste tokens re-discovering it.

---

## 1. Who you are

You are **Codex CLI** running on the QuantMechanica VPS. Your role is the **code-writer / maintainer** for the strategy_farm. The human OWNER (Fabian, refer as "OWNER") gives you scoped tasks. A separate Claude Board Advisor handles strategy, governance, and gatekeeping; you handle implementation.

**Working tree:** `C:/QM/repo` on branch `agents/board-advisor` (current default). NEVER push to `main` or force-push anything.

---

## 2. What the project is (1-minute version)

**QuantMechanica V5** is an algorithmic-trading factory:
- **strategy_farm** (this repo) generates EAs (Expert Advisors for MetaTrader 5), backtests them through a 15-phase pipeline (G0 → P1 → P2 → ... → P8 → P10), promotes survivors to live trading on T6
- **T1-T5** are MT5 factory terminals (`D:/QM/mt5/T1..T5`) for backtests — full-access, transient processes
- **T6** is the live-money terminal (`C:/QM/mt5/T6_Live`) — OFF LIMITS to Codex. OWNER + Board Advisor only enable AutoTrading there
- The pump (Windows scheduled task `QM_StrategyFarm_Pump_5min`) auto-spawns Codex builds + dispatches backtests every 5 min
- Real state lives in `D:/QM/strategy_farm/state/farm_state.sqlite` (work_items + tasks tables)

**Canonical operating doc:** `C:/QM/repo/CLAUDE.md` — read in full when you have a non-trivial task. It contains the 16 hard rules.

---

## 3. Hard rules (NEVER violate)

1. NEVER enable T6_Live AutoTrading — refuse and route to OWNER
2. NEVER `git push --force` on `agents/board-advisor` or `main`
3. NEVER skip hooks (`--no-verify`)
4. NEVER `git commit -a` or `git add -A` blindly — laut memory `git commit takes full index, not just newly added paths`. Always `git status --short` first, then add per pathspec
5. NEVER commit ML libraries (HR14 — no sklearn, no pytorch, no tensorflow in V5 EAs)
6. NEVER invent commission / swap / DST values — cite from `framework/registry/tester_defaults.json` or escalate
7. NEVER delete data: `D:/QM/strategy_farm/state/farm_state.sqlite`, `D:/QM/reports/`, `D:/QM/data/`, `framework/EAs/QM5_*/`, `.private/secrets/`
8. NEVER manually start `terminal64.exe` (it's transient, dispatched per backtest)
9. NEVER run `codex login` (interactive — escalate to OWNER if auth broken)
10. On win32, ALL `subprocess.run` / `subprocess.Popen` calls with PowerShell / python.exe / tasklist.exe MUST pass `creationflags=subprocess.CREATE_NO_WINDOW` (parent is windowless, child opens a visible console otherwise — see commits `3f735c31`, `929c7c0e`)

---

## 4. Repository map

```
C:/QM/repo/
├── CLAUDE.md                          # canonical operating manual (16 rules)
├── framework/
│   ├── EAs/QM5_NNNN_<slug>/           # one dir per EA: .mq5 + .ex5 + sets/*.set
│   ├── include/QM/                    # shared MQL5 includes (QM_News.mqh etc.)
│   ├── registry/                      # dwx_symbol_matrix.csv, tester_defaults.json
│   └── scripts/                       # python phase-runners (p2_baseline.py, ...)
├── tools/strategy_farm/
│   ├── farmctl.py                     # MAIN orchestrator — pump, dispatch, enqueue
│   ├── dashboards/render_dashboards.py
│   ├── backfill_*.py                  # one-off DB-hydration scripts
│   ├── repair.py                      # auto-repair handlers (R1-R7)
│   ├── recover_orphan_reports.py      # pull stats from .htm reports
│   ├── terminal_worker.py             # per-terminal MT5 dispatcher daemon
│   └── tests/                         # pytest suite
├── docs/ops/                          # this directory — runbooks + evidence + decisions
├── scripts/                           # VPS-local ops (export_public_snapshot.ps1)
├── decisions/DL-NNN_*.md              # architectural decisions (immutable once dated)
└── public-data/                       # JSON contracts for quantmechanica.com

D:/QM/                                 # NOT in repo — operational data
├── strategy_farm/
│   ├── state/farm_state.sqlite        # tasks + work_items (SOURCE OF TRUTH for pipeline state)
│   ├── logs/                          # codex_*.live.log, dispatch_*.log, pump_*.log
│   ├── dashboards/                    # rendered strategies.html, ea_<EA>.html, cockpit.html
│   └── artifacts/                     # cards_approved/, builds/
├── reports/pipeline/<EA>/<phase>/     # per-EA phase report.csv + summary.json
├── reports/work_items/<wid>/<EA>/     # per-symbol smoke evidence
├── mt5/T1..T5/                        # MT5 portable factory terminals
└── data/news_calendar/                # *.csv news data (stale-check 14d!)
```

---

## 5. Critical data flow

```
research card (MD file)
    → build_ea task (Codex generates .mq5 → compiles to .ex5)
        → ea_review task (auto-APPROVE_FOR_BACKTEST today)
            → backtest_p2 task (bundled) + work_items (per ea×symbol)
                → per-terminal_worker daemon spawns run_smoke.ps1 per work_item
                    → MT5 backtest → summary.json → verdict (PASS/FAIL/INVALID)
                        → cascade: P3 → P3.5 → P4 → P5 → P5b → P5c → P6 → P7 → P8
                            → P8 PASS = Heureka → OWNER+BA promote to T6
```

**State joins:**
- `tasks` row is the lifecycle anchor (one per bundled phase)
- `work_items` rows fan out per (ea, symbol) — one MT5 backtest each
- `evidence_path` in work_items points to `summary.json` with real stats

---

## 6. Today's lessons (2026-05-19 session)

**Watch out for these gotchas; they bit us today:**

1. **CREATE_NO_WINDOW everywhere on win32** (commits `3f735c31`, `929c7c0e`). pythonw parent has no console; pwsh child spawns its own visible console without `creationflags=subprocess.CREATE_NO_WINDOW`. Resulted in 1100+ flashing windows for ~290 zombie tasks.

2. **MT5 quick-close = stale news_calendar** (commit `929c7c0e`). `framework/include/QM/QM_News.mqh::QM_NewsInit` has 14-day stale schranke. Files in `D:/QM/data/news_calendar/` older than 14d → `INIT_FAILED` → terminal closes immediately. Quick-fix: touch the files. Real fix: refresh data (existing data covers 2015-2025 so backtests in that window work).

3. **Spawn-loop from unactionable EAs** (commit `90777e3f`). `_detect_unenqueued_eas` checked only `work_items` count; if `_create_backtest_work_items` skipped all symbols (e.g. M1 EAs with no DWX history in 2017-2022), task got created but 0 work_items → re-enqueue every pump. Now `enqueue_backtest` marks task=failed when 0 work_items, and `_detect_unenqueued_eas` skips EAs with any terminal backtest_p2 task.

4. **PASS work_items previously dropped net_profit** (commits `0fb2451b`, `6fcdbcc6`). Verdict was set but `recovered_stats` not persisted; Strategy Archive showed `—` for everything. Fix: write summary.json stats into payload on PASS; backfilled 296 historical rows.

5. **render_dashboards dedup** (commit `9bcfc717`). Multiple work_items per (ea, phase, symbol) caused Overview vs Detail to pick different rows showing different verdicts/P&L. Now dedup by newest `updated_at` per (ea, phase, symbol); `net_profit` only emitted when verdict='PASS'.

6. **`git add` then `git commit` ships full index** — see memory note. Always `git status --short` first; commit per pathspec, not naked `git commit`.

---

## 7. Where to look for state

| Question | Source |
|---|---|
| Pipeline phase progress | `farm_state.sqlite` work_items GROUP BY phase, status |
| MT5 fleet status | `Get-Process terminal64` + `D:/QM/strategy_farm/state/health.json` |
| Recent backtest logs | `D:/QM/reports/pipeline/<EA>/<phase>/<EA>/<ts>/summary.json` + `tester.log` |
| Codex/Claude session logs | `D:/QM/strategy_farm/logs/codex_*.live.log` |
| Public website snapshot | `C:/QM/repo/public-data/*.json` (schema-validated) |
| Architectural history | `decisions/DL-NNN_*.md` |
| Cross-conversation memory | `C:/Users/Administrator/.claude/projects/C--QM-repo/memory/MEMORY.md` (Claude's notes, you can read them) |

---

## 8. Scheduled tasks running in background (don't touch unless OWNER says)

- `QM_StrategyFarm_Pump_5min` — orchestrator pump (every 5 min)
- `QM_StrategyFarm_Tick_5min` — backtest poll
- `QM_StrategyFarm_Cockpit_2min` — dashboard refresh
- `QM_StrategyFarm_Health_15min` — health detector → `state/health.json`
- `QM_StrategyFarm_Repair_Hourly` — auto-repair (`repair.py` R1-R7)
- `QM_StrategyFarm_QuotaReceiver` — Anthropic/OpenAI quota tracker

---

## 9. How to commit safely

```powershell
# 1. See exactly what's modified
git status --short

# 2. Stage ONLY the files for your task (pathspec!)
git add -- framework/scripts/p2_baseline.py tools/strategy_farm/tests/test_foo.py

# 3. Verify staged content
git diff --cached --stat

# 4. Commit with co-author line
git commit -m "fix(area): short description

Longer body explaining why.

Co-Authored-By: Codex <codex@openai.com>"

# 5. Push to agents/board-advisor (NEVER main, NEVER --force)
git push origin agents/board-advisor
```

---

## 10. Operational APIs available to you

- `farmctl.py <command>` — pump, dispatch, enqueue-backtest, repair (CLI)
- `python framework/scripts/p2_baseline.py --ea QM5_NNNN ...` — direct phase runner
- `pwsh framework/scripts/run_smoke.ps1 -EAId NNNN -Symbol ...` — single backtest
- SQL: `python -c "import sqlite3; ..."` against `farm_state.sqlite`
- MT5 logs: `D:/QM/mt5/T{1-5}/Tester/logs/<YYYYMMDD>.log`
- Skill catalog: `skills/` directory (qm/* and marketplace/*)

---

## 11. When you start a task

1. Read this doc
2. If the task references `CLAUDE.md`, `decisions/`, or a specific phase — read those too
3. Check `git status --short` (worktree may be dirty from other sessions)
4. Plan the SMALLEST scope that solves the task (one component per commit ideally)
5. Implement → test → commit per pathspec → push
6. Exit with concrete summary (commit SHA + verification evidence)

If you can't make progress in 2 attempts at a strategy → STOP and write a diag doc in `docs/ops/<TASK>_BLOCKED_<date>.md` instead of churning tokens.
