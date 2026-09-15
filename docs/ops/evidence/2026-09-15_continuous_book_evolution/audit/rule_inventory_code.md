# Rule Inventory — CODE & CONTRACT Enforcement Points (task: rule_inventory_code)

**Headline (3 lines)**
1. For every rule named in directive §21 the exact enforcement point was located: most live either in one Python guard (`book_build_guard.py`, `build_book_ftmo.py`, `terminal_worker.py`, the four governors) or in a JSON contract (`gate_manifest.v4.json`, `ftmo_probability_contract.v1.json`, `concentration_tail_limits.v1.json`, `agent_quota_gate.v1.json`); a minority (Q17 min-lot / 14-day, HR16) have **no** code gate at all and live only in spec/runbook/vault doctrine.
2. Two of the caps the directive orders converted to warnings — the discrete **family≤3 / symbol≤2** caps — are already **not** enforced in the current builders; they survive only as documentation in `ftmo_probability_contract.v1.json`, whose `source` pointer (`build_book_ftmo.py:60,66`) is stale. The 25-candidate trigger, by contrast, is a hard fail-closed refusal in code.
3. Classifications (§20): the resource/worker thresholds, correlation control, R1-lineage/R4-runtime-ML, and disk safety are **A (safety/evidence)** — keep; the 25-trigger, family/symbol/correlation numeric caps, FTMO thresholds and density are **B (economic/selection)** — the directive already decides to relax to guardrails; the pipeline serial chain and quota pacing are **C (process)**; Q17 min-lot/14-day, HR16, and the 80 GB research guard are **D (historical)** — the directive supersedes them.

---

## Findings (numbered, each with evidence path)

### F1 — Fixed 25-candidate Q15 trigger / book guard  (class B, with a D-shaped hard block)
- **Enforcement (code):** `tools/strategy_farm/book_build_guard.py:31` `MIN_QUALIFIED_PAIRS = 25`; refusal at `:238-242` (`qualified_pairs_below_minimum: {n} < 25` appended to `reasons`, `allowed=not reasons`); `require_book_build_allowed()` `:260+` raises `BookBuildRefused` (exit code 2, `:66`).
- **Enforcement (contract):** `tools/strategy_farm/config/gate_manifest.v4.json:370-385` `book_trigger` → `requires_all[0].condition = "qualified_candidates_ge_25"`, `on_unmet: "REFUSE (raise), never skip; under 25 only measure/complete the pool"`, and `supersedes` note voiding the old 5-pair Q11 auto-trigger.
- **Diagnostic counter:** `tools/strategy_farm/path_to_25.py:29` `TARGET_QUALIFIED_PAIRS = 25`, sealed count *definition* bound by sha256 to `decisions/2026-08-27_owner_count_definition_option_a.md` (`path_to_25.py:62-63,571-577`).
- **Decision / origin:** count-definition sealed `decisions/2026-08-27_owner_count_definition_option_a.md`; the "25" threshold itself comes from the DRIVE-TO-25 campaign / OWNER-DEC-A1 (2026-08-25, memory `project_qm_drive_to_25_campaign_2026-08-25`); gate manifest explicitly voids the prior 5-pair trigger.
- **Tests that pin it:** `tools/strategy_farm/tests/test_book_build_guard.py:58` `test_below_25_refuses_even_with_owner_order` (asserts `"qualified_pairs_below_minimum: 24 < 25"`), `:91` (25 without order still refused), `:107` `test_25_and_matching_owner_order_pass`.
- **Directive verdict (§4):** explicitly superseded — no OWNER-mandated minimum. Evaluate whatever valid pool exists; unqualified strategies still fail closed.
- **Minimal change → warning:** in `book_build_guard.py:238-242` stop appending the `<25` message to `reasons` (so it no longer flips `allowed`); keep `qualified_pairs` on `GuardResult` as diagnostic and keep the OWNER-order-artifact requirement (`_find_owner_order`). Set `MIN_QUALIFIED_PAIRS` to an advisory constant (or delete the branch). In `gate_manifest.v4.json:373-383` drop the `qualified_candidates_ge_25` element of `requires_all`, keep `owner_order_artifact_present`, and change `on_unmet` wording. Update `test_book_build_guard.py:58,71` to assert the pool is now *measured, not refused*. (This is the change directive §68 Phase B and §70 already order.)

### F2 — Q17 min-lot  (class A/D — safety on first live exposure, but *mandatory* min-lot is historical)
- **Enforcement:** **none in code.** `gate_manifest.v4.json:277-288` Q17 "Live Burn-In DXZ" is `authority: OWNER`, `runner: MANUAL`, `evidence_role: PROSPECTIVE_BURN_IN`. The rule lives only in spec/runbook: `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md:253-257` (2-week window, **minimum lot size**, KS kill-switch), `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md:162` ("14-day min, min-lot, KS kill-switch").
- **Decision / origin:** `decisions/2026-04-26_v5_sub_gate_reconstruction.md` (P10 reconstruction) + OWNER 2026-04-26 DXZ-live-only (`PIPELINE_V5_SUB_GATE_SPEC.md:292`).
- **Tests:** none pin min-lot (no code path).
- **Directive verdict (§10):** universal mandatory min-lot superseded → evidence-based introduction (probation weight / staged risk / parallel observation / no introduction). Live activation stays OWNER-only (§64).
- **Minimal change:** documentation only (no code line to flip). Rewrite `PIPELINE_V5_SUB_GATE_SPEC.md §P10` and `BOOK_CEREMONY_RUNBOOK_2026-09.md:162` to make min-lot one option, not the default; add an evidence-based initial-risk table to the Q17 vault contract. AutoTrading toggle guard (OWNER-only, HR) is unchanged.

### F3 — Q17 fixed 14-day waiting period  (class C/D)
- **Enforcement:** **none in code** — same manual Q17 gate as F2. Doc: `PIPELINE_V5_SUB_GATE_SPEC.md:257` ("14 calendar days"), `:267,284` (INSUFFICIENT_DATA → 14-day extension), `BOOK_CEREMONY_RUNBOOK_2026-09.md:162`.
- **Distinct, do-not-touch 14-day rule:** the news-calendar staleness *schranke* in `framework/include/QM/QM_News.mqh::QM_NewsInit` (14-day → `INIT_FAILED`, `docs/ops/CODEX_ONBOARDING.md:108`) and the manifest news-age check (`BOOK_CEREMONY_RUNBOOK_2026-09.md:265`, `age < 336 h`) are **A safety/evidence** and are NOT the Q17 wait — keep them.
- **Decision / origin:** inherited P10 window, `decisions/2026-04-26_v5_sub_gate_reconstruction.md:40`.
- **Directive verdict (§10):** a fixed 14-day wait must not automatically block weekly portfolio evolution.
- **Minimal change:** documentation only; make the 14-day burn-in an evidence-dependent probation window in the Q17 vault/spec, not a universal calendar block.

### F4 — Family caps (max 3 per family)  (class B) — **already not builder-enforced (drift)**
- **Enforcement (documented, not active):** `tools/strategy_farm/config/ftmo_probability_contract.v1.json:39` `q15_discrete_count_caps.family_max = 3` (`status: OWNER_RATIFIED`, `source: "build_book_ftmo.py:60,66"`). Those source lines are **stale**: `build_book_ftmo.py:60` is `FUND_SCORE_FLOOR = 1.0` and `:66-69` is a comment stating the FTMO book uses aggregate correlation/cluster control, **NOT** a per-family/per-symbol count cap. No `family_max`/per-family discrete check exists in `build_book_ftmo.py`, `build_book_dxz.py`, or `book_reoptimizer.py` (grep confirmed).
- **Active family cap (different dimension):** `tools/strategy_farm/portfolio/concentration_tail.py:162-204` `family_fingerprints` + the SP-C3 percent-of-budget cap `family = 57.5%` of the 11.0% stop-risk budget (`concentration_tail_limits.v1.json:9`). This is the economic concentration cap, not the discrete "≤3".
- **Decision / origin:** discrete caps — OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904 (`decisions/2026-09-04_owner_receipts_briefing_2_4.md`); SP-C3 pct caps — `docs/ops/SP-C3_CONCENTRATION_TAIL_LIMITS_DESIGN_2026-08-22.md`, ratified `concentration_tail_limits.v1.json:42-48`.
- **Directive verdict (§8):** discrete family cap must become a guardrail/warning/diagnostic; measure real economic dependence (trade/return/tail/timing overlap, mechanism similarity).
- **Minimal change:** flip `ftmo_probability_contract.v1.json:39` `q15_discrete_count_caps.status` from `OWNER_RATIFIED` to `ADVISORY`/`DIAGNOSTIC` and correct the stale `source` pointer; keep the `concentration_tail.py` percent-of-budget family cap as a portfolio-risk *input* (already evidence-shaped). No builder line needs removal because none enforces the discrete cap today.

### F5 — Symbol caps (max 2 per symbol)  (class B) — **already not builder-enforced (drift)**
- **Enforcement (documented, not active):** `ftmo_probability_contract.v1.json:39` `symbol_max = 2`. `build_book_ftmo.py:66-69` comment **explicitly rejects** a per-symbol cap ("the FTMO book MAY run multiple EAs/strategies on the same symbol ... NOT via a per-symbol cap").
- **Active symbol cap (different dimension):** SP-C3 `symbol = 46%` of budget (`concentration_tail_limits.v1.json:8`), enforced via `concentration_tail.py:135-158` (`_bare_symbol`, per-symbol grouping).
- **Decision / origin:** same as F4 (OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904).
- **Directive verdict (§8):** convert to guardrail; "three genuinely different XAUUSD mechanisms are not automatically the same risk".
- **Minimal change:** same as F4 — reclassify the discrete `symbol_max` to ADVISORY in the contract; retain the SP-C3 percent-of-budget symbol cap as risk input.

### F6 — Fixed pairwise correlation cap  (class A/B — correlation is genuine portfolio risk, the *number* is economic)
- **Enforcement (multiple, all active):**
  - Book admission (hard, ROT-sealed) `0.50`: `tools/strategy_farm/portfolio/portfolio_correlation.py:77` (Q15); `build_book_ftmo.py:75,84` `WORKING_DEFAULT_MAX_PAIRWISE_CORRELATION`, applied `:196` (`value >= cap → CLUSTER_CORRELATION_EXCLUDED`; unknown corr → `CLUSTER_CORRELATION_UNVERIFIED` fail-closed, `:307-312`).
  - Greedy reoptimizer selection `--max-corr` default `0.50`: `tools/strategy_farm/portfolio/book_reoptimizer.py:6,91`.
  - Q09 marginal-eval reject `0.40` (DL-083): `tools/strategy_farm/portfolio/ftmo_timebox_eval.py:112-114` (`DEFAULT_CORRELATION.maximum_budget_exclusive`), applied `:1115-1117`; strong-warning band `0.15` `:109-111` (advisory).
  - Contract map: `ftmo_probability_contract.v1.json:28-31` `correlation.caps_absolute_layered` (`hard_book_admission 0.50 = ROT_SEALED`; `q09_marginal 0.40 = RATIFIED`; `timebox_strong_warning 0.15 = ADVISORY`).
- **Decision / origin:** `0.50` — OWNER 2026-07-15 (comment `build_book_ftmo.py:77`); `0.40` — `decisions/2026-07-20_DL-083_marginal_eval_threshold_calibration.md`.
- **Tests:** correlation gate covered by `tests/test_dual_book_builders.py` (CLUSTER_CORRELATION_* paths).
- **Directive verdict (§8):** replace static cutoff with measured economic dependence; "do not replace the old static caps with another arbitrary set of permanent caps. Portfolio-level risk is the real constraint." Correlation control itself is legitimate risk input, so keep the *mechanism*, relax the *fixed number*.
- **Minimal change → warning:** in `build_book_ftmo.py:196` and `portfolio_correlation.py:77` convert the hard `>= cap` exclusion into an admit-with-WARN that feeds a portfolio dependence panel (add trade-overlap / tail-dependence / timing-dependence per §8). Keep `CLUSTER_CORRELATION_UNVERIFIED` fail-closed (§71). **Caveat:** the `0.50` book-admission is `ROT_SEALED` (`portfolio_correlation.py:77`); §8 authorizes relaxing static caps into risk inputs, so this is *decided*, but the change should carry an explicit decision record and keep richer dependence measures rather than a new arbitrary cap.

### F7 — HR16 one-research / one-EA at a time  (class D)
- **Enforcement:** **no dedicated code gate** — HR16 is vault doctrine (`01 Identity/Hard Rules`). Closest runtime knobs: research reservoir throttle `tools/strategy_farm/agent_router.py:2231,2428,3575` (`min_ready_strategy_cards` default 5 — "new research only when ready-card reservoir < 5"); per-lane serialization `agent_router.py:645` (`max_parallel: 1` on the kimi lane; second belt only, real guard is the adapter single-flight lock); schema default `agent_router.py:908,1260`.
- **Decision / origin:** vault Hard Rule HR16 (old-infra serialization constraint).
- **Directive verdict (§24):** "only one research / one EA development at a time" is no longer binding; controlled parallelism authorized when evidence stays isolated, task identity clear, repo/compute/MT5/quota allow.
- **Minimal change:** update vault `01 Identity/Hard Rules` (mark HR16 superseded by §24) — the router already supports per-lane `max_parallel`, so the only code lever is raising `max_parallel` on eligible lanes where compute/quota permit; the reservoir throttle (`min_ready_strategy_cards`) can stay as an anti-spam pacer (§24 "do not create uncontrolled idea spam").

### F8 — Research source restrictions (R1–R4)  (class A — lineage + runtime-ML reject; already permissive)
- **Enforcement:** `processes/qb_reputable_source_criteria.md` (R1 single-source/type-open `:29-63`; R2 mechanizable `:67-75`; R3 ≥1 DWX instrument; R4 no runtime-ML/martingale). Prescreen: `tools/strategy_farm/card_intake_prescreen.py` (mechanism-overlap dedup `:331`, rules/falsification headings `:415,430`, runtime-ML span handling `:525-528`, internal-source reason `:539-548`). Internal R1: `tools/strategy_farm/research_source.py` (QM-RESEARCH:// mint/verify, `source_hash = sha256(source.md)` fail-closed `:11,227,472-484`).
- **Decision / origin:** OWNER 2026-06-30 (R1 fully source-agnostic on author; R4 narrowed to ML/basket-runaway) — `qb_reputable_source_criteria.md:6-22`; internal-source contract slice C4/R1 (`docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`).
- **Tests:** `tests/test_research_source.py`, `tests/test_research_mechanization_check.py`.
- **Directive verdict (§36/§37/§41/§42):** already aligned — internal QM-RESEARCH artifact is a valid R1 (§36); Fable/multi-agent authorship must be allowed alongside Kimi (§37); ML in *research* allowed (§41); runtime ML still rejected (§42, keep R4).
- **Minimal change:** generalize `research_source.py` / `card_intake_prescreen.py:539-548` so `source_author` accepts `Fable` / another authorized agent / documented multi-agent collaboration, not only Kimi (`research_source.py:477+` already writes a generic `source_author` field). Preserve fail-closed hash/provenance and R4 runtime-ML reject. No restriction to loosen otherwise — R1–R4 are already source-agnostic.

### F9 — FTMO purchase thresholds (FUND_SCORE, P(pass≤30d), 60-day)  (class B)
- **Enforcement (book-build gates, not a purchase button):** `build_book_ftmo.py:60` `FUND_SCORE_FLOOR = 1.0` (reject `FUND_SCORE_BELOW_1` `:270-275`); `:61-63,478` `P1_LOWER_BOUND_FLOOR` = `lower_95_min = 0.80`; horizon 60d/30d `ftmo_probability_contract.v1.json:15-16` (`ftmo_timebox_eval.py:72,74`); DSR gate `dsr_p_min 0.05 / dsr_prob_min 0.95` `:25` (`framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py:34`). Authoritative engine `ftmo_timebox_eval.py` (`:10` `AUTHORITATIVE_DECISION`). `P(pass≤30d)`/`P(pass≤60d)` are diagnostic conventions (`ftmo_p1_mc.py`, `challenge_firstpassage.py`, contract `:16`).
- **No purchase automation exists:** grep for purchase/BUY in configs/censuses returned nothing — purchase is OWNER-only (§64) and there is no code path that could buy (satisfies §70 "paid purchase cannot occur through automation").
- **Decision / origin:** rulepack `FTMO_2S_100K_SWING_V2.json`; contract `ftmo_probability_contract.v1.json` status `PENDING_OWNER_RATIFICATION` (ROT); DSR `sub_8_2_dsr_mc_fdr.py`.
- **Directive verdict (§15):** FUND_SCORE, first-passage, P(pass≤30d/60d) "remain valuable evidence ... not automatically eternal Hard Rules"; probability-of-success first, speed second; re-evaluate the ≤30d / hard-60d speed targets.
- **Minimal change:** keep FUND_SCORE/P1-lower/DSR as evidence gates for FTMO-book admission (directive keeps evidence). Reframe the speed metrics (≤30d, 60-day first-passage) in `ftmo_probability_contract.v1.json` / the FTMO readiness doc as *secondary* diagnostics, not pass/fail (§57 "time to target as a secondary objective"). No purchase gate to build (none exists; keep it that way).

### F10 — FTMO density rules  (class B)
- **Enforcement:** `build_book_ftmo.py:400-438` `_density` (checks `minimum_sleeves`, `density_evidence_complete`, `each_sleeve_active_days_per_60d >= min_active_days_per_60d`, `minimum_trading_days_phase1 = 4`); required evidence key in `book_builder_common.py:477` (`density` in `ftmo_required`); return-density ranking `ftmo_candidate_efficiency.py:1,121` (`trades_per_year`). Activity criterion: `portfolio/audit_activity_criterion.py:78` (`frequency_floor`), `docs/ops/ACTIVITY_CRITERION.md` (≥10 distinct entry-days/scored year).
- **Decision / origin:** activity criterion OWNER 2026-08-20, OQ-18 closed (`ACTIVITY_CRITERION.md`); FTMO density from the FTMO rulepack.
- **Directive verdict (§16/§18/§48):** use Demo aggressively; scalping / higher-frequency explicitly allowed and *valued* for FTMO. Density is a positive selector — the risk is a floor that *excludes* valuable high-frequency systems, not that it is too loose.
- **Minimal change:** keep density as an economic *input* to FTMO fitness (§57). Ensure the `each_sleeve_active_days_per_60d` check is a portfolio-level warning, not a per-sleeve hard reject, so a legitimately low-frequency sleeve inside an otherwise dense book is not fail-closed; do not add any new upper cap that would penalize scalping (§18).

### F11 — Redundant pipeline gates / serial dependencies  (class C)
- **Enforcement (contract):** `gate_manifest.v4.json:290-309` `ordinary_chain` Q00→Q17 with `linearity_invariant` (`:310`, strictly monotone, every `gate.next` = immediate successor). Per-gate `next` fields force the serial walk; backfill planner `:386-395` (FRONTIER_FIRST global, EARLIEST_MISSING_PREREQUISITE per pair).
- **Already-parallel / decoupled:** Q02–Q08 are per-(EA,symbol) independent and run in parallel across the T1–T10 fleet (they are the throughput metric). Q10_PORTFOLIO is informational only, "never a pre-Q11 abort" (`gate_manifest.v4.json:192`, OWNER E1 2026-08-22) — already decoupled.
- **Duplication candidates (full-history re-runs):** Q05 "Gross Full-History Robustness" (`:120`), Q09 "Baseline Full Run / PRE_NEWS_FULL_HISTORY_BASELINE" (`:168-175`), and Q11 "Incumbent Full-History Confirmation" (`:198-201`) all re-execute full history; `reuse_rule` already permits hash-bound reuse (`REUSE_ONLY_HASH_BOUND_FULL_HISTORY_Q08_BASELINE`, `REUSE_HASH_AND_CONTRACT_EQUAL`).
- **Decision / origin:** rebaseline v4 `decisions/2026-08-23_owner_gate_manifest_v4_linear.md`.
- **Directive verdict (§22/§23):** audit each gate for duplicate detection / stale assumptions / excessive compute / unnecessary serialization; pipeline continuous, not a global drain barrier. Do not lower criteria to create PASSes.
- **Minimal change:** no hard block to flip — this is an efficiency audit. Recommend: (a) collapse Q05/Q09/Q11 full-history runs to a single hash-bound artifact reused across the three roles where build+setfile+window+contract hashes are equal (the `reuse_rule` already sanctions it — enforce it in the backfill planner); (b) fan out Q07 multi-seed replicates in parallel; (c) confirm no gate re-derives another's evidence. Keep the evidence-dependency ordering intact (§22).

### F12 — AI quota restrictions  (class A/C — runaway/cost protection + pacing; backtests never throttled)
- **Enforcement:**
  - Gate policy `tools/strategy_farm/config/agent_quota_gate.v1.json`: `hard_exhaustion` weekly 98% / 5h 95% (`:10-13`); `task_classes` research (weekly 65 / 5h 50, `:201-211`), build (78/65, `:212-221`), ops_review (95/90, `:222-238`); `never_gate_task_types` backtest/deterministic (`:191-199`); `owner_priority_min 70` (`:9`).
  - `tools/strategy_farm/quota_governor.py`: `FLOOR_USED_PCT = 15` (`:60`), `HARD_CEIL_PCT = 90` (`:63`), weekly-pace throttle; flags `CODEX_LOW_TOKENS.flag` / `CLAUDE_DISABLED.flag` (`:53-54`). Backtests never throttled (`:10`).
  - `tools/strategy_farm/codex_budget_line.py`: `DEFAULT_TARGET_AT_RESET_PCT = 92` soft ceil (`:35`), priority≥70 tickets bound to the weekly line (`:8-11`); rollback `QM_CODEX_BUDGET_LINE=0`.
  - `tools/strategy_farm/agy_governor.py`: `FLOOR_PCT` + `AGY_LOW_QUOTA.flag` (`:34,85-89`), ~5h rolling window.
  - `tools/strategy_farm/kimi_governor.py`: caps `{day: 40, week: 200}` (`:77,155-157`), `conserve_pct = 70` (`:78,158`), EXHAUSTED at cap-hit / two rate-limits / period-end (`:208-211`); `KIMI_LOW_QUOTA.flag`.
- **Decision / origin:** OWNER 2026-06-21 (quota governor), OWNER 2026-09-13 (codex budget line, `feedback_codex_weekly_pacing_2026-09-13`), OWNER 2026-09-15 (kimi governor, OWNER-DEC-KIMI-INTEGRATION-20260915).
- **Tests:** `tests/test_agent_router.py` (quota gate paths), kimi governor covered by adapter tests.
- **Directive verdict (§31/§33):** the Kimi 40/200/70 numbers are *fallback guardrails, not contract limits*; discover and prefer real quota telemetry; Fable may adjust conservative defaults; keep runaway protection. Codex/Claude weekly governors are legitimate cost/safety and stay.
- **Minimal change:** `kimi_governor.py:77,155-158` already reads caps from the `gov` dict via `setdefault`, so raising them is config-only (`D:/QM/reports/state/kimi_governor_state.json`); wire in a real-usage snapshot (§32) and prefer it when `usage_source != "local_ledger_only"`, keeping 40/200 only as the anomaly/runaway floor. Leave `quota_governor.py`/`codex_budget_line.py`/`agy_governor.py` thresholds unchanged (safety). Do not touch `never_gate` backtest exemption.

### F13 — Resource thresholds  (class A safety, except the 80 GB research guard = D)
- **80 GB research guard (D — arbitrary):** `tools/strategy_farm/research/research_env.py:48-51` `RESEARCH_DISK_MIN_FREE_GB = 80.0` (design-doc §2.3 D6 gate; the module notes it "stays well above the DISK_MIN_FREE_GB=40 worker floor"). The check function already parameterizes it (`research_env.py:118` `disk_min_free_gb=RESEARCH_DISK_MIN_FREE_GB`).
  - **Directive verdict (§34):** not an OWNER Hard Rule; D: had ~68 GB free so research was blocked; audit real scratch/dataset/memory needs, replace with measured margins or relocate scratch; never delete canonical evidence to free space.
  - **Minimal change:** lower `RESEARCH_DISK_MIN_FREE_GB` to a measured value (worker floor 40 GB + measured research scratch headroom) or make it env-overridable (mirror `terminal_worker` env pattern); optionally repoint research scratch to a volume with headroom.
- **tester_cache_purge LowWater 60 (A — disk safety):** live scheduled-task action runs `-LowWaterGB 60` (`docs/ops/evidence/2026-09-05_m05_recovery/scheduled_history.json:52`; corroborated `docs/ops/evidence/2026-09-15_kimi_integration/audit/drift.md:14`); script default is 150 (`tools/strategy_farm/tester_cache_purge.ps1:30`); 10-min cadence (`install_tester_cache_purge_scheduled_task.ps1`). Keep. **Drift:** CLAUDE.md / `COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md:135` still describe "no-op ≥150 GB / LowWater 80→150".
- **Worker CPU pause (A — crash protection):** `tools/strategy_farm/terminal_worker.py:210-211` `CPU_MAX_LOAD_PERCENT = 97.0`, `CPU_RESUME_LOAD_PERCENT = 90.0` (OWNER 2026-08-15, `:203`); guard sleep 20 s (`:212`). Keep.
- **RAM classes (A — OOM protection, measured not arbitrary):** `terminal_worker.py:168` `RAM_MIN_FREE_GB = 14.0`, `:169` resume 20.0, `:191` emergency 2.0, `:234` `COMMIT_MIN_FREE_GB = 24.0`, `:268` multi-symbol 12.0, `:279` `MULTISYMBOL_COMMIT_RESERVATION_GB = 44.0`, `:294` two-leg-metal 24.0, `:307` `SINGLE_INDEX_TICK_COMMIT_RESERVATION_GB = 44.0`, index-by-base table `:328` (`SP500 44.0`, others provisional per `docs/ops/evidence/2026-09-14_index_ram_table/`). Rollback env `QM_INDEX_TICK_RESERVATION_TABLE=0`. Keep — these are measured working-set reservations, directive does not touch factory RAM safety.
- **Decision / origin:** research guard — Kimi edge-discovery design (`docs/ops/KIMI_EDGE_DISCOVERY_DESIGN.md`); worker thresholds — OWNER 2026-08-15 (CPU), index RAM table 2026-09-14; cache purge — OWNER 2026-06-21 factory recovery.
- **Tests:** `tests/test_tester_cache_budget.py`, `tests/test_index_tick_reservation_table.py`, worker claim/drain tests.

---

## Drift table (doc/vault says vs runtime says vs path)

| # | Doc / contract says | Runtime / code says | Path |
|---|---|---|---|
| D1 | `ftmo_probability_contract.v1.json` q15_discrete_count_caps `family_max 3 / symbol_max 2` are `OWNER_RATIFIED` and enforced at `build_book_ftmo.py:60,66` | Those lines are `FUND_SCORE_FLOOR` + a comment that explicitly says the FTMO book uses aggregate correlation/cluster control **not** per-symbol/family count caps; no discrete cap is enforced in any builder | contract `:39` vs `build_book_ftmo.py:60,66-69` |
| D2 | CLAUDE.md / `COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md:135`: tester purge "no-op ≥150 GB free; LowWater 80→150" | Live task action runs `-LowWaterGB 60` | scheduled task ARG, `docs/ops/evidence/2026-09-05_m05_recovery/scheduled_history.json:52` |
| D3 | `gate_manifest.v4.json:5` `draft_note` says "PROPOSAL ONLY ... DEFAULT_MANIFEST stays gate_manifest.v3.json" | Same file `status: "ACTIVE"` (`:4`) and `activation_guard.state: "ACTIVE"`, `activated_at 2026-08-23` (`:421-427`); memory confirms v4 is the live linear pipeline | `gate_manifest.v4.json:5` vs `:4,421-427` (internal contradiction — stale draft_note) |
| D4 | `ftmo_probability_contract.v1.json` correlation `hard_book_admission 0.50` documented as enforced at `build_book_ftmo.py:75` | Builder enforces `WORKING_DEFAULT_MAX_PAIRWISE_CORRELATION` (from the contract) at `:196`; the `0.40` marginal cap is only a comment in the builder (`:77-78`) and is actually enforced in `ftmo_timebox_eval.py:112-114` | contract `:30` (`provenance_comment_only`) vs `build_book_ftmo.py:196`, `ftmo_timebox_eval.py:112-114` |
| D5 | CLAUDE.md pipeline prose in places still references "Q00–Q13" older numbering | Active manifest is Q00–Q17 linear (`gate_manifest.v4.json`) | CLAUDE.md vs `gate_manifest.v4.json:290-309` |

---

## Open questions strictly requiring OWNER

None newly required by *this* audit — directive §4/§8/§10/§24/§33/§34 already decide every conversion above, and §68 Phase B orders their implementation. Two pre-existing tensions are noted for the implementing phases (they are not blockers for the rule-effectiveness audit itself):
- **OQ9 (from `ftmo_probability_contract.v1.json:39`):** the 10.0 unit-weight account budget admits ≤10 sleeves but Q15 targets 10–15 EAs — consistent only if sleeve ≠ EA. This predates the directive and is being dissolved by §8 (caps → risk inputs); flag it to the phase-E portfolio-engine work rather than re-asking OWNER.
- **Correlation 0.50 is `ROT_SEALED`** (`portfolio_correlation.py:77`): §8 authorizes converting static caps to risk inputs, so relaxation is *decided*, but the implementing change (F6) should carry a dated decision record and keep richer dependence measures, not a new arbitrary number.

---

## Recommended actions for the implementing phases (concrete file paths)

1. **F1 / Phase B (§4):** edit `tools/strategy_farm/book_build_guard.py:31,238-242` to stop treating `<25` as a refusal reason (keep it as a `GuardResult` diagnostic; keep the OWNER-order requirement); edit `tools/strategy_farm/config/gate_manifest.v4.json:373-383` to drop `qualified_candidates_ge_25` from `book_trigger.requires_all`; update `tools/strategy_farm/tests/test_book_build_guard.py:58,71,91`; mint the superseding decision at `decisions/2026-09-15_owner_continuous_book_evolution.md` (§4 orders an explicit artifact).
2. **F4/F5 / Phase B (§8):** in `tools/strategy_farm/config/ftmo_probability_contract.v1.json:39` set `q15_discrete_count_caps.status` → `ADVISORY` and fix its stale `source` pointer; keep `tools/strategy_farm/portfolio/concentration_tail.py` percent-of-budget caps as portfolio-risk inputs; add trade-overlap / tail-dependence outputs to the book builders.
3. **F6 / Phase B+E (§8):** convert the hard correlation exclusion in `tools/strategy_farm/portfolio/build_book_ftmo.py:196` and `tools/strategy_farm/portfolio/portfolio_correlation.py:77` to admit-with-WARN feeding a dependence panel; keep `CLUSTER_CORRELATION_UNVERIFIED` fail-closed; record the ROT relaxation in a dated decision.
4. **F2/F3 / Phase B (§10):** rewrite `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md §P10`, `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md:162`, and the Q17 vault page to make min-lot and the 14-day burn-in evidence-based options, not universal blocks; leave the news-calendar 14-day staleness schranke (`QM_News.mqh`) untouched.
5. **F7 / Phase B (§24):** mark HR16 superseded in vault `01 Identity/Hard Rules`; raise `max_parallel` on eligible lanes in `tools/strategy_farm/agent_router.py` where compute/quota allow; keep `min_ready_strategy_cards` as an anti-spam pacer.
6. **F8 / Phase C (§37):** generalize `source_author` handling in `tools/strategy_farm/research_source.py` and `tools/strategy_farm/card_intake_prescreen.py:539-548` to accept Fable / other authorized agents / multi-agent collaboration; preserve hash/provenance fail-closed and the R4 runtime-ML reject.
7. **F11 / Phase B (§22/§23):** enforce hash-bound single-artifact reuse across Q05/Q09/Q11 full-history roles in the backfill planner (`gate_manifest.v4.json:386-395` already sanctions it) and parallelize Q07 seeds; do not lower any pass criterion.
8. **F12 / Phase C (§31/§33):** wire a real Kimi-usage snapshot into `tools/strategy_farm/kimi_governor.py` (prefer it over the 40/200/70 local caps when `usage_source` is authoritative), keeping the local caps as the runaway floor.
9. **F13 / Phase C (§34):** lower or env-parameterize `tools/strategy_farm/research/research_env.py:51` `RESEARCH_DISK_MIN_FREE_GB` to a measured margin (or relocate research scratch); leave worker CPU/RAM/disk safety thresholds unchanged.
10. **Drift D2/D3/D5 / Phase B (§65/§66):** reconcile CLAUDE.md + `COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md:135` to LowWater 60; remove the stale `draft_note` from `gate_manifest.v4.json:5`; correct residual "Q00–Q13" prose to Q00–Q17.
