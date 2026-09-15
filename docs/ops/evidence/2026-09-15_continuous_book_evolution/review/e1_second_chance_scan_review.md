# Adversarial review — slice `e1_second_chance_scan`

**Reviewer:** Claude (adversarial review lane) · **Date:** 2026-09-15
**Patch:** `scratchpad/patches_d3/e1_second_chance_scan.patch` (2406 lines)
**Repo HEAD at review:** `1617cb22be689974139272d8dc8afe8d2617fb4a` (branch `agents/board-advisor`)
**Verdict:** ACCEPT_WITH_FIXES · **RED boundary crossed:** NO

---

## What I did

- Read the full patch (all 7 files) end to end.
- `git apply --check` against live HEAD → **clean** (`APPLY_CHECK_OK`, no conflicts).
- Opened the real runtime artifacts and cross-checked every headline number against the
  report and the generator output.
- Ran the test suite in the implementer worktree → **26 passed**.
- Ran the generator `--dry-run` against live state and a two-run in-process determinism
  check.
- Grepped the patch for RED touches (DB writes, verdict/threshold edits, T_Live /
  AutoTrading / purchase / deploy, scheduler registration, secrets, sealed-file edits).

## Correctness / honesty verification (all PASS)

| Check | Result |
|---|---|
| `git apply --check` | Clean, no conflicts |
| Tests | 26 passed (`test_second_chance_register.py` + `test_strategy_wiki_sync.py`) |
| Artifacts exist | `second_chance_register.{json,csv}` (1.37 MB / 402 KB) + vault page (18.7 KB), all mtime 2026-09-15 20:11 |
| Counts sum | 542 eligible + 731 still_invalid + 12 suppressed = 1285 = total ✓ |
| Report numbers vs JSON | Exact match: 1285 / 542 / 731 / 12 / 0 challengers / 4 tail; by-reason all match; MARTINGALE 0 ✓ |
| `inputs_sha256` | `37ec3be9…` in JSON = vault page = report ✓ |
| Determinism | Two `build_register` runs byte-identical except `generated_at_utc`; `inputs_sha256` stable; `--dry-run` reproduces counts ✓ |
| Counterfactual honesty | 37 econ-fail, 3 own sealed streams, 34 EVIDENCE_MISSING; venues genuinely EVALUATED (DXZ obj 12.05/242d, FTMO 2.60/103d — match report); 0 challengers is a real result, not a stub ✓ |
| Real inputs present | `lineage_map.json` (2.0 MB), `strategy_universe_map.json` (216 KB) both on disk ✓ |
| Idempotency | Wiki-sync join folds SC fields into per-node digest only when a register entry exists; test proves first-add re-renders, second build writes 0, non-population nodes untouched ✓ |
| Vault page marker | `generated: true` + "do not edit" + immutability note present ✓ |

## RED-boundary scan (all clear)

- **Farm DB:** opened read-only (`file:…?mode=ro`); no INSERT/UPDATE/DELETE/commit anywhere.
  The only "DELETE" grep hits are rollback prose.
- **Verdict semantics / gate thresholds:** untouched. The register *classifies* a read-only
  population; it writes no verdicts and edits no gate manifest or threshold.
- **§30 economic thresholds:** not modified. The §27 counterfactual is strictly additive
  (portfolio-utility test) and its class spec explicitly "does NOT rewrite the original gate
  PASS/FAIL" and grants no live eligibility.
- **T_Live / AutoTrading / purchase / live deploy / terminal64:** none — the three grep hits
  are documentation asserting the *absence* of these actions.
- **Scheduler:** no task registration in the patch (write-installer/instructions only,
  correctly deferred to the orchestrator) — no starvation/double-claim surface introduced.
- **Sealed/dated artifacts:** none edited in place. New files + a generator modification only.
- **Secrets / provider grants:** none. No `.private`, no credentials, no capability grants.

## Findings

### Major (non-blocking; advisory to the orchestrator)

1. **Counterfactual holdout is 2025, not the canonical sealed 2026 OOS window.** The task
   asked for "the existing holdout split conventions." The sealed Q08 sleeve streams end
   2025-12-30, so the generator falls back to the *trailing full calendar year 2025* as the
   "out-of-sample" split. 2025 overlaps the backtest/selection era, so it is not a true OOS
   holdout — a challenger flagged on it would be in-sample-contaminated. **Mitigated** by:
   (a) the run produced **0** challengers (conservative — no false rescue occurred), (b) the
   deviation is documented transparently in the module, programme doc §4 and the report,
   (c) the `PORTFOLIO_UTILITY_CHALLENGER` class spec independently *requires* an independent
   holdout (the 2026 OOS window) before any downstream action, (d) it grants no live
   eligibility, and (e) the code auto-switches to the 2026 window once those streams are
   sealed. Acceptable as-is; surface the caveat so no challenger is ever actioned on a
   2025-only basis.

### Minor

2. **Dangling decision-record citation.** The programme doc and `second_chance_reasons.v1.json`
   cite `decisions/2026-09-15_owner_max_factory_utilization_eligibility_v2.md`, which does
   **not** yet exist in the repo. It is referenced by the directive-3 header too, so its
   creation is an orchestrator/master-directive act — but until minted, the citation is
   unresolved.

3. **HISTORICAL_POLICY (412) is the largest ELIGIBLE bucket (409 eligible).** This includes
   activity/frequency-floor rejections governed by the recently-*ratified* Aktivitätskriterium
   (OWNER 2026-08-20, OQ-18). "Eligible" here means "eligible for a §30 review," not a
   threshold change or auto-readmission, and the re-test plan §5 correctly gates Wave 4 behind
   the full §30 procedure (counterfactual → versioned contract → test). Not a RED touch (no
   threshold edited). Guardrail: HISTORICAL_POLICY must never be batch-enqueued as ordinary
   reruns; keep it §30-bound.

4. **Population source.** Records are enumerated from generated Strategy-Wiki projection
   classes (REJECTED/RETIRED/DRAFT), not by directly scanning `cards_rejected` /
   `cards_review` / `strategy-seeds` drafts (those are used only for reason text). Reasonable
   per directive §23 (the wiki is the addressable population), but any historical record not
   projected into the wiki is out of scope by construction.

## Conclusion

The slice is real, deterministic, idempotent and honest. Every headline number reproduces
from live state; the 0-challenger counterfactual and 34 EVIDENCE_MISSING are genuine
evidence results, not gaps. No RED boundary is crossed: the generator is read-only
read-model generation (GRÜN), the DB is opened `mode=ro`, no verdicts/thresholds/scheduler/
live surfaces are touched, and the wiki-sync join is a present-or-absent read-only overlay
that reverts cleanly. The Major finding (2025 holdout) is a documented, self-mitigating
methodological limitation with a 0 result and a spec-level independent-holdout requirement
downstream — it does not block landing the patch, but the OOS caveat and the §30 gating of
HISTORICAL_POLICY should travel with any enqueue decision.

**ACCEPT_WITH_FIXES** — fixes are advisory (mint the decision record; carry the OOS caveat;
keep HISTORICAL_POLICY §30-bound). No code defect blocks the merge.
