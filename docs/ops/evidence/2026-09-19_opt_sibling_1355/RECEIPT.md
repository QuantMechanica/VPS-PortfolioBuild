# RECEIPT — QM5_1355/NDX `_opt` sibling QM5_41482 — mechanical staging through COMPILE_OK and Q02 seed — 2026-09-19

**Agent:** Claude (headless orchestration lane), task
`0f99d9ea-6661-4028-a25e-e2a3b9725a45`, replaying the verified sibling recipe
of `docs/ops/evidence/2026-09-16_opt_sibling_10911/` (RECEIPT.md continuation
recipe, `contract_notes.md`, `derive_sibling_source.py`), reference approved
sibling `QM5_41321_grimes-trendday-v2-opt`, completed chain `QM5_41478`.

**Authority:** Card sealed `g0_status: APPROVED` under
`g0_authority: "OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917 (Fable seal,
ticket 0f99d9ea-6661-4028-a25e-e2a3b9725a45)"` —
`decisions/2026-09-17_owner_fable_full_executive_authority.md` §2 delegates
Strategy Card / portfolio-candidate authority (and MQL5/framework, registry,
Git/GitHub, gate/pipeline changes) to Fable without routine OWNER approval;
the sole remaining OWNER gate is the paid FTMO Challenge purchase. Unlike the
2026-09-16 predecessor (which stopped at the card seal because no standing
mechanical authority covered it), this ticket's own payload already carried
the seal instruction, so the full chain below was executed end to end.

## What was done, in order

1. **Reserved EA id** — `farmctl.py reserve-ea-ids --slug
   williams-vix-fix-fx-h4-opt --strategy-id 6e967762-…` → `QM5_41482`
   (`reserve_ea_id.json`). Committed alone on `agents/board-advisor`
   (`ae2bb579ca`) to clear the allocator's dirty-registry guard before use —
   no other file touched.
2. **Derived sibling source** — `derive_sibling_source.py` replays the
   verified `QM5_13013 -> QM5_41321` / `QM5_10911 -> QM5_41478` 7-hunk
   transformation against `QM5_1355_williams-vix-fix-fx-h4.mq5`: identity
   strings, `QM_PATTERN_PERMISSION_EA_MANAGED` + `QM_PatternPermission.mqh`,
   `qm_ea_id 1355->41482`, the identity-free pattern-measurement surface
   (byte-checked against the approved `QM5_41321` block), fail-closed
   `OnInit` wiring, `PP_CENSUS_SUMMARY` in `OnDeinit`, and the
   `Pattern_AllowsRequest(req)` entry gate. **Plus an 8th hunk** discovered
   only at first compile (see below): the Q08 MAE hook.
3. **Base setfile** — parent's NDX H4 parameterization verbatim
   (`RISK_FIXED=1000`, `RISK_PERCENT=0`) + `qm_ea_id=41482` + six neutral
   `opt_pp_*=0`.
4. **Card sealed** — `strategy_card_QM5_41482_williams-vix-fix-fx-h4-opt.md`,
   placed at `D:/QM/strategy_farm/artifacts/cards_approved/`.
5. **Pre-allocation validation** (staged artifacts, `staged/`):
   `dl089_matrix_service._neutral_matrix_setfile` OK (1184-byte neutral
   setfile); `opt_census.validate_base_setfile` OK;
   `optimization_fork_driver._pattern_measurement_readiness` `ready=True`,
   `blockers=[]`; `validate_build_guardrails.py` PASS/0 findings
   (`build_guardrails_20260919.json`). Re-verified against the final governed
   copy post-repair: `dl089_contract_validation_20260919.json` (unchanged
   PASS/ready=True).
6. **`governed_magic_allocator.py --card … --dry-run` then real run** —
   `allocator_dryrun_20260919.json` / `allocator_apply_20260919.json`: created
   `framework/EAs/QM5_41482_williams-vix-fix-fx-h4-opt/` + card-of-record,
   `ea_id_registry.csv` row, magic row `414820000` (slot 0, NDX.DWX),
   regenerated `QM_MagicResolver.mqh`. 21/21 verification tests pass (one
   Windows scratch-dir `PermissionError` flake reproduced red then green in
   isolation — not a real regression).
7. **Promoted staged `.mq5`/`.set`** into the governed EA directory.
8. **`enqueue-compile QM5_41482_williams-vix-fix-fx-h4-opt`** → work item
   `25c1060f-…`, held `COMPILE_EA_WORKER_ROLLOUT_PENDING`.
   `release_compile_wave.py --apply` released it
   (`release_compile_wave_apply.json`) → **COMPILE_FAIL**,
   `build_check_result=FAIL`, `failure_classes=["EA_Q08_MAE_HOOK_MISSING"]`:
   the parent (`QM5_1355`, last built 2026-08-16) predates the current-build
   Q08 MAE hook contract (`build_gate_hardening.py`); the 7-hunk derivation
   faithfully replayed that gap. **Root-caused against the newer-generation
   parent `QM5_10911`/sibling `QM5_41478`, both of which already carry
   `QM_FrameworkTrackOpenPositionMae()` as the first `OnTick` statement.**
9. **Repair** — added hunk 8 (same call, same comment, first `OnTick`
   statement; pure telemetry, no signal/entry/exit/sizing/risk/news change).
   Re-validated (build guardrails PASS), re-promoted. Registered a generic
   compile-fail repair authority
   (`compile_fail_repair:20260919:QM5_41482_williams-vix-fix-fx-h4-opt:e0549fbd`,
   `tools/strategy_farm/config/compile_fail_repair_authorities.v1.json`,
   evidence `docs/ops/evidence/2026-09-19_compile_fail_repair_authority/QM5_41482.json`)
   bound to the exact failed predecessor row and its failure classes — the
   generic twin of the 2026-09-18 `QM5_41475`/`QM5_41477` precedents.
   `enqueue-compile … --source-repair-authority …` → work item `56887ed0-…`;
   `release_compile_wave.py --apply` released it
   (`release_compile_wave_apply2.json`) → **COMPILE_OK**
   (`ex5_sha256 e0d52b7c…`).
10. **`farmctl.py service-dl089-matrix --work-item-id
    ba724ef2-22eb-54fa-b155-a793ef54b5c1`** — the original deferred Q12
    declaration ("expected one approved `_opt` sibling for QM5_1355/NDX.DWX,
    found 0") flipped: `deferred: []`, `q02_prerequisites` shows
    `measurement_ea_id: QM5_41482`, seeding Q02 backtest work item
    `c45946a3-…` (`Q02`, `QM5_41482`/`NDX.DWX`, status `active`) —
    `service_dryrun_after_20260919.json`. The factory's own automated
    dl089-matrix-service pass had already run the seed by the time this
    dry-run executed.

## Commits (all `agents/board-advisor`, explicit pathspecs, no other files touched)

| Commit | Scope |
|---|---|
| `ae2bb579ca` | `framework/registry/ea_id_registry.csv` — reserve QM5_41482 |
| `1a8b9d537b` | `compile_fail_repair_authorities.v1.json` + evidence — Q08 MAE hook repair authority |
| `14cea454ee` | `QM_MagicResolver.mqh`, `ea_origin.v1.csv`, `magic_numbers.csv`, `framework/EAs/QM5_41482_williams-vix-fix-fx-h4-opt/` (`.mq5`, `.set`, `.ex5` — the pre-commit hook validated the `.ex5` against the `COMPILE_OK` receipt at commit time) |

## State left behind

- Parent `QM5_1355` source, its Q02–Q11 verdicts and evidence: **untouched**.
- No verdict mutation anywhere in this ticket's scope.
- Main / `cto_main`: **not touched** — all work on `agents/board-advisor` per
  task instructions; this artifact is left in `REVIEW` for the Claude+OWNER
  close-out to integrate.
- Q02 backtest for `QM5_41482`/`NDX.DWX` is now running under ordinary
  factory automation; the DL-089 census will materialize once Q02 clears
  `PASS` and K/L/G scheduling admits it — no further action from this ticket
  is required to progress it.
