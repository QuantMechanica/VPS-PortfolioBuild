# Governed identity minting for 17 PENDING_*-cards (orthogonal wave 2)

- **Task ID:** f7d75020-3ef6-4a0c-a0ff-1eed67a9bfbe (claude, ops_issue, priority 75)
- **Commissioned by:** claude-orchestrator 2026-08-24 Factory-CEO-Session
- **Prior evidence:** 11 REVIEW governed-magic-precondition REFUSE closeouts on 2026-08-24
  (`docs/ops/evidence/2026-08-24_pending_*_governed_magic_precondition.json` and predecessors),
  all confirming the same root cause: approved cards under
  `D:/QM/strategy_farm/artifacts/cards_approved/` still carried placeholder `PENDING_<HASH>`
  identities, so `governed_magic_allocator.py` correctly refused fail-closed
  (`exact_card_identity_missing`).
- **Generated:** 2026-08-24, claude-orchestration-3 (headless single-pass cycle)

## 1. Scope

`ls D:/QM/strategy_farm/artifacts/cards_approved/PENDING_*.md` → 17 files (matches the task's
"17 Stueck" estimate exactly). No matching mirror copies exist under the repo-local
`C:/QM/repo/artifacts/cards_approved/` or `C:/QM/repo/state/artifacts/cards_approved/` — D: is the
sole location for these 17, so the "both storage locations consistent" acceptance criterion is
satisfied trivially (nothing to reconcile on the C: side for this batch).

## 2. Governed sequence executed

Per the SOP referenced in the task (identity mint → card relocation → governed magic precheck →
verify), executed serially, no parallel minting sessions:

1. **Reserve numeric QM5 identities** — `farmctl.py reserve-ea-ids`, one atomic batch call per
   distinct `source_id` group (5 calls covering all 17 slugs; each call is a single locked,
   atomic CSV append, so even a batched call cannot collide with a concurrent agent's reservation).
   Commit: `c046a7f68` — `ops: reserve numeric QM5 identities for 17 PENDING_* G0-approved cards`.
   IDs allocated: `QM5_41140`-`QM5_41156` (contiguous, no gaps, no collisions with existing rows).
2. **Relocate cards** — for each card: rewrote the `ea_id:` frontmatter field from
   `PENDING_<HASH>` to `QM5_<numeric>` and renamed the file from
   `PENDING_<HASH>_<slug>.md` to `QM5_<numeric>_<slug>.md` in place under
   `D:/QM/strategy_farm/artifacts/cards_approved/` (runtime storage, not git-tracked — no commit
   needed for this step).
3. **Governed magic precheck (dry-run only, no allocation)** —
   `governed_magic_allocator.py --card <path> --dry-run --max-eas 1` for all 17 relocated cards.
   All 17 returned `"status": "eligible"` with a proposed `"action": "allocate"` decision, exit
   code 0 (see §3 and the companion CSV). No `--apply` was run: no magic-number rows, resolver
   rows, or EA directories were created. Magic allocation remains a separate, later governed step
   (typically triggered at build_ea time), out of scope for this identity-minting task.
4. **Verify** — `framework/scripts/validate_registries.py --json`. Overall registry status is
   `fail`, but exclusively from **1358 pre-existing** issues and **1192 pre-existing** warnings
   unrelated to this change (duplicate magic-number rows on older EA IDs, e.g. `1156`, `1257`,
   `9988`, `11897`, `12552` — none of them in the `41140`-`41156` range this task touched). Cross-
   checked: **0** of the 17 new IDs appear in the `issues` list; all 17 appear exactly once each in
   the `warnings` list as `ea_id_registry:ea_dir_missing:<id>:<slug>` — expected and benign, since
   no EA source directory has been built for any of them yet (identity-only reservation, per the
   task's scope). The validator's pre-existing `status: fail` is unchanged by this task; it did not
   introduce any new issue.

## 3. ID mapping table

Full table: `docs/ops/evidence/2026-08-24_pending_cards_governed_identity_minting.csv`.

| old placeholder | new EA ID | slug | target symbol | source_id | precheck |
|---|---|---|---|---|---|
| PENDING_04E5F6D9 | QM5_41140 | nzdjpy-carry-unwind-crisis-momentum | NZDJPY.DWX | BRUNNERMEIER-NAGEL-PEDERSEN-CARRY-CRASH-2008 | eligible |
| PENDING_0CD18DF4 | QM5_41141 | gbpusd-quarter-end-benchmark-fix-hedge-flow | GBPUSD.DWX | MELVIN-PRINS-LONDON-FIX-2015 | eligible |
| PENDING_11F7C177 | QM5_41142 | eurusd-month-end-benchmark-fix-hedge-flow | EURUSD.DWX | MELVIN-PRINS-LONDON-FIX-2015 | eligible |
| PENDING_2EF79507 | QM5_41143 | gbpusd-month-end-benchmark-fix-hedge-flow | GBPUSD.DWX | MELVIN-PRINS-LONDON-FIX-2015 | eligible |
| PENDING_F0F2A56F | QM5_41144 | eurusd-quarter-end-benchmark-fix-hedge-flow | EURUSD.DWX | MELVIN-PRINS-LONDON-FIX-2015 | eligible |
| PENDING_0E30F570 | QM5_41145 | sp500-highvol-liquidity-reversal | SP500.DWX | NAGEL-EVAPORATING-LIQUIDITY-2012 | eligible |
| PENDING_8C049562 | QM5_41146 | uk100-highvol-liquidity-reversal | UK100.DWX | NAGEL-EVAPORATING-LIQUIDITY-2012 | eligible |
| PENDING_C992226C | QM5_41147 | gdaxi-highvol-liquidity-reversal | GDAXI.DWX | NAGEL-EVAPORATING-LIQUIDITY-2012 | eligible |
| PENDING_FD6BDE09 | QM5_41148 | ws30-highvol-liquidity-reversal | WS30.DWX | NAGEL-EVAPORATING-LIQUIDITY-2012 | eligible |
| PENDING_1C937FC6 | QM5_41149 | audusd-local-session-inventory-drift | AUDUSD.DWX | BREEDON-RANALDO-FX-INTRADAY-2013 | eligible |
| PENDING_6008900C | QM5_41150 | gbpusd-local-session-inventory-drift | GBPUSD.DWX | BREEDON-RANALDO-FX-INTRADAY-2013 | eligible |
| PENDING_CB600D2E | QM5_41151 | usdjpy-local-session-inventory-drift | USDJPY.DWX | BREEDON-RANALDO-FX-INTRADAY-2013 | eligible |
| PENDING_CCE37C90 | QM5_41152 | eurusd-local-session-inventory-drift | EURUSD.DWX | BREEDON-RANALDO-FX-INTRADAY-2013 | eligible |
| PENDING_37F8C8E4 | QM5_41153 | audjpy-carry-unwind-crisis-momentum | AUDJPY.DWX | BRUNNERMEIER-NAGEL-PEDERSEN-CARRY-CRASH-2008 | eligible |
| PENDING_A3A88F5E | QM5_41154 | eurjpy-carry-unwind-crisis-momentum | EURJPY.DWX | BRUNNERMEIER-NAGEL-PEDERSEN-CARRY-CRASH-2008 | eligible |
| PENDING_AFB377B5 | QM5_41155 | gbpjpy-carry-unwind-crisis-momentum | GBPJPY.DWX | BRUNNERMEIER-NAGEL-PEDERSEN-CARRY-CRASH-2008 | eligible |
| PENDING_E23718DE | QM5_41156 | gdaxi-scheduled-announcement-risk-day | GDAXI.DWX | SAVOR-WILSON-ANNOUNCEMENT-RISK-2013 | eligible |

Two of these (`PENDING_E23718DE`→`QM5_41156`, `PENDING_0CD18DF4`→`QM5_41141`) were the exact
subjects of two governed-magic-precondition REFUSE evidence docs closed earlier in this same cycle
(`docs/ops/evidence/2026-08-24_pending_e23718de_governed_magic_precondition.json`,
`docs/ops/evidence/2026-08-24_pending_0cd18df4_governed_magic_precondition.json`). Those documents
remain correct as point-in-time evidence of the state *before* this minting task ran; they are not
retracted, only superseded by the mint recorded here.

## 4. Collision safety

`reserve-ea-ids` acquires an exclusive file lock on `ea_id_registry.csv`
(`_acquire_registry_lock`), reads the current max numeric ID, and appends atomically — this is the
governed, race-safe path (see `[[project_qm_duplicate_build_dispatch_magic_collision]]` /
`[[project_qm_claude_lease_pool_duplicate_build]]` class of prior incidents this prevents). No
retired row was revived, no magic number was invented, no `ea_id*10000+slot` formula was touched —
this task only reserved base EA IDs and relocated cards; it performed no magic-number allocation.

## 5. Not done (by design, out of this task's scope)

- No `--apply` magic allocation, no resolver mutation, no EA directory/build was created for any
  of the 17. That is the next governed step, triggered normally by `build_ea` dispatch.
- No pipeline verdicts exist yet for any of these 17 (all were G0-approved drafts with zero
  `work_items` history), so nothing to preserve/change there.

## 6. Artifacts

- Registry commit: `c046a7f68`
- ID mapping CSV: `docs/ops/evidence/2026-08-24_pending_cards_governed_identity_minting.csv`
- This document: `docs/ops/evidence/2026-08-24_pending_cards_governed_identity_minting.md`
