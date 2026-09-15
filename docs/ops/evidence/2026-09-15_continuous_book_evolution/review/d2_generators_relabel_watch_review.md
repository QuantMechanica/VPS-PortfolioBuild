# Adversarial review — slice `d2_generators_relabel_watch`

- Reviewer: Claude (adversarial reviewer), 2026-09-15
- Decision: OWNER-DEC-CBE-20260915 (Continuous Book Evolution), directive §3/§4/§60/§72
- Patch: `scratchpad/patches_defg/d2_generators_relabel_watch.patch`
- Repo HEAD at review: `4ad7ab7016a77f25323b95912573eafbb21c5e69` (branch `agents/board-advisor`)
- Verdict: **ACCEPT_WITH_FIXES** (one MAJOR follow-up, two MINORs; no blocking issue, no RED boundary crossed)

## What was verified (with own commands)

### Apply + tests
- `git apply --check` against HEAD → **clean** (no conflicts), despite the dirty
  working tree in the git-status snapshot.
- Isolated worktree at HEAD (`C:/d2wt`, short path to dodge the Windows
  filename-length limit on the deep `.set` files) + `git apply` → clean.
- Ran the slice test set from repo root:
  - `test_path_to_25_metrics.py test_path25_red_team.py
    test_operator_surfaces_rebaseline.py test_book_evolution_readmodels.py
    test_hourly_watch_census_stall.py test_morning_brief_live_status.py
    test_book_build_guard.py` → **103 passed**.
  - `test_notion_morning_brief.py test_run_agent_orchestration_heartbeat.py
    test_mission_control_v2_data.py` → **35 passed**.
  - Total **138 passed**, matching the implementer summary. The two pre-existing
    sealed-count sha256 failures are green.

### Item 4 — sealed-count sha256 root cause (independently reproduced)
- `decisions/2026-08-27_owner_count_definition_option_a.md`: git blob is LF,
  1090 bytes → sha256 **`d47501ca…`** = the pinned `_COUNT_DECISION_SHA256`.
- Re-CRLF'd copy of the same bytes → sha256 **`2df61c55…`** = exactly the
  "actual" value named in the b1 slice report and the failing test.
- Confirmed: **the dated decision file was NOT amended after sealing** — identical
  content, newline policy only. The fix (`_lf_canonical_sha256` normalizes
  CRLF/CR→LF before hashing) is correct, matches the git-stored blob, and still
  detects real content changes. The dated decision bytes are untouched. Diagnosis
  is honest and corroborated. (Note: on THIS checkout the file is already LF so the
  raw hash also matches; the fix makes the pin robust on a CRLF/autocrlf checkout,
  which is where the b1 report saw the failure.)

### Cross-slice dependencies present at HEAD
The patch references symbols owned by the b1/B book-guard slice; all present at HEAD:
- `book_build_guard.MIN_QUALIFIED_PAIRS` (=25, diagnostic), `MIN_VALID_POOL` (=1),
  `TRIGGER_POLICY` (`"any_valid_pool (OWNER-DEC-CBE-20260915)"`), `DEFAULT_ORDER_DIR`,
  `GuardResult.reference_pool_size` / `.trigger_policy`.
- `check_book_build_allowed(venue, db_path, order_dir="decisions", *, qualified_rows=None)`
  — accepts the 3rd positional `order_dir` the patch passes. OK.

### RED-boundary sweep — none crossed
- No gate threshold or verdict-semantics change. The qualification **predicate**
  (contiguous v4 evidence to terminal Q14) is unchanged in `path_to_25.py`.
- `path25_red_team` phase-3: the arbitrary `qualified < 25 ⇒ FAIL` branch is removed
  and replaced by the book-build guard invariant (non-empty valid pool + OWNER order).
  This is directive-sanctioned (§4) and does **not** weaken fail-closed:
  `test_phase3_row_without_book_authority_is_a_hard_failure` still FAILs a phase-3 row
  with no OWNER order. A count-only diagnostic becomes `INFO`, never a pass gate.
- No farm-DB writes: every SQLite open is `mode=ro` (`path_to_25`, `path25_red_team`,
  `hourly_watch`). No `INSERT/UPDATE/DELETE/commit()`, no `mode=rw`.
- No T_Live / AutoTrading / FTMO-purchase / live-deployment / secrets touched.
- All JSON output keys are backward compatible; new keys (`reference_pool_size`,
  `trigger_policy`, `count_semantics`, `reference_pool_size_superseded_utc`) are additive.

### Read-model schemas + honesty
- New `book_evolution_readmodels.py` is read-only, never opens the DB, never invents
  values; absent/unreadable/non-object files degrade to `EVIDENCE_MISSING`.
- Live read-models on `D:/QM/reports/state/`: `book_evolution_dxz.json`,
  `book_evolution_ftmo.json`, `ftmo_challenge_readiness.json` are present and populated
  (written by other slices); `research_state.json` and `factory_bottleneck.json` are
  **absent**, so the headline's Research/Factory facets correctly render
  `EVIDENCE_MISSING`. Consistent with the design and the report.

### "Not done" claims verified
- `render_dashboards.py` / `render_cockpit.py`: grep confirms **no** "Way to 25" /
  "/25" / objective / Nordstern wording. Their bottleneck lines are neutral
  (pending-count based) and the only `25` literals are an unrelated build-fail
  threshold and 2026-07-25 dates. Leaving them untouched is correct, not a miss.
- Vault ToDo "Way-to-25" renderer: grep for `Way to 25` / `WAY_TO_25` / `Nordstern`
  across `tools/`+`scripts/` returns nothing. NOT_APPLICABLE confirmed.
- Out-of-scope `test_build_qualified_roster.py::test_roster_binds_the_census_snapshot_and_qualified_ids`
  fails on the `set(guard)` exact-key assertion (extra `reference_pool_size` /
  `trigger_policy`). Reproduced as **pre-existing at HEAD with the D2 patch stashed** —
  caused by the b1/B `GuardResult` change, not D2. Correctly flagged for the
  book-guard/roster owner.

## Findings

### BLOCKING
None.

### MAJOR
1. **Stale runtime-artifact claim: the vault Heartbeat does NOT currently show the
   new headline.** The report states the regenerated `Heartbeat.md` "now shows the
   Continuous Book Evolution headline + diagnostic pool readout." At review time the
   live vault page
   (`G:/My Drive/QuantMechanica - Company Reference/08 Current State/Heartbeat.md`,
   mtime 16:26) still shows the OLD `## Weg zu 25` section and `Buch-Guard 26 / 25`
   / `Qualifiziert: 26 / 25 Paare`. Root cause: the canonical `heartbeat_snapshot.py`
   is unpatched (`## Weg zu 25` at line 480) and the 15-min scheduled task
   `QM_Orchestrator_Heartbeat_15min` (last run 16:22, next 16:37) regenerates from
   the unpatched code and **clobbers** any pre-merge manual regeneration.
   Consequence: regenerating the vault surface before the patch lands in the canonical
   repo is ephemeral and the "now shows" claim is no longer true. Not blocking — it
   self-heals once the patched code is canonical — but per "Evidence over claims" the
   claim should be corrected, and the surface re-verified after merge (the scheduled
   task will render it correctly within one cycle).

### MINOR
1. **`census_stall_alert` measures drain-window wait, not literal terminal-idle
   duration.** The task wording is "≥3 terminals idle ≥10 min"; the implementation
   fires on drain-window `opened_epoch` / `first_skipped_epoch` age ≥600s combined
   with an instantaneous idle-terminal count ≥3. This is a reasonable proxy (the drain
   window's open age tracks the stall), but it is a slightly different quantity than
   per-terminal idle time. Acceptable; note for the watch owner.
2. **`idle_factory_terminals` returns 10 when the PowerShell terminals field is empty**
   (e.g. a PS error yields `""`). Combined with `census_done_60m==0` and an open drain
   window this could over-fire the stall alert on a transient PS failure. Low risk (the
   drain-window gate must also be satisfied), but a `terminals_field == ""` guard would
   harden it. The pre-existing `census_done_60m=0 and nothing active` check already
   covers the genuinely-idle case.
3. **`factory_bottleneck.json` writer is absent** (implementer-noted). The Factory
   facet of the new headline will read `EVIDENCE_MISSING` indefinitely until a writer
   slice lands. Follow-up for the read-model owner, not a D2 defect.

## Recommendation
Apply the patch. After it merges to the canonical repo, let (or force) the
`QM_Orchestrator_Heartbeat_15min` task regenerate `Heartbeat.md` and verify the
vault surface shows the Continuous Book Evolution headline, then correct the report's
"now shows" wording. Route the pre-existing `test_build_qualified_roster` fix and the
`factory_bottleneck.json` writer to their respective owners.
