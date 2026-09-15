# OWNER directive 2026-09-15 — Continuous Book Evolution / FTMO Acceleration / Autonomous Edge Discovery (ULTRACODE)

- Author: OWNER (chat, 2026-09-15 ~12:1xZ, message headed "ULTRACODE / QUANTMECHANICA — MASTER OWNER DIRECTIVE:
  CONTINUOUS BOOK EVOLUTION / FTMO ACCELERATION / AUTONOMOUS EDGE DISCOVERY / KIMI QUANT RESEARCH"), transcribed by
  Orchestrator Claude/Fable (session https://claude.ai/code/session_01EbahMJqzhTCfpmWAPcTaoE). The full directive text is
  preserved verbatim in `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md`; this file
  records the binding decisions. Phase-A truth snapshot and audit reports: same directory
  (`PHASE_A_TRUTH_SNAPSHOT.md`, `audit/`).
- Decision id: `OWNER-DEC-CBE-20260915`
- Status: BINDING. The OWNER instructed (§68B): "Do NOT ask OWNER to reapprove decisions already explicit here." The items
  below are FINAL; they are implemented across several slices — the implementation status column names which.

## 0. Scope and precedence

This directive "supersedes older QuantMechanica intermediate goals, process constraints and portfolio rules wherever they
conflict with the decisions stated here" (§0). It does **not** relax validation quality (§22), and it does **not** touch
the RED boundaries (§64 live/money authority, §71 stop conditions) — those stay exactly as they were. Truth precedence is
runtime/filesystem over stale Vault numbers (§1). Superseded rules are marked superseded, never deleted; history is
preserved (§3 "Do not rewrite history").

The single north-star reframing: **candidate count is a diagnostic, not a business goal.** Optimize for validated expected
economic improvement of the DXZ and FTMO books, not for the number of strategies, tickets, tested EAs, or AI calls (§0,
§73).

## Decisions (OWNER, binding) — the §68B "PHASE B — OWNER POLICY IMPLEMENTATION" list

Each item: directive section · what it supersedes (prior decision/DL/rule + its enforcement path, per
`docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/rule_inventory_code.md`) · implementation status · what
stays unchanged.

### 1. Remove "Way to 25" as a business goal
- **Directive:** §3, §60, §73.
- **Supersedes:** the DRIVE-TO-25 campaign / OWNER-DEC-A1 (2026-08-25, memory `project_qm_drive_to_25_campaign_2026-08-25`)
  as a *business target*. Enforcement/surfacing of the "25" milestone lives in `tools/strategy_farm/path_to_25.py:29`
  (`TARGET_QUALIFIED_PAIRS = 25`) and the read models `mission_control_v2_data.py`, `render_cockpit_v2.py`,
  `morning_brief.py`, `heartbeat_snapshot.py`, `operator_surfaces.py`.
- **Implementation status:** LATER SLICE (Phase D — Mission Control / read-model surfaces). This slice
  (`b1_book_guard_decision`) removes the *enforcement trigger* only; the milestone framing in the surfaces is a Phase-D
  edit and those files are deliberately left untouched here.
- **Stays unchanged:** candidate counts may still be *displayed* as diagnostics (§60 "Candidate counts may be displayed.
  Do not elevate them into business goals"); the qualification predicate is untouched.

### 2. Remove the fixed 25-candidate book-build trigger  ← IMPLEMENTED IN THIS SLICE
- **Directive:** §4 (explicit: "`BOOK BUILD PERMITTED ⇔ qualified_candidates >= 25` is explicitly superseded ... The
  portfolio engine may evaluate any currently valid qualified pool"). §4 also orders an explicit OWNER decision artifact
  superseding the old trigger — this file is that artifact.
- **Supersedes (rule_inventory F1):** the hard fail-closed refusal
  `tools/strategy_farm/book_build_guard.py` `MIN_QUALIFIED_PAIRS = 25` (refusal reason `qualified_pairs_below_minimum:
  N < 25`, raising `BookBuildRefused`, exit 2) and the contract element
  `tools/strategy_farm/config/gate_manifest.v4.json → book_trigger.requires_all[qualified_candidates_ge_25]`
  (`on_unmet: "REFUSE ... under 25 only measure/complete the pool"`). The count-definition seal
  `decisions/2026-08-27_owner_count_definition_option_a.md` remains valid — only the *minimum-count trigger* is superseded,
  not the *definition* of what counts.
- **Implementation status:** THIS SLICE. `book_build_guard.py`: `MIN_QUALIFIED_PAIRS = 25` is retained ONLY as a
  diagnostic `reference_pool_size` constant (read models import it); the real trigger becomes `MIN_VALID_POOL = 1`
  (build/evaluate allowed for any NON-EMPTY valid pool); `GuardResult` gains backward-compatible
  `reference_pool_size` and `trigger_policy = "any_valid_pool (OWNER-DEC-CBE-20260915)"`; the empty-pool refusal reason is
  `qualified_pool_empty`. `gate_manifest.v4.json`: the `qualified_candidates_ge_25` condition keeps its legacy token name
  (pinned by the schema/validator/`path25_red_team`) but its detail, `on_unmet` and `supersedes` are rewritten to
  diagnostic/non-empty semantics; the stale `draft_note` (drift D3) is corrected.
- **Stays unchanged (fail-closed):** the qualification predicate — a (EA, symbol) pair whose highest *contiguous* valid
  gate is the active terminal requalification gate (today Q14), every gate on Q02..Q14 carrying a done PASS-class verdict
  and no invalidating hold (`rebaseline_census` / `book_build_guard._qualified_pair_rows`). Unqualified pairs are never
  counted and still fail closed. The OWNER book-order artifact requirement
  (`decisions/YYYY-MM-DD_owner_book_order_<venue>.md`) is unchanged. Gate criteria and verdict semantics are untouched.

### 3. Two permanently evolving books (DXZ + FTMO), evaluated independently
- **Directive:** §5, §7, §57.
- **Supersedes:** any assumption that a DXZ survivor is automatically an FTMO strategy or that FTMO must mirror DXZ.
  Enforcement today: separate builders `tools/strategy_farm/portfolio/build_book_dxz.py` and `build_book_ftmo.py`.
- **Implementation status:** LATER SLICE (Phase E — continuous portfolio recomposition engine; per-candidate
  `DXZ_FITNESS` / `FTMO_FITNESS`).
- **Stays unchanged:** both books face the full pipeline validation (§22); RED live-book authority (§64).

### 4. Weekly book recomposition is a core business process
- **Directive:** §6, §58, §59, §61.
- **Supersedes:** ad-hoc/manual book ceremonies as the only cadence. Materiality/anti-churn framework: weekly default is
  KEEP unless material evidence supports improvement.
- **Implementation status:** LATER SLICE (Phase H — Friday evidence cut → Saturday analysis → Sunday recommendation →
  OWNER handoff), plus `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` weekly recomposition contract.
- **Stays unchanged:** deterministic portfolio math (§58 "Portfolio calculations should be deterministic. AI interprets
  the result").

### 5. Q17 mandatory min-lot burn-in is superseded
- **Directive:** §10.
- **Supersedes (rule_inventory F2):** the universal min-lot rule in `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md:253-257` and
  `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md:162`, originating in `decisions/2026-04-26_v5_sub_gate_reconstruction.md`
  (P10). There is **no code gate** for min-lot — it is spec/runbook doctrine only.
- **Implementation status:** LATER SLICE (documentation refactor of Q17 into an evidence-based introduction/probation
  stage).
- **Stays unchanged:** live AutoTrading activation remains OWNER-only (§64); the reduced-risk probation option must carry
  an explicit evidence/risk reason.

### 6. Q17 fixed 14-day waiting period is not a universal hard block
- **Directive:** §10.
- **Supersedes (rule_inventory F3):** the fixed 14-calendar-day burn-in in `PIPELINE_V5_SUB_GATE_SPEC.md:257` /
  `BOOK_CEREMONY_RUNBOOK_2026-09.md:162` (P10 window). No code gate.
- **Implementation status:** LATER SLICE (documentation — make the burn-in an evidence-dependent probation window).
- **Stays unchanged (DO NOT TOUCH):** the news-calendar 14-day *staleness* schranke in
  `framework/include/QM/QM_News.mqh::QM_NewsInit` (14-day → `INIT_FAILED`) and the manifest news-age check (age < 336 h)
  are safety/evidence rules, NOT the Q17 wait — they remain enforced.

### 7. Old hard portfolio caps become evidence-based portfolio-risk analysis
- **Directive:** §8.
- **Supersedes (rule_inventory F4/F5/F6):** the discrete `family_max = 3` / `symbol_max = 2` caps documented in
  `tools/strategy_farm/config/ftmo_probability_contract.v1.json:39` (OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904,
  `decisions/2026-09-04_owner_receipts_briefing_2_4.md`) — already builder-drift (no builder enforces the discrete cap;
  see Observed-Drift D1); and the fixed pairwise correlation cap `0.50` (`portfolio/portfolio_correlation.py:77`,
  `build_book_ftmo.py:75,196`, ROT-sealed, OWNER 2026-07-15) plus the `0.40` marginal cap (DL-083,
  `ftmo_timebox_eval.py:112-114`).
- **Implementation status:** LATER SLICE (Phase B/E — reclassify discrete caps to `ADVISORY`; convert the hard
  correlation exclusion to admit-with-WARN feeding a dependence panel with trade-overlap / tail-dependence / timing
  dependence). The correlation-`0.50` ROT relaxation must carry its own dated decision record when implemented.
- **Stays unchanged (fail-closed):** `CLUSTER_CORRELATION_UNVERIFIED` stays fail-closed (§71); the SP-C3 percent-of-budget
  concentration caps (`concentration_tail_limits.v1.json`, `portfolio/concentration_tail.py`) remain as portfolio-risk
  *inputs*. §8 forbids replacing old static caps with a new arbitrary permanent set.

### 8. Controlled parallelism is allowed (HR16 relaxed)
- **Directive:** §24, §23.
- **Supersedes (rule_inventory F7):** the absolute "only one research / one EA development at a time" reading of HR16
  (vault `01 Identity/Hard Rules` — no dedicated code gate). Also supersedes the "global drain barrier" doctrine (§23,
  memory `project_qm_pipeline_drain_directive_2026-08-21`).
- **Implementation status:** LATER SLICE (mark HR16 superseded in the vault; raise `max_parallel` on eligible
  `agent_router.py` lanes where compute/quota permit).
- **Stays unchanged:** the `min_ready_strategy_cards` reservoir throttle stays as an anti-spam pacer (§24 "Do not create
  uncontrolled idea spam"); evidence isolation, clear task identity, MT5/quota protection are preconditions.

### 9. FTMO two-week Demo required before any paid purchase
- **Directive:** §11, §12, §16, §62.
- **Supersedes:** any path that buys a Challenge without a representative two-week Demo validation cycle. A material
  strategy/risk/compliance change during validation triggers a new/extended representative period.
- **Implementation status:** LATER SLICE (`docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md`,
  `docs/ops/FTMO_CHALLENGE_READINESS.md`; Mission Control FTMO readiness panel in Phase D).
- **Stays unchanged:** paid purchase is OWNER-only and cannot occur through automation (§64, §71; rule_inventory F9
  confirms no purchase code path exists — keep it that way).

### 10. One paid FTMO Challenge at a time; 100k / 2-Step default; success probability over speed
- **Directive:** §13, §14, §15.
- **Supersedes (rule_inventory F9):** the speed-first objectives (fastest +10%, ≤30 days, hard 60-day first-passage) as
  pass/fail hard rules. FUND_SCORE, first-passage, P(pass≤30d/≤60d) remain valuable *evidence* (`build_book_ftmo.py:60`,
  `ftmo_probability_contract.v1.json`), reframed as secondary diagnostics.
- **Implementation status:** LATER SLICE (FTMO readiness doc + contract reframing). A second simultaneous paid Challenge
  requires a future OWNER decision.
- **Stays unchanged:** FUND_SCORE / P1-lower / DSR stay as FTMO-book admission *evidence* gates (not lowered); purchase
  OWNER-only.

### 11. Scalping and trailing stops are expressly allowed
- **Directive:** §18, §19, §48.
- **Supersedes (rule_inventory F10):** any implicit rejection of low-timeframe / high-frequency / short-holding systems.
  The FTMO density check (`build_book_ftmo.py:400-438`) is a positive selector; the risk is a floor that *excludes*
  valuable high-frequency systems, so its per-sleeve check should be a portfolio-level warning, not a hard reject.
- **Implementation status:** LATER SLICE (research policy docs `docs/research/AUTONOMOUS_EDGE_DISCOVERY.md`; density-check
  softening in the FTMO builder).
- **Stays unchanged:** net-economics scrutiny for scalping (spread, commission, slippage, fill realism, stop-distance) is
  mandatory (§18) — permission is not a lowering of validation.

### 12. Machine learning allowed in offline research; forbidden in EA runtime
- **Directive:** §41, §42.
- **Supersedes / restates:** already decided by `OWNER-DEC-KIMI-INTEGRATION-20260915`
  (`decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md`, decision 3) and the HR14 2026-09-15 annex.
  Restated here for the continuous-evolution programme. Enforcement (rule_inventory F8): `processes/qb_reputable_source_criteria.md`
  R4 (no runtime ML), `card_intake_prescreen.py:525-528` runtime-ML span handling.
- **Implementation status:** ALREADY IMPLEMENTED (baseline). No change in this programme.
- **Stays unchanged (Hard Rule):** no ML in the EA or its live/backtest decision engine; every candidate entering Q00 is
  fully mechanical (finite bounded parameters, no inference API, no model file, no online learning).

### 13. Autonomous strategy ideation and Fable/Kimi internal authorship are allowed
- **Directive:** §36, §37, §38, §39, §50.
- **Supersedes (rule_inventory F8):** the Kimi-only shape of the internal-source tooling and any assumption that a strategy
  must originate from an external human source. A durable internal `QM-RESEARCH://<id>` artifact is a valid R1 source with
  an explicit author (Kimi, Fable, another authorized agent, or documented multi-agent collaboration). Enforcement:
  `tools/strategy_farm/research_source.py`, `card_intake_prescreen.py:539-548`,
  `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`.
- **Implementation status:** LATER SLICE (generalize `source_author` handling beyond Kimi).
- **Stays unchanged (fail-closed):** hash/provenance/lineage requirements (`source_hash = sha256(source.md)`); `author =
  Kimi/Fable` without a resolvable durable artifact is invalid; a Kimi-authored hypothesis always gets a non-Kimi critic
  (Creator → Critic separation, §52).

## RED boundaries explicitly preserved (unchanged by this directive)

Per §64 (Live and Money Authority) and §71 (Safety / Stop Conditions), this directive does **not** authorize and this
decision does **not** change: gate thresholds / criteria / verdict semantics; deletion or rewriting of verdicts, trade
streams, or dated decisions/evidence; T_Live, AutoTrading activation, live deployment, or any live-book change without
OWNER authority; automatic FTMO Challenge purchase; automatic Kimi subscription upgrade/renewal; hiding failed research.
The candidate **qualification predicate** and all pipeline pass criteria remain fully in force — unqualified candidates
still fail closed. A genuinely new RED question is prepared as an OWNER decision package (issue/options/evidence/impact/
recommendation/rollback), and unaffected work continues (§71).

## Rollback

- This slice (decision 2): `git revert` the commit touching `tools/strategy_farm/book_build_guard.py`,
  `tools/strategy_farm/config/gate_manifest.v4.json`, `tools/strategy_farm/tests/test_book_build_guard.py`. There is no
  runtime feature flag; the guard change is a pure code/contract edit. Reverting restores `MIN_QUALIFIED_PAIRS = 25` as the
  hard trigger and the original `book_trigger` detail text. No DB/state migration is involved.
- Later-slice items list their own rollback in their respective decision/PR.

## Observed-drift annex (Phase-A truth reconciliation, §68A) — no code change here

Recorded from the audit reports; deterministic dispositions belong to the relevant implementing slices.

1. **`candidate_qualifications` table is EMPTY.** `select count(*) from candidate_qualifications` = 0 in
   `farm_state.sqlite`; qualification is actually tracked via `portfolio_candidates` + the `by_gate_v4`
   (highest-contiguous-valid-gate) census, and the book guard computes the qualified pool live from `rebaseline_census`.
   The empty ledger must not be read as "zero qualified"; the authoritative qualified source is
   `book_build_guard._qualified_pair_rows` / `rebaseline_census`. Source:
   `docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/pipeline_factory_state.md` (drift table) and
   `.../audit/candidate_universe.md`. Disposition: the Phase-E portfolio engine must read the correct qualified source, not
   the empty ledger; no write to the DB is performed here.
2. **Three simultaneous "Q14 candidate" numbers (26 / 28 / 29).** The one authoritative *qualified* count is **26**
   (highest *contiguous* valid gate == Q14); 28 = terminal-verdict rows (`q14_terminal_rows`), 29 = highest *observed* Q14
   (`by_gate_v4.Q14`). Only 26 is the qualification definition; 28/29 are diagnostics. CLAUDE.md /
   `COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md` wording "the OWNER counter counts terminal Q14 pairs" maps to 28/29 and is
   the §68A drift. Source: `.../audit/candidate_universe.md` §2. Disposition: single canonical definition = predicate A
   (Phase B/D relabelling of the diagnostics; surfaces left to Phase D).
3. **`gate_manifest.v4.json` stale `draft_note` (drift D3).** The note said "PROPOSAL ONLY … DEFAULT_MANIFEST stays
   gate_manifest.v3.json" while the same file is `status: ACTIVE`, `activation_guard.state = ACTIVE`, activated 2026-08-23,
   and runtime writes v4 rows. **Corrected in this slice** (note rewritten to ACTIVE/superseded; the old proposal text is
   quoted inside the new note so history is preserved).
4. **Incumbent live book vs. qualified pool.** The staged 28-sleeve DXZ manifest overlaps today's qualified-26 by only 10
   pairs; the built roster `roster_v2b.json` = 24. Source: `.../audit/candidate_universe.md` §5. Disposition: Phase-E
   engine reconciles incumbent vs. current qualified per-sleeve — out of scope here.
5. **Q10 refresh needed for QM5_41219 XAUUSD** (latest news row `REVIEW_REQUIRED`; qualifies only via an earlier
   `CONFIG_LOCKED` row). Data-hygiene item for the news-review lane; not a guard change.
