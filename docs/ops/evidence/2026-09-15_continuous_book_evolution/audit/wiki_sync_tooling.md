# Audit — Strategy Wiki Sync Tooling (Directive §3–§8)

**Read-only auditor · 2026-09-15 · branch `agents/board-advisor`**

## Headline (3 lines)
1. The Strategy Wiki Sync is a **documented target contract only** — `09 Strategy Wiki/Strategy Wiki Sync Protocol.md` (2026-08-20) specifies it, but **no generator exists**: there is no `strategy_wiki_sync.py`, no scheduled task writes wiki nodes, and 0 of the 45 vault strategy nodes carry `generated: true`; all were hand-written by bulk `INGEST` runs (last `_INDEX.md` full rebuild 2026-05-08).
2. Coverage is a chasm: **~3,999 canonical strategy cards / 4,956 registered EAs (4,109 active) vs 45 vault strategy projections (~1.1%)**; the one existing dedup tool that references the wiki (`framework/scripts/research_dedup_check.py`) has been **fail-closed since inception on a wrong path** (`G:\My Drive\09 Strategy Wiki` — missing the `QuantMechanica - Company Reference` segment), so vault-side dedup has never actually run.
3. Every §4 field can be sourced from existing read-models (pipeline_state.json gate readmodel, EA/magic registries, canonical Strategy Cards, `research_source.py` QM-RESEARCH lineage, agent_chain receipts) except a few that are structurally `EVIDENCE_MISSING` today (per-EA `card_hash`/`repo_path`/`build_hash` are not in the readmodel and must be computed at projection time; DXZ/FTMO per-strategy status has no per-EA read-model). A deterministic `strategy_wiki_sync.py build/lint/index` plus a `STRATEGY_WIKI_SYNC` Mission Control health key is specified below.

---

## Measured counts

| Metric | Value | Query / command |
|---|---:|---|
| Vault strategy nodes (`09 Strategy Wiki/strategies/*.md`) | 45 | `ls "G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki/strategies/" \| wc -l` |
| Vault nodes with `generated: true` | 0 | `grep -rl "generated: true" ".../09 Strategy Wiki/strategies/" \| wc -l` |
| Vault source nodes / concepts / indicators | 24 / 20 / 26 | `ls ".../09 Strategy Wiki/{sources,concepts,indicators}/" \| wc -l` |
| `strategy_cards_count` (canonical, readmodel) | 3,999 | `pipeline_state.json["strategy_cards_count"]` (unique `.md` stems across `strategy-seeds/cards`, `strategy-seeds/specs`, `D:/QM/strategy_farm/artifacts/cards_approved`; `scripts/build_pipeline_state.py:87` `count_strategy_cards`) |
| `eas_registered_count` | 4,956 | `pipeline_state.json["eas_registered_count"]` |
| EA registry rows by status | active 4,109 · retired 802 · pending 32 · DRAFT 4 · allocated 4 · backtest-only 2 · APPROVED 1 · build_test 1 · reserved 1 | `csv.DictReader(framework/registry/ea_id_registry.csv)` |
| `eas_with_reports_count` (per_ea entries) | 3,093 | `pipeline_state.json["eas_with_reports_count"]` / `len(per_ea)` |
| approved cards `strategy-seeds/cards/approved/` | 925 | `ls strategy-seeds/cards/approved/ \| wc -l` |
| top-level cards `strategy-seeds/cards/*.md` | 635 | `find strategy-seeds/cards -maxdepth 1 -name "*.md" \| wc -l` |
| cards `D:/QM/strategy_farm/artifacts/cards_approved/` (repo mirror `artifacts/cards_approved/`) | 253 | `ls artifacts/cards_approved/ \| wc -l` |
| `framework/EAs/` build dirs | 4,125 | `ls framework/EAs/ \| wc -l` |
| magic_numbers.csv rows | 18,496 | `wc -l framework/registry/magic_numbers.csv` |
| by_gate_v4 (highest contiguous gate census) | Q02 2089·Q03 1085·Q04 569·Q05 334·Q06 306·Q07 242·Q08 52·Q09 107·Q10 32·Q11 51·Q12 2·Q14 29 | `pipeline_state.json["by_gate_v4"]` |
| Scheduled tasks matching `Wiki`/`Vault` | 2 (`QM_MorningBriefing_Vault`, `QM_NightlyBackup_Vault`) — **neither syncs strategy nodes** | `Get-ScheduledTask QM_* \| ? {$_.TaskName -match 'Wiki\|Vault'}` |
| Scheduled task that runs a strategy-wiki projection | 0 | `Get-ScheduledTask` action scan for `wiki\|strategy_wiki\|check_repo_vault` → none |
| `strategy_wiki_sync.py` in repo | 0 (does not exist) | `ls tools/strategy_farm/*.py`; grep `strategy_wiki_sync` → no code hits |

Coverage ratio (vault projections / canonical cards): **45 / 3,999 ≈ 1.1 %**. Even against the 45-node universe the `_INDEX.md` header still claims "zuletzt vollständig neu gebaut: 2026-05-08 (28 Cards)".

---

## Findings

### F1 — The concept is fully specified but unbuilt
- `G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki/Strategy Wiki Sync Protocol.md` (Status: *target contract*, 2026-08-20) defines exactly the §3 flow: `Registry + Cards + Gate Readmodel + Report Manifest → validate keys/hashes → render/update nodes → rebuild _INDEX → link/frontmatter/staleness lint → optional public projection`, with rules "repo-card wins", "generated nodes carry `generated: true` + producer + source-hash + sync time", "manual edits to generated fields fail the lint", "missing reports = `EVIDENCE_MISSING`, never a silent link", "idempotent: same sources → byte-identical generated content".
- `_SCHEMA.md` documents the Karpathy 3-layer wiki model (Raw Sources / Wiki / Schema) and the directory layout.
- `_TEMPLATE Strategy.md` exists with frontmatter fields (`ea_id, slug, sources[], concepts[], indicators[], g0_status, r1..r4, pipeline_phase, card_hash, repo_path, quality_grade, generated, last_updated`).
- **But no code implements it.** All 45 nodes were produced by manual `INGEST` events recorded in `_LOG.md` (2026-08-15 bulk imports), carry `generated: false` / no generated flag, and mix `card_schema_version: 2` frontmatter that does not match the sync-protocol schema. This is the core §3 gap: "Implement/finish the existing Strategy Wiki Sync concept as a deterministic generated projection."

### F2 — The only wiki-aware automation is broken on a path bug (drift)
- `framework/scripts/research_dedup_check.py:60` hard-codes `DEFAULT_WIKI_VAULT = Path(r"G:\My Drive\09 Strategy Wiki")`. The real vault root is `G:\My Drive\QuantMechanica - Company Reference\09 Strategy Wiki`.
- Consequence, reproduced in the MNT-026 evidence (`docs/ops/evidence/2026-08-21_mnt026_dedup_fail_closed.md` line 63 and `..._reverification.md` line 69): the wiki source resolves to `ROOT_ACCESS_ERROR` / `MISSING_ROOT` every run. Dedup against the vault wiki has **never executed**; only EA-registry + repo-cards dedup runs. Any new-ID decision "must rerun with all source bindings OK or stop fail-closed" — so this bug either blocks clean dedup or silently proceeds without vault coverage.

### F3 — Read-models for §4 already exist and are healthy
- **Gate readmodel**: `D:/QM/reports/state/pipeline_state.json` (9.6 MB, regenerated 2026-09-15T14:27Z by `scripts/build_pipeline_state.py`; also written by `render_cockpit.py`). `per_ea[]` carries `ea_id, latest_pass_phase, phase_verdicts, status, final_verdict, phase_blockers[], last_run_utc` — directly supplies current highest contiguous gate, pipeline status, terminal verdict, current blocker, evidence freshness.
- **EA/magic registries**: `framework/registry/ea_id_registry.csv` (ea_id, slug, strategy_id, status, owner, created_at, retired_at, retired_reason) and `framework/registry/magic_numbers.csv` (ea_id, ea_slug, symbol_slot, symbol, magic, status) → id/name/slug/lifecycle/build-slot identity.
- **Canonical Strategy Card**: `strategy-seeds/cards/` (+`specs/`, +`artifacts/cards_approved/`) → mechanic, family, source_type, source_id, author, timeframes, target_symbols, direction, parameter family, provenance.
- **Card hash / build identity**: `tools/strategy_farm/canonical_hash.py` (`canonical_blob_sha256`, LF-normalized git-blob basis) is the correct standard for `card_hash` / `build_hash` — must be computed at projection time (not present in the readmodel).
- **Research lineage**: `tools/strategy_farm/research_source.py` (QM-RESEARCH namespace; store `strategy-seeds/sources/`, ledger `D:/QM/reports/state/research_source_ledger.jsonl`; `resolve`/`verify` subcommands, `source_hash` binding) → internal `QM-RESEARCH://` source + hash + lineage.json + critic_receipt.json.
- **Criticism**: `tools/strategy_farm/agent_chain.py` receipts (`qm.agent-chain.receipt.v1`) under `D:/QM/strategy_farm/artifacts/agent_chain/<chain_id>/` → cross-vendor critic verdict + finding_counts.
- **Vault source graph**: `09 Strategy Wiki/sources/*.md` frontmatter (`type: source, source_type, author, year, strategies_extracted[]`) → external source node + author linkage.

### F4 — No Mission Control health key for wiki sync
- `tools/strategy_farm/mission_control_v2_data.py` reads `D:/QM/strategy_farm/state/health.json` and exposes keys like `router_health`; there is **no `STRATEGY_WIKI_SYNC`** key. §6 requires one.

### F5 — Existing reusable "projection" precedent
- `tools/strategy_farm/board_projection.py` and `research/observe_projector.py` already establish the "deterministic projection" pattern in this repo; `check_repo_vault_refs.py` already walks repo→vault `.md` link integrity (a partial lint primitive). The sync tool should reuse these patterns rather than invent new ones.

---

## §4 field → read-model map

Legend: **✓ available** · **⧗ compute-at-projection** (deterministic from an existing artifact) · **✗ EVIDENCE_MISSING** (no per-strategy read-model today).

| §4 field | Source read-model / file | State |
|---|---|---|
| Strategy / EA ID | `ea_id_registry.csv` · card frontmatter `ea_id` | ✓ |
| Name | card `# <title>` / registry `slug` | ✓ |
| Slug | registry `slug` · card frontmatter `slug` | ✓ |
| lifecycle status | registry `status` (+ card `status`/`g0_status`) | ✓ |
| source type | card frontmatter `source_id`/`source_citations[].type`; vault `sources/*.md` `source_type` | ✓ |
| source / internal research ID | card `source_id`; `research_source.py resolve` → `QM-RESEARCH://<id>` | ✓ |
| author | card `source_authors` / registry `owner`; QM-RESEARCH `author` | ✓ |
| mechanical strategy summary | card `strategy_mechanic` + body Entry/Exit/SL/Sizing | ✓ |
| strategy family | card `strategy_type_flags` / `concepts[]` | ✓ |
| key mechanism | card `strategy_mechanic` / `indicators[]` | ✓ |
| timeframe(s) | card `timeframe`/`timeframes[]` | ✓ |
| intended / tested symbols | card `target_symbols[]`; tested = `per_ea` symbol verdicts via report manifest | ✓ |
| long/short direction | card body / `strategy_type_flags` | ✓ (parse) |
| parameter family summary | card params block / `framework/EAs/<slug>/SPEC.md` | ✓ |
| canonical Repo path | derived (`strategy-seeds/cards/<...>.md`) | ⧗ compute |
| Card hash | `canonical_hash.canonical_blob_sha256(card_path)` | ⧗ compute (not in readmodel) |
| source hash | `research_source.py` `source_hash` (ledger); external sources = `EVIDENCE_MISSING` unless a source node exists | ⧗ / ✗ |
| build identity where relevant | `magic_numbers.csv` + `canonical_hash` of `.ex5`/`.mq5`; `framework/EAs/<slug>` build_identity | ⧗ compute |
| current highest contiguous valid gate | `per_ea[].latest_pass_phase` | ✓ |
| current pipeline status | `per_ea[].status` | ✓ |
| terminal verdict where applicable | `per_ea[].final_verdict` | ✓ |
| current blocker | `per_ea[].phase_blockers[]` | ✓ |
| duplicate / clone / variant relationships | `research_dedup_check.py` output + card `strategy_id`/`variant_id` | ✓ (once F2 path fixed) |
| parent/child lineage | QM-RESEARCH `lineage.json`; card `variant_id`/parent refs | ✓ / ⧗ |
| current DXZ status / relevance | **no per-EA read-model** (T_Live book profile is portfolio-level) | ✗ EVIDENCE_MISSING |
| current FTMO status / relevance | **no per-EA read-model** (FTMO book is portfolio-level) | ✗ EVIDENCE_MISSING |
| live/demo status if relevant | derive from T_Live magic registry / `build_tlive_book_profile.py`; else `NOT_APPLICABLE` | ⧗ / ✗ |
| evidence freshness | `per_ea[].last_run_utc` vs now | ✓ |
| last synchronization timestamp | written by the sync tool into a **sidecar** (not the deterministic node body) | ⧗ (tool-generated) |

The DXZ/FTMO per-strategy gap (§4, §8, §19) is the one substantive missing read-model: it should be filled by a small per-EA membership index derived from the live/FTMO book manifests, or the field emitted as `NOT_APPLICABLE`/`EVIDENCE_MISSING` rather than guessed.

---

## Drift

| # | Drift | Evidence |
|---|---|---|
| D1 | Wiki dedup source permanently fail-closed on wrong path | `framework/scripts/research_dedup_check.py:60` `G:\My Drive\09 Strategy Wiki` vs real `...\QuantMechanica - Company Reference\09 Strategy Wiki`; MNT-026 evidence `ROOT_ACCESS_ERROR`/`MISSING_ROOT` |
| D2 | `_INDEX.md` claims a 2026-05-08 full rebuild of 28 cards; 45 nodes now exist, index maintained by hand | `.../09 Strategy Wiki/_INDEX.md` header |
| D3 | Sync protocol schema (`_TEMPLATE Strategy.md`: `card_hash, repo_path, quality_grade, generated`) does not match the actual node frontmatter (`card_schema_version: 2`, no `generated`/`card_hash`) | `strategies/QM5_30001_*.md` vs `_TEMPLATE Strategy.md` |
| D4 | No scheduled automation for wiki sync or repo→vault link lint; `check_repo_vault_refs.py` and `weekly_unreadable_links_mail.py` exist but the former is not in `qm_tasks.manifest.ps1` | `Get-ScheduledTask` scan; grep of manifest |
| D5 | ~99 % of the canonical universe is invisible in the vault (45 of ~3,999); §3 "every canonical Strategy Card must be discoverable from the Vault" unmet | counts table |

---

## Recommended implementation

Reuse the existing readmodel + projection + lint primitives; do not invent a second truth. All new code under `tools/strategy_farm/`.

### 1. `tools/strategy_farm/strategy_wiki_sync.py` (new) — 3 subcommands
- **`build`** — deterministic projection. Inputs (all existing): `framework/registry/ea_id_registry.csv`, `magic_numbers.csv`, canonical cards (`strategy-seeds/cards[/approved]`, `specs`, `artifacts/cards_approved`), gate readmodel `D:/QM/reports/state/pipeline_state.json` (`per_ea`), report/evidence manifest via `evidence_status.py`, `research_source.py resolve/verify` for `QM-RESEARCH` lineage, `canonical_hash.canonical_blob_sha256` for `card_hash`/`build_hash`, `agent_chain` receipts for criticism. Output: one node per canonical strategy at `09 Strategy Wiki/strategies/QM5_<id>_<slug>.md` with `generated: true`, `producer: strategy_wiki_sync/v1`, `source_hash`, and every §4 field or an explicit `NOT_EVALUATED`/`UNKNOWN`/`NOT_APPLICABLE`/`EVIDENCE_MISSING`.
- **`index`** — regenerate `_INDEX.md` grouped by projection class, from the generated node set only (never hand-edited).
- **`lint`** — the §6 machine check: for `canonical_strategy_records` vs `valid_vault_strategy_projections` report `missing, stale, hash_mismatch, duplicate, orphan, invalid_link, unresolved_source, unresolved_lineage`; reuse `check_repo_vault_refs.py`'s link-walk for `invalid_link`. Exit non-zero on any category; emit `state/strategy_wiki_sync.json` health artifact.

### 2. Projection classes (§5 mapping rule — deterministic, source-of-truth = registry `status` + card `status` + `per_ea.final_verdict`)
`ACTIVE/CANONICAL` (registry active AND card approved AND not superseded) · `DRAFT` (card status DRAFT / g0 PENDING) · `RETIRED` (registry retired) · `REJECTED` (final_verdict FAIL/BLOCKED terminal) · `DUPLICATE` (dedup exact/self match) · `SUPERSEDED` (card `superseded_by` / lineage child exists) · `HISTORICAL` (imported, no active EA). Class written to frontmatter `projection_class` and used as the `_INDEX.md` grouping — so status is unmistakable and no historic idea reads as currently viable.

### 3. Idempotency rule
Byte-identical output for identical canonical inputs: sort all frontmatter keys and list members; render body from a fixed template order; **no timestamps in the node body**. The only volatile values (`last_synced_at`, run id, input file mtimes/hashes) live in a **sidecar** `09 Strategy Wiki/strategies/.sync/<id>.json`, so a re-run with unchanged inputs produces a no-op diff on the node itself (satisfies §7 "same canonical inputs → same generated result"). `card_hash`/`source_hash` come from `canonical_hash`/`research_source` (content-addressed), not wall-clock.

### 4. Scheduled task + hook
- Scheduled task **`QM_StrategyFarm_WikiSync`** (SYSTEM, e.g. every 6 h or after the heartbeat), action `python -X utf8 tools/strategy_farm/strategy_wiki_sync.py build && ... index && ... lint`, registered in `tools/strategy_farm/qm_tasks.manifest.ps1`.
- **Post-card-change hook**: invoke `strategy_wiki_sync.py build --only <id>` from the card-approval path (`card_intake_prescreen.py` / approve-card flow) and from the QM-RESEARCH `seal` path, so §7 "new strategies appear automatically" holds without a manual Drive copy.

### 5. Mission Control health key
Add `STRATEGY_WIKI_SYNC` to `mission_control_v2_data.py`, reading `state/strategy_wiki_sync.json`: `GREEN` when lint reports zero of every category; `YELLOW` on stale-only; `RED` on missing/hash_mismatch/orphan/unresolved. Surface counts (missing/stale/duplicate/orphan) alongside `router_health`.

### 6. Prerequisite fixes (small, reversible)
- Fix `research_dedup_check.py:60` wiki root to `G:\My Drive\QuantMechanica - Company Reference\09 Strategy Wiki` (D1) so dedup and the sync tool share one correct vault path — recommend a shared constant in a new `tools/strategy_farm/vault_paths.py` reused by `check_repo_vault_refs.py`, `research_dedup_check.py`, and `strategy_wiki_sync.py`.
- Add a per-EA DXZ/FTMO membership index (from live + FTMO book manifests) so the §4 DXZ/FTMO fields resolve deterministically instead of `EVIDENCE_MISSING`.

*All findings carry a path/query above. No files were modified; this report and its sidecar are the only writes.*
