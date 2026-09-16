# CRITIC-PREP VERIFICATION — QM5_41475 / 41476 / 41477 (frozen candidates, pre-critic)

Date: 2026-09-16 ~16:45–17:05Z
Executor: Kimi (interim OWNER delegation), task `e1c-followup`, worktree preflight PASS
(`--paths docs/ops/evidence tools/strategy_farm/research`), base `0ef15a4697d7` on `agents/board-advisor`.
Method: every value below was recomputed/executed read-only today; machine-readable capture in
`verify_raw.json` (this directory). Prescreen was re-run in its default DRY mode; no DB writes,
no commits, no card/store mutations. Reference doc: `docs/ops/CRITIC_TO_Q00_TRANSITION_2026-09-16.md`.

## Verdict summary

| EA | branch @ HEAD (verified) | verify | prescreen (dry, today) | drift vs transition doc |
|---|---|---|---|---|
| QM5_41475 H-CW | `agents/kimi-hcw-20260915` @ `86e166f26f` ✓ | **ok: true** | **KEEP, reasons []** | doc §1 stale (see DRIFT-2) |
| QM5_41476 H-MR | `agents/kimi-hmr-20260916` @ `04f10839b2` ✓ | reject: 8 × MISSING_FIELD:critic.* | REJECT: 8 × MISSING_FIELD:critic.* + NEAR_DUPLICATE 10140 | **DRIFT-1 (material): setfiles carry real build_hash** |
| QM5_41477 H-FXMR | `agents/kimi-fxmr-20260916` @ `ea38197cc0` ✓ | reject: 8 × MISSING_FIELD:critic.* | REJECT: 8 × MISSING_FIELD:critic.* | none |

## Per-EA verified state

### QM5_41475 — H-CW (provenance QM-RESEARCH-2026-0002)

- Card: `artifacts/cards_approved/QM5_41475_cash-window-index-continuation-h1.md`, sha256
  `6ac0419e5b98e72023d4…` (full value in verify_raw.json); `g0_status: APPROVED`,
  `review_status: REVIEW_PENDING`; binds `preregistration_sha256: cd661891…54322e` (==
  stored record sha, == recompute). No `source_hash` field (by design; doc agrees).
- Prereg: `strategy-seeds/sources/QM-RESEARCH-2026-0002/preregistration.json`,
  stored `record_sha256 cd661891447f6bb2ef2465607f7df40138e6a9de0879d0242b5dc7c35554322e`;
  RECOMPUTED per the doc's method (sha256 of sorted-JSON record minus the field) → **MATCH**;
  `preregister.py --check` exit 0 (record unchanged vs `H_CW_card.md`).
- Ledger (`D:\QM\reports\state\research_source_ledger.jsonl`, last row 0002): status `reviewed`,
  ledger sha == current `sha256(source.md)` = `fcc8f2dce6d7…` (verify prints the same source_hash).
- Critic receipt: `strategy-seeds/sources/QM-RESEARCH-2026-0002/critic_receipt.json` — real
  cross-vendor receipt: critic vendor `claude`, seat `opus-4.8 (Fable orchestrator, inline
  read-only)`, `critic_verdict: REVISE` (0 blocking / 3 major / 3 minor per doc), `repo_write: false`.
- research_source.verify: **exit 0, ok: true, reasons []** (today).
- ex5: `C:\QM\worktrees\kimi-hcw-20260915\framework\EAs\QM5_41475_…\QM5_41475_….ex5`
  sha256 `99126310ab17af2c…60461` — **untracked** (EX5_COMMIT_GUARD; worktree git status shows
  only the untracked ex5, otherwise clean).
- Setfiles (6, all `; build_hash: pending`): NDX/GDAXI/SP500 × `_H1_backtest.set`/`_H1_live.set`
  (`set_version: s20260915-001`).
- Magic rows (`framework/registry/magic_numbers.csv`): 414750000/NDX.DWX (slot 0),
  414750001/GDAXI.DWX (1), 414750002/SP500.DWX (2) — active; `ea_id_registry.csv` row active.
- Farm DB: 0 work_items, 0 tasks for the label.

### QM5_41476 — H-MR (provenance QM-RESEARCH-2026-0006)

- Card: `artifacts/cards_approved/QM5_41476_cash-open-mean-reversion-h1.md`, sha256
  `a6c1f343317b98e02d38…`; `g0_status: APPROVED`, `review_status: REVIEW_PENDING`;
  binds `source_hash: 1887b25e…2bd19` == current `sha256(source.md)` (no rebind pending until
  the post-critic seal); `preregistration_sha256: 8129b0fc…` == stored record sha.
- Prereg: stored `record_sha256 8129b0fc617229c40f7898c64a79072ff93019eb08fc7fa7faef69987b140d2d`,
  RECOMPUTED → **MATCH**; `--check` exit 0.
- Ledger last row 0006: status `preregistered`, sha == current source.md.
- Critic receipt: **placeholder** — all 8 required fields empty (`PENDING`).
- research_source.verify: exit 1 — exactly
  `MISSING_FIELD:critic.{chain_id, plan.creator.vendor, plan.creator.model, plan.critic.vendor,
  plan.critic.model, critic.critic_verdict, critic.critic_seat_final, critic.generated_at_utc}`.
- Prescreen (dry, today): **REJECT**, reasons =
  (1) `NEAR_DUPLICATE:QM5_10140_tv-london-session-break.md:score=1.0000`;
  (2) `INTERNAL_SOURCE_UNRESOLVED:` + the same 8 MISSING_FIELD sub-reasons. Matches doc §1 exactly.
- ex5: `…\kimi-hmr-20260916\…\QM5_41476_….ex5` sha256 `89d1107a00ef0365…a702` — untracked, clean tree.
- Setfiles (6): NDX/GDAXI/SP500 × `_H1_backtest.set`/`_H1_live.set` (`set_version: s20260916-001`)
  — **`; build_hash:` carries 6 distinct 64-hex stamps** (see DRIFT-1).
- Magic rows: 414760000/1/2 NDX/GDAXI/SP500 active; ea_id registry row active.
- Farm DB: 0 work_items, 0 tasks.

### QM5_41477 — H-FXMR (provenance QM-RESEARCH-2026-0005)

- Card: `artifacts/cards_approved/QM5_41477_fx-session-mean-reversion-m15.md`, sha256
  `5a52229b2eac826f630b…`; `g0_status: APPROVED`, `review_status: REVIEW_PENDING`;
  binds `source_hash: ba89005b…b8c` == current `sha256(source.md)`; `preregistration_sha256:
  c408f534…` == stored record sha.
- Prereg: stored `record_sha256 c408f534bc8825783d44487dd51def684227955988b680fbd4228d4578027475`,
  RECOMPUTED → **MATCH**; `--check` exit 0.
- Ledger last row 0005: status `preregistered`, sha == current source.md.
- Critic receipt: **placeholder** — 8 fields empty.
- research_source.verify: exit 1 — exactly the same 8 MISSING_FIELD:critic.* reasons.
- Prescreen (dry, today): **REJECT** — the 8 MISSING_FIELD reasons only (no duplicate).
  Matches doc §1 exactly ("the fail-closed critic gate working exactly as designed").
- ex5: `…\kimi-fxmr-20260916\…\QM5_41477_….ex5` sha256 `4e07143ac4e07ed6…1219b` — untracked, clean tree.
- Setfiles (6): EURUSD/GBPUSD/USDJPY × `_M15_backtest.set`/`_M15_live.set`
  (`set_version: s20260916-001`), **all `; build_hash: pending`** (matches doc).
- Magic rows: 414770000/EURUSD, 414770001/GBPUSD, 414770002/USDJPY active; ea_id row active.
- Farm DB: 0 work_items, 0 tasks.

## DRIFT FLAGS (vs `CRITIC_TO_Q00_TRANSITION_2026-09-16.md`)

- **DRIFT-1 (material, blocks Q00 for 41476):** the doc's §1 table says H-MR setfiles are
  "`build_hash: pending`" — they are not. The branch's *committed* setfiles (commit `9e491426f1`,
  2026-09-16 05:19Z) carry 6 distinct real `build_hash` stamps, produced by the EA-build session's
  LOCAL `build_check` run (evidence `docs/ops/evidence/2026-09-16_kimi_hmr/build_check_run.txt`)
  and committed with the EA. Consequence: the §2c guard "no setfile with a real `build_hash`
  (`BOUND_SETFILE_HASH_EXISTS`)" makes `enqueue-compile QM5_41476_…` REFUSE after the merge.
  Required pre-Q00 fix (mechanics-only, no strategy change): reset the 6 setfiles to
  `; build_hash: pending` on the branch (regenerate via `framework/scripts/gen_setfile.ps1` or a
  byte-level header reset), commit, then merge; the governed COMPILE_EA lane re-stamps
  `build_hash` itself (doc §2d). 41475/41477 are unaffected (verified `pending`, committed).
- **DRIFT-2 (stale doc, favorable):** doc §1 says H-CW prescreen currently REJECTs with
  `INTERNAL_SOURCE_UNRESOLVED:HASH_MISMATCH:lineage.json`. That birth defect was repaired by the
  governed re-seal at 2026-09-16 05:59Z (handoff scoreboard: "prescreen KEEP (birth defect fixed
  via governed re-seal 05:59Z)"); today `research_source.verify --id QM-RESEARCH-2026-0002` exits 0
  ok:true and prescreen is **KEEP with empty reasons**. The doc's TL;DR already prescribes the
  re-seal; only the §1 table row is stale. The existing claude receipt verifies clean
  post-re-anchor — no receipt replacement needed for 0002 unless the critic era wants a
  post-lineage-edit re-review for the REVISE findings (0 blocking / 3 major / 3 minor).
- **DRIFT-3 (informational):** none of the three cards carries a `card_sha256` front stamp yet
  (doc §4 checklist expects one after an in-place `approve-card` amend). Baseline content hashes
  are recorded above and in verify_raw.json; any amend must re-stamp per §2a.
- No drift: branch HEADs, prereg record hashes, ledger states, magic/ea_id registry rows,
  ex5 shas + uncommitted state, H-MR/H-FXMR prescreen reject reasons, empty farm DB — all
  exactly as the doc states (H-CW state newer than the doc's §1 row, see DRIFT-2).

## Exact transition command sequence per EA (from the doc, updated with the drifts)

Common pre-Q00 chain (doc §2a–2c): critic receipt → `research_source.py seal` → `verify` →
card fixes → prescreen KEEP → merge branch → `farmctl enqueue-compile <label>` →
`release_compile_wave.py --work-item-ids … --apply` → COMPILE_EA (build_check stamps
build_hash) → governed smoke (§2e acceptance rule) → `farmctl intake-first-q02 --apply`.

1. **QM5_41475** (H-CW): `seal QM-RESEARCH-2026-0002 --status reviewed` (already effectively
   done — verify passes today; re-run seal only if the critic edits the store) → no card edit
   (no `source_hash` field) → prescreen (already KEEP) → merge per doc §5 H-CW path (take from
   branch: EA dir + `docs/ops/evidence/2026-09-15_kimi_hcw/`; main's side for everything else)
   → `enqueue-compile QM5_41475_cash-window-index-continuation-h1` → wave release → smoke on
   NDX.DWX (≥1 trade or documented zero-trade reason) → intake-first-q02.
2. **QM5_41476** (H-MR): **first** reset the 6 setfiles to `build_hash: pending` on
   `agents/kimi-hmr-20260916` and commit (DRIFT-1) → critic receipt →
   `seal QM-RESEARCH-2026-0006 --status preregistered` → update card `source_hash` to the
   seal-printed sha AND add the one-sentence differentiation note (marker phrase, doc §2a)
   → in-place `approve-card … --reasoning "source_hash rebind + dedup differentiation after
   critic seal per OWNER_DIRECT_SESSION_DELEGATION"` (re-stamps card_sha256) → prescreen
   (expect KEEP; NEAR_DUPLICATE may remain a *warning*) → merge (fast-forward per §5) →
   `enqueue-compile QM5_41476_cash-open-mean-reversion-h1` → wave release → smoke NDX.DWX →
   intake-first-q02.
3. **QM5_41477** (H-FXMR): critic receipt → `seal QM-RESEARCH-2026-0005 --status preregistered`
   → card `source_hash` rebind + in-place `approve-card` → prescreen (expect KEEP) → merge
   (fast-forward) → `enqueue-compile QM5_41477_fx-session-mean-reversion-m15` → wave release →
   smoke EURUSD.DWX → intake-first-q02.

All card/store/branch edits and every state-mutating farmctl step above remain
critic-era/operator actions — this verification made none of them.
