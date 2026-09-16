# RECEIPT — QM5_10911/GDAXI `_opt` sibling mechanical staging — 2026-09-16

**Agent:** Kimi agent-16 under Kimi interim OWNER delegation
(`KIMI_INTERIM_HANDOFF_2026-09-18.md` line 42: "Agent-16 attempting the
mechanical part of the 10911 GDAXI sibling (ea_id 41478) with strict
stop-on-governance boundaries").
**Mode:** mechanical staging + read-only verification only. Zero `--apply` on the
matrix service, zero DB writes, zero registry writes, zero commits, no sealed-card
amendments, no hold releases. 41475/41476/41477 rows untouched.

## Stop-line statement (read first)

The mechanical chain breaks at exactly one point: **the sibling card needs
`g0_status: APPROVED`, which only OWNER records** after R1-R4
(`processes/01-ea-lifecycle.md:32`, `processes/13-strategy-research.md:49`,
`processes/process_registry.md:41`). The service hard-requires that seal
(`dl089_matrix_service.py:295`). No standing mechanical authority covers a new
10911 sibling — the six Amendment C siblings (41342-41347) each cite their own
OWNER scope (router task `db42cb90-…`), and H-CW (41475) cites a named
OWNER_DIRECT_SESSION_DELEGATION. Minting an APPROVED card for 41478 would
fabricate governance authority, so I STOPPED there per the strict rule.
Everything below is the completed mechanical half plus the exact continuation
recipe.

## Sibling contract (full detail: `contract_notes.md`)

`dl089_matrix_service.py::_measurement_sibling` discovers exactly one
`framework/EAs/QM5_*_*-opt/docs/strategy_card.md` whose frontmatter has
`parent_ea_id: QM5_10911`, `target_symbols` ∋ `GDAXI.DWX`,
`g0_status: APPROVED`, `ea_id: QM5_41478`, `period: H1`; then requires on disk
`<label>.mq5`, `<label>.ex5`, `sets/<label>_GDAXI.DWX_H1_backtest.set`
(`qm_ea_id=41478`, `RISK_FIXED>0`, `RISK_PERCENT=0`, `; environment: backtest`,
six `opt_pp_*` keys); then `_pattern_measurement_readiness` on source+setfile;
then a `COMPILE_EA done/COMPILE_OK` DB receipt whose ex5/mq5 hashes match the
on-disk binaries.

## What was built (all staged, nothing placed in governed locations)

| Artifact | Path (under this evidence dir) | SHA-256 |
|---|---|---|
| Contract analysis | `contract_notes.md` | `be0cd50f…6194` |
| Source derivation (reproducible script) | `derive_sibling_source.py` | `a5cc322b…d2d2` |
| Sibling source (602 lines) | `staged/QM5_41478_grimes-complex-pb-opt.mq5` | `ac7476b4…d7f2` |
| Sibling GDAXI base setfile | `staged/QM5_41478_grimes-complex-pb-opt_GDAXI.DWX_H1_backtest.set` | `0ad60a94…573f` |
| Card DRAFT (house format, **not sealed**) | `staged/strategy_card_QM5_41478_grimes-complex-pb-opt.DRAFT.md` | `798d2eeb…4e98` |
| Service dry-run before-state (4 rows) | `service_dryrun_before_20260916.txt` | `380429f1…d9b` |
| Allocator dry-run report (card-gate proof) | `allocator_dryrun_20260916.json` | `e767eb5d…8802` |
| Build-guardrail validation (staged artifacts) | `build_guardrails_20260916.json` | see file |

**Source derivation:** parent `QM5_10911_grimes-complex-pb.mq5` + the verified
7-hunk sibling transformation (template = approved `QM5_13013 → QM5_41321`
diff, 112 lines): identity strings, `QM_PATTERN_PERMISSION_EA_MANAGED` +
`QM_PatternPermission.mqh` includes, `qm_ea_id 10911→41478`, the identity-free
pattern surface block (byte-copied from 41321; the derivation script asserts it
is byte-present in the approved sibling), fail-closed `OnInit` profile wiring,
`PP_CENSUS_SUMMARY` in `OnDeinit`, and the `Pattern_AllowsRequest(req)` entry
gate. Resulting diff vs parent shows exactly the 7 expected hunks. Parent entry,
exit, sizing, news, Friday-close mechanics untouched.

**Setfile:** parent's GDAXI parameterization (verbatim economic params,
`RISK_FIXED=1000`, `RISK_PERCENT=0`) + `qm_ea_id=41478`,
`qm_magic_slot_offset=0` (pending allocator reconciliation), six neutral
`opt_pp_*=0`, `build_hash: pending` (stamped by the compile lane).

## Verification (executed against the canonical service code, read-only)

1. `dl089_matrix_service._neutral_matrix_setfile(staged.set, "QM5_41478")` → **OK**
   (1732-byte neutral matrix setfile produced).
2. Negative control: the parent's own GDAXI setfile is **refused** (`missing
   inputs: qm_ea_id`) — the staged delta is exactly the contract-required delta.
3. `opt_census.validate_base_setfile(staged.set, "QM5_41478")` → **OK**
   (`qm_ea_id=41478`, risk contract satisfied, `environment: backtest`).
4. `optimization_fork_driver._pattern_measurement_readiness` on staged source +
   neutral setfile → **`ready=True`, blockers `[]`**.
5. Allocator dry-run (`--dry-run --max-eas 0`): `planned_eas: 0`, 41478 absent —
   the allocator only discovers APPROVED cards, proving allocation is card-gated.
6. Service dry-run (canonical `farmctl.py service-dl089-matrix --work-item-id
   <each of the 4 rows>`, no `--apply`): all 4 still
   `expected one approved _opt sibling for QM5_10911/GDAXI.DWX, found 0`,
   `applied=false` — confirming (a) DB untouched, (b) evidence-dir staging is
   correctly invisible to discovery. **No "after" flip is possible until the
   governed artifacts land** — that is the remaining work below.
7. `validate_build_guardrails.py` over the staged source + setfile: **overall
   PASS, 0 findings** (`build_guardrails_20260916.json`; news-stale ceiling 336
   respected) — the same guardrail gate the Amendment C siblings cleared.

## Staged continuation recipe (in order, with owners)

1. **OWNER — card seal.** Ratify R1-R4 in the staged draft, copy to
   `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41478_grimes-complex-pb-opt.md`,
   set `g0_status: APPROVED` + real `g0_authority` (mirrors the 41347 card
   exactly). Also decide the sister unblock items from the same disposition:
   41347 +GDAXI target amendment and 41343 +NDX amendment.
2. **Operator (mechanical, proven 2026-09-15 for H-CW) — allocation.** From the
   canonical worktree `C:/QM/repo`:
   `python -X utf8 tools/strategy_farm/governed_magic_allocator.py --dry-run`
   then without `--dry-run` (it creates `framework/EAs/QM5_41478_grimes-complex-pb-opt/`
   + card-of-record, writes `ea_id_registry.csv` row 41478 + magic rows,
   regenerates `QM_MagicResolver.mqh`), then run the 21-test verification suite
   (`test_governed_magic_allocator.py` + `test_magic_allocation_precheck.py` +
   `test_magic_resolver_strict_default.py`), then commit path-scoped on main:
   `registry: governed allocation QM5_41478 grimes-complex-pb-opt (GDAXI.DWX magic slot)`. **Never hand-edit registry CSVs.**
3. **EA engineering — promote staged artifacts.** Move the staged `.mq5` to
   `framework/EAs/QM5_41478_grimes-complex-pb-opt/` (or re-derive in the build
   worktree per H-CW precedent) and the staged `.set` to its `sets/` dir;
   reconcile `qm_magic_slot_offset` with the allocator's slot assignment.
4. **Build lane (currently codex-quota-gated to 2026-09-19) — governed compile.**
   COMPILE_EA via `compile_work_items.py` + MetaEditor (0 errors/0 warnings);
   the lane stamps `build_hash`, binds ex5/mq5 hashes into the `COMPILE_OK`
   receipt that `_compile_receipt` requires. Do not fabricate the receipt.
5. **Central operator — verify flip, then apply.** Re-run dry per row:
   `python -X utf8 tools/strategy_farm/farmctl.py service-dl089-matrix --work-item-id 96239586-47c0-5fe2-8ef5-3d29910cc47c`
   — the `found 0` refusal must flip to Q02-seeded. Then:
   `python -X utf8 tools/strategy_farm/farmctl.py service-dl089-matrix --work-item-id 96239586-47c0-5fe2-8ef5-3d29910cc47c --apply`
   (one row suffices to seed; repeat for the other three owners if not swept in
   the same pass). Q02 then runs, and the matrix materializes on a subsequent
   pass once Q02 is `done/PASS` and K/L/G scheduling admits it.

## State left behind

- DB: untouched (all passes `applied=false`; allocation/compile lanes not run).
- Repo: no commits; the only new files are this evidence dir. Registry CSVs
  untouched. 41475/41476/41477 rows untouched.
- Governed locations (`framework/EAs/QM5_41478_*`, `cards_approved`): intentionally
  empty — the allocator creates the EA dir + card-of-record at step 2, per its
  own contract.
