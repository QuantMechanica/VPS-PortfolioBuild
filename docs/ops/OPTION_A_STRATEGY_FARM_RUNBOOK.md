# Option A Strategy Farm Runbook

Status: active, 2026-07-22

Purpose: operate the strategy factory through a deterministic local controller.
No external agent company, role hierarchy, or issue system owns routing, scheduling,
state, or gate authority.

## Control Model

One local orchestrator owns state transitions. Claude and Codex do bounded tasks only.

Pipeline:

```text
source_queue -> research_extract -> card_gate -> build_ea -> compile_deploy -> backtest_queue -> classify -> next_action
```

## Directory Layout

Use `D:\QM\strategy_farm` as the runtime state root.

```text
D:\QM\strategy_farm\
  queue\
    sources.jsonl
    research_tasks.jsonl
    build_tasks.jsonl
    backtest_tasks.jsonl
  state\
    farm_state.sqlite
    locks\
  artifacts\
    source_notes\
    cards_draft\
    cards_approved\
    builds\
    backtests\
    verdicts\
  logs\
```

The repo implementation lives under:

```text
C:\QM\repo\tools\strategy_farm\
```

## Authority and Responsibilities

The OWNER is the sole human approval authority. Claude and Codex are bounded
workers and reviewers; neither persona is a governance gate.

### Gate semantics (binding)

- **Source authorization:** OWNER approves a source for extraction.
- **G0 research gate:** OWNER sets `g0_status: APPROVED` after R1-R4 review.
  This is the complete authorization to build, instrument, debug, compile,
  deploy to T1-T5, and run non-live backtests. A separate descriptive card
  field such as `status: DRAFT` does not revoke or override G0 approval.
- **Build gate:** deterministic artifacts must exist and agree: `.mq5`, `.ex5`,
  registry rows, setfiles, compile PASS, and deployment hashes.
- **Test gates:** phase runners decide PASS/FAIL only from version-bound evidence
  and the numerical rules in the phase specifications. Reviewer names or agent
  roles cannot substitute for evidence.
- **Promotion gate:** G0, successful build, or a non-zero smoke test does not
  authorize T6 or live trading. Promotion requires all prescribed test gates,
  a complete execution contract, a signed deploy manifest, and explicit OWNER
  approval.

Division of labor:

Claude (research and review):
- Read one source at a time. Produce source notes and draft Strategy Cards.
- Reject discretionary, incomplete, black-box, martingale/grid, non-codeable ideas.
- **Review Codex-built EAs** against the card (mechanical match, HR14 no-ML,
  HR4 risk model, HR5 magic, framework architecture). Verdict:
  `APPROVE_FOR_BACKTEST` or `REJECT_REWORK` with explicit rework directives.
- Prepare evidence and a recommended verdict for OWNER at G0 and promotion.
- Never enqueue builds or touch MT5.

Codex (middle — EA build + middle-pipeline phases):
- Build EAs only from cards with `g0_status: APPROVED`.
- Treat that field as sufficient authorization for implementation and T1-T5
  debugging; do not wait for obsolete role-based approvals.
- Compile, deploy to T1-T5, generate setfiles, enqueue backtests.
- Rework EAs based on Claude review `rework_directives`.
- Fix tooling when deterministic checks fail.
- Never choose the next source.

Controller (`farmctl.py`):
- Select the next runnable item.
- Enforce one active source lane at a time (HR16, DB constraint).
- Maintain SQLite state and file artifacts.
- Render Claude/Codex prompts with all bindings substituted.
- Record returned JSON artifacts back into task state.
- Launch MT5 workers/backtests (Phase C, in progress).
- Classify outputs and advance state.

## Initial Source Order

1. Current in-flight Davey work already on disk.
2. Forex Factory Trading Systems: `https://www.forexfactory.com/forums`
3. BabyPips forums: `https://forums.babypips.com/`
4. MQL5 CodeBase MT5: `https://www.mql5.com/en/code/mt5`
5. MQL5 Articles: `https://www.mql5.com/en/articles/trading`
6. Legacy local inventory: `G:\My Drive\QuantMechanica`

## State Rules

- Exactly one source lane may be `active`.
- A source can produce at most two candidate cards before the controller advances.
- A card cannot enter `build_tasks` unless `card_gate = APPROVED`.
- A build cannot enter `backtest_tasks` unless:
  - `.mq5` exists
  - `.ex5` exists
  - registry rows exist
  - setfiles exist
  - T1-T5 deployment hashes match
- A backtest result is one of:
  - `PASS`
  - `ZERO_TRADES`
  - `INFRA_FAIL`
  - `STRATEGY_FAIL`
  - `REJECTED`

## Phase A — Source/Research (DONE 2026-05-15)

Implemented commands: `init`, `seed-sources`, `status`, `next`, `claim-source`,
`set-source-status`, `events`, `claude-prompt`.

Lifecycle (one active source at a time, DB-enforced):

```text
pending → active → notes_ready → cards_ready → approved / rejected → done
```

## Phase B — Codex Build + Claude Review (DONE 2026-05-15)

Implemented commands: `build-ea`, `record-build`, `claude-review-prompt`, `record-review`.

Task kinds in the `tasks` table:

- `build_ea` — Codex implementation step. `pending → done/failed/blocked`.
- `ea_review` — Claude review step. `pending → done` (verdict in payload).

### Build & Review Loop

For each APPROVED Strategy Card (`g0_status: APPROVED` in frontmatter):

```powershell
# 1. Create build_ea task + render Codex prompt
python tools/strategy_farm/farmctl.py build-ea --card <path-to-card.md>
# → returns task_id, prompt_path, build_result_path, suggested codex command

# 2. Run Codex against the prompt
codex exec --model gpt-5-codex --cd C:/QM/repo "$(Get-Content -Raw <prompt-path>)"
# → Codex writes JSON to build_result_path

# 3. Record Codex's result
python tools/strategy_farm/farmctl.py record-build `
  --task-id <task_id> --result-file <build_result_path>
# → task transitions to done / failed / blocked

# 4. If done: create ea_review task + render Claude review prompt
python tools/strategy_farm/farmctl.py claude-review-prompt --build-task-id <task_id>
# → returns review_task_id, prompt_path, verdict_path

# 5. Run Claude review (Board Advisor on heartbeat, or claude CLI)
# → Claude writes verdict JSON to verdict_path

# 6. Record verdict
python tools/strategy_farm/farmctl.py record-review `
  --task-id <review_task_id> --result-file <verdict_path>
# → APPROVE_FOR_BACKTEST: ready for Phase C dispatch
# → REJECT_REWORK: re-render Codex prompt with rework_directives
```

The two prompt templates live at:

- `tools/strategy_farm/prompts/codex_build_ea.md`
- `tools/strategy_farm/prompts/claude_review_ea.md`

Both produce structured JSON only (no prose). The controller validates the
expected schema and transitions tasks accordingly. HR7 `NO_REPORT ≠ EA-Schwäche`
is honored — `smoke_result: zero_trades` still proceeds to review.

## Phase C — MT5 Backtest Dispatch + Classify (DONE 2026-05-15, v1 = P2 only)

Implemented commands: `mt5-slots`, `enqueue-backtest`, `dispatch-tick`.

The dispatcher wraps the existing `framework/scripts/p2_baseline.py` (which
already self-distributes across T1-T5 via ThreadPoolExecutor). farmctl owns
the high-level orchestration; the phase script owns MT5-slot management.

Task kinds:

- `backtest_p2` (and later `backtest_p3`, etc.) — `pending → active → done/failed`.
  Status `done` is set both for PASS and non-PASS classifications; the actual
  verdict lives in `payload.classification.verdict`.

### Backtest Dispatch Loop

After Claude review returns `APPROVE_FOR_BACKTEST`:

```powershell
# 1. Create backtest_p2 task from approved review
python tools/strategy_farm/farmctl.py enqueue-backtest `
  --review-task-id <ea_review-id> --phase P2
# → task_id of the backtest_p2 task

# 2. Advance state — starts pending, polls active, classifies completed
python tools/strategy_farm/farmctl.py dispatch-tick
# Returns an actions[] array: started / still_running / classified / timeout / no_runner

# 3. Show MT5 fleet status (any time)
python tools/strategy_farm/farmctl.py mt5-slots
```

### dispatch-tick semantics

1. Poll all `active` backtest tasks. If the expected `report.csv` exists →
   classify and mark `done`. If the task is older than `--timeout-hours`
   (default 6h) with no report → mark `failed` with `timeout_reason`.
2. If no task is `still_running` after polling, start the oldest pending
   one: subprocess.Popen the phase runner detached (Windows: `CREATE_NEW_PROCESS_GROUP | DETACHED_PROCESS`), record PID + log_path + cmd.

HR16 enforcement (v1): exactly one backtest task `active` at any time across
the whole farm. Multi-EA saturation across T1-T5 is a future config flag.

### P2 hard-number gate (`classify_p2`)

Reads `p2_baseline.py`'s report.csv (columns `ea_id, phase, symbol, terminal, verdict, invalidation_reason, evidence`) and applies:

- ≥1 PASS symbol → `verdict: PASS` (advance EA — Portfolio-Kandidat = min. 1 Symbol durch)
- All FAIL with `trade_count_below_min` reason → `verdict: ZERO_TRADES` (HR7
  NO_REPORT ≠ EA-Schwäche; investigate filters/window before declaring strategy fail)
- ≥50% INVALID → `verdict: INFRA_FAIL` (G1 / real-ticks / Model 4 setup problem)
- Otherwise → `verdict: STRATEGY_FAIL`

P3..P8 classifiers will be added as those phases are wired in. Wired via the
`PHASE_CLASSIFIERS` dict in `farmctl.py`.

## Phase D — Autonomy primitives (DONE + INSTALLED 2026-05-15)

OWNER 2026-05-15: full autonomy on, hourly Claude wake on subscription.
Three scheduled tasks live on the VPS:

| Task | Cadence | Purpose | LLM cost |
|---|---|---|---|
| `QM_StrategyFarm_Tick_5min` | every 5 min | `farmctl tick` — advances backtest tasks (start pending, poll active, classify P2 reports). | none |
| `QM_StrategyFarm_Dashboard_Hourly` | hourly :00 | `render_dashboards.py` — regenerates `current.html` + `strategies.html`. | none |
| `QM_StrategyFarm_AutonomousWake_Hourly` | hourly :17 | `autonomous_wake.ps1` → spawns `claude -p` with bootstrap prompt → reads `prompts/autonomous_loop.md` → executes one wake step. | yes (subscription) |

**farmctl `tick`** is currently a thin wrapper over `dispatch-tick`. Future
revisions will add post-classify chaining (PASS → enqueue next phase / FAIL
→ mark EA DEAD) and post-review auto-enqueue (`APPROVE_FOR_BACKTEST` → P2)
inside `tick`. Until then the chaining happens in the autonomous wake.

The autonomous wake follows the decision tree in
`tools/strategy_farm/prompts/autonomous_loop.md` — exactly one productive
step per wake (research / G0 verdict / Codex build / EA review / enqueue),
hard boundaries on HR16 + HR14 + T6 + agent lifecycle, structured log to
`D:/QM/strategy_farm/logs/autonomous_wakes.log`.

### Task management

```powershell
# List
Get-ScheduledTask -TaskName 'QM_StrategyFarm_*' | Format-Table TaskName, State

# Pause autonomy (LLM wake)
Disable-ScheduledTask -TaskName 'QM_StrategyFarm_AutonomousWake_Hourly'

# Resume
Enable-ScheduledTask -TaskName 'QM_StrategyFarm_AutonomousWake_Hourly'

# Trigger one wake on demand
Start-ScheduledTask -TaskName 'QM_StrategyFarm_AutonomousWake_Hourly'

# Uninstall
Unregister-ScheduledTask -TaskName 'QM_StrategyFarm_AutonomousWake_Hourly' -Confirm:$false
```

### Wake log

Two log streams:
- `D:/QM/strategy_farm/logs/autonomous_wakes_invocation.log` — every PS1 invocation (WAKE_INVOKED / WAKE_EXITED) with exit code.
- `D:/QM/strategy_farm/logs/autonomous_wakes.log` — one structured line per wake from the claude session itself (what it actually DID).
- `D:/QM/strategy_farm/logs/autonomous_wake_<utc-iso>.log` — full session output per wake.

## Phase E — Dashboards (DONE 2026-05-15)

The active dashboards are generated directly from strategy-farm state (stdlib
Python, no Jinja2):

- **Source** (committed): `tools/strategy_farm/dashboards/`
  - `render_dashboards.py` — single stdlib-only script (no deps)
  - `style.css` — brand design system
- **Rendered output** (generated, not committed, served locally via `file://`):
  - `D:/QM/strategy_farm/dashboards/current.html` — project progress one-pager
  - `D:/QM/strategy_farm/dashboards/strategies.html` — Strategy Archive
  - `D:/QM/strategy_farm/dashboards/style.css` — synced from source on render
- **Public publication** (Strategy Archive, deferred): reuse existing
  `scripts/export_public_snapshot.ps1` pattern — schema-validated JSON + HTML
  pushed to `public-data/` for quantmechanica.com/strategy.
- **Scheduler:** hourly Windows Task (not yet installed — same pattern as `tick`).

### Project Progress one-pager — sections, in scroll order

Designed per OWNER 2026-05-15 feedback ("show me visual progress"). Bewusst raus:
Issue-Listen, Agent-Fleet, Token-Burn,
Heartbeat-Status, Recovery-Cycles. Drin:

1. **Header** — title + UTC timestamp + mission tagline.
2. **HERO** — Portfolio dots (1/5 EAs live) + Heureka phase bar G0..P10 for
   the leading active EA + name of the active EA. The single most important
   "where are we" view, top of page.
3. **MT5 Fleet** (left column card) — running terminal64.exe count, 5 slots
   visualized (busy = emerald glow, idle = greyed), saturation %, MISSION-FAILURE
   signal flag when count = 0 per Mission Baseline 2026-05-09.
4. **Throughput 7d** (right column card) — Unicode sparklines for sources
   claimed / task transitions / total events, with weekday labels and totals.
5. **Pipeline table** — top 10 EAs by recency. Per EA: id, slug, mini phase
   bar (15 segments G0..P10 colored done/current/failed), current phase, status
   pill (FLOW / LIVE / DEAD).
6. **Blockers** — what is NOT moving: blocked sources, blocked/failed tasks,
   MT5 idle. Severity-coded left border.
7. **Recent Events** — last 15 from `events` table.

Data sources: `D:/QM/strategy_farm/state/farm_state.sqlite` (sources, tasks,
events) + tasklist scan for MT5 + `artifacts/` for evidence paths.

### Strategy Archive — sections

1. **Hero** — title + transparency sub-headline.
2. **Lane summary** — Live / In Flow / Dead counts (3 tiles).
3. **Transparency banner** — DEAD EAs not hidden; failure data is part of the public record.
4. **EA card grid** — auto-fill cards, one per EA, each showing id, slug,
   mini phase bar, current phase, completed phases, last updated, evidence path.
5. **Footer** — generation provenance + future export_public_snapshot link.

### Running it

```powershell
# Render both dashboards (writes to D:/QM/strategy_farm/dashboards/)
python C:\QM\repo\tools\strategy_farm\dashboards\render_dashboards.py

# View locally
start file:///D:/QM/strategy_farm/dashboards/current.html
start file:///D:/QM/strategy_farm/dashboards/strategies.html
```

Empty state handled gracefully — first run with 0 EAs still produces valid HTML
with informative "no candidates yet" placeholders.

## Phase D — Driver Loop (TODO)

Single `farmctl tick` command that advances state by one step
(no daemon, no heartbeat). Wired to Windows Task Scheduler at 5-min
interval once Phase C is stable.

## First Acceptance Test

The first farm acceptance test is not profit. It is deterministic motion:

1. Controller selects exactly one source.
2. Claude produces one source note + draft card(s).
3. OWNER flips `g0_status: APPROVED` on one card; this authorizes build and
   non-live debugging even if another descriptive status field still says `DRAFT`.
4. `farmctl build-ea` creates build_ea task + Codex prompt.
5. Codex builds, compiles, smokes → writes JSON.
6. `farmctl record-build` records result; task → done.
7. `farmctl claude-review-prompt` creates ea_review task + Claude prompt.
8. Claude reviews → writes verdict JSON.
9. `farmctl record-review` records `APPROVE_FOR_BACKTEST`.
10. (Phase C) Controller deploys and enqueues one MT5 backtest.
11. A result lands in `artifacts\verdicts`.
12. `farmctl status` shows the next action from deterministic local state.

