# Independent review: QM5_41398 balke-pattern-repair-opt

Router task: `e1358f42-c9f2-4cd2-89ce-f337b17ac84a` (`ops_issue`, priority 92, decision-bound
to claude). Order: `docs/ops/evidence/2026-09-09_balke_41398_review_handoff.md`. Authority:
`decisions/2026-09-09_balke_pattern_recovery.md`. This is an independent review by Claude
through the router, not a self-approval by the implementer (Codex, commit `677068883e` atop
`503fb410f5`).

## Verdict: PASS (independent, evidence-backed)

Every claim in the handoff and in `docs/ops/evidence/2026-09-09_balke_pattern_recovery.md` was
re-derived from primary evidence, not taken on trust.

## What was independently checked

1. **Compile evidence.** Read
   `D:/QM/reports/work_items/e8e4cad7-5ec5-428b-9c61-f690e26f8089/QM5_41398/COMPILE_EA/compile_evidence.json`
   directly: `compile_result=PASS`, `compile_errors=0`, `compile_warnings=0`,
   `build_check_result=PASS`, `success=true`. `ex5_sha256` and `mq5_sha256` in that file match
   the handoff's claimed hashes exactly. Recomputed SHA256 locally on the frozen bundle
   (`D:/QM/reports/pattern_permission_repair/balke_41398_20260909/`) and on the live repo copy
   (`C:/QM/repo/framework/EAs/QM5_41398_balke-pattern-repair-opt/QM5_41398_balke-pattern-repair-opt.mq5`):
   all three (frozen bundle, repo working tree, evidence JSON) agree on
   `fdbb7499f349a6bd238231e7eb3d4a6257290af650e363ba78b0f95518890540` (MQ5) and
   `68d37d3a6b6d5d4354e5a9aa494488d8d2809b1f662ff75fbb26440658137c01` (EX5).
2. **Source delta vs frozen 41097.** `diff` of the two `.mq5` files shows exactly four hunks:
   the `#property description` string, one added `#define QM_PATTERN_PERMISSION_EA_MANAGED`
   line plus its one-line comment, an identity comment string, and `qm_ea_id = 41097 -> 41398`.
   No other line differs. This matches the claimed scope (identity/description +
   `QM_PATTERN_PERMISSION_EA_MANAGED` guard only).
3. **Registry/magic.** `git show 677068883e -- framework/registry/ea_id_registry.csv
   framework/registry/magic_numbers.csv`: exactly one appended row per file. `ea_id_registry.csv`
   row 41398 carries the same logical-identity UUID (`6e967762-b26d-59a3-b076-35c17f2e7c36`) as
   the frozen 41097 row, confirming shared lineage to `QM5_13213`. `magic_numbers.csv` row is
   `41398,balke-pattern-repair-opt,0,USDJPY.DWX,413980000,...,active` — matches
   `ea_id*10000+slot` (41398*10000+0). Grep confirms `413980000` appears exactly once in the
   registry (no collision); no retired row was touched or reused.
4. **28 inputs / neutral control / risk mode.** Counted 28 non-group `input` declarations in
   the compiled source (7 `input group` headers separate them). All 28 appear as explicit
   assignments in the generated backtest set
   (`framework/EAs/QM5_41398_balke-pattern-repair-opt/sets/..._USDJPY.DWX_H1_backtest.set`):
   `RISK_FIXED=1000`, `RISK_PERCENT=0` (hard-rule compliant), all six `opt_pp_{buy,sell}{1,2,3}=0`
   (neutral unfiltered control, as required by the CEO decision), `qm_news_stale_max_hours=336`
   (at the guardrail ceiling, not above it — compliant with the build guardrail).
5. **Closed D1 reference / straddle ownership.** `QM_PPC_REFERENCE_TF = PERIOD_D1` and
   `QM_PPC_CLOSED_SHIFT = 1` are compile-time constants (not inputs, cannot be swept).
   `Strategy_BuildStraddlePlan` populates both `plan.buy_req` and `plan.sell_req` and sets
   `want_buy = want_sell = true` every day a valid range exists — both straddle legs are owned
   by the same plan/permission/decision pipeline, not split logic.
6. **Inherited early-news-return before management/exit.** Confirmed in the live `OnTick()`
   (lines 550-611 of the compiled source): the news-allow check (`if(!news_allows) return;`)
   executes before `Strategy_ManageOpenPosition()` and before the `Strategy_ExitSignal()` block.
   This ordering is **unchanged** by the reviewed diff (item 2 above shows no OnTick edits), so
   it is present identically in both 41097 (baseline) and 41398 (repair measurement). Judgment:
   this does **not** invalidate the isolated, non-live repair-vs-baseline comparison, because
   the defect affects both instruments equally and cancels out in a relative comparison. It
   **does** remain a real limitation for any future live/deploy consideration (an open position
   cannot be managed or exited while the news gate is closed) and is explicitly **not** fixed or
   waived by this review — any deploy decision needs its own separately declared baseline that
   addresses this ordering. No implicit deploy approval is given here.
7. **gen_setfile.ps1 fix.** `git show 677068883e -- framework/scripts/gen_setfile.ps1` is a
   single narrow change: `Add-DefaultsMatchingInputs`'s `-Target` parameter type changed from
   `[hashtable]` (which PowerShell copies by value, silently discarding card-default writes
   into the caller's `[ordered]` dictionary) to `[System.Collections.IDictionary]` (kept by
   reference). Independently re-ran the new regression test
   (`tools/strategy_farm/tests/test_gen_setfile.py::test_card_defaults_mutate_ordered_target_and_override_source`,
   both `powershell.exe` and `pwsh` parametrizations): **2 passed** locally, confirming a card
   override (17->23) lands exactly once and an unknown card input is discarded. No existing
   bound `.set` file was touched by this commit (diff is limited to the one new EA's own set,
   the two registries, `QM_MagicResolver.mqh`, `gen_setfile.ps1`, and test/decision/evidence
   files) — confirmed via `git show --stat 677068883e`.
8. **Three-way Q12 hold check.** Queried `work_item_holds` directly: all three protected rows
   (`97908d93-...`, `ed127702-...`, `0e5eff83-...`) carry `hold_code=BALKE_PATTERN_REPAIR_REVIEW_PENDING`,
   `active=1`, `release_on_restart=0`, as claimed. Queried `work_items`: all three are
   `status=pending`, `verdict=NULL`, `claimed_by=NULL` — unclaimed/pending/unverdicted, matching
   the handoff's precondition for release.

## Actions taken after PASS (scope: exactly the current declaration only)

- `farmctl.py release-hold --work-item-id 97908d93-3ff8-5528-9518-8968aea72342
  --expected-hold-code BALKE_PATTERN_REPAIR_REVIEW_PENDING --dry-run` -> `would_release: true`,
  scoped to that single row. Applied (no `--dry-run`) after this document was written.
- `ed127702-...` and `0e5eff83-...` were left held (untouched) as instructed.
- `farmctl.py service-dl089-matrix --work-item-id 97908d93-...` (no `--apply`) before the
  release showed the row `deferred` with `machine_reason: "blocking hold:
  BALKE_PATTERN_REPAIR_REVIEW_PENDING"`, confirming the service correctly sees the hold and
  will not commission Q02 while it is active.
- After release, re-ran the same targeted service call with `--apply`:
  `farmctl.py service-dl089-matrix --work-item-id 97908d93-... --apply` ->
  `q02_prerequisites: [{"created": true, "measurement_ea_id": "QM5_41398",
  "q12_work_item_id": "97908d93-3ff8-5528-9518-8968aea72342", "status": "pending",
  "superseded_work_item_id": null, "verdict": null, "work_item_id":
  "2fc84747-27db-5e88-9568-3fdda6c30769"}]`. Exactly one new Q02 work item was created
  (`2fc84747-27db-5e88-9568-3fdda6c30769`), `superseded_work_item_id: null` confirms no old
  41097 measurement is being reused, `deferred: []` confirms nothing else was touched. `status`
  is `pending` — no economic measurement has run yet; the factory queue will pick it up under
  its normal MT5-slot scheduling. Runtime budget for the full matrix must be reported from this
  Q02's actual duration once it completes, before the 1,085-cell + 4 WF-cell matrix is started.

## What this review does not claim

No economic result, no improved-return claim, no portfolio/live authorization. Compile PASS and
this independent review are not an economic PASS. The full 1,085-cell + 4 WF-cell matrix is
explicitly **not** started here; only the single Q02 baseline is commissioned, gated on its own
PASS before any further matrix execution, per the handoff's runtime-budget requirement.
