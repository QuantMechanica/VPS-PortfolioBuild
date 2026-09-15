# Strategy Wiki Completeness Counts — Directive §2

**Audit date:** 2026-09-15 · **Auditor:** Claude (read-only) · **Scope:** OWNER follow-up directive §2 (measure, do not infer from `_INDEX.md`).

## Headline (3 lines)
1. The generated Strategy Wiki does **not exist yet**: all 45 vault strategy nodes are hand-migrated (0 carry `generated`/`card_hash`/`generated_by`); the last full `_INDEX` rebuild was 2026-05-08 (28 cards) and the "Strategy Wiki Sync Protocol" is still a **target contract**, with no exporter in `tools/` or `scripts/`.
2. Against **3,750 canonical strategy records** (and 3,246 EAs in the live pipeline), the vault projects **45 nodes**, of which only **13 map to a canonical record** — a coverage of **0.35 %**; **3,737 canonical cards have no vault node** and **17 vault nodes are orphans** (`ea_id: TBD`, no canonical record).
3. Secondary drift: the repo-authoritative card store is tiny (253 in `artifacts/cards_approved` + 925 in `strategy-seeds/cards/approved`) while **3,427 approved cards live only on D:\ runtime** (3,233 D-only); **213 approved cards are absent from the EA registry**; and **0 of 3,427 approved cards persist `card_sha256`**, so hash-based staleness cannot be computed today.

## Measured counts

| Metric | Value | Source / query |
|---|---|---|
| strategy-seeds/cards (top-level draft seeds) | 635 | `ls strategy-seeds/cards/*.md \| wc -l` |
| strategy-seeds/cards/approved (repo approved) | 925 (917 w/ QM5 id) | `find strategy-seeds/cards/approved -name '*.md' \| wc -l` |
| artifacts/cards_approved (C:\ repo) | 253 | `find C:/QM/repo/artifacts/cards_approved -maxdepth 1 -name '*.md' \| wc -l` |
| cards_approved (D:\ runtime) | 3,427 | `find D:/QM/strategy_farm/artifacts/cards_approved -maxdepth 1 -name '*.md' \| wc -l` |
| cards_draft (D:) / cards_review (D:) | 20 / 159 | `find …/cards_draft(…/cards_review) -maxdepth 1 -name '*.md'` |
| cards_rejected (D:) | 1,016 | `find …/cards_rejected -maxdepth 1 -name '*.md'` |
| cards_recovery / cards_blocked_r3_data / card_duplicates_g0 (D:) | 3 / 8 / 15 | same pattern per dir |
| framework/EAs/*/docs/strategy_card.md | 1,710 (of 4,125 EA dirs) | `find framework/EAs/*/docs/strategy_card.md \| wc -l` |
| ea_id_registry.csv rows | 4,956 (active 4,109 / retired 802 / other 45) | `wc -l framework/registry/ea_id_registry.csv`; status Counter |
| magic_numbers.csv rows | 18,496 | `wc -l framework/registry/magic_numbers.csv` |
| **Pipeline: distinct EA ids (work_items)** | **3,246 gate-bearing (3,454 incl. non-gate)** | `SELECT COUNT(DISTINCT ea_id) FROM work_items` (=3,454); gate-classified via highest-phase join |
| **Pipeline: distinct (EA,symbol)** | **15,563** | `SELECT COUNT(DISTINCT ea_id||'\|'||IFNULL(symbol,'')) FROM work_items` |
| **Vault strategy projections** | **45** | `find "09 Strategy Wiki/strategies" -name '*.md' \| wc -l` |
| — of which machine-generated | **0** | `grep -lE '^generated:\|^card_hash:\|^generated_by:' strategies/*.md \| wc -l` = 0 |
| — with real QM5 ea_id / with `TBD` / legacy numeric | 17 / 17 / 11 | `grep -m1 '^ea_id:' … \| sort \| uniq -c` |
| **Distinct canonical/valid cards** | **3,750** | join script `projection_class==CANONICAL` (CSV) |
| **Draft cards** | **218** | join `projection_class==DRAFT` |
| **Retired cards** | **356** | join `projection_class==RETIRED` (registry status=retired) |
| **Rejected cards** | **893** | join `projection_class==REJECTED` (member of cards_rejected) |
| **Duplicate cards** | **7** | join `projection_class==DUPLICATE` (member of card_duplicates_g0) |
| **Cards with EA ids** | **4,055** | join: real ea_id present in any card store |
| **Cards without EA ids** | **42** | join: `ea_id` absent/`TBD` but present in a card store |
| **Missing vault projections (canonical)** | **3,737** | join: CANONICAL and no `vault_node` |
| Missing projections (canonical OR pipeline) | 3,958 | join: (CANONICAL or in_pipeline) and no vault_node |
| **Stale vault projections** | **≥6 (lower bound)** | join: `vault_node_mtime < card_mtime`; content-date of all nodes ≈ 2026-05-08 |
| **Duplicate vault projections** | **0** | no two nodes share one normalized id |
| **Orphaned vault projections** | **17** | join: vault_node with no card/registry/pipeline record (all `ea_id: TBD`) |

Full one-row-per-id join written to `wiki_completeness_join.csv` (5,246 rows, all flags) and `wiki_completeness_summary.json`, both next to this report.

## Classification definition (quoted frontmatter fields)

Cards use two on-disk conventions:
- **Approved store** (`cards_approved`, `strategy-seeds/cards/approved`): YAML `---` frontmatter with `ea_id: QM5_NNNNN`, `slug`, `source_id`, **`g0_status: APPROVED`**, `pipeline_phase: G0`, `last_updated`. No `card_sha256` is persisted (0/3,427).
- **Seed drafts** (`strategy-seeds/cards/*.md`): a ```` ```yaml ```` header block with `strategy_id`, **`ea_id: TBD`**, **`status: DRAFT`**.
- **Registry** (`ea_id_registry.csv`): column **`status`** ∈ {active, retired, DRAFT, pending, …}.

Records are keyed by the normalized numeric EA id (strip `QM5_`); a card with no real id keys on its filename. Precedence used to assign one `projection_class`:
1. member of `cards_rejected/` → **REJECTED**
2. registry `status == retired` → **RETIRED**
3. member of `card_duplicates_g0/` → **DUPLICATE**
4. real id **and** present in an approved store (`g0_status: APPROVED`) → **CANONICAL**
5. `in_draft`/`in_review`/`status: DRAFT`/top-level seed → **DRAFT**
6. real id present in registry/pipeline/EA-docs → **CANONICAL** (card body on D: runtime only)
7. otherwise → **OTHER**

Vault node quality: a node is **generated** iff its frontmatter carries `generated`/`card_hash`/`generated_by` — **none do**. Staleness by hash cannot be computed because nodes carry no hash and cards persist no `card_sha256`; mtime staleness is a lower bound (all node contents date to the 2026-05-08 migration; the Google-Drive mtime is 2026-08-20).

## Findings
- **F1 — the deterministic projection was never built.** `Strategy Wiki Sync Protocol.md` (status "target contract", 2026-08-20) specifies the exact flow (Registry+Cards+Gate readmodel+Report manifest → generated node → rebuilt `_INDEX` → staleness lint) and generated-node keys (`generated: true`, `card_hash`, `repo_path`, `build_hash`, sync time). No exporter implements it: `grep -rliE 'strategy_wiki|wiki_sync|card_hash' tools/ scripts/` finds only `canonical_card_hash()` in `strategy_card_v3.py` (computes a hash, never written into cards or nodes) and a template reference in `farmctl.py`. `vault_generated == 0`.
- **F2 — coverage is 0.35 %.** 13 of 3,750 canonical records have any vault node; 3,737 are missing. The 45 nodes decompose as 13 CANONICAL, 8 DRAFT, 7 RETIRED, 17 OTHER (orphan `TBD`).
- **F3 — 17 orphaned nodes.** All carry `ea_id: TBD` (e.g. `chan-at-bb-pair`, 11 legacy numeric-id nodes 1003–1017 and 6 others) with no matching approved card / registry row / pipeline id.
- **F4 — repo vs runtime card drift.** Directive §3 says "Repo Card remains authoritative," but the repo-committed approved stores total 1,178 ids (253 + 925, 189 overlap D:) while 3,233 approved cards exist **only** on D:\ runtime. The authoritative-source claim is not physically true today.
- **F5 — registry gap.** 213 approved cards have no `ea_id_registry.csv` row; 56 pipeline EAs have no card in any store (incl. 2 diagnostic ids `QM_DIAG_DWX_*`).
- **F6 — pipeline furthest-progress shape** (highest gate per EA, `work_items`): Q02 1,165 · Q04 1,503 · Q05 235 · Q08 122 · Q10_NEWS 66 · Q14 34 · Q15 1. Only ~34 EAs have reached the terminal optimisation band; the vault represents almost none of them.

## Drift vs `_INDEX.md`
`_INDEX.md` claims "last full rebuild 2026-05-08 (QUA-836, 28 cards)". Measured: 45 strategy nodes exist (not 28), none generated, and the canonical universe has grown to 3,750 — the index understates its own node count and is 4 months and ~3,700 strategies behind the canonical universe. Inferring completeness from `_INDEX.md` (which the directive forbids) would report a healthy wiki; the measured state is 0.35 % coverage.

## Recommended implementation (files)
1. **Build the exporter** `tools/strategy_farm/strategy_wiki_sync.py`: read `framework/registry/ea_id_registry.csv` + canonical cards (resolve repo-first, fall back to D: runtime) + gate readmodel (`work_items` highest contiguous valid gate) + report/evidence manifest + lineage; render one idempotent node per canonical id into `09 Strategy Wiki/strategies/<slug>.md` with `generated: true`, `producer`, `card_hash` (reuse `canonical_card_hash()` in `strategy_card_v3.py`), `source_hash`, `sync_time`, and all §4 fields (missing → `NOT_EVALUATED`/`UNKNOWN`/`EVIDENCE_MISSING`).
2. **Persist `card_sha256`** into every approved card at approve-time (`strategy_card_v3.py` already computes it) so staleness = hash mismatch becomes deterministic.
3. **Reconcile repo vs runtime** (F4): decide the single authoritative approved store and mirror; register the 213 unregistered approved cards; retire/relabel the 17 orphan `TBD` nodes as DRAFT/HISTORICAL.
4. **Completeness lint + Mission Control health** `STRATEGY_WIKI_SYNC = GREEN` (directive §6): compare `canonical_strategy_records` vs `valid_vault_projections`, emit missing/stale/hash-mismatch/duplicate/orphan; schedule after card changes.

**Evidence files:** this report; `wiki_completeness_join.csv`; `wiki_completeness_summary.json` (all in `docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/`).
