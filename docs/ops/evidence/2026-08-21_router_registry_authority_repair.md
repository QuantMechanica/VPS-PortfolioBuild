# Router registry single-writer repair

Date: 2026-08-21

Task: `cd982cfc-c0d9-4581-9d4c-36eb77d2a04f`

Status: implementation evidence for REVIEW; verdict-neutral routing infrastructure only

## Pre-write rollback record

This snapshot was read from `D:/QM/strategy_farm/state/farm_state.sqlite`, table `agent_registry`, before any live registry write in this repair. Restoring these exact values is the rollback:

| agent_id | enabled | capabilities_json | max_parallel | cost_rank | budget_class | updated_at |
|---|---:|---|---:|---:|---|---|
| claude | 1 | `["code","tests","repo_edit","repo","ops","research","review","strategy","summary"]` | 3 | 30 | standard | `2026-08-21T13:16:04+00:00` |
| codex | 1 | `["code","tests","repo_edit","review","ops","research","strategy"]` | 5 | 20 | standard | `2026-08-21T13:16:04+00:00` |
| gemini | 1 | `["code","tests","repo_edit","research","strategy","source_discovery","video_analysis"]` | 2 | 10 | standard | `2026-08-21T13:16:04+00:00` |

Exact rollback SQL, if OWNER directs it:

```sql
UPDATE agent_registry SET enabled=1, capabilities_json='["code","tests","repo_edit","repo","ops","research","review","strategy","summary"]', max_parallel=3, cost_rank=30, budget_class='standard', updated_at='2026-08-21T13:16:04+00:00' WHERE agent_id='claude';
UPDATE agent_registry SET enabled=1, capabilities_json='["code","tests","repo_edit","review","ops","research","strategy"]', max_parallel=5, cost_rank=20, budget_class='standard', updated_at='2026-08-21T13:16:04+00:00' WHERE agent_id='codex';
UPDATE agent_registry SET enabled=1, capabilities_json='["code","tests","repo_edit","research","strategy","source_discovery","video_analysis"]', max_parallel=2, cost_rank=10, budget_class='standard', updated_at='2026-08-21T13:16:04+00:00' WHERE agent_id='gemini';
```

No rollback was executed. The SQL is recorded only to satisfy recoverability before the authorized routing-registry correction.

## Root cause and writer identity

The named writers of the narrow `2026-08-21T12:48:25Z` rows were the scheduled processes executing `sync_default_registry` from:

- `C:/QM/worktrees/codex-orchestration-1/tools/strategy_farm/agent_router.py`
- `C:/QM/worktrees/gemini-orchestration-1/tools/strategy_farm/agent_router.py`

Both linked worktrees carried pre-`ccca6cf13` narrow defaults. The canonical primary checkout `C:/QM/repo` carried the wider defaults and rewrote the same database at `12:53:40Z`. Evidence and the two measured states are sealed in `C:/QM/repo/docs/ops/evidence/2026-08-21_agent_registry_capability_flapping.md`.

The repair is deliberately structural: linked worktrees become registry readers even if their source revision is stale, while only the primary checkout (identified by a real `.git/` directory rather than a linked-worktree `.git` file) may synchronize defaults.

## Capability disposition submitted for review

- **Claude narrowing was drift.** OWNER intent in `agent_router.py` assigns the headless Claude lane coding and ops overflow. Its minimum contract therefore includes `code`, `ops`, and `review`; cost rank 30 and max parallel 3 remain unchanged.
- **Gemini narrowing omitted `video_analysis`, but whether its canonical `code`/`tests`/`repo_edit` grants should remain is a separate OWNER decision.** This repair preserves the canonical wide row, submits the concern in this REVIEW artifact, and does not silently narrow the lane. The existing mandatory Codex-review path for any Gemini draft remains intact.
- **Codex is unchanged.** It remains cost rank 20 and max parallel 5, so eligibility expands without changing preference.

## Implementation and verification

Implemented in the canonical checkout:

- `C:/QM/repo/tools/strategy_farm/agent_router.py`: `_registry_writer_authorized()` permits registry synchronization only when the router source checkout has a real `.git/` directory. Linked worktrees, whose `.git` is a file, return `read_only=true` and report the live capability contract without writing.
- `AGENT_TASK_TYPE_LANES` derives the minimum Claude/Codex ops contracts from `TASK_TYPE_CAPABILITIES`; Gemini additionally requires governed `video_analysis` capability. `registry_contract()` reports any live drift.
- Governed required skills remain binding even when the live registry omits them. A structurally unroutable task receives `payload.router_capability_warning.code=ROUTER_CAPABILITY_UNROUTABLE`, an event named `routing_capability_unroutable`, and a `capability_unavailable:<requirements>` route result rather than a silent skip.
- `status` now exposes both the writer/read-only result and the live registry-contract result.

Focused verification:

```text
python -m pytest -q tools/strategy_farm/tests/test_agent_router.py \
  -k "not replenish"
23 passed, 4 deselected in 9.45s

python -m pytest -q <three new registry authority/contract/warning tests>
3 passed in 1.95s

python -m py_compile tools/strategy_farm/agent_router.py \
  tools/strategy_farm/tests/test_agent_router.py
PASS
```

The four pre-existing replenishment tests were excluded from the focused run because their fixture traverses the live canonical card inventory through `strategy_priority._load_cards`; a faulthandler probe showed that scan still in `Path.read_text` after 10 seconds. This repair does not alter that path. All non-replenishment router tests passed.

## Authorized live correction

After the rollback values above were recorded, the primary checkout executed `agent_router.py init` once. Receipt:

```json
{
  "checkout_root": "C:\\QM\\repo",
  "read_only": false,
  "synced": ["codex", "claude", "gemini"],
  "contract": {"ok": true, "gaps": []}
}
```

Post-write rows at `2026-08-21T13:32:44+00:00`:

| agent_id | capabilities_json | max_parallel | cost_rank |
|---|---|---:|---:|
| claude | `["code","tests","repo_edit","repo","ops","research","review","strategy","summary"]` | 3 | 30 |
| codex | `["code","tests","repo_edit","review","ops","research","strategy"]` | 5 | 20 |
| gemini | `["code","tests","repo_edit","research","strategy","source_discovery","video_analysis"]` | 2 | 10 |

Thus code defaults and live registry agree at handoff, Claude is eligible for both `ops_issue` and `triage_failure`, and Gemini is eligible for governed `video_analysis`. The source guard becomes durable for scheduled linked worktrees when this REVIEW patch is accepted and propagated to them; until then, the live correction is accurate but an older unpatched scheduler revision can still reintroduce the measured drift.
