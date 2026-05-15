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

## Phase C — MT5 Backtest Dispatch + Classify (TODO)

Not yet implemented. Planned commands:

- `enqueue-backtest --review-task-id <id> --phase P2`
- `mt5-slots` — show free T1-T5 slots from process scan
- `dispatch-tick` — pull next backtest_* task, assign to free slot
- `classify --task-id <id>` — read `.htm` report, write verdict
  (`PASS | ZERO_TRADES | INFRA_FAIL | STRATEGY_FAIL`)

Wired to existing phase scripts: `phase_orchestrator.py`,
`pipeline_dispatcher.py`, `p2_baseline.py`..`p8_news_impact.py`,
`aggregate_phase_results.py`.

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

