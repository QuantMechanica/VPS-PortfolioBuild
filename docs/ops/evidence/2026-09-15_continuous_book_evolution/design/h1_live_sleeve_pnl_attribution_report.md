# Slice h1_live_sleeve_pnl_attribution — report

Directive 3 §33 / §43H / §44. Build the deterministic live-money per-sleeve PnL
attribution feed from real DXZ execution data and wire it into the recomposition engine,
research ROI, strategy lineage and the 15-min read-models. As of 2026-09-15.

## Status: DONE (ran for real, read-only; numbers below)

Live evidence is **PRESENT and fresh** — no EVIDENCE_MISSING for the primary feed. The
AccountMonitor already exports a documented text CSV of live deals, so no T_Live script
attach or binary `.dat` decode was needed.

## Files

New:
* `tools/strategy_farm/live_sleeve_attribution.py` — generator (schema
  `qm.live-sleeve-attribution/v1`), read-only, deterministic, idempotent.
* `tools/strategy_farm/tests/test_live_sleeve_attribution.py` — 7 tests (fixture deals).
* `docs/ops/LIVE_SLEEVE_PNL_ATTRIBUTION.md` — canonical spec (sources, parsing, mapping,
  formulas, blend rule, health semantics, EVIDENCE_MISSING today, first-run numbers,
  rollback).
* `docs/ops/evidence/2026-09-15_continuous_book_evolution/design/h1_live_sleeve_pnl_attribution_report.md` — this report.

Modified (wiring, read-only joins):
* `tools/strategy_farm/portfolio/recompose/frozen_snapshot.py` — `_live_evidence(dxz)` now
  embeds the attribution summary + documented blend rule and **freezes the file into
  `inputs/`**; `load_snapshot` re-hashes it (section-70). New constants
  `LIVE_BLEND_MIN_DAYS`, `LIVE_BLEND_RULE`, helper `_live_attribution_block`.
* `tools/strategy_farm/research/external_roi.py` — `economic_contribution` per programme is
  now real realized live USD by origin (was EVIDENCE_MISSING); new
  `load_live_economic_contribution`, top-level `live_economic_contribution`,
  `--live-attribution` CLI, live fingerprint in `inputs_sha256`, doc/summary updates.
* `tools/strategy_farm/strategy_wiki_sync.py` — new per-EA node fields
  `live_realized_net_usd / live_realized_dd_usd / live_trade_count / live_last_deal_utc`
  (read-only join via `load_live_pnl`); `Sources.live_attribution`; hashed so only
  live-book nodes churn.
* `tools/strategy_farm/book_evolution_runner.py` — `_default_state_builds` appends
  `live_sleeve_attribution` (refreshes before every freeze).
* `tools/strategy_farm/tests/test_research_external_roi.py`,
  `tools/strategy_farm/tests/test_strategy_wiki_sync.py` — hermetic fixtures + live-join tests.

## Contracts

* `qm.live-sleeve-attribution/v1` (NEW): `D:/QM/reports/state/live_sleeve_attribution.json`.
  Per sleeve (magic→ea_id/symbol/slot): realized_pnl, floating_pnl(=EVIDENCE_MISSING),
  gross, net, swap, commission, trade_count, realized_dd, contribution_to_book_return,
  contribution_to_book_dd, since_utc, last_deal_utc, data_source, freshness. Plus
  book_totals, correlation_matrix (Pearson daily; EVIDENCE_MISSING when n_days<20), health
  (source_present/deals_parsed/roster_size/mapped_sleeves/unmapped_magics/dark_sleeves),
  authorization (all false). Carries `schema` + `generated_at_utc`.
* `qm.research-roi/v1` (EXTENDED, additive): `economic_contribution.pnl` becomes real USD;
  adds `live_economic_contribution`.
* `qm.recompose-frozen-inputs/v1` (EXTENDED, additive): `live_evidence.live_attribution`.
* `qm.strategy-wiki-sync` node frontmatter (EXTENDED, additive): 4 live fields.

## Tests

`python -X utf8 -m pytest tools/strategy_farm/tests/test_live_sleeve_attribution.py
tools/strategy_farm/tests/test_research_external_roi.py
tools/strategy_farm/tests/test_strategy_wiki_sync.py
tools/strategy_farm/tests/test_recompose_engine.py
tools/strategy_farm/tests/test_book_evolution_runner.py
tools/strategy_farm/tests/test_book_evolution_readmodels.py
tools/strategy_farm/tests/test_live_deal_attribution.py -q` → **56 passed**.

## Runtime / vault artifacts (produced by the real run)

* `D:/QM/reports/state/live_sleeve_attribution.json` (45 159 bytes, generated
  2026-09-15T18:10:00Z): status PRESENT, 24 sleeves, 103 closed positions,
  correlation PRESENT.
* No vault writes in this slice (wiki nodes are written by the existing wiki-sync task,
  which now carries the live fields on its next run).

## Headline numbers (first real run, read-only)

* Book realized PnL **−2 477.67 USD**, realized DD **3 376.52 USD**, realized return
  **−2.4777 %** (100k base); account equity **99 376.10**, book floating **−13.28**.
* Reconciliation exact: 24 sleeves −938.17 + manual magic-0 −1 539.50 = book −2 477.67.
* Correlation matrix PRESENT: n_days 54, 16 sleeves scored, 120 pairs.
* By origin: external_source −938.17 (22 sleeves/102 trades); internal_discovery 0.0;
  owner_mission 0.0; unmapped live EAs none.
* Dark sleeves (no closes, no-data): 10919, 12567×2, 12778, 12969, 12989, 13117, 13128.

## RED boundaries respected

Read-only against T_Live (parses the AccountMonitor CSV export; never decodes `.dat`,
never attaches a script, never toggles AutoTrading, no order actions — recorded in the
`authorization` block). No farm-DB writes, no terminal64 starts, no verdict/gate changes,
no deployment. The blend rule keeps backtest PRIMARY and never overrides a gate verdict.

## NOT done (with reasons)

* **Per-sleeve floating PnL** — EVIDENCE_MISSING. The AccountMonitor exports only
  book-level floating; per-sleeve needs an open-positions export. Delivered honestly as
  EVIDENCE_MISSING + the exact OWNER/orchestrator action (extend
  `framework/monitor/QM_AccountMonitor.mq5` to write open positions; no AI seat attaches a
  script to T_Live).
* **Internal D-Score ingestion** — out of scope (Darwinex-side; audit finding 18).
* **Mission Control widget** (§45) — separate slice; the read-model it needs now exists.

## Exact commands for the orchestrator

1. Apply patch on `agents/board-advisor`, then run tests:
   `python -X utf8 -m pytest tools/strategy_farm/tests/test_live_sleeve_attribution.py tools/strategy_farm/tests/test_research_external_roi.py tools/strategy_farm/tests/test_strategy_wiki_sync.py tools/strategy_farm/tests/test_recompose_engine.py tools/strategy_farm/tests/test_book_evolution_runner.py -q`
2. Generate the read-model for real (read-only):
   `python -X utf8 tools/strategy_farm/live_sleeve_attribution.py`
3. No new scheduled task needed — the feed is registered as a state-build inside the
   existing book-evolution runner (`QM_StrategyFarm_BookEvolution*`); it refreshes on the
   next runner cycle. No worker reload required.
4. (Optional, OWNER) to unlock per-sleeve floating: extend the AccountMonitor EA to export
   open positions; recompile/redeploy on T_Live is OWNER-only.

## Rollback

Remove the `live_sleeve_attribution` entry from
`book_evolution_runner._default_state_builds`; consumers degrade to EVIDENCE_MISSING and
keep working. All joins are additive and read-only. The generator writes only its own
read-model file.
