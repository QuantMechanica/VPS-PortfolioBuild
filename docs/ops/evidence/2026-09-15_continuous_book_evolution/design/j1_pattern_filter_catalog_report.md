# Slice j1_pattern_filter_catalog — Pattern & Filter Catalog + fresh ablation programme

**Directive:** OWNER directive 3 §22 (fresh pattern-filter programme), §40 (add/maintain a Pattern & Filter Catalog), §44 (`docs/research/PATTERN_FILTER_CATALOG.md`); classification of the "max N filters" rule per master §20.
**Author:** Claude (implementation subagent), 2026-09-15. Branch base `agents/board-advisor` @ `1617cb22be`.
**Status:** DONE. One deterministic read-only generator built, tested (10 passing), and RUN FOR REAL against the live DB + sealed receipts; three outputs written incl. the Vault node.

---

## Summary line

New deterministic, read-only generator `tools/strategy_farm/research/pattern_filter_catalog.py` inventories the **77** framework `QM_PatternId` predicates (categorized to the §40 taxonomy, 16 Unger-related) plus the **6** first-class filter modules, joins the historical DL-089/Q12 test results per predicate from the farm DB (`ea_metrics ⨝ OPT_CENSUS`, **18,326** measured predicate cells) and the **30** SEALED per-program Q12 selection receipts (all `NO_FILTER_CHANGE`), writes the JSON read-model + canonical doc + Vault node, and documents the fresh §22 ablation programme and the disposition of the "max N filters" rule — all with 1 test file (10 passing) and run for real.

## Headline numbers (real run, 2026-09-15)

- Predicates: **77** (price-action 42, trend 12, regime 11, volatility 10, time 2); **16** Unger-related; **0** unclassified.
- Filter modules: **6** (`QM_FilterNewsBlackout`, `QM_FilterRegime`, `QM_FilterVolatility`, `QM_NewsFilter`, `QM_PatternPermission`, `QM_PatternPermissionStraddle`).
- Historical census (DESCRIPTIVE): **18,326** measured predicate cells / **231** baseline cells across **33** census programs.
- Sealed Q12 selection: **30** programs, verdict distribution `{NO_FILTER_CHANGE: 30}` — **no historical EA has ever selected even one filter**; the cap of 3 has never bound.
- Filter cap classified: **SELECTION rule (economic/capacity), NOT a gate-integrity Hard Rule**; recommendation KEEP at 3/direction (non-binding on all evidence), revisit only via the §30 procedure.

## Files changed
- `tools/strategy_farm/research/pattern_filter_catalog.py` (new generator)
- `tools/strategy_farm/tests/test_pattern_filter_catalog.py` (new test file)
- `docs/research/PATTERN_FILTER_CATALOG.md` (generated canonical doc — committed as the human-readable artifact)
- `docs/ops/evidence/2026-09-15_continuous_book_evolution/design/j1_pattern_filter_catalog_report.md` (this report)

## Contracts
- New read-model schema `qm.pattern-filter-catalog/v1` (`D:/QM/reports/state/pattern_filter_catalog.json`). Carries `schema` + `generated_at_utc` + `inputs_sha256`. No existing gate contract changed. **Q12's DL-089 selection contract is untouched** (this catalog supplies candidate filters + descriptive history only).

## Tests + summary line
`python -X utf8 -m pytest tools/strategy_farm/tests/test_pattern_filter_catalog.py -q` → **10 passed** (inventory 77 predicates & full CATEGORY_MAP pin, §40 taxonomy closure, Unger-id validity, census delta math, EVIDENCE_MISSING paths, selection-receipt tally, byte-identical determinism, max-N disposition). Also verified byte-identical idempotency of the real JSON + doc across two `--now`-fixed runs.

## Runtime / vault artifacts (real run, with counts)
- `D:/QM/reports/state/pattern_filter_catalog.json` — full model (77 predicates, 6 modules, per-predicate census + selection).
- `docs/research/PATTERN_FILTER_CATALOG.md` — canonical write-up (in-repo, committed).
- `G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki/Pattern & Filter Catalog.md` — Vault node with `generated: true` frontmatter marker (machine-generated, overwritten by the generator).

## Join sources (read-only)
- Inventory: `framework/include/QM/QM_PatternPermission.mqh` (`QM_PatternId` enum, parsed) + fixed §40 CATEGORY_MAP (pinned by test) + `framework/include/QM/QM_FilterLibrary.mqh` umbrella modules.
- Census: `work_items` phase `OPT_CENSUS` (payload `program_id/year/arm/direction/predicate_id`) joined to `ea_metrics` (net_profit/trades/drawdown_money), `mode=ro` + `PRAGMA query_only`. Only `MEASURED` cells; each arm paired to its same-(program,year) `baseline` (null-filter) arm.
- Sealed selection: `D:/QM/strategy_farm/artifacts/opt_census/DL089_*/q12_selection_receipt.json` (`final_selection`, `verdict`) — read, never re-derived.

## Descriptive-vs-verdict boundary (RED-safe)
The catalog's per-predicate census (trade reduction, expectancy delta, DD delta, improved-cell counts vs the null baseline, using the DL-089 return_to_maxdd ≥+5% measure) is labeled DESCRIPTIVE/observational everywhere it appears. The **authoritative** per-EA selection is the sealed receipt verdict, reported verbatim. The generator never writes a verdict, never re-runs or re-weights the sealed DL-089 rule, and never mutates the DB.

## NOT done (with reasons)
- **No enqueue of the fresh ablation programme.** §22's ablation is documented as a design (overlay design, null baseline, pre-registered families + within-family FDR + WF holdout, regime/portfolio effects, search_history_ledger families). Actually enqueuing new census/research work is orchestrator-commissioned (`agent_tasks` writes are a RED boundary for this slice) and is throttled to the ready-card reservoir; see "commands for the orchestrator".
- **No Q12 contract change.** The "max N filters" disposition recommends KEEP-at-3 and explicitly defers any change to the §30 procedure. Changing `gate_manifest.v4.json` Q12 or the DL-089 rule is ROT and out of scope.
- **No scheduled-task registration / worker reload.** Only instructions are provided (RED boundary).
- **Negative mean trade-reduction observed for many predicates** is a genuine descriptive finding (permission arms often barely restrict the counted direction), not a bug; it is surfaced honestly, not smoothed.

## Rollback
Pure additive: delete the four repo files listed above and `D:/QM/reports/state/pattern_filter_catalog.json` + the Vault node `09 Strategy Wiki/Pattern & Filter Catalog.md`. No DB, no gate, no scheduled task touched; nothing to revert in existing files.

## Exact commands for the orchestrator
1. Apply patch (from canonical repo root, on `agents/board-advisor`):
   `git apply <scratchpad>/patches_d3/j1_pattern_filter_catalog.patch`
2. Run tests: `python -X utf8 -m pytest tools/strategy_farm/tests/test_pattern_filter_catalog.py -q`
3. Regenerate (idempotent; writes JSON + doc + Vault node):
   `python -X utf8 tools/strategy_farm/research/pattern_filter_catalog.py`
   (add `--vault NONE` to skip the Vault write when `G:` is unavailable)
4. Commit with explicit pathspecs (orchestrator commits): the generator, test, `docs/research/PATTERN_FILTER_CATALOG.md`, and this report.
5. (Optional, cadence) register a refresh task alongside the other read-model generators (e.g. fold into the existing research read-model cadence or a dedicated 60-min task) — installer/instructions only; task registration is a RED boundary.
6. (Optional, §22 follow-through) when the ready-card reservoir < 5, commission a predeclared pattern-filter ablation campaign per the `ablation_programme` block: one `search_history_ledger` entry per filter family BEFORE search, within-family FDR, WF holdout — as a Codex/agy router task; feeds Q12 as candidates only.
