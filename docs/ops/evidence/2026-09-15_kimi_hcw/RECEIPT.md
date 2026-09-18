# Evidence Receipt — H-CW (QM-RESEARCH-2026-0002) → V5 EA build

**STATUS=REVIEW_PENDING** — build complete AND registry-allocated; independent
non-Kimi critique still required before any pipeline entry (claude disabled
until 2026-09-17, codex on hold until 2026-09-19, agy quota-dead).

**REGISTRY STATUS=ALLOCATED** — governed allocation commit `57d48627e4` is merged
into this branch: `magic_numbers.csv` rows 414750000/414750001/414750002 (active),
`ea_id_registry.csv` row 41475 (active), `QM_MagicResolver.mqh` regenerated
(18352 rows, registry sha256 `90849CCF7562F…82D9F`). Pipeline/backtest entry remains
a separate governance decision (Q00+); this receipt authorizes build only.

- Date: 2026-09-15 (UTC); updated after allocation unblocked (second session)
- Authority: OWNER_DIRECT_SESSION_DELEGATION to Kimi, 2026-09-15 (build-only; no
  pipeline phase, no gate verdict, no live-trading-state changes)
- Worktree: `C:\QM\worktrees\kimi-hcw-20260915`
- Branch: `agents/kimi-hcw-20260915` (base commit `da1b4b4e0c`; merges recorded below)
- Main worktree: untouched (all work confined to the worktree)

## Branch history (this build)

| Commit | Content |
|---|---|
| `807038391e` | preregistration v1 + formal G0 card |
| `1c1896ed23` | EA implementation + hand-authored setfiles + SPEC + visualization spec |
| `b053b3670b` | evidence (first-session receipt) |
| `b18a46b5cf` | post-review fixes (closed-bar-only window, per-bar ATR cache) |
| `cd96799079` (discarded) | first attempt at `git merge main` — **reset away**, see below |
| `<allocation merge>` | merge of governed allocation commit `57d48627e4` (registry + resolver only) |

## Artifacts

| Item | Value |
|---|---|
| EA | `QM5_41475_cash-window-index-continuation-h1` |
| Identity | ea_id 41475, slug `cash-window-index-continuation-h1`, strategy_id QM-RESEARCH-2026-0002 (ea_id_registry, active) |
| Magic (slot per approved-card symbol order, magic = ea_id*10000 + slot) | slot 0 NDX.DWX = **414750000**; slot 1 GDAXI.DWX = **414750001**; slot 2 SP500.DWX = **414750002** (all active) |
| Card | `artifacts/cards_approved/QM5_41475_cash-window-index-continuation-h1.md` (sha256 5949365c…026a0) |
| EA dir | `framework/EAs/QM5_41475_cash-window-index-continuation-h1/` (.mq5, QM5_41475_CashWindowCore.mqh, SPEC.md, docs/strategy_card.md, docs/visualization_spec.md, sets/) |
| Preregistration | `strategy-seeds/sources/QM-RESEARCH-2026-0002/preregistration.json`, record_sha256 **cd661891447f6bb2ef2465607f7df40138e6a9de0879d0242b5dc7c35554322e** (schema qm.research-preregistration/v1, version 1); mechanical spec sha256 e23e2f61…499b (H_CW_card.md); `preregister.py --check` → unchanged: true. Ledger append deliberately skipped (worktree-confined build). |
| Setfiles | 6 × `sets/QM5_41475_cash-window-index-continuation-h1_<SYMBOL>_H1_<backtest|live>.set`, **canonically regenerated via `framework/scripts/gen_setfile.ps1`** after allocation (magic_slot resolved from the registry: NDX 0 / GDAXI 1 / SP500 2; card defaults bound from the approved card). Header `build_hash: pending` is the generator's canonical pre-compile state; the governed compile (build_check set-header update) stamps the real hash — that step requires the governed lane, see Smoke. Per-file sha256 in `setfile_and_ex5_sha256.txt`. |

## Magic allocation — UNBLOCKED

- `57d48627e4` ("registry: governed allocation QM5_41475 …", parent `c062742682`
  = cherry-pick of this branch's card/prereg commit) was committed on
  `agents/board-advisor`, **not on `main`** (main's committed
  `magic_numbers.csv` still lacks the 41475 rows; the canonical worktree's copies
  of the rows are uncommitted). This branch obtained the allocation by merging
  `57d48627e4` directly — a 3-file commit (3 magic rows + 1 identity row +
  resolver regen) that applied cleanly onto this lineage.
- **Merge note / unexpected finding:** a plain `git merge main` was NOT clean.
  Main's committed history since merge-base `d02f3f3496` carries factory files
  (Q14-Q16 manifests, dashboards, tests) as *replayed* commits parallel to this
  branch's lineage copies — 21 add/add and content conflicts resulted. Resolving
  them toward main broke cross-imports of untouched lineage modules
  (`phase_ids.ACTIVE_GATE_CONTRACT_VERSION`, caught by the test suite). The main
  merge was therefore reset and replaced by the scoped allocation merge: this
  build lane keeps its consistent, test-green lineage state and the exact
  governed registry delta. When this branch is later integrated to main, the
  integrator should take main's side for the conflicting factory files (they
  are outside this build's scope).

## Compile

- MetaEditor 64 `D:\QM\mt5\T1\metaeditor64.exe /compile` with `/inc` pointed at
  `artifacts/builds/inc_staging` (worktree `framework/include` staged under
  `Include\` + terminal stdlib; the Roaming profile include tree is stale and
  was NOT mutated).
- Result after allocation merge (resolver with 41475 tuples embedded):
  **0 errors, 0 warnings** (`artifacts/builds/compile/QM5_41475_local_wt_includes.log`).
- `.ex5` sha256 99126310…60461 (not committed — EX5_COMMIT_GUARD requires a
  governed COMPILE_EA receipt; hash recorded in `setfile_and_ex5_sha256.txt`).
- `compile_one.ps1 -Strict` / `build_check.ps1` refuse ad-hoc while terminal64
  is alive (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`, captured in
  `build_check_refusal.txt`). Substitute checks: symbol-literal lint clean;
  21-test registry suite; canonical gen_setfile run.

## Tests (post-allocation state)

- `python -m pytest -q tools/strategy_farm/tests/test_governed_magic_allocator.py tools/strategy_farm/tests/test_magic_allocation_precheck.py framework/scripts/tests/test_magic_resolver_strict_default.py` → **21 passed** (matches VERIFICATION_TEST_PASS_COUNT; resolver now includes the 41475 tuples).
- `lint_ea_symbol_literals.py --ea-root framework/EAs/QM5_41475_cash-window-index-continuation-h1` → **OK** (no hardcoded .DWX literals).
- `card_intake_prescreen.py --card <card>` (from the canonical checkout): **KEEP**, zero reasons/warnings (`card_prescreen_report.json`).

## Smoke

**Skipped (documented).** The governed smoke admission
(`custom_history_smoke_admission.py`) is a farm-reservation gate: it connects to
the farm DB, checks active work-item claims, and writes
`terminal_reservations.json` — factory-state writes outside this delegation.
Current reservations at check time: T6 and T8 held by other agents'
`run_smoke_custom_history_admission` jobs (until ~00:36/00:53 UTC); the remaining
terminals run live books (the same condition that refuses ad-hoc compiles).
**Post-integration acceptance rule (house):** run the governed smoke on the first
card-listed symbol (NDX.DWX); it must produce ≥1 trade or a documented
zero-trade reason.

## Artifact hashes

- `artifact_sha256.txt` — mq5, mqh, preregistration.json, H_CW_card.md, card.
- `setfile_and_ex5_sha256.txt` — 6 setfiles + ex5 (post-allocation rebuild).

## Next steps for Fable

1. Independent critique of card / preregistration / EA (REVIEW_PENDING gate).
2. Integrate this branch to main (integrator resolves the known parallel-replay
   conflicts in factory files — take main's side; the registry/EA files merge
   cleanly).
3. Governed lane: COMPILE_EA → build_check (stamps setfile build_hash) → smoke
   (acceptance rule above).
4. Only after 1+3: Q00/pipeline entry is a separate governance decision.
