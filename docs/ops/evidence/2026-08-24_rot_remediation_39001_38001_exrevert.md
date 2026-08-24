# ROT remediation — revert ad-hoc EX5 for QM5_39001 + QM5_38001

- Router task: `b63eaead-7890-4be4-b8e7-0edea3fe6a85` (ops_issue, claude)
- Executed: 2026-08-24, from canonical checkout `C:/QM/repo` on
  `agents/board-advisor` (HEAD at start `413f1ebb5`)
- Trigger: `docs/ops/evidence/2026-08-24_review_qm5_39001.md` (Claude review,
  RECYCLE) and `docs/ops/evidence/2026-08-24_greview_39001.md` (cross-review,
  RECYCLE) both independently found the rework commits for QM5_39001
  (`50435c0f7`) and QM5_38001 (`eabcee237`) contained EX5 binaries compiled
  ad hoc via an idle MetaEditor (T8, portable mode) **after** the governed
  wrapper (`build_check.ps1`) failed closed with
  `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because factory terminals were live.
  This is the documented ROT violation: no `.ex5` may enter the tracked
  inventory outside a governed `COMPILE_EA` receipt, and QM5_39001 is a
  repeat case (see `docs/ops/evidence/2026-08-23_rework-39001.md` for the
  first occurrence pattern).

## Scope

Revert only the ad-hoc-compiled `.ex5` binaries. The source-level review
repairs in both rework commits (`.mq5`, `SPEC.md`, setfiles, focused tests,
evidence docs) are **not** touched — they were reviewed on their own merits
(RECYCLE for unrelated card-fidelity/state/staleness defects, not for the
source repair work itself) and remain in the tree. No registry, DB, factory,
or `T_Live` change was made. No compile was performed by this task — that
would repeat the same violation; instead both EAs were handed to the
governed `COMPILE_EA` queue as append-only successors.

## Hash table

| EA | File | Before this task | After this task | Note |
|---|---|---|---|---|
| QM5_39001 | `.ex5` | `c1b0950d6b18a170ab3b0519a17b92a3769e68a9727599348e159fb0aa674efd` (ad hoc, T8 non-portable MetaEditor, committed `50435c0f7`) | `5bf6b35574a922e8d744f3d95e26c8a51030f60bf633a0ad5a883df19719eb20` (restored from parent commit `bfd467bc6`, last governed-committed binary) | Restored binary is itself stale vs current `.mq5` (known, pre-existing — this task does not fix staleness, only the ROT violation) |
| QM5_39001 | `.mq5` | `70ee90c426a46639259826c0ee4568a876cf6571cc4816577ba305285e42c17e` | unchanged | not touched |
| QM5_38001 | `.ex5` | `eaabe10f8ae3ee2792e6e4195c5cd6fb3cf4562b89930a3774363057e35fecbd` (ad hoc, T8 portable MetaEditor with temporarily mirrored includes, committed `eabcee237`) | *(removed)* | Pre-rework state had **no** `.ex5` at all: the prior governed commit `fb225460d` ("build: harden QM5_38001 VWAP scalper") deliberately deleted the stale binary (`Bin 398832 -> 0 bytes`) when its source changed without a fresh governed compile. Restoring "Vorzustand" means absence, not a stale prior binary. |
| QM5_38001 | `.mq5` | `f7e8f55896b3e90ae9775a559829f4f2bc14c901b2ae9cae237289ff993e8e9f` | unchanged | not touched |

Verification commands used:

```text
git log --oneline 50435c0f7..HEAD -- framework/EAs/QM5_39001_forexfactory-trading-made-simple-tms/   -> (empty; no later touches)
git log --oneline eabcee237..HEAD -- framework/EAs/QM5_38001_codetrading-vwap-bollinger-rsi-scalper/ -> (empty; no later touches)
git merge-base --is-ancestor 50435c0f7 main  -> not an ancestor (rework never reached main)
git merge-base --is-ancestor eabcee237 main  -> not an ancestor (rework never reached main)
sha256sum <ex5 paths>                        -> matched the ad-hoc hashes recorded in both rework evidence docs before the revert
```

## T8 include-mirror check

`docs/ops/evidence/2026-08-23_rework-38001.md` claims T8's original include
tree was restored in a `finally` block after the portable compile. Verified
independently by comparing every file under
`D:/QM/mt5/T8/MQL5/Include/QM/` against `C:/QM/repo/framework/include/QM/`
by byte size: all 46 files match except `QM_MagicResolver.mqh`
(T8: 612402 bytes; repo: 616828 bytes as of 2026-08-24 16:58), which is
expected drift — the resolver regenerates on every EA-ID reservation and T8
only receives a fresh mirror at governed compile time, not continuously. No
residual contamination found; no cleanup action required.

## What changed in this commit

- `git checkout bfd467bc6 -- framework/EAs/QM5_39001_forexfactory-trading-made-simple-tms/QM5_39001_forexfactory-trading-made-simple-tms.ex5`
  (restores the pre-rework governed binary)
- `git rm framework/EAs/QM5_38001_codetrading-vwap-bollinger-rsi-scalper/QM5_38001_codetrading-vwap-bollinger-rsi-scalper.ex5`
  (removes the ad-hoc binary; no governed replacement exists yet)
- `tools/strategy_farm/compile_work_items.py`: added a new named,
  single-purpose source-repair authority
  (`ROT_REMEDIATION_39001_38001_AUTHORITY` =
  `router_ops_issue:b63eaead-7890-4be4-b8e7-0edea3fe6a85`), following the
  exact existing pattern (`SOURCE_REPAIR_AUTHORITY`,
  `Q02_INFRA_SOURCE_REPAIR_AUTHORITY`, etc.) — an explicit constant bound to
  this router task ID and exactly these two EA labels, wired into
  `_source_repair_authorized`. This does not weaken the default
  no-overwrite/no-ad-hoc guard for any other EA.
- This evidence file.

## Governed COMPILE_EA successors (append-only)

```text
python tools/strategy_farm/farmctl.py enqueue-compile \
  --source-repair-authority "router_ops_issue:b63eaead-7890-4be4-b8e7-0edea3fe6a85" \
  QM5_39001_forexfactory-trading-made-simple-tms \
  QM5_38001_codetrading-vwap-bollinger-rsi-scalper
```

Result: `ok=true`, both enqueued as `idempotent_open` (a `COMPILE_EA` work
item already existed from a prior attempt, unaffected by this run —
append-only, no row was overwritten):

| EA | COMPILE_EA work_item_id | status | activation_hold |
|---|---|---|---|
| QM5_39001 | `3c0472f2-325c-4062-aba8-5666138d44e9` | pending | `COMPILE_EA_WORKER_ROLLOUT_PENDING` |
| QM5_38001 | `960f030f-5632-4e6c-a3e8-9dc39dfb0bde` | pending | `COMPILE_EA_WORKER_ROLLOUT_PENDING` |

Both hold on the same fleet-wide `COMPILE_EA_WORKER_ROLLOUT_PENDING` gate as
every other queued `COMPILE_EA` row (release only through the governed
release-on-restart ceremony) — not a special case introduced here.

## Verification

```text
git status --short -- framework/EAs/QM5_39001_forexfactory-trading-made-simple-tms/ framework/EAs/QM5_38001_codetrading-vwap-bollinger-rsi-scalper/
 M framework/EAs/QM5_39001_forexfactory-trading-made-simple-tms/QM5_39001_forexfactory-trading-made-simple-tms.ex5
 D  framework/EAs/QM5_38001_codetrading-vwap-bollinger-rsi-scalper/QM5_38001_codetrading-vwap-bollinger-rsi-scalper.ex5

python tools/strategy_farm/farmctl.py compile-status QM5_39001_forexfactory-trading-made-simple-tms QM5_38001_codetrading-vwap-bollinger-rsi-scalper
counts: pending=2, activation_held=2, active=0, compiled=0, failed=0, not_enqueued=0
```

## Rollback

```text
git revert --no-edit <this commit>
```

Restores the ad-hoc EX5 bytes and the `compile_work_items.py` authority
addition. The two `COMPILE_EA` work items already enqueued are append-only
router state and are not affected by a source revert; if this remediation is
reverted, those two work items should be superseded by a new task rather
than deleted.

## Follow-up (not in scope here)

- `2d0bdc23-749d-4443-9000-beec43d0135c` (review, QM5_39001) and
  `ce1b2ad8-e99a-49b3-96d1-581726dc3bdf` (review, QM5_38001) remain `BLOCKED`
  per their own findings; nothing here changes their disposition.
- Once `COMPILE_EA_WORKER_ROLLOUT_PENDING` clears fleet-wide, both EAs will
  compile through the governed path and produce a fresh, hash-bound EX5 —
  at that point QM5_39001 still carries the unresolved card-fidelity/GMT/
  state defects from `docs/ops/evidence/2026-08-24_greview_39001.md`; those
  are a separate rework, not this remediation.
