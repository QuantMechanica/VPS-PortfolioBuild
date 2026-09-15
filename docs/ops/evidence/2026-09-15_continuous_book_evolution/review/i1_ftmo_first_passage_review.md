# Adversarial review — slice `i1_ftmo_first_passage`

Reviewer: Claude (adversarial). Date: 2026-09-15. Verdict: **ACCEPT_WITH_FIXES**.
Patch: `.../scratchpad/patches_d3/i1_ftmo_first_passage.patch` (1619 lines, 7 files).
Repo HEAD at review: `1617cb22be689974139272d8dc8afe8d2617fb4a`.
Reviewed code = implementer worktree `C:/QM/repo/.claude/worktrees/wf_717b9d36-ba6-7`
(worktree HEAD == main HEAD; `git diff --stat` matches the patch exactly).

## Scope confirmed against the task (directive §34 / §43 item I)

Delivered and verified:
- New engine `tools/strategy_farm/ftmo/first_passage.py` (schema `qm.ftmo-first-passage/v1`):
  seeded calendar-aligned block-bootstrap first-passage walk over per-sleeve daily
  PnL streams scaled to each sleeve's `risk_pct`; official parameters read only from
  the bound rulepack (never hardcoded); P(target hit), P(daily-loss), P(max-loss),
  censoring, time-to-target p10/p50/p90/mean, calendar-day pass marks, cost/slippage
  sensitivity (shared bootstrap indices), and conditional failure modes
  (sleeve/symbol/weekday). Frozen manifest `qm.ftmo-first-passage-manifest/v1`.
- Wiring: `ftmo_fitness.compute_ftmo_fitness` challenge_survival enrichment;
  `challenge_readiness.build_readiness` auto-loads the read-model into
  `simulations.first_passage`; living-doc section added.
- Tests (`test_ftmo_first_passage.py`, 15) + regression on the wired files.
- RUN FOR REAL on the `demo_8` W38 roster; honest low-pass finding reported.

## Realness / determinism / honesty — PASS

- **Deterministic (independently reproduced).** Re-ran the engine read-only from the
  sealed W38 manifest (`snapshot_r2/manifest.json`) → headline reproduced
  byte-for-byte: `p_target_hit 0.8163`, `p_daily 0.0`, `p_max 0.0244`,
  `p_censored 0.1593`, `median 439.0`, matching `D:/QM/reports/state/ftmo_first_passage.json`.
- **Honest numbers.** Every headline figure in the report and the living doc matches
  the read-model (0.816/0.971/0.024/0.159; p10/p50/p90 184/439/818; 30d 0.0 …
  252d 0.0785; breach shares 10706:GBPUSD 0.4672, USDCAD 0.209, EURUSD 0.1393;
  Fri 0.4221; cost sweep 0.8163→0.7746). Probabilities close: 0.8163+0.1593+0.0244=1.0.
- **EVIDENCE_MISSING preserved.** `dropped_sleeves: []` here (all 8 resolved), but the
  missing-roster degrade path is real and tested (`test_missing_roster_degrades_not_invents`);
  `load_for_readiness` returns None → readiness stays EVIDENCE_MISSING when absent.
- **Streams sha-pinned.** Each sleeve carries a real `stream_sha256`, verified against
  the recompose manifest (mismatch drops the sleeve). `manifest_git_commit` and
  `input_manifest_sha256 27f6f631…` present.
- **Conservative approximation labelled.** Per-trade-MAE intraday-low proxy (not
  tick-exact MTM) is disclosed in the read-model `label`/`method`, the doc, and the
  report; `ftmo_complete_mtm_evidence` go-criterion correctly left OPEN.
- Tests: `test_ftmo_first_passage.py` 15 passed; `test_ftmo_fitness.py` +
  `test_ftmo_challenge_readiness.py` + `test_ftmo_no_purchase_guard.py` +
  `test_ftmo_evaluator_fidelity.py` 26 passed. No regression.

## RED-boundary sweep — CLEAN

- **No verdict-semantics change.** `ftmo_fitness` challenge_survival `status`
  (PASS/MARGINAL/FAIL) is still computed solely from admitted_pairs + best_fund_score
  vs floor; the patch only adds informational `first_passage` keys to the axis value.
  `overall_verdict` untouched. `fp` is optional (`snapshot.get`), absent-safe.
- **No economic-threshold change** (no §30 counterfactual needed): thresholds all read
  from the rulepack; none redefined.
- **`ftmo_rule_contract.load_two_step_contract` widening — verified benign.** Now
  accepts `FTMO_2S_100K_STANDARD_V2` alongside SWING. I compared the *projected*
  contract fields from both packs via the loader: `initial_equity, target_fraction,
  daily/total_loss_fraction, min_trading_days, timezone, breach/target_operator,
  maximum_loss_model` are **identical**. The packs do differ in news/weekend/leverage
  rules, but those are not projected by the two-step contract and are unused by any
  two-step evaluator path. Fidelity tests still pass. No numeric impact on the 8
  existing callers (each passes its own path; widening only loosens the accept gate).
- **No** T_Live / AutoTrading / purchase / live-deploy / terminal-start /
  farm-DB / sqlite writes. Engine writes two read-models + regenerates the living doc
  only (verified by grep of all changed files). No-purchase guard passes.
- **No** sealed-artifact or dated-decision in-place edits; **no** secrets; **no**
  provider-grant changes; **no** scheduler change (cadence correctly left for the
  orchestrator, flagged as a RED boundary in the report — honest deferral).
- **No** recovery/queue/claim logic touched (nothing scheduler- or claim-adjacent).

## `git apply --check` — applies clean against committed HEAD

- Full-patch `git apply --check` **fails on `docs/ops/FTMO_CHALLENGE_READINESS.md`**.
- Root cause verified: NOT a real conflict against HEAD. The patch's base blob for
  that file (`8c8bcbb80c…`, timestamp 2026-09-15T15:32:47Z) is **byte-identical to the
  committed HEAD blob** (`git rev-parse HEAD:…` = `8c8bcbb80c…`). The apply failure is
  solely because the *working tree* carries an uncommitted regeneration of this
  machine-generated living doc (timestamp 17:52:01Z, `M` in `git status`).
- `git apply --check --exclude=docs/ops/FTMO_CHALLENGE_READINESS.md` → **OK** (all six
  code/report files apply cleanly).

## Findings

### Blocking (apply-time mechanical only — no implementer rework)
1. **Whole-patch apply fails on the living doc due to uncommitted working-tree drift.**
   Before applying, the orchestrator must either `git checkout -- docs/ops/FTMO_CHALLENGE_READINESS.md`
   (discard the ungoverned working-tree regen) and then apply the full patch, OR apply
   code-only and regenerate the doc via `python tools/strategy_farm/ftmo/challenge_readiness.py build`.
   The patch itself is correct; this is not a defect in the reviewed work.

### Major
- None. (The rule-contract widening was the only candidate; verified benign above.)

### Minor
1. `ftmo_rule_contract` now silently binds `STANDARD` for any caller. Projected fields
   are identical today, but the STANDARD pack additionally restricts news/weekend
   trading; if a future two-step evaluator ever starts projecting those, the widened
   accept-gate would let both packs through with divergent semantics. Consider a
   comment/assert pinning the identical-projected-fields invariant (a test asserting
   the two loaders agree would lock it).
2. `generated_at_utc` uses wall-clock `now()`, so the read-model timestamp changes on
   every run while substantive content + `input_manifest_sha256` stay stable. Fine as
   metadata, but means the file is not byte-identical across reruns (content is).
3. Calendar-day pass marks (e.g. "252 cal-days") are mapped to business days via 5/7
   and could be misread as trading-day counts; the `horizon_note` explains this, so
   low risk — keep the note prominent in any OWNER-facing summary.

## Bottom line

The engine is real, deterministic (independently reproduced), honest, and RED-clean;
wiring is enrichment-only with no verdict or threshold change; the rulepack widening is
verified benign. The single blocking item is a mechanical apply-time step (the living
doc regenerated in the working tree), not a flaw in the patch, which applies cleanly
against committed HEAD. Accept once the orchestrator handles the living-doc drift at
apply time and regenerates the doc.
