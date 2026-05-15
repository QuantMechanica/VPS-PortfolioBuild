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

Claude:
- Read one source at a time.
- Produce source notes and draft Strategy Cards.
- Reject discretionary, incomplete, black-box, martingale/grid, or non-codeable ideas.
- Never enqueue builds or touch MT5.

Codex:
- Build EAs only from approved cards.
- Compile, deploy to T1-T5, generate setfiles, enqueue backtests.
- Fix tooling when deterministic checks fail.
- Never choose the next source.

Controller:
- Select the next runnable item.
- Enforce one active source lane at a time.
- Maintain SQLite state and file artifacts.
- Launch Claude/Codex jobs with explicit prompts.
- Launch MT5 workers/backtests.
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

## Bootstrap Sequence

1. Keep Paperclip and old QM scheduled jobs disabled.
2. Create `D:\QM\strategy_farm` directories.
3. Initialize `farm_state.sqlite`.
4. Seed `sources.jsonl` with the ordered source list.
5. Implement `farmctl.py` commands:
   - `init`
   - `status`
   - `next`
   - `claim`
   - `complete`
   - `enqueue-backtest`
   - `classify`
6. Start with a dry-run controller loop before allowing Claude/Codex subprocess execution.

## First Acceptance Test

The first farm acceptance test is not profit. It is deterministic motion:

1. Controller selects exactly one source.
2. Claude produces one source note or card.
3. Codex receives one approved card and produces one EA artifact set.
4. Controller deploys and enqueues one MT5 backtest.
5. A result lands in `artifacts\verdicts`.
6. `farmctl status` shows the next action without relying on Paperclip.

