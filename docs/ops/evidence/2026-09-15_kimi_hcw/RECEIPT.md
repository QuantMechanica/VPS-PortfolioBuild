# Evidence Receipt — H-CW (QM-RESEARCH-2026-0002) → V5 EA build

**STATUS=REVIEW_PENDING** — build complete, independent non-Kimi critique pending
(claude disabled until 2026-09-17, codex on hold until 2026-09-19, agy quota-dead).

**REGISTRY STATUS=BLOCKED (PENDING_ALLOCATION)** — identity/magic NOT allocated; see
"Magic allocation" below. This EA must not enter the pipeline, backtests, or any
book until allocation completes.

- Date: 2026-09-15 (UTC)
- Authority: OWNER_DIRECT_SESSION_DELEGATION to Kimi, 2026-09-15 (build-only; no
  pipeline phase, no gate verdict, no live-trading-state changes)
- Worktree: `C:\QM\worktrees\kimi-hcw-20260915`
- Branch: `agents/kimi-hcw-20260915` (base commit `da1b4b4e0c`)
- Main worktree: untouched (all work confined to the worktree)

## Artifacts

| Item | Value |
|---|---|
| EA | `QM5_41475_cash-window-index-continuation-h1` |
| Planned identity | ea_id 41475, slug `cash-window-index-continuation-h1` (free in all three registries at base commit; allocator dry-run `action=allocate`, `reserve_identity=true`, 3 rows) |
| Planned magic (slot per approved-card symbol order, magic = ea_id*10000 + slot) | slot 0 NDX.DWX = **414750000**; slot 1 GDAXI.DWX = **414750001**; slot 2 SP500.DWX = **414750002** |
| Card | `artifacts/cards_approved/QM5_41475_cash-window-index-continuation-h1.md` (sha256 5949365c…026a0) |
| EA dir | `framework/EAs/QM5_41475_cash-window-index-continuation-h1/` (.mq5, QM5_41475_CashWindowCore.mqh, SPEC.md, docs/strategy_card.md, docs/visualization_spec.md, sets/) |
| Preregistration | `strategy-seeds/sources/QM-RESEARCH-2026-0002/preregistration.json`, record_sha256 **cd661891447f6bb2ef2465607f7df40138e6a9de0879d0242b5dc7c35554322e** (schema qm.research-preregistration/v1, version 1); mechanical spec sha256 e23e2f61…499b (H_CW_card.md); `preregister.py --check` → unchanged: true. Ledger append deliberately skipped (worktree-confined build). |
| Setfiles | 6 × `sets/QM5_41475_cash-window-index-continuation-h1_<SYMBOL>_H1_<backtest|live>.set` (authored to the gen_setfile house format; canonical generator refused — requires active magic rows) |

## Compile

- MetaEditor 64 `D:\QM\mt5\T1\metaeditor64.exe /compile` with `/inc` pointed at
  `artifacts/builds/inc_staging` (worktree `framework/include` staged under
  `Include\` + terminal stdlib; the Roaming profile include tree is stale and
  was NOT mutated).
- Result: **0 errors, 0 warnings** (`artifacts/builds/compile/QM5_41475_local_wt_includes.log`).
- `.ex5` sha256 2df0c458…89f4f.
- `compile_one.ps1 -Strict` and `build_check.ps1` refused with
  `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` (terminal64 alive; governed path would
  enqueue into the live factory — out of bounds for this delegation). Refusal
  captured in `build_check_refusal.txt`. Substitute checks run: symbol-literal
  lint OK; input groups verified against the skeleton contract (5 groups +
  Stress + Strategy); registry/magic test suite below.

## Tests

- `python -m pytest -q tools/strategy_farm/tests/test_governed_magic_allocator.py tools/strategy_farm/tests/test_magic_allocation_precheck.py framework/scripts/tests/test_magic_resolver_strict_default.py` → **21 passed** (matches VERIFICATION_TEST_PASS_COUNT).
- `card_intake_prescreen.py --card <this card>` (run from the canonical checkout so the internal-source store resolves to the untouched main-repo source tree): **KEEP**, zero reasons/warnings. Running it from the worktree reports exactly one reason, `INTERNAL_SOURCE_UNRESOLVED:HASH_MISMATCH:lineage.json`, caused by the preregistration version append (the tool-designed lineage mutation); not a card defect. Reports: `card_prescreen_report.json`.

## Magic allocation — BLOCKER (environmental)

`governed_magic_allocator.py --repo <worktree> --card <card> --max-eas 1` (apply):

- Card governance checks: **passed** (`eligible`, `reserve_identity=true`, 3 rows,
  symbols in card order).
- Apply step aborted fail-closed at resolver regeneration:
  `resolver_regeneration_failed … [strict-default] 2 active ea_id(s) would be
  dropped` — ea_id 11924 (`rb-mean-reversion`) and 11941 (`ff-inst-code-levels`)
  have active magic rows (allocated 2026-09-13) whose EA directories exist ONLY
  as uncommitted content in the canonical worktree; no commit in the repository
  contains them, so any clean worktree of `da1b4b4e0c` cannot regenerate the
  resolver without dropping those rows. Full rollback verified (registry files
  byte-identical after the abort).
- Per delegation instructions the registry was NOT hand-edited and the
  regenerator's `--allow-dropped` override was NOT used (requires OWNER-reviewed
  recovery).
- Reports: `magic_allocation_report.json` (aborted apply), `magic_allocation_dryrun.json` (accepted plan).

### Remediation options for Fable / OWNER (any one unblocks)

1. Commit the two orphan EA directories (`framework/EAs/QM5_11924_rb-mean-reversion`,
   `framework/EAs/QM5_11941_ff-inst-code-levels`) from the canonical worktree
   (their owner's lane), then rerun the allocator from this worktree.
2. OWNER-reviewed recovery with `update_magic_resolver.py --allow-dropped` (drops
   the two orphan rows from the resolver until their dirs are committed).
3. Rerun the allocator with `--repo C:/QM/repo` once the canonical worktree is
   quiescent (NOT done here — forbidden by delegation).

After allocation: regenerate resolver, verify with the 21-test suite, rerun
`gen_setfile.ps1` (it will replace the hand-authored setfiles and stamp the real
build hash), then compile via the governed lane.

## Smoke

**Skipped.** The smoke/deploy harness targets terminal T1 while terminal64 is
alive; the governed compile path is refused for the same reason, and the governed
alternative (`farmctl.py enqueue-compile`) writes live factory state, which this
delegation forbids. Post-allocation smoke acceptance: ≥1 trade on the first
card-listed symbol or a documented zero-trade reason (house rule).

## Artifact hashes

See `artifact_sha256.txt` (mq5, mqh, ex5, preregistration.json, H_CW_card.md, card).

## Next steps for Fable

1. Resolve the magic-allocation blocker (options above).
2. Independent critique of card + preregistration + EA (REVIEW_PENDING).
3. Governed compile + build_check + smoke on the allocated identity.
4. Only then: Q00→ pipeline entry is a separate governance decision; this
   receipt authorizes nothing beyond build.
