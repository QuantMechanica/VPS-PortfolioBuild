# Book-path scratch rehearsal (GAP G8) -- steps 5-10 against the current 5-pair pool

**Status:** evidence-only rehearsal. No production tool changed; no live/T_Live/DB/queue/decisions
state written. The report is the deliverable.
**Author:** Claude (board-advisor lane, worktree `wf_8c3a9afe-b0f-3`), 2026-09-03.
**Scope of task:** BOOK_CEREMONY_RUNBOOK_2026-09 section 2, steps 5-10, smoke-tested now so the
real trigger day (guard reports `qualified_pairs >= 25`) is not the first run of the chain.
**Trigger reference (runbook 6, G8):** Q15_DXZ / Q15_FTMO have never carried a row; the
builder -> fit -> stage -> deploy chain has never run against a real >= 25 pool.

## 0 - Provenance and read-only statement

- **Fast-forward merge (task precondition):** `git merge --ff-only agents/board-advisor`
  succeeded. BEFORE `a92cda60fe1e62eeee73de6068dd2634dba490d2` ->
  AFTER `c032dbb1a50dfab0328aa17d80bad0c548e4ec28` (Fast-forward, exit 0).
- **DB access:** every DB read used `rebaseline_census.open_ro` (rebaseline_census.py:209-216),
  which opens `file:...?mode=ro` (read-only URI). No write path to the farm DB was invoked.
- **Scratch workspace (never decisions/, never C:/QM/mt5/T_Live):**
  `%LOCALAPPDATA%/Temp/3/claude/.../scratchpad/g8_rehearsal/` with subdirs `order-dir/`
  (throwaway `--order-dir`), `tlive_fixture/MT5_Base/MQL5/{Presets,Experts/Live EAs}/`
  (self-authored T_Live-shaped fixture), `staging/`, `backup/`, `logs/`.
- **Interpreter:** `C:/Python311/python.exe` (3.11.9), run from the worktree root.
- **Calibrations guard (task postcondition):** `git status --short framework/calibrations/`
  is EMPTY -- no QM5_9993 autostub created; no `git checkout -- framework/calibrations` needed.
- **Worktree:** all work inside `C:/QM/repo/.claude/worktrees/wf_8c3a9afe-b0f-3`; the only
  worktree file written is this report.

## 1 - Guard status output, verbatim

### 1.1 book_build_guard --status --venue dxz --order-dir decisions (canonical, read-only)

```
{
  "allowed": false,
  "distinct_eas": 5,
  "order_artifact": null,
  "qualified_pairs": 5,
  "reasons": [
    "qualified_pairs_below_minimum: 5 < 25",
    "owner_order_missing: venue=dxz order_dir=decisions"
  ],
  "strategy_families": 5
}
```
exit 2, elapsed 2474 ms.

### 1.2 book_build_guard --status --venue ftmo --order-dir decisions (read-only)

```
{
  "allowed": false,
  "distinct_eas": 5,
  "order_artifact": null,
  "qualified_pairs": 5,
  "reasons": [
    "qualified_pairs_below_minimum: 5 < 25",
    "owner_order_missing: venue=ftmo order_dir=decisions"
  ],
  "strategy_families": 5
}
```
exit 2, elapsed 4735 ms.

### 1.3 risk_freeze.py status (verbatim)

```
OWNER-DEC-RISK-FREEZE  status=ACTIVE  armed=2026-08-31T05:12:17.7290629Z
  total RISK_PERCENT   baseline 9.7499  now 9.7499
  freeze held          YES
  lift conditions:
    [SP-A1/A2-DEPLOY-POINTER] live_deployment_pointer.json is signed and its consumers read authenticated instead of UNKNOWN
        blocked by: The 10-preset repair provenance is now archive/receipt verified (task 58b96908), but the live deployment pointer and authenticated consumer rollout remain separately unsigned/uncompleted.
    [NEWS-CONTRACT-V2] news impact taxonomy implemented under qm.news_impact_mapping.v1
        blocked by: router task 84c988e6 -- OWNER half decided 2026-08-22 (clean canonical); still gated on Q09 rerun completion
    [GOVERNOR-HARDENING] account/portfolio governor hardened AND actually enforcing
        blocked by: SP-C1 is approved and dry-run-proven at commit 593c9ddca, but its v2 monitor deploy and action adapter remain OWNER/ROT-gated and are not live
```
exit 0, elapsed 286 ms.

### 1.4 Concentration policy (sanity, runbook 1.4)

`tools/strategy_farm/config/concentration_tail_limits.v1.json` -> `"status": "OWNER_RATIFIED"`
(line 3), `"stop_risk_budget_pct": 2.5` (line 5). The DXZ builder can therefore emit
APPLY_RECOMMENDED as far as the policy gate is concerned (build_book_dxz.py:98-103).

## 2 - Rehearsal environment: the current qualified pool

Read-only census via `book_build_guard._qualified_pair_rows` (terminal gate `Q14`,
gate_manifest resolved). The 5 qualified `(EA, symbol)` pairs (exit 0, 10029 ms):

| ea_id | symbol | has sealed stream in dxz_final_20260719? |
|-------|--------|------------------------------------------|
| 10706 | GBPUSD.DWX | yes (10706_GBPUSD_DWX.jsonl) |
| 11421 | EURUSD.DWX | yes (11421_EURUSD_DWX.jsonl) |
| 11422 | USDCAD.DWX | NO |
| 13054 | XTIUSD.DWX | NO |
| 1537  | XAGUSD.DWX | NO |

Stream layout expected by the builder: `<stream_root>/QM/q08_trades/<ea>_<symbol_dots_as_underscores>.jsonl`
(portfolio_common.load_streams:274; book_builder_common.load_daily:255-276). The default bundle
`D:/QM/reports/portfolio/dxz_final_20260719` holds 24 streams, of which only 2 belong to the pool.

## 3 - Step ledger (runbook section 2, steps 5-10)

Legend: R = refused (fail-closed, correct), P = proceeded, D = defect surfaced.

### Step 5 - Build the book (dry-run analytic). Actor: Claude.

**5a. Literal runbook command (runbook 2, line 154).** `[D]`
`python tools/strategy_farm/portfolio/build_book_dxz.py --venue dxz --order-dir <scratch>`
- exit 2, 391 ms.
- Output: `build_book_dxz.py: error: unrecognized arguments: --venue dxz`.
- The DXZ builder's `parser()` (build_book_dxz.py:242-257) has no `--venue`. The runbook's
  step-5 command is not runnable as written. **Defect D1.**

**5b. Corrected DXZ command, scratch order-dir + read-only DB + scratch out-dir.** `[R]`
`python .../build_book_dxz.py --book-db D:/QM/strategy_farm/state/farm_state.sqlite --order-dir <scratch> --out-dir <scratch>`
- exit 1, 7333 ms.
- Refused, but as an UNCAUGHT `BookBuildRefused` traceback (not a structured refusal):
  `BOOK_BUILD_REFUSED: qualified_pairs_below_minimum: 5 < 25; owner_order_missing: venue=dxz order_dir=<scratch> (qualified_pairs=5, distinct_eas=5, strategy_families=5)`
- Refusing check: `book_build_guard.require_book_build_allowed` -> `raise BookBuildRefused`
  at **book_build_guard.py:228**, called at **build_book_dxz.py:262** (BEFORE the
  `try/except BookBuildError` at build_book_dxz.py:265-286). **Defect D2** (traceback vs clean refusal).

**5c. FTMO builder, scratch order-dir.** `[R]`
`python .../build_book_ftmo.py --book-db <ro> --order-dir <scratch> --out-dir <scratch>`
- exit 1, 3174 ms.
- Same uncaught `BookBuildRefused` traceback: refusing check **book_build_guard.py:228**,
  called at **build_book_ftmo.py:612** (before the try at :615-637). **Defect D2.**

**5d. White-box exercise of the DXZ analytic internals (no writes).** `[P]/[D]`
Called `build_book_dxz.build_dxz_manifest(...)` directly (CLI guard/argparse bypassed for a
logic-only exercise; no file written, no live/DB state touched). exit 0, 1248 ms.
- **A -- default July roster vs itself, default stream root:** the chain RUNS end to end.
  status `CONCENTRATION_CAP_BREACH`, 24 sleeves, common window 2019-07-23..2024-12-13 (1349 days).
  The analytic machinery is intact (Observation O1 on the status).
- **B -- current 5-pair pool roster, default stream root:**
  `BookBuildError: sealed stream basis is missing roster sleeves: 1537:XAGUSD.DWX, 11422:USDCAD.DWX, 13054:XTIUSD.DWX`
  at **book_builder_common.py:260** (via `load_daily`, build_book_dxz.py:124). The pool cannot
  be built with the existing bundle. **Defect D4.**

### Step 6 - Portfolio fit report for OWNER (q11_fit_<date>.md). Actor: Claude.

`[D]` No tool exists (gap G2). No producer references `q11_fit_` under `tools/`; no
`*fit_report*` file exists. `tools/strategy_farm/portfolio/portfolio_refit.py` is a greedy
re-fit (imports `portfolio_assemble.greedy_select`), not the OWNER-facing correlation /
ENB / marginal-Sharpe / risk-budget fit report the runbook promises. **Defect D3** (this and
step 5's roster decoupling are the same root gap). Not runnable; nothing to smoke-test.

### Step 7 - OWNER selects sleeves + weights. Actor: OWNER.

`[out of scope]` OWNER decision act; no AI-runnable command. Not rehearsable by an AI seat
(and would fabricate an OWNER decision). Recorded here only to keep the step numbering honest.

### Step 8 - Q16 Operational Readiness (11 checks). Actor: Codex + OWNER + Claude.

`[out of scope, partial]` No single runnable tool; the 11 checks are a checklist (runbook 4)
signed by OWNER, with Claude's Hard-Rule verifications (#3 SHA256, #4 magic, #5 ENV/risk,
#10 news). The deploy tool enforces the SHA256/target/schema slice of this at step 10 (below);
the manifest signing (#11) and compile (#1) are ROT/Codex acts. Not rehearsed as a unit.

### Step 9 - Stage presets at book risk. Actor: Claude.

**9. Dry-run against the scratch fixture + scratch manifest.** `[P]/[D]`
`python .../stage_tlive_presets_risk.py --presets <fixture> --manifest <scratch> --out-dir <scratch> --json <scratch>`
- First run: the diff/patch logic PROCEEDED correctly (printed `presets=5  problems=0`,
  each `RISK_PERCENT=1.000000 -> 1.95`), THEN crashed on the `--json` write with an unhandled
  `FileNotFoundError` because the `--json` parent directory did not exist. exit 1, 322 ms.
  Refusing/failing line: **stage_tlive_presets_risk.py:156** (`args.json.write_text(...)` has
  no parent `mkdir`, unlike the `--apply` path at :141). **Defect D5.**
- Clean re-run (json parent pre-created): exit 0, 204 ms; report written; `staged_presets/`
  NOT created (dry-run writes no presets -- correct); report shows the exact 2-line proof
  `["-RISK_PERCENT=1.000000", "+RISK_PERCENT=1.95"]` per sleeve. Mechanics are sound.
- `--apply` path was deliberately NOT run (it would trigger `risk_freeze.assert_live_book_mutation_allowed`
  at stage_tlive_presets_risk.py:71 and, on a real T_Live `--presets`, read live files).

### Step 10 - Deploy copy-plan (dry-run then apply). Actor: Claude (dry-run).

**10. CLI dry-run against the scratch fixture (`--live-root <fixture>`), scratch order-dir.** `[R]`
`python tools/strategy_farm/deploy_tlive_book.py --plan <scratch> --live-root <fixture> --book-db <ro> --order-dir <scratch>`
- exit 1, 2676 ms.
- Uncaught `BookBuildRefused` traceback: the deploy tool runs the book guard even for a
  dry-run, refusing check **deploy_tlive_book.py:129** (`book_guard("dxz", ...)`) ->
  **book_build_guard.py:228**. Confirms runbook 4 ("book_build_guard is required even for a
  dry-run"). **Defect D2** (traceback form; `main` has no try, deploy_tlive_book.py:191-209).

**10b. White-box dry-run via the tool's own injection seam (no writes).** `[P]`
Called `deploy_tlive_book.execute(plan, apply=False, book_guard=<no-op>)` -- `execute` exposes
`book_guard`/`guard` as injectable callables (deploy_tlive_book.py:121-122) for exactly this.
apply=False so no bytes are written and the risk_freeze guard (deploy_tlive_book.py:133) is
never reached. exit 0, 312 ms. Result: `MODE=DRY_RUN, validated_items=6, written_items=0`, all
6 source SHA-256 matched, destinations resolved under the fixture's MQL5/Presets and
MQL5/Experts/Live EAs. Fixture verified unchanged afterward (5 .set + 5 .ex5, no .tmp).
The plan validator and dry-run reporting are sound.

**10c. Negative white-box: containment guards.** `[P, guards fire]`
`deploy_tlive_book.load_and_validate_plan` on three bad plans -> all `CopyPlanError`:
- destination outside allowed parents (`MQL5/Config/evil.set`) -> refused at
  **deploy_tlive_book.py:82-86**.
- path traversal (`../../../evil.set`) -> refused at **deploy_tlive_book.py:80-81**.
- SHA-256 mismatch -> refused at **deploy_tlive_book.py:100-105**.
These are the checks that protect the real `C:/QM/mt5/T_Live` on the trigger day; they work.

### Cross-cutting: tests

`python -m pytest -q test_book_build_guard.py test_dual_book_builders.py
test_risk_freeze_prevention.py test_rebaseline_census.py` -> **64 passed, 1 skipped, 1 warning**
(exit 0, 4347 ms). The book-path tools' own suites are green; the findings below are about the
chain's decoupling and UX/robustness, not broken tool logic.

## 4 - Defects and refusals found

### Refusals (correct fail-closed behavior -- the guard chain works)

- **R1. Below-floor + no order.** book_build_guard.py:200-203 (`qualified_pairs_below_minimum`)
  and book_build_guard.py:129/:170 (`owner_order_missing`), raised at book_build_guard.py:228.
- **R2. Guard required even for a dry-run deploy.** deploy_tlive_book.py:129.
- **R3. Risk-freeze ACTIVE blocks live-book mutation.** risk_freeze.py:463-464
  (`assert_live_book_mutation_allowed`); ACTIVE confirmed by status (section 1.3). Reached only
  past the book guard, so not hit in this rehearsal, but present on both the DXZ builder
  (build_book_dxz.py:279) and the deploy apply path (deploy_tlive_book.py:133) and the stager
  apply path (stage_tlive_presets_risk.py:71).
- **R4. Deploy containment.** deploy_tlive_book.py:82-86 / :80-81 / :100-105 (verified 10c).

### Defects (would slow or surprise the trigger day)

- **D1 (doc, runbook 2 line 154).** The DXZ build command lists `--venue dxz`, which
  build_book_dxz.py does not accept (parser at build_book_dxz.py:242-257) -> argparse exit 2.
  Severity: low (the FTMO command in the same table is correct).
- **D2 (UX, both builders + deploy CLI).** The book guard (and the DXZ builder's risk_freeze
  assert) is called OUTSIDE the `try/except BookBuildError`, so a fail-closed refusal surfaces
  as a raw Python traceback with exit 1 instead of the structured JSON refusal (+exit 2) the
  tools already use for BookBuildError. Sites: build_book_dxz.py:262 vs try at :265-286;
  build_book_ftmo.py:612 vs try at :615-637; deploy_tlive_book.py:191-209 (`main` has no try),
  refusal at :129. Contrast the clean `book_build_guard.py --status` (JSON + exit 2). Severity:
  medium (an operator running step 5/10 before the order exists, or if the pool dips below 25,
  gets a stack trace rather than a legible "refused because...").
- **D3 (tool gap = G2/G8 core).** The builders build from a hand-maintained roster FILE whose
  default is the stale July 24-sleeve live manifest (build_book_dxz.py:47 DEFAULT_ROSTER,
  resolve_roster at book_builder_common.py:91-160; build_book_ftmo.py:43). That roster is
  entirely decoupled from the guard's qualified-pool census: the default roster contains only 2
  of the 5 current qualified pairs (11421/EURUSD, 10706/GBPUSD) plus 22 unrelated sleeves. The
  guard passing (>= 25) neither selects nor feeds the qualified pairs into the builder, and no
  tool emits a roster from the census. On the trigger day, `build_book_dxz.py` with defaults
  would build the July book, not the newly-qualified book. Severity: high (this is the substance
  of G8 -- the "chain has never run against the real pool").
- **D4 (missing inputs for the pool).** The sealed daily-PnL stream bundle (`--stream-root`,
  default dxz_final_20260719) covers only legacy sleeves; 3 of the 5 qualified pairs
  (1537/XAGUSD, 11422/USDCAD, 13054/XTIUSD) have no `QM/q08_trades/<ea>_<sym>.jsonl`, so
  build_dxz_manifest raises BookBuildError at book_builder_common.py:260. No wiring exists from
  the census's Q14-terminal sealed streams to a builder stream_root. Severity: high (the builder
  cannot run against the qualified pool until a matching stream bundle is assembled).
- **D5 (stager robustness).** stage_tlive_presets_risk.py:156 `args.json.write_text(...)` has no
  parent `mkdir` (the `--apply` path does, at :141), so pointing `--json` at a not-yet-existing
  directory crashes with an unhandled FileNotFoundError AFTER printing the full success report,
  exiting 1 even when problems=0. Severity: low-medium (misleading: success then crash).
- **D6 (doc vs code, runbook 1.3 lines 116-117).** The runbook states "Both book builders call
  risk_freeze.assert_live_book_mutation_allowed(...) before writing a manifest ... same in
  build_book_ftmo.py." This is FALSE: build_book_ftmo.py imports no risk_freeze (imports at
  build_book_ftmo.py:21-39) and never calls the freeze assert; its `main` (build_book_ftmo.py:610-646)
  writes the manifest with no freeze guard. Only the DXZ builder calls it (build_book_dxz.py:279).
  Both builders write to D:/QM/reports (not T_Live) and both still refuse at the book guard today,
  so this is not a live-write hole -- but it is an inconsistency in the stated safety property.
  Severity: low-medium (reconcile doc and code).

## 5 - Minimal fixes proposed (NOT implemented -- report is the deliverable)

- **D1:** In BOOK_CEREMONY_RUNBOOK_2026-09.md step 5 (line 154), drop `--venue dxz` from the DXZ
  command; the venue is implicit (build_book_dxz always guards "dxz"). One-line doc edit.
- **D2:** In each builder `main` and in deploy `main`, wrap the guard call (and the DXZ
  risk_freeze assert) so `BookBuildRefused` / `RiskFreezeBlocked` are caught and printed as the
  same structured JSON refusal the tools emit for BookBuildError, with a stable exit code (2/3).
  Roughly: `try: book_build_guard.require_book_build_allowed(...) except BookBuildRefused as e:
  print(json.dumps({"status":"BOOK_BUILD_REFUSED", ...})); return 2`. No behavior change to the
  refusal itself, only its presentation.
- **D3 + G2:** Add a `q15_fit_report.py` (Codex, ops_issue) that reads the guard's qualified rows
  (book_build_guard._qualified_pair_rows) and emits (a) a `qm.dual-book-roster/v1` roster bound to
  the census and (b) the OWNER fit report (correlation matrix, family clustering, symbol coverage,
  marginal Sharpe, ENB, risk-budget). The builders should then consume that census-bound roster
  rather than defaulting to a stale live manifest (make `--roster` required, or default it to the
  fit-report output).
- **D4:** Add a stream-bundle assembler that collects each qualified pair's sealed Q10/Q14
  daily-PnL stream into a `stream_root/QM/q08_trades/` layout the builder consumes; add a
  stream-coverage precondition to the runbook (and optionally to book_build_guard) so a pool that
  the stream bundle does not cover is surfaced before step 5 rather than as a mid-build
  BookBuildError.
- **D5:** Add `args.json.parent.mkdir(parents=True, exist_ok=True)` before
  stage_tlive_presets_risk.py:156 (and create `--out-dir` in dry-run too, or document that both
  parents must pre-exist).
- **D6:** Reconcile the safety property: either add `risk_freeze.assert_live_book_mutation_allowed`
  to build_book_ftmo.py `main` before `write_json` (symmetry with build_book_dxz.py:279), or
  correct runbook 1.3 to state that only the DXZ builder calls the freeze assert and the FTMO
  manifest is a pre-freeze analytic artifact.

## 6 - Observations (not defects in the chain)

- **O1.** Re-evaluating the current live July 24-sleeve roster against ITSELF under the now-ratified
  SP-C3 concentration policy returns `CONCENTRATION_CAP_BREACH` (step 5d/A). This means the trigger
  day's concentration cap is a live constraint the eventual >= 25 book must satisfy, and it is worth
  confirming whether the current deployed book would itself pass the ratified caps if rebuilt.
  Outside G8 scope; flagged for the Q15/Q16 owners.
- **O2.** The end-to-end conclusion of this rehearsal: the tooling's fail-closed gates and
  containment guards WORK (R1-R4, tests green), but the chain cannot yet run against the qualified
  pool for two structural reasons that are independent of reaching 25 pairs: no census-bound roster
  generator (D3) and no pool-covering stream bundle (D4). Reaching `qualified_pairs >= 25` is
  necessary but not sufficient; D3 and D4 must be closed before step 5 can produce a real book.

## 7 - Hard-limits compliance

No commit, no push, no farm-DB write (all DB reads via mode=ro), no enqueue/hold/restart, no write
under C:/QM/mt5/T_Live (a self-authored scratch fixture was used), no write under
C:/QM/repo/decisions/ (a scratch `--order-dir` was used), no risk-freeze lift, no gate-criteria /
verdict-logic / dxz23_execution_contracts.json / live-deployment-pointer touch, no OWNER order
fabricated. All work inside the worktree; the only worktree file written is this report.
`git status --short framework/calibrations/` is empty.
