# Orchestration Workstream Ready

Status: CURRENT MIRROR  
Date: 2026-05-21

## Closeout

The Friday 2026-05-22 Claude/Gemini/Codex orchestration workstream now has concrete worker prompts and an executable router feedback loop.

Research remains reservoir-gated at schema-clean, prebuild-ready Strategy Cards < 5, but when research is needed all available AI families are deliberately challenged:

- Gemini: broad source discovery.
- Codex: implementation-aware strategy design.
- Claude: deep strategy critique and synthesis, only when enabled.

Prompt files:

- `G:/My Drive/QuantMechanica - Company Reference/Prompt for Fabian_Start_Orchestration_2026-05-22.md`
- `G:/My Drive/QuantMechanica - Company Reference/Prompt for Codex_Orchestration_Workstream_2026-05-22.md`
- `G:/My Drive/QuantMechanica - Company Reference/Prompt for Gemini_Orchestration_Workstream_2026-05-22.md`
- `G:/My Drive/QuantMechanica - Company Reference/Prompt for Claude_Orchestration_Workstream_2026-05-22.md`

Old Goal/P8/Restart prompts were moved to:

`G:/My Drive/QuantMechanica - Company Reference/00 Governance/Archive/Old Prompts/2026-05-21/`

Shared loop:

```powershell
cd C:/QM/repo
python tools/strategy_farm/agent_router.py status
python tools/strategy_farm/agent_router.py enqueue-friday-smoke
python tools/strategy_farm/agent_router.py run --min-ready-strategy-cards 5 --max-routes 5
python tools/strategy_farm/agent_router.py route-many --max-routes 5
python tools/strategy_farm/agent_router.py list-tasks --agent <codex|gemini|claude>
python tools/strategy_farm/agent_router.py update-task <task_id> --state REVIEW --artifact-path "<artifact>" --verdict "<short_verdict>"
python tools/strategy_farm/agent_router.py close-review <task_id> --state APPROVED --verdict "<short_verdict>" --artifact-path "<artifact>"
python tools/strategy_farm/agent_router.py sync-q11-candidates
```

Hardening now in place:

- ready-card counting uses `farmctl.ready_strategy_card_inventory()` and excludes cards that fail prebuild validation or the Strategy Card output schema.
- research replenish payloads include dedupe requirements, per-agent research perspectives, and the required Strategy Card schema.
- research outputs are quarantined in `D:/QM/strategy_farm/artifacts/cards_review/`; router rejects direct `cards_approved/` returns.
- cards returned to `cards_review/` are checked for schema and duplicate fingerprints before the task can enter REVIEW.
- Friday smoke tasks are idempotent via `agent_router.py enqueue-friday-smoke`; disabled agents are skipped instead of blocking the router.
- Live seed 2026-05-21: Codex and Gemini smoke tasks were created; Claude smoke was skipped because `CLAUDE_DISABLED.flag` still exists. Codex smoke is complete at `docs/ops/friday_smoke_codex_2026-05-22.md`; Gemini smoke remains TODO until Gemini capacity is free.
- Cockpit queue panels now include `Agent router` with open task count, agent enabled/cap state, target agent, and artifacts.
- Cockpit now shows agent-task SLA ages and `Profitability next actions` for the next deterministic EA step.
- Claude default cap is 3 after `CLAUDE_DISABLED.flag` is removed.
- `python tools/strategy_farm/claude_reenable_check.py` is the read-only Claude preflight before removing the flag.
- REVIEW tasks now have explicit closeout through `close-review`; old Codex REVIEW ops tickets were closed as APPROVED on 2026-05-21.
- Q11/P8 PASS work items are mirrored into `portfolio_candidates` through `sync-q11-candidates`; current count is 0.
- Portfolio target is 5 distinct Q11-PASS EAs, preferably across multiple robust symbols and low-overlap return sources. See `docs/ops/Q11_PORTFOLIO_TARGET_2026-05-21.md`.

Strategy Card output schema:

- frontmatter: `ea_id`, `slug`, `g0_status`, `r1_track_record`, `r2_mechanical`, `r3_data_available`, `r4_ml_forbidden`, `expected_trades_per_year_per_symbol`
- body: thesis, market universe, timeframe, entry, exit, risk, falsification, Q08/Q11 risks, implementation notes

Claude-specific guard:

- Claude must not work while `D:/QM/strategy_farm/CLAUDE_DISABLED.flag` exists.
- OWNER must confirm Claude quota/spend before using the Claude prompt.
- After the flag is removed, Claude router cap is 3.

## Lint State

Resolved the previous broad lint caveat:

- `python framework/scripts/validate_registries.py` now returns `status=ok`.
- `python framework/scripts/lint_strategy_wiki.py --vault "G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki"` returns `OK`.

The registry command keeps non-fatal inventory warnings hidden by default; use `--show-warnings` for the full audit list.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_agent_router.py tools/strategy_farm/tests/test_research_backlog_inventory.py -q
13 passed in 1.77s

python tools/strategy_farm/render_cockpit.py
cockpit written: D:\QM\strategy_farm\dashboards\cockpit.html
```
