# Adversarial review — slice `b1_book_guard_decision`

- Reviewer: Claude (adversarial, read-only)
- Date: 2026-09-15
- Verdict: **ACCEPT** (no blocking findings; majors are correctly-scoped follow-up slices)
- Patch: `C:/Users/ADMINI~1/AppData/Local/Temp/1/claude/C--QM-repo/15a7ddd6-2faa-4bee-8808-c948b4dcd647/scratchpad/patches_bc/b1_book_guard_decision.patch`
- Directive: `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md` §3, §4, §68B
- Files in patch: `decisions/2026-09-15_owner_continuous_book_evolution.md` (new),
  `.../design/b1_book_guard_decision_report.md` (new),
  `tools/strategy_farm/book_build_guard.py`, `tools/strategy_farm/config/gate_manifest.v4.json`,
  `tools/strategy_farm/tests/test_book_build_guard.py`

## Method

Read the full patch, the verbatim directive, the Phase-A truth snapshot, the current canonical
`book_build_guard.py`, `gate_manifest.v4.json` (draft_note + book_trigger), the full current
`test_book_build_guard.py`, the strict validator `gate_manifest.py:782-797`, `path25_red_team.py:230-258`,
and every book-guard consumer. Verified `git apply --check` on the canonical tree, validated the JSON,
and grepped for renamed/affected symbols and hard-coded `25` callers.

## (1) RED boundaries — CLEARED

- **No gate threshold / criterion change.** The pipeline gate criteria and verdict semantics are untouched.
  The only thing changed is the *book-build entry trigger* (`qualified_pairs >= 25` → `>= 1`, i.e. non-empty),
  which OWNER §4 explicitly orders superseded ("`BOOK BUILD PERMITTED ⇔ qualified_candidates >= 25` is
  explicitly superseded … The portfolio engine may evaluate any currently valid qualified pool") and §68B
  orders implemented without re-approval. Authorized by the top-of-hierarchy explicit OWNER directive.
- **No qualification weakening.** The qualification predicate (`_qualified_pair_rows`,
  contiguous-through-terminal-gate via `rebaseline_census`) is byte-for-byte unchanged. Unqualified pairs
  are still never counted — directly proven by the new `test_unqualified_pairs_are_never_counted`
  (a frontier-Q13 pair does not enter the pool). Confirmed against Phase-A canonical definition (§3 snapshot).
- **Fail-closed preserved.** Empty pool → `qualified_pool_empty` refusal; unmeasurable pool (missing DB /
  exception) → `qualified_pool_unavailable` refusal (the new empty-pool reason is deliberately suppressed
  only when `qualified_pool_unavailable` is already present, so it never masks the harder failure). Both
  paths keep `allowed=False`. Verified `test_book_path_refusal_cli.py` (absent DB + no order) still refuses.
- **No T_Live / AutoTrading / purchase / evidence-rewrite / farm-DB-write touch.** `book_build_guard` is
  read-only by contract; the patch adds no writes. The OWNER-order artifact requirement (`_find_owner_order`)
  is untouched. No credentials/tokens.
- **History preserved.** The stale `draft_note` correction quotes the original proposal text inline; the
  decision record supersedes prior rules by marking, never deleting; `MIN_QUALIFIED_PAIRS = 25` is retained
  (as a diagnostic constant). Consistent with §3/§65 "do not rewrite history".

## (2) Directive fidelity — MET

- **§68B decision record.** `decisions/2026-09-15_owner_continuous_book_evolution.md`
  (id `OWNER-DEC-CBE-20260915`) transcribes all 17 §68B bullets as 13 numbered decisions (some bullets
  sensibly consolidated: one-challenge + 100k/2-step + speed→prob into #10; scalping + trailing into #11;
  ML research + runtime-forbidden into #12; autonomous ideation + Fable/Kimi authorship into #13). Each item
  carries the directive section, the superseded prior decision/DL/rule **with its enforcement path** from
  `rule_inventory_code.md`, the implementation status (this slice vs. later), and what stays unchanged.
  Follows the `2026-09-15_owner_kimi_integration…` house style. Dedicated "RED boundaries explicitly
  preserved" section names §64/§71 and the qualification predicate. Observed-drift annex present.
- **§3/§4 trigger change.** Correctly implemented as scoped: guard + manifest + tests + decision record here;
  Mission Control / read-model "Way to 25" surfaces deferred to Phase D (explicitly listed as untouched).
- **No new arbitrary permanent cap invented.** `MIN_VALID_POOL = 1` is the minimal non-empty floor that §4
  itself implies ("any currently valid qualified pool"; "This does NOT mean weak/unqualified strategies
  become eligible"). It is not a candidate-count business cap.
- **No silent no-op warning.** The relaxed trigger still *raises* (fail-closed) on empty/unmeasurable pool
  and on a missing OWNER order; nothing was downgraded to an ignored warning.
- **§3 observed-drift (empty `candidate_qualifications` table)** recorded in the decision record's annex
  item 1 with the authoritative-source note, no code change — as required.
- **Backward-compatible output keys.** `trigger_policy: 'any_valid_pool (OWNER-DEC-CBE-20260915)'` and
  `reference_pool_size` added to `GuardResult` (the output mission_control reads via `asdict`), not to the
  manifest — the correct place, since a new manifest key would break the strict key-set validator.

## (3) Correctness — CLEARED

- `git apply --check` on the canonical tree: **applies cleanly** (all five files, no fuzz). Context lines
  match the current canonical `book_build_guard.py:31/47/236`, `gate_manifest.v4.json:5/373-384`, and
  `test_book_build_guard.py:55-73`.
- **JSON valid.** Each of the four changed manifest string values (`draft_note`, `detail`, `on_unmet`,
  `supersedes`) parses as valid JSON (validated in isolation: 564/878/396/450 chars, single-quoted prose,
  no unescaped `"`/backslash). `book_trigger` key set stays `{policy, entry_gate, requires_all, on_unmet,
  supersedes}`.
- **Strict validator preserved.** `gate_manifest.py:782-797` checks only the `book_trigger` key set and the
  ordered condition token list `["qualified_candidates_ge_25", "owner_order_artifact_present"]` — both kept.
  It does **not** inspect `detail`/`on_unmet`/`supersedes` prose, so the text rewrite is safe. The
  deliberate decision to keep the legacy token name (misnomer now, documented) is the right call for this
  slice's blast radius.
- **No broken callers.** Grepped every `MIN_QUALIFIED_PAIRS` / `qualified_candidates_ge_25` /
  `check_book_build_allowed` / `GuardResult` consumer:
  - `operator_surfaces.py:298`, `path25_red_team.py:244/257/554/562/580` read `MIN_QUALIFIED_PAIRS`, which
    stays `25` — unbroken. `path25_red_team` book-trigger contract check (`:235-244`) requires token subset
    + `MIN_QUALIFIED_PAIRS == 25` — both preserved → still PASS.
  - `GuardResult` gains two *defaulted, trailing* fields → the 6-positional construction
    (`test_book_build_guard.py:227`) and all `dataclasses.asdict` consumers (`operator_surfaces`,
    `build_qualified_roster`, `release_status`, `path_to_25`, `path25_red_team`, `q15_fit_report`) get a JSON
    superset — backward compatible. `research/research_env.py:165` `GuardResult` is a different class.
  - `farmctl.py`: no book-guard / 25-threshold reference (nominal "farmctl-side" scope, nothing needed).
- **Windows paths:** none introduced; module uses `pathlib` throughout.

## (4) Tests — PRESENT AND MEANINGFUL (§70)

- New/updated tests cover exactly the task's (a)-(d): `test_small_valid_pool_with_owner_order_is_allowed`
  (pool 3 → allowed), `test_empty_pool_refused_even_with_owner_order` (pool 0 → `qualified_pool_empty`),
  `test_unqualified_pairs_are_never_counted` (frontier-Q13 excluded), `test_25_appears_only_as_diagnostic_
  never_blocks` (25 = `reference_pool_size` only, `trigger_policy` set, never a refusal reason). Maps to §70
  "Q15 no longer hard-blocked solely by `<25`" + "invalid/unqualified candidates still fail closed" +
  "DXZ portfolio evaluation works with smaller valid pool".
- Regression safety verified by reading the rest of the suite: the surviving `_pool(25)` tests still pass
  (25 ≥ 1, order logic unchanged); `test_require_raises_book_build_refused_with_result` (`_pool(0)`) still
  raises (now via `qualified_pool_empty`); `test_book_path_refusal_cli.py` (absent DB) still refuses via
  `qualified_pool_unavailable` + `owner_order_missing`, and its `qualified_pairs < 25` assertions hold on a
  count of 0. Consistent with the implementer's "48 passed, 2 skipped" line (2 skips = jsonschema importorskip).
- I did not re-run pytest (read-only, and the patch targets a different worktree), but every failure mode I
  could reason about statically is covered; the summary line is credible.

## (5) Docs — CLEARED

English comments throughout; dated supersession markers (`OWNER-DEC-CBE-20260915`, 2026-09-15) in code,
manifest, and decision record; no history deleted (old draft_note text quoted inline; decision record
supersedes-not-deletes). Decision record RED-boundary and rollback sections present.

## Findings

### Blocking
None.

### Major (follow-up slices — correctly deferred here, must be tracked)
- **REGISTRY.md row missing.** `decisions/REGISTRY.md` has no `OWNER-DEC-CBE-20260915` row (grep = 0). The
  implementer omitted it to avoid a parallel-slice merge conflict. The integrator MUST add it when landing
  the decision record, or the decision is un-indexed.
- **Read-model surface coherence gap until Phase D.** With the guard now allowing any non-empty pool, the
  still-untouched `/25` surfaces (`operator_surfaces.py:298` `minimum_qualified_pairs=25`, `path_to_25.py`,
  `render_cockpit_v2`, `morning_brief`, `heartbeat_snapshot`) and the `path25_red_team` phase-3
  `qualified < 25 → hard failure` logic will contradict the new trigger policy. This is explicitly Phase D
  in the task scope and in the decision record (item 1, LATER SLICE) — acceptable to defer, but it is a real
  live inconsistency the moment this slice lands, so Phase D should follow promptly.

### Minor (notes)
- `tools/strategy_farm/tests/test_portfolio_periodic_report.py:62` hard-codes the fixture string
  `"qualified_pairs_below_minimum: 0 < 25"`. It is a static fixture (does not call the guard) so it still
  passes, but it now references a superseded reason string — worth updating for clarity in a later touch.
- The manifest condition token `qualified_candidates_ge_25` is now a misnomer (semantics = non-empty pool).
  Deliberate and documented (pinned by validator/schema/draft/path25_red_team); rename deferred to the
  Phase-D "Way to 25" decommission. Note only.
- Implementer-reported pre-existing failures (`test_operator_surfaces_rebaseline`, 3× `test_path25_red_team`
  with `sealed count decision sha256 mismatch` at `path_to_25.py:575`) were verified by the implementer via
  `git stash` in the source worktree and are in out-of-scope Phase-D files. They were excluded from the
  48-passed run. The integrator should confirm the canonical suite's status for those files after apply —
  they are untouched by this slice, so not a blocker for it.

## Conclusion

The slice does exactly what §3/§4/§68B require, within a tightly-drawn scope, with the qualification
predicate and all RED boundaries intact and fail-closed behavior preserved. Patch applies cleanly, JSON is
valid, the strict validator and red-team contract checks still pass, no caller is broken, and the §70 tests
are present and meaningful. **ACCEPT.** Track the two majors (REGISTRY row at integration; Phase-D surface
coherence) as follow-ups.
