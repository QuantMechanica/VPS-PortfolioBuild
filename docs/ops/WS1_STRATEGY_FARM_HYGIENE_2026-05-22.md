# WS-1 Strategy Farm Hygiene

Date: 2026-05-22
Task: `5a6f226e-315b-4cd3-80e3-33a757213836`

## Result

- Generic `research_strategy` replenishment in `tools/strategy_farm/agent_router.py` is frozen. `run` and `replenish` now report `frozen: true` and create no open-ended reservoir tasks.
- `tools/strategy_farm/repair.py` now includes an idempotent GC handler in the hourly repair path:
  - stale files older than 7 days under `D:/QM/strategy_farm/logs`
  - stale files older than 7 days under `D:/QM/strategy_farm/reports`
  - stale `D:/QM/strategy_farm/queue/*.md` prompts older than 7 days
  - orphaned `framework/registry/ea_id_registry.csv.*.tmp` files older than 1 day
- Stale generic Codex research task `c714b1f3-1eed-429c-b9b6-8eb5b4af8171` was closed as `APPROVED` with verdict `GENERIC_RESEARCH_REVIEW_CLOSED_WS1_FREEZE`.
- Local agent scratch `.gemini/` is ignored so scheduled-task scratch files are not committed.

## Commit / Merge

- Committed WS-1 and the pre-existing 2026-05-22 farm working-tree delta as `d1748e3c` (`ops: WS-1 freeze generic research and add farm GC`).
- `git fetch origin` succeeded.
- `git merge --no-edit origin/main` was attempted and aborted after broad conflicts across legacy docs, framework scripts, registry/public-data files, and binary `.ex5` artifacts. The branch remains intact at `agents/board-advisor` ahead of `origin/agents/board-advisor` by 1 commit and still behind `origin/main` by 224 commits.
- Push was not attempted because the requested main reconciliation did not produce a mergeable tree.

## Verification

- `python -m py_compile tools/strategy_farm/agent_router.py tools/strategy_farm/repair.py`: PASS
- `python -m unittest tools.strategy_farm.tests.test_agent_router`: PASS, 17 tests
- `python tools/strategy_farm/farmctl.py repair`: PASS, `repairs_applied=0`, `errors=[]`
- `python tools/strategy_farm/agent_router.py run --min-ready-strategy-cards 5 --max-routes 5`: PASS, `replenish.created=[]`, `frozen=true`

No Q-gate verdicts were inferred. No T_Live or AutoTrading changes were made. No terminal was started manually.
