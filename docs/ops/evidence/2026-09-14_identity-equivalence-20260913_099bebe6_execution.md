# Execution record — OWNER-DEC-IDENTITY-EQUIVALENCE-20260913 (receipt 099bebe6)

Decision-bound task `9bbfcad8-0340-5ccf-b08c-7cbb82284f00` (Claude lane, orchestrator execution
2026-09-14).

## Authority

OWNER 2026-09-14 ~13:2xZ (chat, control review "Geschwindigkeit, Fortschritt, offene Punkte,
naechster Hebel / 80-20"): "Los gehts, alles freigegeben und gemaess Vorschlag entschieden!
Ausser RAM Zukauf." Card recommendation: JA fuer (1)-(3) jetzt, (4) im Cutover-Fenster.
Transcribed as a YES receipt by the Orchestrator (Stehende Vollmacht: OWNER chat instruction =
source of truth 1).

| Field | Value |
|---|---|
| decision_id | `OWNER-DEC-IDENTITY-EQUIVALENCE-20260913` |
| receipt_id | `099bebe6-1db6-4174-82be-4287639f49ff` |
| receipt_sha256 | `0dcb95b9393dfd6ad6bcd953f7dc2b9318185cce75ddc9e0574f033b5cd26a0f` |
| decided_at_utc | 2026-09-14T13:45:21Z |
| choice | YES |

## What was executed

1. **Rule recorded ACTIVE.** `decisions/2026-09-13_identity_equivalence_proof_rebuilds.md`
   `Status:` changed `PROPOSED` -> `RATIFIED / IDENTITY_EQUIVALENCE_RULE=ACTIVE (OWNER receipt
   2026-09-14)`, OWNER receipt block added (decision_id/receipt_id/receipt_sha256/decided_at_utc/
   quoted instruction), `## Rule (proposed)` -> `## Rule (ratified, active)`, rollback section's
   "inactive without an OWNER receipt" clause removed (the rule is now unconditionally active
   until superseded). Exact tolerances and verdict names unchanged (`volume_ratio_abs_tol=0.02`,
   `volume_max_step_lots=0.01`, `pnl_per_lot_rel_tol=0.005`, `net_ratio_abs_tol=0.05`;
   `EQUIVALENT_EXACT` / `EQUIVALENT_LOT_NORMALISED` / `NOT_EQUIVALENT`).
2. **41471/41472 re-proved now that their Q02 rows exist.**
   ```
   python -X utf8 tools/strategy_farm/identity_equivalence_proof.py prove \
     --original 462e2f78-8589-48eb-8bca-25c804b67bf8 --rebuilt 26aaec94-02ee-4a71-9eed-68b624b45adc
   python -X utf8 tools/strategy_farm/identity_equivalence_proof.py prove \
     --original f56d3034-abfe-4337-a103-1a85a50ad208 --rebuilt 1f8a23d2-6824-4d56-916b-6c76a2b1ed21
   ```
   Results: `QM5_12778 -> QM5_41471` **NOT_EQUIVALENT** (389 vs 261 deals, 130/261 compared deals
   differ); `QM5_13117 -> QM5_41472` **NOT_EQUIVALENT** (225 vs 225 deals, 112/225 compared deals
   differ). Filed in `docs/ops/evidence/2026-09-13_identity_equivalence/README.md` (Results table
   extended to five pairs, proof-artifact table extended, reproduce section extended). Per the
   rule's clause (d), no verdict row, census change or pool-definition change was created from
   either proof — both remain ordinary new identities that must earn their own Q02..Q10 evidence.
3. **repair_v2 staging marked DEPLOYABLE_AT_CUTOVER.**
   `docs/ops/evidence/2026-09-13_dxz_book_v2/REPAIR_V2_41470_STAGING.md`: blocker item 1 (OWNER
   receipt) marked satisfied with the receipt fields above; package status header changed to
   `DEPLOYABLE_AT_CUTOVER`; blockers 2 (book-v2 cutover order) and 3 (LIVE_RISK_FREEZE lift)
   remain open and unchanged; sibling-sleeves note updated with today's NOT_EQUIVALENT results
   for 41471/41472 and the conclusion that they stay on the original RED-9
   patch/recompile/DL-089-requalify path, not repair_v2.
   `docs/ops/evidence/2026-09-13_dxz_book_v2/deploy_manifest_v2_DRAFT.yaml`:
   `sleeves_repair[QM5_12969...].status` changed `BLOCKED_PENDING_SOURCE_PATCH` ->
   `DEPLOYABLE_AT_CUTOVER`, with a `repair_v2:` block added (substitute EA/magic, proof path +
   sha256 + verdict, staging path, remaining `blocked_by` list). `deployment_action: NO_OP`
   unchanged — nothing is applied until the cutover order lands; `sleeves_existing_reweighted`
   stays `BLOCKED_BY_LIVE_RISK_FREEZE` (freeze status untouched by this task). YAML re-parsed
   after edit (`yaml.safe_load`), no structural error.
   `docs/ops/evidence/2026-09-13_dxz_book_v2/Q16_CHECKLIST_V2.md`: RED-9 paragraph in section 3
   extended with a 2026-09-14 note distinguishing 12969 (alternate closure via repair_v2,
   DEPLOYABLE_AT_CUTOVER) from 12778/13117 (unaffected, NOT_EQUIVALENT today, stay on the
   original patch path). The 11-checks table itself (section 2, checks 1/6/7/9/10) was **not**
   changed — no compile happened on T_Live, no commission value was invented, nothing was
   deployed, so none of those cells earn GREEN from this task.
4. **Vault Hard-Rules annex — deferred, not done.** `G:\My Drive\QuantMechanica - Company
   Reference\01 Identity\Hard Rules` is not reachable from this headless session (`G:` drive not
   mapped in this process; `Get-ChildItem` fails with "Cannot find drive"). Per CLAUDE.md source-
   of-truth order, filesystem state already outranks the vault mirror, and the canonical,
   git-tracked decision record (`decisions/2026-09-13_identity_equivalence_proof_rebuilds.md`) is
   authoritative and already updated. Flagging as an open follow-up for a session with vault
   access rather than blocking this execution on it.

## Acceptance (against the task's `acceptance` list)

- "Rule recorded with the exact tolerances and verdict names" — **met** (item 1).
- "repair_v2 staging marked deployable only at a cutover order; no file reaches T_Live from this
  task" — **met**: status is `DEPLOYABLE_AT_CUTOVER`, not `DEPLOYED`/`READY`; `deployment_action`
  stayed `NO_OP`; no `deploy_tlive_book.py` invocation (dry-run or otherwise) was made by this
  task; no T_Live file/chart/preset/process touched.
- "No gate verdict, threshold or candidate-universe change" — **met**: `identity_equivalence_proof.py`
  reads `farm_state.sqlite` and report artifacts read-only; no `work_items`/`agent_tasks` row was
  written by the proof runs; no gate threshold file touched.
- "NO_AUTOTRADING; NO_DEPLOY_WITHOUT_CUTOVER_ORDER" — **met**.

## Forbidden actions — none taken

No Factory_OFF/ON, no worker/terminal interruption, no T_Live mutation, no AutoTrading change,
no order placement, no gate-threshold/criterion/candidate-universe change, no deletion or
overwrite of any existing verdict/trade stream/evidence file, no book construction or live-book
mutation.

## Evidence

- `decisions/2026-09-13_identity_equivalence_proof_rebuilds.md` (this commit)
- `docs/ops/evidence/2026-09-13_identity_equivalence/README.md` (this commit)
- `docs/ops/evidence/2026-09-13_dxz_book_v2/REPAIR_V2_41470_STAGING.md` (this commit)
- `docs/ops/evidence/2026-09-13_dxz_book_v2/deploy_manifest_v2_DRAFT.yaml` (this commit)
- `docs/ops/evidence/2026-09-13_dxz_book_v2/Q16_CHECKLIST_V2.md` (this commit)
- `D:/QM/reports/identity_equivalence/QM5_12778__QM5_41471/.../proof.json` (sha256
  `70f86e0ad1ad92ddb0aea23973a1fb19182880f2e71095f3208eea296ec6f588`)
- `D:/QM/reports/identity_equivalence/QM5_13117__QM5_41472/.../proof.json` (sha256
  `d91ca2d35ade113f5562a485a0955edc0af822cd59d577fe15257233da5e1086`)

## Still open

- Vault `01 Identity/Hard Rules` annex mirror (blocked on `G:` drive access this session).
- Book-v2 cutover order and LIVE_RISK_FREEZE lift — separate OWNER acts (task `9e5db1e9`,
  Governor v2 enforce, is condition 3 of the freeze and is handled as its own decision-bound
  task in this same cycle).
- 12778/13117 (41471/41472) remain on the standard RED-9 path: their own Q02..Q10
  requalification, no shortcut.
