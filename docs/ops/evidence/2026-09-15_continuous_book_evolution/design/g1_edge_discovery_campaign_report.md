# Slice report — g1_edge_discovery_campaign

**Date:** 2026-09-15 · **Authority:** OWNER-DEC-CBE-20260915 §37–§54, §68 PHASE G, §69, §70;
follow-up §16. **Branch:** agents/board-advisor (worktree). **Slice key:** `g1_edge_discovery_campaign`.

## Summary
Delivered the autonomous edge-discovery programme charter, extended the OBSERVE projector with the
white-space fields the audit found missing, built the deterministic research-state read-model, and
**ran the first Kimi research campaign for real end-to-end** (CAMP-2026-0001-ftmo-gap): a live 932 s
Kimi call on the farm's own OBSERVE evidence → durable hash-verified QM-RESEARCH artifact → sealed
after a cross-vendor critique → visible in experiment memory + research state. One mechanizable
hypothesis (H-CW) and durable negative findings were produced.

## Files changed / added
Code:
- `tools/strategy_farm/research/observe_projector.py` (M) — new white-space classifiers
  (`classify_timeframe/holding/symbol_class/session`), `extract_parameter_sensitivity`; gate SQL now
  selects `setfile_path`; `gate_outcomes.csv` gains `timeframe/holding_class/symbol_class/session`;
  new `parameter_sensitivity.csv` (derived only where an OPT_CENSUS `runs` list exists — 21,651 real
  rows on the live DB); `families` loaded once up front.
- `tools/strategy_farm/research/research_state_readmodel.py` (A) — deterministic generator writing
  `D:/QM/reports/state/research_state.json` (schema `qm.research-state/v1`) from campaign manifests +
  ledgers + Kimi governor/quota state; tolerates every input absent (EVIDENCE_MISSING/UNKNOWN/None).
- `tools/strategy_farm/research/campaign_lib.py` (A) — LLM-free core: FTMO-gap hypotheses H1–H3,
  `build_hypothesis_card` (passes mechanization), `validate_provider_separation` (§52),
  `compute_observe_summary`, `assemble_campaign_manifest`.
- `tools/strategy_farm/research/run_ftmo_gap_campaign.py` (A) — live phase-1 driver (OBSERVE →
  preregister → Kimi → governor → mechanize).
- `tools/strategy_farm/research/finalize_ftmo_gap_campaign.py` (A) — phase-2 driver (mint → attempt
  cross-vendor chain → fall back → seal → experiment memory → manifest → research state).

Docs / durable artifacts:
- `docs/research/AUTONOMOUS_EDGE_DISCOVERY.md` (A) — programme charter (§39–§54 + provider roles +
  campaign lifecycle + harvest-funnel ROI numbers).
- `docs/ops/evidence/2026-09-15_continuous_book_evolution/research/CAMP-2026-0001_receipt.md` (A) +
  `research/CAMP-2026-0001/` (kimi_answer, critique_claude, campaign.json, observe_summary, run/finalize).
- `strategy-seeds/sources/QM-RESEARCH-2026-0001/` (A) — sealed internal-source artifact (author Kimi):
  source.md + research.json + lineage.json + critic_receipt.json + h1/h2/h3_result.json +
  observe_manifest.json + H1/H2/H3 cards.
- `.gitattributes` (M) — pin `strategy-seeds/sources/QM-RESEARCH-*/** -text` so the sealed sha256
  survives autocrlf checkouts (the existing 0000 artifact is CRLF-on-disk; without this the 0001 seal
  would break on the orchestrator's checkout — same trap the LF-blob Pin-SHA rule exists for).

Tests:
- `tools/strategy_farm/tests/test_research_campaign.py` (A) — mechanization ML policy, provider
  separation, research-state read-model, observe summary.
- `tools/strategy_farm/tests/test_research_observe_projector.py` (M) — new-field + parameter-sensitivity tests.
- `tools/strategy_farm/tests/_research_fixtures.py` (M) — `setfile_path` column + OPT_CENSUS `runs` row.

## Contracts (schemas written / regression-tested)
- `qm.research-dataset/v1` — extended (gate_outcomes new columns + parameter_sensitivity.csv), back-compatible.
- `qm.research-state/v1` — `D:/QM/reports/state/research_state.json` (D1 + briefing consume it).
- `qm.research-campaign/v1` — `campaign.json` (Mission Control Research view + read-model).
- `qm.observe-summary/v1` — deterministic per-campaign OBSERVE stats.
- Reused unchanged: `qm.internal-research-source/v1`, `qm.research-preregistration/v1`,
  `qm.research-search-history/v1`, `qm.experiment_memory/v1`, `qm.research-mechanization-check/v1`.

## Tests + result
`python -X utf8 -m pytest tools/strategy_farm/tests/test_research_observe_projector.py
tools/strategy_farm/tests/test_research_campaign.py tools/strategy_farm/tests/test_research_ledgers.py -q`
→ **27 passed in 2.71s**. Broader slice suite (observe/campaign/ledgers/mechanization/env-guard/source/
r1/matrix/backlog) → **89 passed in 6.80s**. The four §70/§(4) requirements are covered:
- observe_projector new fields — `test_whitespace_fields_in_gate_outcomes`, `test_classify_helpers_*`,
  `test_parameter_sensitivity_only_where_derivable`.
- research_state_readmodel from fixtures — `test_research_state_readmodel_from_fixtures`,
  `test_research_state_tolerates_all_inputs_absent`.
- runtime-ML card fails mechanization while an ML-provenance card passes —
  `test_ml_provenance_card_passes_but_runtime_ml_card_fails`.
- Creator/Critic separation on the campaign receipt data — `test_provider_separation_directive_52`,
  `test_campaign_manifest_carries_creator_critic_separation`.

## Runtime artifacts written (live campaign)
- `strategy-seeds/sources/QM-RESEARCH-2026-0001/` (sealed; `research_source.verify` → ok=true,
  sha256 `e2c72cf9…`).
- `D:/QM/research/campaigns/CAMP-2026-0001-ftmo-gap/` (observe dataset `4deb0c21…`, kimi_prompt/answer,
  preregistration, campaign_run.json, campaign_finalize.json, campaign.json).
- `D:/QM/reports/state/research_state.json` (1 campaign, quota `managed_usage_endpoint`).
- Appended: `D:/QM/reports/state/experiment_memory_ledger.jsonl` (H1/H2/H3 + NEGATIVE_FINDING),
  `search_history_ledger.jsonl` (3 preregistered families), `research_source_ledger.jsonl` (mint+seal),
  `kimi_usage_ledger.jsonl` + `kimi_quota_state.json` (governor telemetry now `ok`).

## Campaign result (follow-up §16 checklist — all YES)
Lane enabled (governor NORMAL) · real campaign ran (Kimi 932 s, cli 0.43.1) · artifact produced
(QM-RESEARCH-2026-0001) · criticised cross-provider (creator Kimi / critic Claude, cross_vendor=true) ·
sealed (verdict REVISE ≠ REJECT) · created a mechanical hypothesis (H-CW) **and** a durable negative
finding · visible in experiment memory + research_state. H1 inconclusive, H2 refuted-in-proxy, H3 not
established. See `CAMP-2026-0001_receipt.md`.

## Rollback
- Code is additive; revert the slice commit. The read-model/campaign drivers write only under
  `D:/QM/research/`, `D:/QM/reports/state/` and the repo source store — no farm-DB/gate/verdict write.
- To unseal the artifact: it is append-only ledger + immutable versioned store; a supersession is a
  `research_source.remint`, never an in-place edit.
- Kimi kill switch `QM_KIMI=0` (adapter never spawns); the campaign drivers are manual (no scheduled task).

## Items NOT done / caveats (honest)
- **Cross-vendor critic was the orchestrator (Claude/Fable) inline, not a spawned headless seat.**
  `agent_chain.run_chain` was attempted and **gated** — all three non-Kimi critic lanes were quota-
  blocked (CLAUDE_DISABLED / CODEX_LOW_TOKENS / AGY_LOW_QUOTA flags present 2026-09-15). Per the slice
  fallback, Claude/Fable (a different vendor than the Kimi creator) performed the read-only critique;
  `critic_fallback_used=true`, `cross_vendor=true` recorded honestly. Next-experiment item: re-run
  through a spawned non-Kimi seat once a critic lane is off quota-hold to corroborate the REVISE.
- **The Kimi call returned status `protected_write`** (not `ok`): the before/after protected-tree
  snapshot flagged ~65 changed paths — **all** are concurrently-churning live-factory / T_Live /
  governor state files (account_snapshot.json, terminal.ini, heartbeat, pipeline_state, launch-slot
  locks, farm_state.sqlite-wal, …), **none** in the campaign out_dir; Kimi's no-shell research posture
  cannot write them. This is the documented concurrent-factory / mirrored-notification churn, a
  false-positive of the guard under a running factory, not a Kimi mutation. Text was valid and kept.
- **Two of three preregistered hypotheses (H1, H3) were untestable** on the current OBSERVE projection
  (no worst-day-loss / wdd_p90 / per-trade / first-passage fields; 96.5% `session=unspecified`). This
  is an infrastructure finding, recorded as the campaign's structural lesson and as a next-experiment
  item (extend observe_projector to join the sleeve-stream / first-passage engines and derive session
  from execution time-of-day). It did not block delivery — the campaign still produced a mechanizable
  hypothesis and a durable negative finding.
- `parameter_sensitivity` is a genuine objective-spread signal over OPT_CENSUS runs, not a full
  per-input sensitivity surface (that lives in the OPT_CENSUS grids, out of scope here); emitted only
  where derivable.
- §49 EXTERNAL-vs-INTERNAL ROI remains a measured GAP (no per-EA origin field) — flagged in the
  charter; an engineering task, not this slice.
- Did not commit/push (orchestrator commits); did not touch T_Live/AutoTrading/FTMO purchase/gates/
  verdicts/farm-DB; MT5 backtests unaffected.
