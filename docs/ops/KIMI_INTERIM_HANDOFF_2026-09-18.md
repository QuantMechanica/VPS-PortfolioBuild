# KIMI INTERIM HANDOFF — 2026-09-18

**Owner of this file:** Kimi (interim Quant Research + Strategy Engineering lead, OWNER_DIRECT_SESSION_DELEGATION, started 2026-09-15).
**Purpose:** continuity contract for Fable/Claude on return. Keep current.
**Last update:** 2026-09-15 ~23:30 UTC.

## Current branch / HEAD

- Main repo `C:\QM\repo`: branch `agents/board-advisor`, HEAD `c9dcd9b5fa` (watchdog NO_RUNNABLE_WORK fix), **pushed to origin, divergence 0** (2026-09-16 ~04:40Z).
- Remaining dirty files are pre-existing unknown-owner items (`.set` file, `ea_origin.v1.csv` line-endings, deleted `artifacts/qm5_41262_build_result_20260901.json`, machine regen drift recurring on the living docs — normal cadence). Not mine, not touched.

## Directive-3 worktree state — **WAVE 1 MERGED INTO MAIN 2026-09-15** 

Merge executed by Kimi interim per §38/§39/§40 (reviews on disk = independent Claude adversarial passes; all test suites re-verified; zero merge-caused regressions — proof in receipt). Full plan: `docs/ops/evidence/2026-09-15_directive3_wave1_merge_map.md` · execution receipt: `docs/ops/evidence/2026-09-15_directive3_wave1_merge/receipt.md`.

- Merged (cherry-picked `-x` from checkpoint commits): ba6-1 a1 AI capacity `5f20a0532f` · ba6-6 h1 live sleeve PnL `484d3f0228` · ba6-4 e1 second-chance `a6752e7254` · ba6-7 i1 FTMO first-passage `f35f303e4a` (+ readiness doc regenerated `167174f837` per review blocking fix) · ba6-3 d1 eligibility v2 `9cad21ef11` · ba6-5 g1 resource scheduler `4eb4058012` · ba6-8 j1 pattern catalog `0b2a5a6b63`.
- Conflicts resolved: book_evolution_runner keep-both (ai_capacity + live_sleeve_attribution state builds); strategy_wiki_sync keep-both (second_chance + live_pnl joins; one mis-resolution caught by tests and fixed, 27/27 green).
- **ba6-2 (b1 AI benchmark) deliberately NOT merged** — decision gate: unreviewed, no design report. Worktree checkpointed `8d203c053e`; evidence verified real (scorecard at `D:\QM\reports\state\ai_capability_scorecard.json` matches its doc). Recommendation: Fable completes it (write b1 design report + one adversarial review pass, focus: providers.py spawn guards + benchmark_code shell fencing), then merge. Abandonment also defensible.
- Slice worktrees still on disk with checkpoint commits; fanout temp JSONs in `%TEMP%\1\claude\...` may be wiped on reboot — everything essential is now committed.
- **OPEN tracked fixes from the reviews (for Fable):** j1 census-join contaminated baseline (fix `load_census_join` strict arm + re-run before citing figures; the "0 filters ever selected" headline is verified independent of the defect) · g1 STEP-2 calibrated RAM table 4→8 GB census doubling (default-off; pin before activation) · d1 residual grid guard at `governed_magic_allocator.py:374` (known; fail-closed) · e1 OOS-window caveat must travel with any second-chance enqueue.
- **No Wave 2 was ever defined for Directive 3** — orchestrator session died on Claude weekly limit. §43 order A–J residuals ready to commission: c1 routing, e2, f1/f2 tail-risk engine (prerequisite: merged eligibility v2 + tail-risk research doc, both now on main).

## Factory state — IDLE ROOT-CAUSED 2026-09-16 ~04:30Z

**Classification: NO_RUNNABLE_WORK** (not a scheduler/lock fault). Chain of evidence:
- 0 active work items; 10/10 workers alive and cycling claims every ~12s; last successful claim 01:51Z.
- The canonical selector (`farmctl.pending_claim_order_sql()`, verified by executing it) returns **22 rows**: 21 Q08 + 1 Q06. Of 3,794 raw pending: 2,555 PRESCREEN_SKIPPED OPT_CENSUS (inert by design), 225 superseded, ~86 governed-analytic/Q12 matrix declarations, 22 quarantined, rest held.
- All 21 Q08 rows fail the claim-time-independent DSR precheck: `SINGLE_CONFIGURATION_UNAVAILABLE:EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED` — their cards lack the `qm-dsr-single-configuration` declaration block (a governance-sealed card amendment, NOT an ops fix). This is the Q08_DSR_CONTEXT_UNAVAILABLE class the Phase-A audit assigned to Fable.
- The 1 Q06 row is RAM-class-skipped (37.9 GB measured reservation vs 14 GB threshold, 45 GB free) — legitimate guard.
- The watchdog had been FALSE-classifying this as dispatch_stall every 10 min and flapping FactoryON_AtLogon (rc=1, itself failing) + parking workers 5 min of every 10. **FIXED** `c9dcd9b5fa`: watchdog now counts canonically-claimable rows (`claimable` + `no_runnable_work` fields in factory_watchdog.jsonl every 15 min = the §12I deterministic idle signal) and only heals a stall when ≥3 claimable rows exist. Static tests 4/4 + PS syntax verified.

**Recovery actions taken / in flight:**
- `c9dcd9b5fa` watchdog classification fix (committed + pushed).
- Background agent (agent-10) servicing the 86 pending Q12-analytic DL-089 declarations via canonical `farmctl service-dl089-matrix` → expands frontier cells into runnable census work (the Phase-A-recommended Q12 prioritization for the 51 Q11-frontier pairs).
- Second-chance QM5_11563: gemini lane produced a REVIEW_READY card draft (PENDING_B0EF5D66 in cards_review); next step = controller/Codex allocation — quota-gated to 09-19.

**Remaining blocked classes (governance-gated, documented for Fable):** Q08 DSR single-configuration declarations (21 rows) · COMPILE_EA/build lane (codex quota to 09-19 + repo-dirty guard stragglers: `.set` file, `ea_origin.v1.csv` line-endings, deleted artifact JSON — unknown-owner) · NEWS-lane work (E1-C OWNER decision) · Q09 news rows need bound run plans.

## Research programmes launched 2026-09-16 (all REVIEW_PENDING / staged for Fable)

- **TAIL_RISK — DONE + committed `56e930f728`**: `docs/research/TAIL_RISK_PROGRAMME_2026-09-16.md` + `tools/strategy_farm/config/tail_risk_families.v1.json` (16/16 schema tests). Four bounded families (A positive pyramid, B negative pyramid, C bounded martingale 4-level with written terminal failure condition, D bounded grid/recovery) with deterministic risk contracts sized inside ratified budgets, stress matrix s01–s08, and a 12-step joint-tail protocol (λ_L, worst-day overlap vs seed-pinned permutations, correlation convergence, margin escalation; Gaussian copula baseline-only). Thresholds marked PROPOSED_PENDING_OWNER_RATIFICATION; slots into Directive-3 f1/f2 engine for Fable; aggressive multi-sleeve books stay EVIDENCE_MISSING for diversification until then.
- **PATTERN_FILTER ablation — DONE + committed `bdb8aec85d`**: 11 bases (10 qualified + H-CW conditional), exactly one predicate each, 3 arms with mandatory NO_FILTER null, BH FDR, kill criteria, 22 declared direction-trials for Q16 deflation. Key semantic finding: `QM_PatternProfileMode` is blacklist-only → all hypotheses are adverse-condition blacklist entries. Q12 stays ROT; commissioning = Fable signed decision (programme notes a code fact: each trial currently runs as a full 1,085-cell sealed census; reduced plan needs a code change — recommendation: run ABL-001 full first). Open questions for Fable in design §7 (incl. ABL-008 base REVIEW_REQUIRED news flag, Balke fresh-program-id constraint).
- **SECOND_CHANCE continuation — DONE + committed `3c8e4901be`**: all four verified — 10648/1354 rejections are G0 card-form R1 fails (superseded under Eligibility V2 §5/§16), 0 clone edges; **provenance minted as draft: QM-RESEARCH-2026-0003←10648, 0004←1354** (ledger-appended, verify passes except LEDGER_STATUS_BAD:draft by design). **9576 STOOD DOWN** (normal pipeline advanced it: Q08 NDX ff0b551b pending — a second-chance path would duplicate). **1355 stood down as observation** (Q10_NEWS dbd984be pending, pipeline owns it). Top-25 ranked expansion shortlist at `docs/research/SECOND_CHANCE_SHORTLIST_2026-09-16.md` (leaders: 11211/11855 SCALPING wave-2, 11650, 11373 MULTI_POSITION, 34002 energy stat-arb, 1280 Chan OU; PYRAMIDING trio parked pending bounded-risk contract; 409 HISTORICAL_POLICY stay §30-bound).
- **EA id-collision avoided**: agents self-allocated research ids from the authoritative ledger — H-MR took QM-RESEARCH-2026-0006, FXMR took 0005 (0003/0004 taken by second-chance mints). EA ids 41476 (H-MR) / 41477 (FXMR) / 41478 (10911 sibling attempt) as planned.
- **H-FXMR (QM5_41477) — BUILD COMPLETE + ALLOCATED, REVIEW_PENDING**: branch `agents/kimi-fxmr-20260916` @ `ea38197cc0` (card+prereg cherry-picked `5a58fdf883`). Provenance QM-RESEARCH-2026-0005, prereg sha `c408f534…7475`. Compile 0/0, ex5 sha `4e07143a…1219b` (uncommitted per EX5_COMMIT_GUARD), 6 setfiles, 21/21 tests, lint clean. Prescreen REJECTs on `MISSING_FIELD:critic.*` only — the fail-closed critic gate validated end-to-end. Magic allocated `6275bfa234` (414770000/1/2).
- **H-MR (QM5_41476) — BUILD COMPLETE + ALLOCATED, REVIEW_PENDING**: branch `agents/kimi-hmr-20260916` @ `04f10839b2` (card+prereg cherry-picked `c711bf359c`). Provenance QM-RESEARCH-2026-0006, prereg sha `8129b0fc…0d2d`. Compile 0/0 (canonical build_check PASS), ex5 sha `89d1107a…a702` (uncommitted per EX5_COMMIT_GUARD), 6 setfiles, 21/21 tests. Includes an honest deterministic pilot (Dukascopy 2018-2020: 2.9 trades/mo, +0.02R — labeled PILOT_MOTIVATION_NOT_PROOF, below the preregistered bar). Prescreen: critic-pending + one analyzed NEAR_DUPLICATE false-positive vs QM5_10140 (reversion vs continuation thesis, bigram collision). Magic allocated `6e876184f2` (414760000/1/2).

## Interim scoreboard 2026-09-16 ~08:00Z (all pushed)

**Three complete FTMO-class strategies, all REVIEW_PENDING, all magic-allocated:**
| Strategy | EA id | Magic | Provenance | Branch |
|---|---|---|---|---|
| H-CW cash-window index continuation H1 | QM5_41475 | 414750000-2 | QM-RESEARCH-2026-0002 | agents/kimi-hcw-20260915 @ 86e166f26f |
| H-FXMR FX session mean reversion M15 | QM5_41477 | 414770000-2 | QM-RESEARCH-2026-0005 | agents/kimi-fxmr-20260916 @ ea38197cc0 |
| H-MR cash-open mean reversion H1 | QM5_41476 | 414760000-2 | QM-RESEARCH-2026-0006 | agents/kimi-hmr-20260916 @ 04f10839b2 |

**Programmes committed on main**: TAIL_RISK families A-D + joint-tail protocol (`56e930f728`) · PATTERN ablation 11 bases (`bdb8aec85d`) · SECOND_CHANCE top-25 + draft provenance 0003/0004 (`3c8e4901be`) · Q12 queue disposition (`8ef7244fe4`) · 10911 sibling staging + OWNER recipe (`e18e5f3f5c`).

**Single remaining gate for all three strategies**: independent non-Kimi critic (claude ≥09-17, codex ≥09-19) → then Q00 governance decision → governed COMPILE_EA (stamps build_hash) → smoke → pipeline. Nothing else is mine to advance.
- **10911/GDAXI `_opt` sibling — STAGED, stopped at OWNER seal** (`e18e5f3f5c`): agent-16 completed everything mechanical and verified it against the canonical service code — sibling source (verified 7-hunk transform from the approved 41321 template), GDAXI H1 setfile with `qm_ea_id` + neutral `opt_pp_*` keys, `_pattern_measurement_readiness ready=True zero blockers`, build guardrails PASS, allocation proven card-gated by dry-run. It STOPPED at `g0_status: APPROVED` (OWNER-only per 01-ea-lifecycle/13-strategy-research). **Exact 5-step recipe** in the receipt: OWNER seals the DRAFT card → operator runs allocator → promote staged artifacts → build lane COMPILE_EA (codex 09-19) → central operator re-runs service dry (refusal must flip) + `--apply` on row 96239586. Same pattern needed for 11294/GDAXI and 20086/NDX (card amendments GDAXI→41347 / NDX→41343).
- **Q12 DL-089 matrix queue DISPOSITIONED** (`8ef7244fe4`, dry-run over all 106 rows via canonical service): 0 serviceable by design — 82 byte-identical re-declarations of completed programs (correct dedup), 15 hold-blocked, **9 = the true frontier: 10911+11294 GDAXI and 20086 NDX lack approved `_opt` siblings**. Fable unblock paths: sealed card amendments (GDAXI→QM5_41347, NDX→QM5_41343), OWNER release of RAM_WINDOW_44GB, bulk-supersede of the 82 duplicates. Agent-16 attempting the mechanical part of the 10911 GDAXI sibling (ea_id 41478) with stop-on-governance boundaries.

## Completed work (Kimi interim)

0. **Factory idle root-cause + watchdog fix + safe push** (above; branch pushed to origin, divergence 0).

1. Full collision/truth audit (4 subagent passes).
2. P5 scheduled-task run-as repair — `db4bd1fa83`, receipt `docs/ops/evidence/2026-09-15_scheduled_task_runas_repair/receipt.md` (wiki-sync GREEN, KimiOrchestration rc=0, BookEvolution readmodels rc=0; weekly ceremony first live firing **Fri 2026-09-18 23:15 local**).
3. **Directive-3 Wave-1 merge** (above).
4. P2 second-chance Wave-1 commission: QM5_11563 retest task `b0ef5d66` (gemini lane IN_PROGRESS; receipt `docs/ops/evidence/2026-09-15_second_chance_wave1/`).
5. News-calendar REFUSED root-caused + repair **prepared not applied** (`docs/ops/evidence/2026-09-15_news_calendar_repin_repair/` — guarded applier + 38-field verified patch; needs OWNER/Fable hand per "kein AI-Commit").
6. Design-2 reuse assessment (shell reusable today; checklist delivered to H-CW implementer).

## New Strategy Cards

- **QM5_41475_cash-window-index-continuation-h1** (H-CW) — `artifacts/cards_approved/QM5_41475_cash-window-index-continuation-h1.md`, house format, provenance QM-RESEARCH-2026-0002, deterministic risk contract, prescreen **KEEP** (0 reasons). **Preregistered:** `strategy-seeds/sources/QM-RESEARCH-2026-0002/preregistration.json` v1, record_sha256 `cd661891…54322e`, spec=H_CW_card.md (`--check` unchanged).

## New EAs implemented

- **QM5_41475_cash-window-index-continuation-h1** — worktree `C:\QM\worktrees\kimi-hcw-60915` (branch `agents/kimi-hcw-20260915`), commits `807038391e` (card+prereg) → `1c1896ed23` (EA+setfiles) → `b053b3670b` (receipt) → `b18a46b5cf` (fixes). V5 skeleton + EA-dir module `QM41475_CashWindowCore.mqh`; UTC sessions via QM_DSTAware (13–17 entry / 20 flatten / Fri 17 cutoff); closed-bar breakout of first N session bars + EMA confirm; ATR stop 1.0×; TP 1.75R; 6-bar time stop; shock/spread-median/fail-closed-news/daily −1%/weekly −2%/one-entry-per-day filters; **Design-2 `QM_ChartPanelCompare` panel integrated** (tester-bypassed); SPEC.md + visualization_spec.md. **Compile: 0 errors 0 warnings** (MetaEditor vs staged include tree; log in evidence). 21 allocator/precheck/resolver tests pass.
- **STATUS = REVIEW_PENDING.** ~~Blocked at magic allocation~~ **ALLOCATION UNBLOCKED 2026-09-15 ~23:45Z**: card+prereg cherry-picked to main (`c062742682`), governed allocator run from the canonical worktree (`--repo C:/QM/repo`, default — sees the on-disk 11924/11941 dirs), committed `57d48627e4` (magic **414750000/414750001/414750002** = NDX/GDAXI/SP500 slots 0/1/2; 21/21 allocator verification tests pass). The orphan-dir inconsistency (11924/11941 gitignored docs-only skeletons vs active registry rows) remains for Fable to settle properly.
- Final branch state `agents/kimi-hcw-20260915` @ `86e166f26f`: all 6 setfiles canonically generated (build_hash `pending` = correct pre-compile value; real hash is stamped by the governed COMPILE_EA lane), `.ex5` rebuilt against the new resolver (0 errors/0 warnings, sha `99126310…60461`, uncommitted per EX5_COMMIT_GUARD), 21/21 tests, lint clean. Smoke: skipped (farm-reservation gate writes factory state = outside delegation; T6/T8 reserved by other smoke jobs) — recorded acceptance rule: governed smoke on NDX.DWX, ≥1 trade or documented zero-trade reason.
- **Integration note for Fable:** the H-CW branch merged ONLY the allocation commit `57d48627e4`, not full main (full merge surfaces Q14–Q16 factory-file replay add/add conflicts between lineages — agent-4 reset that attempt, documented in its receipt). When promoting the EA later: merge EA dir `framework/EAs/QM5_41475_cash-window-index-continuation-h1/` + SPEC/visualization_spec + setfiles; take main's side for everything else.
- Evidence: `docs/ops/evidence/2026-09-15_kimi_hcw/RECEIPT.md`.

## Factory work enqueued

- Second-chance Wave-1: QM5_11563 retest, agent task `b0ef5d66`, gemini lane IN_PROGRESS (20:52Z). Note its terminal history = Q08 INVALID ×2 (DSR-context class) — may stall on the Q08_DSR hold class; disposition is Fable's.
- Nothing else enqueued by me. Factory at audit: 2 active Q07 backtests, build lane stalled (codex hold to 09-19 + repo-dirty guard now PARTIALLY relieved — Wave-1 merge removed ~30 dirty files; the guard's remaining blockers are the unknown-owner stragglers above).

## Research findings

- H-CW motivation: farm's own evidence shows 9/10 index intraday/scalp Q10 rows PASS; universe map high-density FTMO-fit = 1.05% of pairs; top white space = intraday × session-open × index (EV 34, n=0). H-CW is the momentum-side candidate; a session-open mean-reversion complement remains unwritten white space.
- EDGE-2/4/5 all REFUTED/DEAD (pre-session commits). FTMO NOT_READY (−10.26% realized DD breach history); current 8-sleeve swing demo unrepresentative.
- Second-chance register (now merged tooling): 1,285 records → 542 eligible; only 60 have any metrics; Wave-1 = QM5_11563 commissioned.

## Design-2 visual standard

Inspection complete (agent-6): shell reusable today — include `QM_ChartPanelCompare.mqh` + 13-arg Initialize + EA-local snapshot builder (~100–150 lines mirroring real trading gates). QM5_41475 is the second adopter. No generic presenter extension point yet (by design). Reword `QM_ChartPanelCompare.mqh:10-11` canary comment when Fable accepts the pattern.

## Tests / evidence

- Wave-1 merge: per-slice suites + 88/88 d1/e1/g1/j1 + 41/41 ftmo/book-evolution + 27/27 wiki-sync — all green on merged main; 11 failures in the touched-module sweep proven byte-identical at pre-merge base (pre-existing noise).
- Receipts: `2026-09-15_scheduled_task_runas_repair/` · `2026-09-15_directive3_wave1_merge/` (+ merge_map.md) · `2026-09-15_second_chance_wave1/` · `2026-09-15_news_calendar_repin_repair/` · `2026-09-15_kimi_hcw/`.

## Open blockers

1. ~~H-CW magic allocation~~ RESOLVED (see New EAs). Remaining H-CW items: independent non-Kimi critique (codex earliest 09-19) → then Q00 governance decision → governed COMPILE_EA (stamps setfile build_hash + .ex5 provenance) → smoke on a free terminal.
2. News-calendar registry patch awaiting OWNER/Fable apply (kein AI-Commit). After apply, scheduled refresh self-heals (receipt 000017).
3. 99 NEWS_CALENDAR_TAINTED holds need OWNER E1-C decision (Q09 manifest repin vs remeasurement) — orthogonal to #2.
4. ba6-2 completion decision (Fable).
5. `QM_WorkItemLogPruner_Daily_0310` rc=1 undiagnosed (deliberately untouched).
6. Independent critique backlog: H-CW card/prereg/EA (codex earliest 09-19), cross-vendor critic independence degraded (agy OAuth dead — OWNER re-login action from the audit still open).

## Work intentionally not touched

Live AutoTrading / T_Live / DXZ v2 cutover (OWNER-only, Sun 2026-09-20), FTMO purchases, gate verdicts, trade streams, claude/codex/agy lanes, WorkItemLogPruner, news-calendar data/registry (patch prepared only), unknown-owner dirty files, nothing pushed to origin.

## Recommended next actions for Fable

1. Verify + push main (~100 commits unpushed; includes the entire Wave-1 merge + H-CW card/prereg/allocation).
2. H-CW: independent critique (codex 09-19) → Q00 governance decision → governed COMPILE_EA + smoke (acceptance rule in the H-CW receipt) → promote EA dir from `agents/kimi-hcw-20260915` per the integration note above.
3. Apply the news-calendar registry patch (5 min, guarded applier ready) → verify self-heal; decide Q09 E1-C separately.
4. Complete ba6-2 (design report + adversarial review) then merge; define Directive-3 Wave 2 (c1 routing, e2, f1/f2 tail-risk engine now unblocked); settle the 11924/11941 orphan-dir inconsistency.
5. Friday 2026-09-18: watch the first live BookEvolution ceremony (23:15 local evidence cut) — first run with merged runner (ai_capacity + live_sleeve_attribution state builds inside).
6. Disposition Q08_DSR_CONTEXT_UNAVAILABLE class (49+ holds) — QM5_11563 retest likely lands there.
