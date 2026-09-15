# Slice e1 — Second-Chance Strategy Register (report)

**Slice key:** `e1_second_chance_scan` · **Directive:** §23–§28, §31–§32, §38, §43E, §44
· **Date:** 2026-09-15 · Worktree branch `agents/board-advisor`.

## Summary line

Deterministic classifier + read-model that reclassifies all **1285** historical
REJECTED/RETIRED/DRAFT records into a §24 primary reason and second-chance status
(**542 ELIGIBLE, 731 STILL_INVALID, 12 SUPPRESSED_CLONE**), runs the §27/28 counterfactual
for real (**3** economic-fail records own sealed streams → **0** portfolio-utility
challengers on the 2025 holdout; 34 EVIDENCE_MISSING), ranks eligible candidates by §26
expected portfolio value (FTMO-weighted), and joins the fields onto the generated Strategy
Wiki idempotently — all tested (26 tests green) and run for real.

## Files changed

New:
- `tools/strategy_farm/config/second_chance_reasons.v1.json` — rule table
  (schema `qm.second-chance-reasons/v1`): reason enum, eligibility defaults + rationale,
  precedence-ordered keyword / verdict-class / registry-reason / hold-code rules,
  scoring weights, RAM/FTMO markers.
- `tools/strategy_farm/research/second_chance_register.py` — generator
  (schema `qm.second-chance-register/v1`): population enumeration, classification, clone
  suppression, priority scoring, counterfactual, JSON+CSV+vault writers, CLI (`--dry-run`).
- `tools/strategy_farm/tests/test_second_chance_register.py` — 14 tests.
- `docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` — method, reason rules, real counts,
  top candidates by venue, capacity-bounded re-test plan, NEW-lineage ticket template.
- `docs/ops/evidence/2026-09-15_continuous_book_evolution/design/e1_second_chance_scan_report.md` — this report.

Modified:
- `tools/strategy_farm/strategy_wiki_sync.py` — read-only Second-Chance join: optional
  `second_chance_register` source, `load_second_chance()`, six per-node frontmatter fields
  + a "Second-chance" body section, folded into the per-node input digest **only when a
  register entry exists** (idempotent; no mass re-render when the register is absent).
- `tools/strategy_farm/tests/test_strategy_wiki_sync.py` — optional-key exclusion in the
  completeness test + a new join/idempotency test.

## Contracts

- `qm.second-chance-register/v1` — `D:/QM/reports/state/second_chance_register.json`
  (carries `schema`, `generated_at_utc`, `inputs_sha256`, `counts` (by reason × eligibility),
  `counterfactual`, per-record `records`, `ranked_top200`).
- `qm.second-chance-register/v1` CSV mirror — `second_chance_register.csv` (one row/record).
- `qm.second-chance-reasons/v1` — the versioned rule table (config).
- `qm.portfolio-utility-challenger/v1` — the counterfactual block + class spec (§28).
- strategy_wiki_sync node frontmatter gains 6 documented-optional keys
  (`second_chance_reason|status|eligibility|priority`, `portfolio_utility_challenger`,
  `second_chance_tail_risk`).

## Tests

`python -X utf8 -m pytest tools/strategy_farm/tests/test_second_chance_register.py tools/strategy_farm/tests/test_strategy_wiki_sync.py -q`
→ **26 passed**. Coverage: classifier precedence (style/ML/no-source/insufficient/OTHER/
BOM+CRLF/registry-override/id-repurpose-debris-guard), clone suppression + material-edge
upgrade, ranking determinism + invalid-exclusion, counterfactual challenger-flag +
EVIDENCE_MISSING, JSON/CSV/vault serialization, wiki-sync join render + idempotency.

## Runtime / vault artifacts (produced by the real run)

- `D:/QM/reports/state/second_chance_register.json` — 1285 records, `inputs_sha256 37ec3be9…`.
- `D:/QM/reports/state/second_chance_register.csv` — 1285 rows.
- `G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki/Second-Chance Register.md`
  — generated page (counts + reason×eligibility + counterfactual + top-200 table).
- Per-node join applied via `strategy_wiki_sync build`: **1298 nodes re-rendered, 3967
  untouched** (population only, no mass churn); a second build wrote **0** (idempotent).

## Headline numbers

- Population 1285 · Eligible 542 · Still-invalid 731 · Suppressed clones 12.
- By reason: INSUFFICIENT_EVIDENCE 470, HISTORICAL_POLICY 412, OTHER 210,
  NO_EXTERNAL_SOURCE 116, ECONOMIC_FAIL 37, DUPLICATE 19, MULTI_POSITION 8, SCALPING 8,
  PYRAMIDING 3, INFRA_FAIL 1, GRID 1, MARTINGALE 0.
- Style-supersession eligible (the records old doctrine wrongly discarded): **20**.
- Counterfactual: 3 econ-fail with sealed stream → **0** challengers; 34 EVIDENCE_MISSING.
- Tail-risk flagged: 4 (3 PYRAMIDING eligible, 1 GRID suppressed clone).

## Rollback

Delete the two `D:/QM/reports/state/second_chance_register.*` files and the vault page;
the wiki-sync join is present-or-absent, so nodes revert on the next build. The classifier
writes no verdicts, no farm-DB rows, and touches no live surface. Reverting the patch
removes the generator, config, tests and the wiki-sync join code.

## NOT done (with reasons)

- **210 OTHER + 470 INSUFFICIENT_EVIDENCE are not re-testable here** — by design: OTHER
  carries no recorded reason (never guessed); INSUFFICIENT_EVIDENCE needs a repaired/
  complete card (fresh intake), a separate card-repair lane, not a second-chance retest.
- **0 portfolio-utility challengers** — real evidence result, not a gap: only 3 econ-fail
  records own sealed streams and none improves a venue objective OOS without adding
  drawdown. The machinery is in place; more challengers can only appear when more sealed
  streams exist.
- **2026 sealed-OOS holdout not used for the counterfactual** — the sealed Q08 sleeve
  streams end 2025-12-30 (no 2026 data); the generator uses the trailing full year (2025)
  and switches to the 2026 window automatically once those streams are sealed. Documented
  in the programme doc §4 and the module.
- **No tickets enqueued** — enqueueing second-chance reruns is an orchestrator act
  (append-only, NEW lineage). The ticket template + capacity-bounded wave plan are in the
  programme doc; no farm-DB writes were made (RED boundary).
- **STRATEGY_ELIGIBILITY_V2.md (slice d1) assumed** — its §17 allowed list and §24 reason
  enum were taken directly from the directive (the file did not yet exist at run time).

## Exact commands for the orchestrator

Apply the patch (from the canonical repo, on `agents/board-advisor`):
```
git apply <scratchpad>/patches_d3/e1_second_chance_scan.patch
git add tools/strategy_farm/config/second_chance_reasons.v1.json \
        tools/strategy_farm/research/second_chance_register.py \
        tools/strategy_farm/tests/test_second_chance_register.py \
        tools/strategy_farm/strategy_wiki_sync.py \
        tools/strategy_farm/tests/test_strategy_wiki_sync.py \
        docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md \
        docs/ops/evidence/2026-09-15_continuous_book_evolution/design/e1_second_chance_scan_report.md
git commit -m "research(second-chance): eligibility-V2 reclassification register + wiki join (directive 3 §23-28)"
```

Regenerate the read-models (deterministic; safe to re-run, no CPU-heavy work):
```
python -X utf8 tools/strategy_farm/research/second_chance_register.py
python -X utf8 tools/strategy_farm/strategy_wiki_sync.py build   # applies the per-node join
```

Scheduled-task registration (write-installer only; do NOT auto-register): add a cadence run
of `second_chance_register.py` immediately before the existing
`QM_StrategyFarm_StrategyWikiSync` task so the join always reflects the current register.
No worker reload required (read-only generator; no farm-DB writes, no terminal64).
