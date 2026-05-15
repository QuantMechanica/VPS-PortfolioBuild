# Option A Strategy Farm Runbook

Status: draft bootstrap, 2026-05-15

Purpose: replace Paperclip as the critical path with a deterministic local controller.
Paperclip may later read reports, but it must not own routing, scheduling, or state.

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

## Agent Responsibilities

Per OWNER 2026-05-15 — division of labor:

Claude (bookends — research + EA review + final gates):
- Read one source at a time. Produce source notes and draft Strategy Cards.
- Reject discretionary, incomplete, black-box, martingale/grid, non-codeable ideas.
- **Review Codex-built EAs** against the card (mechanical match, HR14 no-ML,
  HR4 risk model, HR5 magic, framework architecture). Verdict:
  `APPROVE_FOR_BACKTEST` or `REJECT_REWORK` with explicit rework directives.
- Apply gate verdicts at G0 (R1-R4) and at the final pre-T6 step.
- Never enqueue builds or touch MT5.

Codex (middle — EA build + middle-pipeline phases):
- Build EAs only from cards with `g0_status: APPROVED`.
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

## Phase D — Single tick command + scheduler (TODO)

Plan: `farmctl tick` invokes (in order) `dispatch-tick` for backtests, plus
future advance-on-classification (when a backtest is classified PASS, enqueue
the next-phase backtest automatically; on FAIL, mark EA DEAD and emit a
lessons-learned stub). Then wire to Windows Task Scheduler at 5-10 min
interval. No daemons, just scheduled ticks.

## Phase E — Dashboards (TODO, location decided 2026-05-15)

The old `C:/QM/paperclip/dashboards/{current.html, strategies.html}` are dead
along with Paperclip. Replacement layout:

- **Render script + Jinja templates** (committed): `tools/strategy_farm/dashboards/`
  - `render_dashboards.py`
  - `templates/current.html.j2` (project progress / Mission Hero)
  - `templates/strategies.html.j2` (Strategy Archive — also published online)
- **Rendered HTML output** (generated, not committed, served locally):
  `D:/QM/strategy_farm/dashboards/{current.html, strategies.html}`
- **Public publication** (Strategy Archive only, for quantmechanica.com): reuse
  existing `scripts/export_public_snapshot.ps1` pattern — schema-validated
  JSON + HTML pushed to `public-data/`.
- **Scheduler:** hourly Windows Task `QM_StrategyFarm_Dashboard_Hourly`.

Data sources: `D:/QM/strategy_farm/state/farm_state.sqlite` (sources, tasks,
events) + `artifacts/` (cards, builds, verdicts) + `D:/QM/reports/pipeline/`
(backtest reports) + `mt5-slots` output (live fleet saturation).

## Phase D — Driver Loop (TODO)

Single `farmctl tick` command that advances state by one step
(no daemon, no heartbeat). Wired to Windows Task Scheduler at 5-min
interval once Phase C is stable.

## First Acceptance Test

The first farm acceptance test is not profit. It is deterministic motion:

1. Controller selects exactly one source.
2. Claude produces one source note + draft card(s).
3. OWNER (or Board Advisor) flips `g0_status: APPROVED` on one card.
4. `farmctl build-ea` creates build_ea task + Codex prompt.
5. Codex builds, compiles, smokes → writes JSON.
6. `farmctl record-build` records result; task → done.
7. `farmctl claude-review-prompt` creates ea_review task + Claude prompt.
8. Claude reviews → writes verdict JSON.
9. `farmctl record-review` records `APPROVE_FOR_BACKTEST`.
10. (Phase C) Controller deploys and enqueues one MT5 backtest.
11. A result lands in `artifacts\verdicts`.
12. `farmctl status` shows the next action without relying on Paperclip.

