# Adversarial review — slice `e1_recompose_engine`

Date: 2026-09-15. Reviewer: adversarial review agent (read-only except this file).
Patch: `scratchpad/patches_defg/e1_recompose_engine.patch`.
Repo HEAD at review: `4ad7ab7016a77f25323b95912573eafbb21c5e69`.
Authority: OWNER-DEC-CBE-20260915 (`decisions/2026-09-15_owner_continuous_book_evolution.md`).

## Verdict: ACCEPT (no blocking findings; 2 major follow-ups, 3 minor notes)

The slice builds the deterministic per-venue recomposition engine as specified, ran it
for real for both venues (2026-W38), and left honest read-models in place. The patch
applies cleanly, the tests pass, determinism is verified on the REAL snapshot (not just
the fixture), no RED boundary is crossed, DB access is read-only, and the shared
read-model schemas are respected. The DXZ `ADD_SLEEVE` recommendation is a legitimate
computed result, not a fabrication, and is correctly framed as OWNER-review-only.

## Verification performed (my own commands)

1. **`git apply --check` against HEAD** → exit 0 (clean, no conflicts). Patch touches
   exactly the 12 declared files; nothing outside the recompose package + the one D4 edit
   to `assemble_stream_bundle.py` + the test + the report.
2. **Tests from the implementer worktree** (`.claude/worktrees/wf_4fa62b18-d2d-3`):
   `pytest tools/strategy_farm/tests/test_recompose_engine.py -q` → **9 passed in 3.65s**.
3. **Determinism on the REAL frozen snapshot** (not just the fixture): re-ran
   `evaluate --venue dxz` twice against
   `D:/QM/reports/book_evolution/2026-W38/dxz/snapshot` to a scratch output and
   sha256-compared:
   - rerun_a == rerun_b (evaluation.json): **True**
   - rerun == persisted `D:/QM/reports/book_evolution/2026-W38/dxz/evaluation.json`: **True**
   - rerun read-model == persisted `D:/QM/reports/state/book_evolution_dxz.json`: **True**
   This independently confirms the artifacts are real, regenerate byte-identically, and
   the engine output is a pure function of the frozen snapshot (§70).
4. **Manifest honesty** (`.../2026-W38/dxz/snapshot/manifest.json`): pool count 26 from
   the LIVE source `book_build_guard._qualified_pair_rows` (Q14 terminal, real db_path),
   44 streams present / **0 missing** / none fabricated, incumbents `live_24` (LIVE) +
   `planned_v2_28` (STAGED_NOT_DEPLOYED), git commit matches HEAD, `live_evidence` PRESENT.
5. **Selected-alternative sanity** (`add:10700:XAUUSD.DWX`): Δobjective +0.01216 (> 0.01),
   Δsharpe +0.146 (≥ ratified +0.06), ΔmaxDD −0.199pp (improves), block-bootstrap CI
   [0.00092, 0.00561] excludes 0 over n=1550 days, economic band + switching-cost pass.
   Internally consistent; `material=True` requires every factor, and every factor passes.
6. **RED scan** of added lines: no `sqlite` write / `execute`/`commit`/INSERT/UPDATE/DELETE,
   no AutoTrading toggle, no deploy, no FTMO purchase, no evidence rewrite, no secrets/tokens.
   The only DB path reference resolves through `book_build_guard._qualified_pair_rows` →
   `rebaseline_census.open_ro(...)` (**read-only**, connection closed in `finally`).
7. **Schema conformance** vs the shared contract `qm.book-evolution-venue/v1`: both
   read-models carry `venue, generated_at_utc, iso_week, incumbent{sleeves[...],
   sleeve_count, total_risk_pct, source_path}, evidence{...}, qualified_pool{count,
   definition, csv_path}, challengers[{ea_id,symbol,highest_gate,marginal_value}],
   proposal{outcome ∈ enum, changes, expected_metrics, materiality, confidence,
   operational_risk}, next_recomposition_utc, recommendation_text, owner_action,
   snapshot_dir`; FTMO adds `demo_cycle`. `owner_action` correctly NONE for KEEP/
   CONTINUE_OBSERVATION and `REVIEW_PROPOSED_CHANGE` for the DXZ ADD.
8. **English comments + dated supersession**: all code/comments are English; the D4 edit
   cites `portfolio_engine_existing.md` + OWNER-DEC-CBE-20260915 and preserves the July
   bundle as a content-hash-gated last-resort fallback (no behavioural weakening — ordering
   only changes which matching file is found first; acceptance stays hash-gated).

## Honesty of the real run

- DXZ outcome **ADD_SLEEVE (add 10700 XAUUSD.DWX)** is a real, deterministic, materiality-
  cleared recommendation, `owner_action=REVIEW_PROPOSED_CHANGE`, deployment/AutoTrading
  left OWNER-only. It independently corroborates the human-planned v2 (which adds 10700).
  This is within slice authority (advisory recommendation package, not a book change).
- FTMO outcome **CONTINUE_OBSERVATION** with FTMO_FITNESS **NOT_EVALUATED** — honest: the
  F1 `ftmo_fitness.py` module is absent in this worktree, and the engine degrades rather
  than inventing an objective or substituting the DXZ objective.
- Missing evidence is labelled, never invented: swap cost `EVIDENCE_MISSING` (commission is
  aggregated; `Trade` carries no swap), missing streams recorded not zero-filled (0 here),
  FTMO `live_dd_pct`/`live_since` `EVIDENCE_MISSING`.

## Major (follow-ups; do not block apply)

1. **FTMO `evaluate` is not purely a function of the frozen snapshot.**
   `recompose.py:_ftmo_demo_cycle()` reads the LIVE `D:/QM/reports/state/
   ftmo_challenge_readiness.json` at evaluate time, so two evaluates of the same FTMO
   snapshot taken across a change to that file are NOT byte-identical — a partial dent in
   the §70 "reproducible from frozen inputs alone" property. The reproducibility test only
   covers DXZ, so nothing guards this. It is per-contract that `demo_cycle` mirrors the
   readiness read-model, but the snapshot should freeze a pointer + sha256 of the readiness
   file (or the field should be documented as an explicit live-mirror exempt from §70), and
   a determinism test should cover FTMO. Recommend F1/H coordination.

2. **The proposed alternative's own concentration/risk diagnostics are not surfaced.**
   `risk_diagnostics` (advisory cap warnings + hard-guard summary) is computed only for the
   incumbent baseline roster, not for the selected alternative. The 2026-W38 recommendation
   is to ADD another XAUUSD sleeve to a book already carrying several XAUUSD sleeves; the
   OWNER-facing package does not show the resulting symbol-concentration advisory for the
   proposed roster. Follow-up: attach per-alternative concentration diagnostics (or at least
   the selected proposal's) so the ADD's concentration impact is visible.

## Minor (notes)

1. The persisted `qualified_pool.csv_path` in both read-models points at the transient
   implementer worktree (`C:\QM\repo\.claude\worktrees\wf_4fa62b18-d2d-3\...\
   candidate_universe.csv`). `CANDIDATE_UNIVERSE_CSV` derives from `__file__`/REPO_ROOT, so
   a re-run from the canonical checkout writes the correct `C:\QM\repo\...` path; the current
   persisted value will dangle once the worktree is cleaned. Cosmetic — re-run after merge.
2. The CLI `evaluate` subcommand does not expose `--book-evolution-root` (only the Python
   `evaluate()` param has it). Fine for production (defaults to the canonical root); noted
   for the Phase-H scheduled wrapper.
3. `assemble_stream_bundle.py` D4 change is safe (fallback stays hash-gated) but has no
   dedicated regression test asserting "current v2 bundle wins over July when both match";
   the neighbour sweep (`test_assemble_stream_bundle`) passed but does not pin the new order.

## Boundaries confirmed

- No farm-DB write (read-only `open_ro`); no terminal start; no deployment; no AutoTrading
  toggle; no FTMO purchase; no gate/verdict/threshold change; no evidence rewrite; no
  secrets. Materiality reuses existing `dxz_next_book_trigger` constants (MIN_OOS_SHARPE_
  DELTA=0.06, MAX_DD_WORSENING_PP=0.05) rather than inventing thresholds. The qualification
  predicate is untouched (consumed read-only). **RED boundary NOT crossed.**
