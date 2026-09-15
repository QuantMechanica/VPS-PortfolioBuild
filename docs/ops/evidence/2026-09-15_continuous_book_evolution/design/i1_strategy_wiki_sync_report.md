# Slice I1 — Strategy Wiki Sync (report)

Slice key: `i1_strategy_wiki_sync`
Decision: OWNER follow-up directive 2026-09-15 §2–§8 (HIGH PRIORITY). Branch
`agents/board-advisor`. Shared contract: `lineage_map.json` (`qm.lineage-map/v1`, written by
slice I2, consumed here when present).

## Summary

Built the deterministic Strategy Wiki projection the vault has lacked since the
"Strategy Wiki Sync Protocol" was written as a target contract (2026-08-20): one generated,
machine-owned node per canonical strategy record, all §4 fields (explicit
NOT_EVALUATED/UNKNOWN/NOT_APPLICABLE/EVIDENCE_MISSING), a projection class per §5, a
per-family/per-class generated index, and a completeness+staleness lint that emits the
`STRATEGY_WIKI_SYNC` Mission Control health key. Ran for real against the live vault:
**5,265 generated nodes, lint STRATEGY_WIKI_SYNC = GREEN** (0 missing / 0 stale / 0 duplicate
/ 0 orphan / 0 invalid_link / 0 unresolved_source / 0 unresolved_lineage). Also fixed the
`research_dedup_check.py` wrong-vault-root drift (D1) via a shared `vault_paths.py`, persisted
a self-excluding `card_sha256` into cards at approve-time, and added a best-effort post-approve
wiki-sync hook so new strategies appear automatically (§7). Hand-written nodes are never touched.

## Files changed

- `tools/strategy_farm/vault_paths.py` **(new)** — single source of truth for the vault root
  (`QM_VAULT_ROOT`-overridable) + the Strategy Wiki `strategies/` (hand-written) and
  `generated/` sub-trees, plus `card_content_sha256()` — a deterministic, LF-normalised,
  self-excluding card content hash (drops any prior `card_sha256`/`card_hash` line so persisting
  it back is stable).
- `tools/strategy_farm/strategy_wiki_sync.py` **(new)** — the generator. Subcommands `build`
  (idempotent projection; writes only changed files; prunes generator-owned nodes whose record
  changed class), `index` (generated `_INDEX.md` per class + per family; `--init-root-index`
  refreshes a marker-delimited generated block inside the hand-written root `_INDEX.md` without
  disturbing surrounding text), `lint` (§6 machine check → `strategy_wiki_sync.json`, exit non-zero
  on RED), `status`. Public `build_single(ea_id)` for the post-approve hook.
- `framework/scripts/research_dedup_check.py` — `DEFAULT_WIKI_VAULT` now resolves through
  `vault_paths.strategy_wiki_root()` instead of the wrong hard-coded
  `G:\My Drive\09 Strategy Wiki` (drift D1: vault-side dedup had fail-closed on every run since
  inception).
- `tools/strategy_farm/farmctl.py` — `approve_card` now (1) persists a deterministic
  `card_sha256` (`vault_paths.card_file_content_sha256`) into the approved card's frontmatter so
  staleness is hash-deterministic (§6), and (2) fires a best-effort `strategy_wiki_sync
  build_single(<ea_id>)` post-approve hook (§7; opt out with `QM_WIKI_SYNC_HOOK=0`; never fatal
  to approval). Return dict gains `card_content_sha256`.
- `tools/strategy_farm/factory_bottleneck_readmodel.py` — loads `strategy_wiki_sync.json` as a
  read-model and adds the `strategy_wiki_sync` health key to `compute_book_evolution_health`
  (EVIDENCE_MISSING when the read-model is absent), so Mission Control / Heartbeat surface it.
- `tools/strategy_farm/install_strategy_wiki_sync_scheduled_task.ps1` **(new)** — installer for
  `QM_StrategyFarm_StrategyWikiSync_60min` (SYSTEM, 3 sequential actions build → index
  `--init-root-index` → lint; `-Uninstall`). **Installer written only; NOT registered** (task
  registration is a RED boundary for this slice).

## Contracts

- `strategy_wiki_sync.json` (read-model): `schema=qm.strategy-wiki-sync.health/v1`,
  `generated_at_utc`, `STRATEGY_WIKI_SYNC` ∈ {GREEN, AMBER, RED}, `record_count`,
  `canonical_records`, `valid_projections`, `projected_nodes`, `class_counts`, `counts`
  (missing/stale/duplicate/orphan/invalid_link/unresolved_source/unresolved_lineage), bounded
  `samples`.
- Generated node frontmatter: `generated: true`, `generator: strategy_wiki_sync/v1`,
  `projection_class`, `card_hash`, `source_hash`, `inputs_sha256`, `last_sync_inputs_sha256`,
  plus every §4 field. `inputs_sha256` is the **per-node** input digest (not a global one), so an
  unrelated input change does not rewrite every node (no cloud-sync spam) and staleness is a
  per-node hash comparison.
- Consumes `lineage_map.json` `qm.lineage-map/v1` (`nodes`/`edges`/`families`) when present;
  renders duplicate/clone/variant and parent/child relationships; absent → EVIDENCE_MISSING.
- Mission Control health: `strategy_wiki_sync` key in
  `factory_bottleneck_readmodel.compute_book_evolution_health`.

## Projection-class mapping rule (§5, deterministic; first match wins)

1. **REJECTED** — card in a rejected store, OR terminal reject `final_verdict`.
2. **DUPLICATE** — card in `card_duplicates_g0`.
3. **SUPERSEDED** — card `superseded_by` set, OR a lineage `superseded` edge names this node as
   the superseded side.
4. **RETIRED** — EA-registry `status == retired`.
5. **ACTIVE_CANONICAL** — an approved card exists (approved store or `g0_status: APPROVED`).
6. **DRAFT** — draft/review/seed store, or card `status: DRAFT` / `g0_status: PENDING`.
7. **HISTORICAL** — a record exists (registry/pipeline/lineage) but no card qualifies it above.

Only ACTIVE_CANONICAL counts toward the completeness lint (`missing`); the other classes are
findable-when-present, so a reader can never mistake a rejected/historical idea for a live one.

## Tests (`python -X utf8 -m pytest <files> -q`)

- `tools/strategy_farm/tests/test_vault_paths.py` — 5 tests: default root carries the
  `QuantMechanica - Company Reference` segment; env + explicit override; line-ending &
  self-hash stability; file roundtrip.
- `tools/strategy_farm/tests/test_strategy_wiki_sync.py` — 11 tests: 6-record fixture across
  every class → correct class folders; §4 field completeness on every node (no blanks);
  index + lint GREEN; hash change → stale/AMBER; orphan → RED; missing ACTIVE → RED; idempotency
  byte-identical (second build writes 0); hand-written node never overwritten + cross-linked;
  `build_single` hook; class-change pruning (no duplicate/orphan); id-less records are not
  false-duplicates.
- Regression: `test_factory_bottleneck_readmodel.py`, `test_heartbeat_book_evolution_health.py`,
  `test_mission_control_v2_data.py`, `test_book_evolution_readmodels.py`,
  `test_render_cockpit_v2.py`, `test_build_backlog_dedup.py`, `test_retire_approved_cards.py`.

Summary line: **16 new tests pass; 66 regression tests pass (0 failures).**

## Runtime / vault artifacts written (RUN FOR REAL, live vault)

- `G:\...\09 Strategy Wiki\generated\<class>\*.md` — **5,265 generated nodes**
  (ACTIVE_CANONICAL 3,820 · DRAFT 130 · RETIRED 356 · REJECTED 893 · DUPLICATE 7 · SUPERSEDED 4
  · HISTORICAL 55). First build ~533 s (dominated by Google-Drive write latency), converging
  re-build ~24 s (50 written / 5,215 skipped / 4 pruned).
- `G:\...\09 Strategy Wiki\generated\_INDEX.md` — generated index (per class + per family).
- `G:\...\09 Strategy Wiki\_INDEX.md` — generated marker block appended (hand-written preamble
  preserved verbatim between `<!-- STRATEGY_WIKI_SYNC:BEGIN/END -->`).
- `G:\...\09 Strategy Wiki\generated\.sync\state.json` — sidecar (wall-clock + counts).
- `D:\QM\reports\state\strategy_wiki_sync.json` — health read-model, **STRATEGY_WIKI_SYNC = GREEN**.

## §2 measured counts (live, after convergence)

| Metric | Value |
|---|---:|
| canonical / valid cards (ACTIVE_CANONICAL) | 3,820 / 3,820 |
| draft cards | 130 |
| retired cards | 356 |
| rejected cards | 893 |
| duplicate cards | 7 |
| superseded | 4 |
| historical | 55 |
| cards with EA id (nodes) | 5,160 |
| cards without EA id (nodes) | 105 |
| current pipeline EAs (`per_ea`) | 3,093 |
| total vault projections (generated nodes) | 5,265 |
| missing vault projections | 0 |
| stale vault projections | 0 |
| duplicate vault projections | 0 |
| orphaned vault projections | 0 |

(Coverage went from 45 hand-written nodes / ~0.35 % to 5,265 generated nodes with 100 % of the
3,820 canonical records projected.)

## Rollback

- Code: revert the patch (all changes are additive/guarded; the approve-card hook is opt-out via
  `QM_WIKI_SYNC_HOOK=0` and never fatal).
- Vault: delete `G:\...\09 Strategy Wiki\generated\` and remove the marker block from
  `_INDEX.md` (hand-written text outside the markers is untouched). Hand-written `strategies/`
  nodes were never modified.
- Scheduled task: not registered; run `install_strategy_wiki_sync_scheduled_task.ps1 -Uninstall`
  only after the orchestrator registers it.

## NOT done (with reasons)

- **Scheduled task not registered** — RED boundary for this slice (installer written only). The
  orchestrator runs `install_strategy_wiki_sync_scheduled_task.ps1`.
- **Per-EA DXZ/FTMO status** resolves only for EAs present in the book-evolution read-models
  (incumbent/challenger membership); every other EA emits `NOT_APPLICABLE` (book present) — this
  is correct, not a gap. A fuller per-EA book membership index is out of scope here.
- **External (non-QM-RESEARCH) source hashes** emit EVIDENCE_MISSING — the durable hash lives in
  the source node, not the card; wiring the vault `sources/*.md` graph into `source_hash` is a
  follow-up (does not affect GREEN, since `unresolved_source` only flags unresolvable
  QM-RESEARCH ids).
- **No commit/push** — orchestrator commits (patch delivered).

## Commands for the orchestrator

```powershell
# from C:\QM\repo (canonical repo, after merge)
python -X utf8 tools/strategy_farm/strategy_wiki_sync.py build
python -X utf8 tools/strategy_farm/strategy_wiki_sync.py index --init-root-index
python -X utf8 tools/strategy_farm/strategy_wiki_sync.py lint       # exit!=0 on RED
python -X utf8 tools/strategy_farm/strategy_wiki_sync.py status
# register the 60-min task (SYSTEM):
powershell -File tools/strategy_farm/install_strategy_wiki_sync_scheduled_task.ps1
```
