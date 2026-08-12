# Factory Adaptation — Optimization Track Q14–Q16 + Dual Books (implementation plan)

Decision: `decisions/2026-08-12_DL-084_optimization_track_q14_q16_dual_book.md`.
Program: `docs/research/SURVIVOR_OPTIMIZATION_PROGRAM_2026-08-12.md` v1.1.
Goal state: **two hash-bound book manifests (DXZ + FTMO) built from the optimized
survivor cohort, parked for OWNER application ceremonies.**

## A. Component inventory (what changes, what is reused)

| # | Component | Change | Reuse |
|---|---|---|---|
| A1 | `tools/strategy_farm/config/gate_manifest.v1.json` → **v2** | add Q14/Q15/Q16 entries, widen `canonical_id_pattern` to `^Q(?:0[0-9]|1[0-6])$`, bump `pipeline_version`; document Q11 venue lanes + the Q10→Q14 fork | versioned manifest + `gate_manifest.py` validation (Task #9 machinery) |
| A2 | `phase_ids.py` / cockpit / dashboards | new phases flow automatically from the manifest; add optimization-track panel + dual-book status chips; fix the `LIFETIME (MIXED ERAS)` labeling (ticket 00db5c53 merges here) | `phase_label()` single source |
| A3 | `farmctl.py` | Q14/Q15/Q16 in phase nomenclature; new canonical verdicts (`OPT_ELIGIBLE`, `OPT_REJECTED`, `CHALLENGER_SPAWNED`, `PROMOTE_CHALLENGER`, `KEEP_INCUMBENT`, `ADMIT_BOTH`); dependency roles (Q16 child requires challenger-Q10-PASS + parent-lineage refs); enqueue paths `enqueue-opt-admission`, `enqueue-head-to-head`; opt-card payload contract | CANONICAL_PARENT_CHILD_VERDICTS pattern, work_item_dependencies (Q09-pair precedent), dispatch lane (per-invocation reload) |
| A4 | `framework/scripts/q14_opt_admission.py` (new) | deterministic eligibility from the census + program config (`opt_program.v1.json`: levers, per-lever pre-filters, cohort freeze list); writes opt-cards + opens trial ledger | census SQL (dual-forensics), `ea_metrics` |
| A5 | Q15 = build-lane SOP, not a runner | opt-card → `build_ea` router ticket (new EA identity, magic/registry serial discipline); DEV-window sweep via existing Q03 runner under opt contract; freeze validator (`q15_freeze_check.py`): thresholds frozen, default-OFF equivalence smoke, unwired-input grep; then standard Q02 enqueue for the challenger | build lane, Q03 runner, `run_smoke`, `review_ea`, gen_setfile |
| A6 | `framework/scripts/q16_head_to_head.py` (new) | sealed common-OOS incumbent-beat (anchored Q04 folds + post-DEV holdout, real venue costs), no-change control, DL-082/083 marginal math at book level | Q04 runner outputs, INVVOL evaluator + daily-returns extraction, DL-083 thresholds |
| A7 | `tools/strategy_farm/portfolio/build_book_dxz.py` (new wrapper) | Q11_DXZ lane: capped inverse-vol + WS-2 cluster overlay + incumbent gate ("apply only if not worse") → `D:/QM/reports/portfolio/book_dxz_<date>/manifest.json` + evidence | INVVOL stage tooling (Task #17), regime-split corr code |
| A8 | `tools/strategy_farm/portfolio/build_book_ftmo.py` (new wrapper) | Q11_FTMO lane: FUND_SCORE per sleeve, book bootstrap LB P(P1)≥0.80, density constraints, 1 EA/symbol, FTMO venue cost/swap model → `book_ftmo_<date>/manifest.json` | FTMO M1 bootstrap tooling (ae5331f67), venue_cost_model.json, FTMO swap snapshot 7eab3bf8 |
| A9 | Trial-ledger store | per-opt-card JSON ledger under `D:/QM/reports/opt_track/<card_id>/trial_ledger.json`; Q07/Q08 runners for challenger lineages read the declared trial count (deflation input) | Q08 DSR/PBO plumbing |
| A10 | `terminal_worker.py` | expected: **no change** (challenger cascades are ordinary work items; Q14/Q16 run in the dispatch/analytic lane, not on terminals). If review finds any worker-visible change → OFF/ON activation window required | claim machinery, symbol cap |

## B. Execution phases

**B1 — Build & review (now → ~15.08).** Four Codex tickets (below) + Claude reviews
(builder≠approver). Manifest v2 ships read-inert: defining Q14–Q16 creates zero work
items; existing phases behave identically (regression tests assert this).

**B2 — Activation.** If A10 stays no-change: no OFF/ON needed — dispatch-lane
processes load fresh per invocation. Otherwise: standard ceremony (OFF → mint under
standing unlimited prep → ON). First `q14_opt_admission` run = program activation:
freezes cohort v1, writes opt-cards.

**B3 — Challenger wave 1 (staggered, ~15.08 → ~22.08).** Priority order from the
census + critiques: (1) WS-3 exit-surgery cards (6 high-DD sleeves, MAE-gated);
(2) WS-6 locked ports (pre-registered carrier lists; gated on host-gate
genericization ticket 9ad6d9c0); (3) WS-4 vol-regime profiles (5 eligible sleeves);
(4) MTF tuples only if capacity remains. Builds serial (magic-resolver discipline);
challenger cascades ride the T1–T10 factory (backtests never throttled; symbol cap 4
absorbs the XAU-heavy cohort).

**B4 — Q16 head-to-heads (rolling).** Each challenger reaching Q10 gets its sealed
comparison immediately (no barrier on the cohort).

**B5 — Books (cutoff-driven).** All-terminal OR cutoff (14 days after last Q15
spawn) → `build_book_dxz` + `build_book_ftmo` → manifests + evidence docs →
**OWNER ceremonies** (DXZ apply window; FTMO manifest parked fail-closed unless
LB P(P1)≥0.80). WS-1/WS-2 outputs (requalified sleeves, correlation overlay) feed the
same builders regardless of optimization outcomes — the books do not depend on
optimization succeeding; PROMOTE/ADMIT_BOTH verdicts simply improve the input set.

## C. Router tickets (Codex lane, quota fresh)

| Ticket | Scope | Effort/prio |
|---|---|---|
| OPT-1 | A1 manifest v2 + A2 surfaces + A3 farmctl wiring + regression tests (existing-phase behavior byte-identical; new phases inert) | max / 82 |
| OPT-2 | A4 Q14 admission runner + opt-card schema + A9 trial-ledger store + `opt_program.v1.json` config + tests | max / 78 |
| OPT-3 | A6 Q16 head-to-head evaluator + no-change control + DL-082/083 marginal integration + tests (fixtures from exit-surgery precedent data) | max / 76 |
| OPT-4 | A7+A8 dual book builders + manifest schema + evidence templates + tests (dry-run against the current 24-sleeve roster) | max / 74 |

Q15 SOP + freeze validator: Claude build lane (small, rides existing build_ea
machinery). Host-gate genericization: existing ticket 9ad6d9c0 (prio raised — WS-6
prerequisite).

## D. Risks / fail-closed points

- **Scope creep in gates**: Q14–Q16 add zero discretion — all contracts are
  pre-registered artifacts; a missing opt-card field is a hard reject.
- **Trial-budget explosion**: the ledger is the throttle; `opt_program.v1.json` caps
  concurrent opt-cards (start: ≤12) and cards per parent (≤2).
- **Factory load**: challenger cascades compete with WS-1 requeues — priority
  classes keep the news-backfill chain (ticket 3260d15d, prio 95) untouchable.
- **FTMO bar**: if no sleeve/book clears LB≥0.80, the FTMO manifest still gets
  built + parked with the measured gap — "book stands" = manifest + evidence, the
  challenge decision remains OWNER's at the bar (doctrine unchanged).
- **Numbering collision**: Q14 was once a display stray (purged in the Task-#9
  taxonomy cleanup); manifest v2 re-introduces it deliberately — the vault
  `03 Pipeline/` gets matching pages (Q14–Q16) at activation so vault and manifest
  stay in lockstep.
