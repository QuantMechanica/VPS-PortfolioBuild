# Slice i4_universe_map_roi — Strategy Universe Economic Map + External Source Programme ROI

**Directive:** follow-up §19 (strategy universe economic map) + §20 (external source programme ROI); master §46, §49.
**Author:** Claude (implementation subagent), 2026-09-15. Branch base `agents/board-advisor` @ `8a3ba58fea`.
**Status:** DONE. Two deterministic read-only generators built, wired into the research read-model, tested, and RUN FOR REAL once.

---

## Summary line

Two new deterministic, read-only generators — `universe_map.py` (§19 economic map of the 14,939-pair
strategy universe with qualified/incumbent overlays and a documented white-space ranking) and
`external_roi.py` (§20/§49 harvest funnel by a NEW per-EA `origin_programme` sidecar) — plus their
`research_state` wiring, all landed with 3 test files (37 passing) and run for real against the live DB.

## Headline numbers (real run, 2026-09-15)

**Strategy universe map** (`D:/QM/reports/state/strategy_universe_map.json`, `docs/research/STRATEGY_UNIVERSE_MAP_2026-09.md`):
- Universe = **14,939** `ea x symbol` pairs (Q02+); **qualified 29**; DXZ incumbent 24, FTMO incumbent 8.
- §19 answers: **breakout style 10.32%** (1,541) · **mean-reversion 10.68%** (1,595) ·
  **short-duration FX (intraday/scalp) 27.42%** (4,096) · **gold 9.15%** (1,367) ·
  **session-tagged only 4.38%** (654; unspecified 14,285) · **high-density FTMO-fit only 1.05%** (157).
- Symbol class: fx_major 6,165 · index 3,565 · metal 1,515 · fx_cross 1,472 · energy 986 · fx_jpy 957.
- Holding: position 5,621 · intraday 5,311 · swing 2,441 · scalp 1,448.
- **Top white space** (zero-qualified, tradeable subspace, ranked by 3*ftmo_fit+1*dxz_fit): mean-reversion x
  intraday x session-open x index (EV 34), then scalp/index and pattern/index open cells — the intersection
  of §46 white space and the §47/§48 FTMO gap. Confirms the audit: session-defined intraday index/FX is empty.

**External source programme ROI** (`D:/QM/reports/state/research_roi.json`, `docs/research/RESEARCH_PROGRAMME_ROI_2026-09.md`):
- Origin distribution (new sidecar, 4,876 distinct EAs): **external_source 4,307 · owner_mission 515 ·
  internal_discovery 48 · commercial_rebuild 6 · failure_mining 0**.
- Funnel (EAs; reached = has a work_item row at that gate, not a pass claim):

  | origin | EAs | Q02 | Q08 | Q14 | DXZ book | FTMO book | admit/Q02 % |
  |---|---:|---:|---:|---:|---:|---:|---:|
  | external_source | 4307 | 2781 | 229 | 33 | 19 | 7 | 0.935 |
  | internal_discovery | 48 | 44 | 4 | 0 | 1 | 0 | **2.273** |
  | owner_mission | 515 | 418 | 18 | 2 | 1 | 1 | 0.478 |
  | commercial_rebuild | 6 | 1 | 0 | 0 | 0 | 0 | 0.0 |
  | failure_mining | 0 | 0 | 0 | 0 | 0 | 0 | n/a |

- **ROI signal for §49 allocation:** internal_discovery shows a higher book-admission-per-Q02 yield (2.27%)
  than external_source (0.935%) — small sample (48 EAs) but the first measured evidence that internal
  discovery is not obviously ROI-inferior to another 10k external sources. Sources considered are only the
  measurable universe (seed folders + QM-RESEARCH artifacts), NOT the directive's "tens of thousands" (not in
  metadata — confirmed §6 of the whitespace audit).

## Files changed

New:
- `tools/strategy_farm/research/universe_map.py` — §19 map generator (schema `qm.strategy-universe-map/v1`).
- `tools/strategy_farm/research/external_roi.py` — §20/§49 ROI generator (schema `qm.research-roi/v1`) + origin derivation.
- `framework/registry/ea_origin.v1.csv` — NEW per-EA origin sidecar (schema `qm.ea-origin/v1`; 4,876 rows; `ea_id_registry.csv` untouched).
- `docs/research/STRATEGY_UNIVERSE_MAP_2026-09.md`, `docs/research/RESEARCH_PROGRAMME_ROI_2026-09.md` — human overviews (real run).
- `tools/strategy_farm/tests/test_research_universe_map.py`, `test_research_external_roi.py`.

Modified:
- `tools/strategy_farm/research/research_state_readmodel.py` — folds compact `universe_map` + `roi` summaries into `research_state.json` (degrade-gracefully; new CLI flags `--universe-map-state`, `--research-roi-state`).
- `tools/strategy_farm/tests/test_research_campaign.py` — 1 new folding test + graceful-degradation assertions.

## Contracts

- `qm.strategy-universe-map/v1` (read-model): `schema`, `generated_at_utc`, `inputs_sha256`, `inputs`, `definitions`, `axes`, `totals`, `directive_answers`, `marginals`, `cells`, `ranking_rule`, `whitespace_ranked`.
- `qm.research-roi/v1` (read-model): `schema`, `generated_at_utc`, `inputs_sha256`, `definitions`, `origin_derivation`, `sources_considered`, `totals`, `programmes[]` (funnel + book_admission + yield + economic_contribution).
- `qm.ea-origin/v1` (registry sidecar CSV): `ea_id,slug,origin_programme,basis,has_card`.
- `research_state.json` extended with `universe_map` + `roi` compact blocks (both carry a `status` of PRESENT/EVIDENCE_MISSING).
- Reuses (imports, does not re-implement) `observe_projector` classifiers and `work_item_clean_view`; reads the shared `lineage_map.json` only if present (I2 slice) — not required, degrades gracefully.

## Tests + summary line

`python -X utf8 -m pytest tools/strategy_farm/tests/test_research_universe_map.py tools/strategy_farm/tests/test_research_external_roi.py tools/strategy_farm/tests/test_research_campaign.py tools/strategy_farm/tests/test_research_observe_projector.py -q`
→ **37 passed**. Covers: map cells + classifiers + directive answers + frequency buckets, white-space ranking (FTMO-fit dominance), origin-derivation precedence rules, ROI funnel arithmetic, sources counting, sidecar shape, idempotency (byte-identical with fixed `now`), and research_state folding + graceful degradation.

## Runtime / vault artifacts written (counts)

- `D:/QM/reports/state/strategy_universe_map.json` — 14,939 pairs, 588-ish cells, 25 top white-space rows.
- `D:/QM/reports/state/research_roi.json` — 6 origin programmes, funnel per origin.
- `framework/registry/ea_origin.v1.csv` — 4,876 rows (in the git patch; tracked).
- No Vault write in this slice (map/ROI are docs/research + D: read-models). Live `research_state.json` was NOT overwritten by this slice (validated to a scratch preview only); the 15-min task will regenerate it.

## Determinism / idempotency

Same inputs → byte-identical JSON with `now` fixed (unit test); real-run cross-check: two back-to-back real runs are identical modulo `generated_at_utc`, and `inputs_sha256` is stable. Timestamps are the only wall-clock field; `inputs_sha256` fingerprints the real inputs for change detection (matches the existing read-model convention).

## Rollback

Delete the two new modules, the two docs, the sidecar CSV, and the two test files; revert the two `M` files
(`research_state_readmodel.py`, `test_research_campaign.py`). The `research_state.json` extension is additive and
degrade-gracefully (absent read-models → `EVIDENCE_MISSING`), so reverting the modules alone leaves a valid read-model.
Runtime read-models under `D:/QM/reports/state/` are regenerated by the scheduled task and can be deleted freely.

## NOT-done items (with reasons)

- **Per-EA live/demo PnL attribution** — `economic_contribution.pnl = EVIDENCE_MISSING`; no per-EA PnL
  attribution artifact exists. Reported `book_admission` (DXZ/FTMO incumbent membership) as the closest
  economic-relevance signal. Building a PnL attribution feed is the next step to make §49 a money-ROI (out of scope here).
- **frequency_class is UNKNOWN for ~14,001 pairs** — `ea_metrics.trades` (flat column) is populated for only
  ~810 pairs; per-trade counts otherwise live in `ea_metrics.detail_json`. Parsing 31k JSON blobs was rejected
  as CPU-heavy (whitespace audit §8 flagged this same gap); `holding_class` is the reliable duration axis and
  the caveat is documented in the JSON `definitions` and the MD. A future `observe_projector` extension can emit
  a `parameter_sensitivity`/trade-count CSV to backfill this.
- **mechanism family is still a slug heuristic** (~33% "other") — reused the canonical `observe_projector`
  classifier for consistency rather than inventing a competing taxonomy; a first-class registry mechanism field
  is a separate initiative (whitespace audit recommendation 5).
- **`lineage_map.json`** (I2 slice) not present at run time — the map does not depend on it; relationship
  enrichment (breakout-derivative clustering) will improve automatically once I2 lands.

## Commands for the orchestrator

Regenerate on demand (read-only DB; CPU-modest, single clean-view pass each):
```
cd C:/QM/repo
python -X utf8 tools/strategy_farm/research/universe_map.py
python -X utf8 tools/strategy_farm/research/external_roi.py
python -X utf8 tools/strategy_farm/research/research_state_readmodel.py
```
**15-min read-model task note:** add `universe_map.py`, `external_roi.py`, then
`research_state_readmodel.py` (in that order — the last reads the first two's outputs) to the existing
research read-model scheduled task so Mission Control's Research section and Kimi/Fable prioritisation see the
`universe_map` + `roi` blocks. All three are idempotent and safe to run every cycle; none touch the farm DB,
`terminal64`, T_Live, or gate logic. The origin sidecar `framework/registry/ea_origin.v1.csv` is a committed
artifact — regenerate it (via `external_roi.py`) only when the registry or card stores change materially, and
the orchestrator commits the refreshed sidecar.
