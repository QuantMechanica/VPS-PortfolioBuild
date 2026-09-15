# QuantMechanica — Completeness & Gap Audit (2026-09-15)

**Authority:** OWNER follow-up directive
`docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_followup_directive_completeness_verbatim.md`
(§1, §12–§14, §16, §21, §22, FINAL OWNER PRINCIPLE). Master directive
`.../owner_directive_verbatim.md`; Phase A synthesis `.../PHASE_A_TRUTH_SNAPSHOT.md`.

**This is an audit with evidence, not prose.** Every material claim carries a path or a query, and
the key facts were re-verified against runtime (read-only) at audit time, not read out of documents.
As-of 2026-09-15 ~16:0x–18:2xZ, canonical runtime host, worktree branch `agents/board-advisor`,
worktree HEAD `4aaedf94db` (== `agents/board-advisor` head). Truth precedence per directive §1
(OWNER instruction > runtime/SQLite/filesystem > `.private` > Vault > `docs/ops` > Notion).

**Scope note — what is landed vs staged.** The master directive Phases A–H are **committed to
HEAD** (31 commits since `6019af7a17`; `git log --oneline 6019af7a17..HEAD`). The five **Phase I
slices** (this follow-up directive) are delivered as **patches not yet applied to the canonical
repo** — `<scratchpad>/patches_i/{i1..i5}.patch` — but their generators were *run*, so their runtime
and Vault artifacts already exist on disk (`D:/QM/reports/state/*`, `G:/…/09 Strategy Wiki/generated/*`).
This audit distinguishes the two states everywhere it matters.

---

## EXECUTIVE SUMMARY

### COMPANY KNOWLEDGE — is the Vault complete enough?
- **Yes for the strategy layer, and now machine-verified.** `STRATEGY_WIKI_SYNC = GREEN`
  (`D:/QM/reports/state/strategy_wiki_sync.json`): `canonical_records=3820`, `valid_projections=3820`,
  `projected_nodes=5265`, and `missing=stale=duplicate=orphan=invalid_link=unresolved_source=unresolved_lineage=0`.
- **Canonical strategies that exist = 3820** (`ACTIVE_CANONICAL`); full universe classed as
  ACTIVE_CANONICAL 3820 / RETIRED 356 / REJECTED 893 / DRAFT 130 / HISTORICAL 55 / DUPLICATE 7 /
  SUPERSEDED 4 (`strategy_wiki_sync.json.class_counts`).
- **Represented now = 5265 generated Vault nodes**, verified on disk under
  `G:/…/09 Strategy Wiki/generated/` (5266 `.md`; subdir counts match the read-model class-by-class:
  ACTIVE_CANONICAL 3820, REJECTED 893, RETIRED 356, DRAFT 130, HISTORICAL 55, DUPLICATE 7, SUPERSEDED 4).
- **What was fixed:** coverage went from **45 hand-written nodes (~0.35% of canonical)** to a
  deterministic generated projection of **100% of the 3820 canonical records**, plus a
  `STRATEGY_WIKI_SYNC` Mission Control health key (`i1` slice; report
  `.../design/i1_strategy_wiki_sync_report.md`). Each node carries the §4 required fields with explicit
  `NOT_EVALUATED/UNKNOWN/NOT_APPLICABLE/EVIDENCE_MISSING` where a value is absent.
- **Residual (does not affect GREEN):** the 60-min sync scheduled task is **not yet registered**
  (installer written; RED boundary) and external (non-QM-RESEARCH) `source_hash` emits
  EVIDENCE_MISSING — so GREEN today is a *point-in-time run*, not yet self-sustaining.

### DXZ — is continuous weekly recomposition operational?
- **Yes, operational and proven end-to-end.** Weekly tasks registered and `Ready`:
  `QM_BookEvolution_FridayEvidenceCut / SaturdayAnalysis / SundayRecommendation / RuntimeVerify`
  + `QM_StrategyFarm_BookEvolutionReadModels_15min` (`Get-ScheduledTask QM_*`, verified live).
- **§12 dry-run concluded a real decision without a candidate-count block:** DXZ outcome
  **ADD_SLEEVE** (10700:XAUUSD.DWX, material=true, §59 cleared) and FTMO **CONTINUE_OBSERVATION**
  (`D:/QM/reports/book_evolution_dryrun/2026-W38/cuts/dryrun-20260915/OWNER_DECISION_PACKAGE.md`,
  `recommendation_index.json`). The full chain Friday-cut → snapshot → DXZ/FTMO fitness → incumbent
  compare → alternatives → materiality → Fable recommendation → OWNER package exists as files.
- **Blockers:** none blocking the workflow. Cross-review critic is `gated`/`NOT_EVALUATED` (Codex+agy
  quota-down; not a blocker). Live per-sleeve **PnL attribution = EVIDENCE_MISSING**
  (`book_evolution_dxz.json.evidence` uses live DD/equity only). Next scheduled recomposition
  `2026-09-20T10:00Z` (`book_evolution_dxz.json.next_recomposition_utc`).

### FTMO — is Demo validation operational? (§13 answers, from `ftmo_challenge_readiness.json` + `ftmo_demo_cycle.json`)
- **Yes, deterministically answerable today.** Recommendation **NOT_READY**; `would_fable_buy_today=false`.
- **Exact portfolio under validation:** 8 sleeves, `roster_hash 6c5383d87777…` — 10706/GBPUSD,
  11421/EURUSD, 11422/USDCAD, 11910/NZDUSD, 13054/USOIL.cash, 20048/USOIL.cash, 1537/XAGUSD,
  21505/XAGUSD, each `risk_pct 0.3125`, total book risk **2.5%** (Standard 2-Step / 100k).
- **Cycle start / material change / representative:** cycle_start `2026-09-15T14:12:11Z`
  (first observation of current roster hash), **validation 0.09/14 days**; `material_changes=[]`;
  **representative = false**. Daily loss (current cycle) **−0.18%**, max DD **−0.29%**, target
  progression **−1.46%** (`metrics`); worst historical cycle daily **−2.34%**, max DD **−10.26%**.
- **Simulated survival / strongest failure mode:** `challenge_survival=FAIL` (0 admitted sleeves,
  best FUND_SCORE **0.41** vs floor **1.0**); first-passage **EVIDENCE_MISSING**; strongest failure
  mode = *"Total-loss breach in a demo cycle: realized max-DD −10.26% vs 10% limit."*
- **What remains before OWNER should buy:** a representative, rule-faithful 2-week demo of a
  purpose-built **FTMO-fit** roster (the proven inventory is low-density swing — structurally the
  opposite profile; see RESEARCH), plus a computed FTMO_FITNESS first-passage. §14 materiality
  contract = `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md` (in HEAD).

### RESEARCH — is autonomous edge discovery operating; is Kimi actually researching? (§16 item by item)
- **Research lane enabled?** YES — `kimi` lane NORMAL, `usage_source=managed_usage_endpoint`,
  `QM_StrategyFarm_KimiOrchestration_15min` = `Ready` (`orchestration_health.json.lanes.kimi`; `Get-ScheduledTask`).
- **At least one real campaign run?** YES — `CAMP-2026-0001-ftmo-gap`, a live 15.5-minute Kimi call
  on the farm's own OBSERVE evidence (`.../research/CAMP-2026-0001_receipt.md`; `research_state.json.counts.campaigns=1`).
- **Produced an artifact?** YES — `QM-RESEARCH-2026-0001` (author Kimi) and `QM-RESEARCH-2026-0002`
  (author `multi-agent:Kimi+Fable`, parent 0001), both hash-verified, status `reviewed`
  (`D:/QM/reports/state/research_source_ledger.jsonl`).
- **Cross-provider critique?** YES — critic = Claude/Fable, `cross_vendor=true`, verdict REVISE.
  **Caveat:** the automated `agent_chain` critic was quota-gated (Codex+agy down) and the critique
  ran as the Fable-inline fallback (`research_state.json.kimi_campaigns[].critic_provider="claude"`;
  `orchestration_health.json.critic_chain.independence_degraded=true`).
- **Sealed?** YES in the summary read-model (`research_state.json.kimi_campaigns[].sealed=true`); the append-only `research_source_ledger.jsonl` terminates QM-RESEARCH-2026-0001/0002 at status `reviewed` (cross-vendor critic verdict REVISE attached) — the artifacts are hash-verified and immutable, the ledger row name is `reviewed`, not `sealed` (critic note 2026-09-15).
- **Mechanical hypothesis or useful negative finding?** BOTH — mechanizable candidate **H-CW**
  (cash-window index continuation, session-flat, ≤432-combo bounded grid) plus negative/inconclusive
  H1/H2/H3 verdicts (`research_state.json.hypotheses.mechanized=["…/H-CW"]`; receipt).
- **Visible in experiment memory + Vault?** YES — `experiment_memory_ledger.jsonl` (9 rows),
  `research_state.json` FRESH (`book_evolution_health.json.research_state_freshness="FRESH"`), Vault
  Research node. **Autonomous edge discovery is operating**, charter `docs/research/AUTONOMOUS_EDGE_DISCOVERY.md`
  (HEAD); programmes ACTIVE = external_edge_harvest, internal_edge_discovery, ftmo_gap_research;
  PLANNED = failure_mining, white_space_research (`research_state.json.programmes`).

### ARCHITECTURE — obsolete rules: existed / removed / kept
- **Existed (superseded by OWNER-DEC-CBE-20260915):** fixed ≥25-candidate book trigger; family≤3 /
  symbol≤2 caps; hard pairwise-correlation 0.50 cap; Q17 mandatory min-lot + fixed 14-day wait;
  HR16 one-research/one-EA-at-a-time; "drain everything before a book" Zwischenziel; hard FTMO
  speed targets; "Way to 25" business goal on live surfaces.
- **Removed / reclassed (in HEAD):** `book_build_guard.py:31-34` 25-trigger → **DIAGNOSTIC/SUPERSEDED**
  (commit `a5453d3b94`); caps → **ADVISORY** (`589858dc66`); correlation → admit-with-WARN +
  dependence panel, mechanism kept (`7951787c50`/`589858dc66`); Q17 → evidence-based probation
  (`b83f8adbfa`); HR16 → controlled parallelism (`b83f8adbfa`); FTMO speed → secondary diagnostic;
  "Way to 25" relabelled to diagnostic pool across cockpit/morning-brief/heartbeat (`aaaede446c`).
  The `i3` sweep then caught **3 code/prompt + 4 vault residual `ACTIVE_BUT_OBSOLETE` survivors** that
  Phase-B slices missed (OLD_RULES_SWEEP_2026-09-15.csv) — e.g. `render_cockpit_v2.py:1384`
  "Weg zu 25", Q17 vault residuals, `autonomous_loop.md:253` HR16, Business Model FTMO-60d target.
  **0 gate thresholds / verdict semantics / validator-pinned tokens were changed** in either wave.
- **Kept intentionally (STILL_ACTIVE_AND_INTENTIONAL):** `MIN_QUALIFIED_PAIRS=25` as a diagnostic
  reference constant; `QM_News.mqh` 14-day staleness (safety, class A); correlation
  `CLUSTER_CORRELATION_UNVERIFIED` fail-closed; worker CPU/RAM/disk safety; FTMO purchase evidence
  gates (FUND_SCORE floor etc., OWNER-only purchase); density as a positive input; AI-quota runaway
  guards; backtests never throttled.

### DOCUMENTATION — remaining drift
- **s10 completeness matrix: 33 items, 30 EXISTS_MATCHES + 3 fixed → 0 MISSING/DRIFTED** (`i3`,
  `DOCUMENTATION_COMPLETENESS_MATRIX_2026-09-15.md`). Canonical pages that were missing now exist in
  HEAD (CONTINUOUS_BOOK_EVOLUTION, RULE_EFFECTIVENESS_AUDIT_2026-09, FTMO_DEMO_VALIDATION_CONTRACT,
  FTMO_CHALLENGE_READINESS, AUTONOMOUS_EDGE_DISCOVERY — all verified present).
- **Remaining drift (residual, non-gating):** generated-wiki lint (3535+ legacy-symbol / broken-link
  hits, *all inside* `09 Strategy Wiki/generated/*` + Drive-sync race — governance-lint owner);
  per-EA `framework/EAs/QM5_*/SPEC.md` bulk "min-lot / Q13" rows (SPEC-template generator slice);
  `build_backup_retention_manifest.py` `PATH_TO_25` naming (downstream JSON key consumed — retention
  slice); `12 ToDo/09_Research_Sourcing.md:45` HR16 parenthetical (low value). None change gate logic.

### AI ORCHESTRATION — health measured (`orchestration_health.json`, `health=AMBER`)
- **Routing correctness 40/40 OK, 0 mismatch** (`routing`). Kimi authority guard intact.
- **Critic independence DEGRADED** — 4/5 recent critiques same-vendor (`same_vendor_share=0.80`),
  cause = Codex + agy critic lanes quota-gated (`critic_chain`).
- **Stale:** 2 IN_PROGRESS beyond 30-min TTL (`3e0c8b83`, `42a437a4`, leases expired, owner_pid null);
  308 unassigned TODO older than 14 days (`stale_tasks`).
- **Fan-out fix landed** (`ac2db161ef` exec-lease + `--max-sessions 1` interim) but **not yet
  demonstrated live** — the claude lane is quota-disabled at `--max-sessions 1`, so
  `exec_lease_scheme_present=false`/`exec_leases_total=0` (`double_claim_guard`); this is the
  orchestrator's exit criterion when re-raising to `--max-sessions 3`.
- **Kimi telemetry:** real endpoint wired (`api.kimi.com/coding/v1/usages`); current fetch is
  `auth_error / token_stale`, `last_ok` reused (plan Allegro, 5h/7d ratios 0.0) — the read-model is
  honest about the transient. Claude weekly 97% (hard-ceiling hold), Codex 80% (budget-line hold),
  agy 401 token_expired.

### RESOURCES — §17 final state
- **Research disk guard fixed and no longer blocking.** Guard now watches the scratch volume
  research actually uses (**C:**), floor **20 GB**; live `research_guard.allowed=true`,
  `scratch_free_gb≈46`, `scratch_on_factory_drive=false`, `free_ram_gb≈28.5`, `max_worker_processes=2`
  (`orchestration_health.json.research_guard`; landed commit `7139ccf959`). The empirically
  unjustified 80 GB D: floor is retired; factory low-water 60 GB is shared config; invariant
  `worker_floor(40) ≤ purge_low_water(60) ≤ research_floor`. D: free is a VOLATILE snapshot (73.3 GB at audit time, 52.8 GB at critic time;
  `factory_bottleneck.json.resources`, tester cache churn) and no longer gates research. MT5/live headroom untouched.

### OWNER — what genuinely requires OWNER action now (§21 strict standard)
Applying the both-conditions test (material economic/operational impact AND unresolvable under
existing authority), **no new blocking OWNER decision arose.** The items below are known standing
OWNER-only gates, presented for completeness with issue / evidence / alternatives / impact /
recommendation / rollback. Detail in the OWNER ACTIONS section.
1. **Sunday DXZ v2 cutover** — standing OWNER-only (Market-Watch add + AutoTrading toggle).
2. **Antigravity (agy) OAuth relogin** — clears 401/token_expired; restores cross-vendor critic independence.
3. **(Optional) Codex budget-line exemption** — only if OWNER wants Phase I applied inside this week's budget.
4. **DXZ ADD_SLEEVE 10700:XAUUSD** — **NOT a separate OWNER decision**: 10700/XAUUSD is already one of
   the v2 cutover's four new sleeves, covered by the existing Freifahrtsschein scope-1–3 approval.

### PRIMARY QUESTION (§1) — verdict: **PARTIALLY (strongly trending to YES)**
The operating model is built, documented, and demonstrated end-to-end — but it is **not yet fully
self-sustaining** (Phase I not committed/scheduled; FTMO book not representative; no live money
signal). See verdict section for the ranked top-5 gaps and the fix table.

---

## 1. COMPANY KNOWLEDGE (directive §2–§8)

**Vault completeness is now a machine check, not an assumption (§6).** `strategy_wiki_sync.json`
(schema `qm.strategy-wiki-sync.health/v1`, generated 2026-09-15T16:19Z):

| Metric | Value | Source |
|---|---|---|
| STRATEGY_WIKI_SYNC | **GREEN** | `strategy_wiki_sync.json` |
| canonical_records / valid_projections | 3820 / 3820 | same |
| projected_nodes | 5265 | same |
| missing / stale / duplicate / orphan / invalid_link / unresolved_source / unresolved_lineage | 0 / 0 / 0 / 0 / 0 / 0 / 0 | same `counts{}` |
| Vault generated `.md` on disk | 5266 | `G:/…/09 Strategy Wiki/generated/**` (PowerShell recount) |
| class subdirs on disk match read-model | ACTIVE_CANONICAL 3820, REJECTED 893, RETIRED 356, DRAFT 130, HISTORICAL 55, DUPLICATE 7, SUPERSEDED 4 | disk vs `class_counts` |

**§3/§5 projection classes are unmistakable** (one folder per class under `generated/`), so the Vault
helps a reader understand the universe without pretending every historic idea is viable. **§7 idempotency**
is designed in (converged rebuild ~24s, 50 written / 5215 skipped / 4 pruned per the i1 report).
**§8 provenance:** internal `QM-RESEARCH://` artifacts resolve; external non-QM-RESEARCH `source_hash`
still emits EVIDENCE_MISSING (durable hash lives in the vault `sources/*` graph, not the card) — a
documented follow-up, not a GREEN blocker.

**Duplicate / edge-lineage map (§9)** — `lineage_map.json` (`i2`, generated 2026-09-15T18:09Z):
768 edges over 4098 nodes (4080 with mechanism_signature + 18 seed/boilerplate). Classes:
exact_clone 264, close_implementation_clone 390, parameter_variant 37,
same_edge_different_implementation 60, child_challenger 1, superseded 4, materially_different 12.
59 identical-signature exact-clone clusters cover 364 EAs (largest = 221). Balke/Gold-Reaper/ORB/XAU
families resolved behaviour-first (Jaccard/ρ + rule-hash), gaps recorded not guessed. Published to
Vault `09 Strategy Wiki/Lineage Map.md` and `docs/research/STRATEGY_LINEAGE_MAP_2026-09.md`.

**Residual (does not move GREEN):** the recurring sync task
`QM_StrategyFarm_StrategyWikiSync_60min` and a lineage health line are **not registered** (RED
boundary — installers written, orchestrator registers). Until then, GREEN is a point-in-time result.

---

## 2. DXZ — CONTINUOUS WEEKLY RECOMPOSITION (§12)

**Operational.** Registered tasks (`Get-ScheduledTask QM_*`, live): `QM_BookEvolution_FridayEvidenceCut`,
`_SaturdayAnalysis`, `_SundayRecommendation`, `_RuntimeVerify` (all `Ready`) +
`QM_StrategyFarm_BookEvolutionReadModels_15min`. Canonical contract `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md`
(HEAD). Engine `tools/strategy_farm/portfolio/recompose/` (commit `e61e6d5261`, metrics include
effective_number_of_bets, downside correlation, overlap; §70 byte-identical regression test).

**§12 dry-run (frozen inputs, deterministic) concluded a real decision, not a count-block:**
`D:/QM/reports/book_evolution_dryrun/2026-W38/cuts/dryrun-20260915/`:
- DXZ outcome **ADD_SLEEVE** — add 10700:XAUUSD.DWX; materiality delta_objective +0.01216, material=true,
  §59 cleared; expected book: 25 sleeves, ENB 23.9, Sharpe 2.58, return/maxDD 3.41, total risk 11.00%,
  worst_day −0.93% (`OWNER_DECISION_PACKAGE.md`, `recommendation_index.json.per_venue.dxz`).
- FTMO outcome **CONTINUE_OBSERVATION** (owner_action NONE).
- Full chain present: `inputs/` frozen read-models → `snapshot/` streams → `analysis/*/evaluation.json`
  → `*_cross_review.json` → `chain/*/chain_receipt.json` → `OWNER_DECISION_PACKAGE.md`. Weekly default
  is KEEP; this week the engine chose CHANGE — proving both branches are reachable.

**Live read-model** `book_evolution_dxz.json` (schema `qm.book-evolution-venue/v1`): incumbent
`live_24` (24 sleeves), 20 challengers evaluated, exactly 1 material (10700:XAUUSD.DWX),
next_recomposition `2026-09-20T10:00Z`, `owner_action=REVIEW_PROPOSED_CHANGE (…AutoTrading remain OWNER-only)`.

**Blockers:** (a) cross-review critic `gated`/`NOT_EVALUATED` — Codex+agy quota-down; the engine
records it truthfully and does not block. (b) **Live per-sleeve PnL attribution = EVIDENCE_MISSING** —
`book_evolution_dxz.json.evidence` uses only live DD/equity; there is no per-sleeve money feed, so
incumbent-vs-challenger fitness is stream-based, not realized-PnL-based (Phase-E live-feed item).

---

## 3. FTMO — DEMO VALIDATION (§13, §14)

**Operational and deterministically answerable.** `ftmo_challenge_readiness.json`
(schema `qm.ftmo-challenge-readiness/v1`) + `ftmo_demo_cycle.json` (schema `qm.ftmo-demo-cycle/v1`)
answer every §13 question:

| §13 question | Answer | Source field |
|---|---|---|
| Exact portfolio under validation | 8 sleeves, roster_hash `6c5383d87777…` (10706/GBPUSD, 11421/EURUSD, 11422/USDCAD, 11910/NZDUSD, 13054+20048/USOIL.cash, 1537+21505/XAGUSD), 0.3125% each, total **2.5%** | `ftmo_demo_cycle.roster`, `sleeve_count`, `total_book_risk_pct` |
| Representative period start | `2026-09-15T14:12:11Z` (first observation of current roster hash) | `cycle_start_utc`, `cycle_start_provenance` |
| Composition changed materially? | No — `material_changes=[]`, `latest_change_assessment.material=false` | `ftmo_demo_cycle` |
| Evidence representative? | **No** — validation **0.09 / 14 days**, `representative=false` | `validation_days`, `representative` |
| Daily loss / max DD / target progression | current cycle −0.18% / −0.29% / −1.46%; worst cycle −2.34% / **−10.26%** | `ftmo_challenge_readiness.metrics` |
| Simulated Challenge survival | `challenge_survival=FAIL`: 0 admitted, best FUND_SCORE 0.41 vs floor 1.0; first_passage EVIDENCE_MISSING | `fitness.fitness_axes` |
| Strongest failure mode | "Total-loss breach in a demo cycle: realized max-DD −10.26% vs 10% limit" | `strongest_failure_mode` |
| Remaining before OWNER buys | representative 2-week demo of an FTMO-fit roster + computed first-passage; proven inventory is swing (wrong profile) | `recommendation=NOT_READY`, `rationale`, `blockers=[]` |

`would_fable_buy_today = {answer:false}`. **§14 materiality contract:** `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md`
(HEAD) — deterministic seven-factor material-change semantics (sleeve add/remove, risk, mechanics,
compliance/news, execution product) with an economic band, avoiding both over-reset and false-carry.
The demo-cycle read-model already applies it (`latest_change_assessment.resets_cycle` logic).

**Main blocker to a paid Challenge:** structural, not compute. The economically-relevant edge for
FTMO is a **session-flat, high-density, low-swap** direction; the entire proven inventory is
D1/H1/H4 swing (the opposite), so `challenge_survival=FAIL` and no representative FTMO-fit book has
completed a rule-faithful 2-week demo. First-passage / breach-probability (`challenge_firstpassage`)
is not yet computed for any pool (slice F1 pending).

---

## 4. RESEARCH — AUTONOMOUS EDGE DISCOVERY & KIMI (§15, §16, §19, §20)

**§16 checklist: all YES (one documented caveat).** Evidence in the Executive RESEARCH block. The
integrated provider now actually researches: `CAMP-2026-0001-ftmo-gap` ran (live 15.5-min Kimi call),
produced sealed hash-verified `QM-RESEARCH-2026-0001/0002` (`research_source_ledger.jsonl`), was
cross-vendor critiqued (Claude/Fable, `cross_vendor=true`, verdict REVISE), and created both a
mechanizable hypothesis (H-CW) and durable negative findings (H1 inconclusive, H2 refuted-in-proxy,
H3 not established). **Caveat:** the *automated* `agent_chain` critic was quota-gated and the critique
ran as the Fable-inline fallback — cross_vendor is honestly true, but automated cross-vendor
independence is degraded until agy/codex quota return.

**§15 Kimi telemetry:** the real endpoint `GET api.kimi.com/coding/v1/usages` is integrated
(`kimi_quota_fetcher`, commit `81718ab2be`), `usage_source=managed_usage_endpoint`. Current fetch is
`auth_error/token_stale` with `last_ok` reuse (plan Allegro, 5h/7d used_ratio 0.0, reset times
present) — `kimi_quota_state.json`. Mission Control shows real capacity when the token is fresh and
falls back to the local ledger as a runaway guard (40/200 → runaway floor). This refutes the earlier
"no programmatic usage endpoint" claim.

**§19 economic map** (`strategy_universe_map.json`, `qm.strategy-universe-map/v1`): universe = 14,939
(EA×symbol) pairs (Q02+), qualified 29, DXZ incumbent 24, FTMO incumbent 8. Style shares:
short-duration FX intraday/scalp **27.42%** (4,096), mean-reversion **10.68%** (1,595), breakout
**10.32%** (1,541), gold **9.15%** (1,367), session-tagged only **4.38%** (14,285 unspecified),
high-density FTMO-fit only **1.05%** (157). **Top white space** = mean-reversion × intraday ×
session-open × index (EV 34), then scalp/index and pattern/index open cells — all with `n_pairs=0`.
This is the actionable misallocation signal: the highest-EV / highest-FTMO-fit cells are empty while
inventory over-indexes swing.

**§20 external-source ROI** (`research_roi.json`, `qm.research-roi/v1`): origin distribution over 4,876
registry EAs = external_source 4,307 / owner_mission 515 / internal_discovery 48 / commercial_rebuild
6 / failure_mining 0. Funnel yields (admit-per-Q02): external 4307→2781(Q02)→229(Q08)→33(Q14)→26 book
= **0.935%**; internal_discovery 48→44→4→0→1 book = **2.273%**; owner_mission 515→418→18→2→2 book =
0.478%; commercial_rebuild 6→1→0. **`economic_contribution.pnl = EVIDENCE_MISSING`** (no per-EA PnL
attribution artifact) — book_admission is used as the closest signal. Read: internal discovery already
out-yields external harvesting per-unit; the objective now is money-ROI, which needs a PnL feed.

---

## 5. AI ORCHESTRATION HEALTH (§18)

`orchestration_health.json` (schema `qm.orchestration-health/v1`, `health=AMBER`):
- Routing 40/40 OK, 0 mismatch; Kimi authority guard intact (no code/tests/repo_edit/ops caps).
- Critic independence DEGRADED (same_vendor_share 0.80, 4/5) — Codex+agy quota-gated.
- 2 stale IN_PROGRESS (`3e0c8b83`, `42a437a4`); 308 unassigned TODO >14d.
- Fan-out fix landed (`ac2db161ef`) but not demonstrated live (claude quota-disabled, `--max-sessions 1`;
  `exec_lease_scheme_present=false`).
- Lanes: claude weekly 97% (hard ceiling), codex 80% (budget-line hold, reset 2026-09-19), agy 401
  token_expired, kimi NORMAL (managed endpoint, day 6 / runaway 120).

**§18 known issues status:** duplicate session fan-out — fix landed, live-proof pending; double claims —
guard present, router leases NULL-owner by design; stale tasks — 2+308 measured with a disposition
plan (`stale_task_disposition_plan_2026-09-15.csv`: PARK 275 / KEEP 59 / COMMISSION 49 / CLOSE 16);
silent review-independence loss — now surfaced in the read-model (the gap was visibility, now fixed).

---

## 6. OWNER ACTIONS (§21 strict standard — issue / evidence / alternatives / impact / recommendation / rollback)

No item meets both §21 conditions as a *new* decision. The standing OWNER-only gates:

**A. Sunday 2026-09-20 DXZ v2 cutover (standing OWNER-only).**
- Issue: cut over the 24-sleeve live book to the staged 28-sleeve v2 (cutover risk 9.8013% → post-burn-in 11.0%).
- Evidence: `decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md`; profile
  `C:/QM/deploy/DXZ_V2_20260913/profile/DarwinexZero_Book2_LiveOps/profile_manifest.json`; preflight all-green.
- Alternatives: cut over Sunday; defer one week; cut a subset.
- Impact: money/live risk — direct book composition + risk-budget change.
- Recommendation: proceed per the approved plan (adds XAGUSD+WS30 to Market Watch, then AutoTrading).
- Rollback: `tlive_book_cutover` preserves presets 01–24; recovery pointer restores the incumbent.

**B. Antigravity (agy) OAuth relogin (known OWNER-lane action).**
- Issue: agy token expired (HTTP 401 `token_expired`), `AGY_LOW_QUOTA.flag` on.
- Evidence: `orchestration_health.json.lanes.gemini.quota` (`token_expired:true`).
- Alternatives: relogin now; leave down (research + cross-vendor critique stay degraded).
- Impact: research speed + review independence (critic collapses to same-vendor without agy/codex).
- Recommendation: relogin — it is the single highest-leverage cheap fix for critic independence.
- Rollback: none needed (auth refresh).

**C. (Optional) Codex budget-line exemption for Phase-I apply.**
- Issue: applying the five Phase-I patches + a couple of scheduled-task registrations is Codex/orchestrator work while Codex is budget-held (80%, +33pts ahead, reset 2026-09-19).
- Evidence: `codex_budget_line.json`; `orchestration_health.json.lanes.codex`.
- Alternatives: wait for the 2026-09-19 reset; grant `codex_budget_line_exempt` for this task; apply via the claude/orchestrator lane.
- Impact: research/ops speed only (no money/live risk).
- Recommendation: wait for reset unless OWNER wants STRATEGY_WIKI_SYNC self-sustaining before Sunday; then exempt.
- Rollback: `QM_CODEX_BUDGET_LINE=0` / remove the exemption tag.

**D. DXZ ADD_SLEEVE 10700:XAUUSD — NOT a new OWNER decision.**
- The weekly engine's proposed add (10700:XAUUSD.DWX) is **already one of the v2 cutover's four new
  sleeves** (1537/XAGUSD, 9641/WS30, **10700/XAUUSD**, 13013/NDX — `manifest_v2_28_r11.json`,
  Phase-A snapshot §1.2). It is covered by the existing Freifahrtsschein scope-1–3 approval and the
  Sunday cutover review. Fold it into the Sunday review; do **not** raise it as a separate ask.

---

## 7. PRIMARY QUESTION VERDICT (§1)

**Is QuantMechanica now a coherent, continuously-learning trading company? — PARTIALLY (strongly
trending to YES).** The knowledge layer (STRATEGY_WIKI_SYNC GREEN + lineage), the weekly
recomposition engine (registered tasks + proven §12 dry-run reaching CHANGE without a count-block),
FTMO Demo observability (every §13 question answered deterministically), the research loop (a real
sealed cross-vendored Kimi campaign + autonomous-discovery charter), the architecture cleanup (all
listed obsolete rules superseded; 0 gate thresholds touched), and the resource guard fix are all in
place. It is **not yet fully self-sustaining**: Phase-I generators are not committed/scheduled, the
FTMO book is not representative or FTMO-fit, and there is no live money signal.

### Top-5 remaining gaps (ranked by business impact)

| # | Gap | Evidence | Concrete next action |
|---|---|---|---|
| 1 | **No representative FTMO-fit book; proven inventory is swing (opposite profile); first-passage uncomputed** | `ftmo_challenge_readiness.json` (FAIL, best FUND_SCORE 0.41<1.0); `strategy_universe_map` high-density FTMO 1.05% | Mechanize H-CW (session-flat index continuation) to Q00; run a rule-faithful 2-week demo on that roster; implement `challenge_firstpassage` (slice F1) |
| 2 | **Live per-EA PnL attribution = EVIDENCE_MISSING** → portfolio fitness + research ROI have no money signal | `research_roi.json` (pnl EVIDENCE_MISSING); `book_evolution_dxz.json.evidence` DD/equity only | Build per-sleeve live attribution feed from `Bases/Darwinex-Live/trades/4000090541/deals_*.dat`; wire into fitness + ROI |
| 3 | **Phase-I not self-sustaining** — wiki-sync/lineage tasks unregistered, i1–i5 patches uncommitted → GREEN is a snapshot | patches at `<scratchpad>/patches_i/*.patch`; `QM_StrategyFarm_StrategyWikiSync_60min` absent from `Get-ScheduledTask` | Orchestrator applies i1–i5, registers the 60-min sync + lineage health tasks |
| 4 | **Cross-vendor critic independence degraded** (agy 401, codex budget-held) | `orchestration_health.critic_chain.same_vendor_share=0.80`; lanes gemini/codex | OWNER agy relogin (Action B); let codex reset 2026-09-19; re-run critique-pending |
| 5 | **Research misallocation risk** — highest-EV / FTMO-fit universe cells are empty while inventory over-indexes swing | `strategy_universe_map.whitespace_ranked` (top cells n_pairs=0); `research_roi` internal yield 2.27% > external 0.94% | Feed whitespace into Kimi/Fable prioritization (programmes ACTIVE); shift new research to mean-reversion×intraday×index-open + high-density FTMO |

### What this programme fixed today (commit ids, HEAD)

| Area | Fix | Commit |
|---|---|---|
| Book trigger | 25-candidate → diagnostic; gate_manifest book_trigger/draft_note drift | `a5453d3b94` |
| Portfolio caps | family/symbol/correlation caps → ADVISORY + dependence panel | `589858dc66`, `7951787c50` |
| Research disk guard | watch scratch volume (C:) floor 20 GB + shared 60 GB low-water; author generalized | `7139ccf959` |
| Kimi telemetry | real `coding/v1/usages` fetch wired into governor; bounded token refresh | `81718ab2be`, `8a3ba58fea`, `4ad7ab7016` |
| Docs/policy | RULE_EFFECTIVENESS_AUDIT, CONTINUOUS_BOOK_EVOLUTION, Q17 evidence-based | `b83f8adbfa` |
| Fan-out | per-task pid-owned exec leases; claude interim `--max-sessions 1` | `ac2db161ef` |
| Mission Control | Book Evolution view + FTMO readiness + factory_bottleneck read-model; 25-counter → diagnostic | `7bf54a133c`, `aaaede446c`, `22597ce2a2` |
| Portfolio engine | deterministic recompose (freeze/evaluate/metrics/materiality/decide) | `e61e6d5261` |
| FTMO | rules snapshot + rulepack rebind; demo-cycle ledger + material-change contract; fitness + readiness (NOT_READY) | `992c59d1af`, `769cf3f0e5`, `871dc4ca58` |
| Research | AUTONOMOUS_EDGE_DISCOVERY charter; first real Kimi campaign sealed QM-RESEARCH-0001/0002 | `32e130dd03`, `8a9e20d053` |
| Weekly automation | recomposition runner + installer + 2026-W38 dry run | `efb5d8ed8c`, `9976ddbaa3` |

### Phase-I patches the orchestrator still needs to apply

`<scratchpad>/patches_i/`: `i1_strategy_wiki_sync.patch`, `i2_lineage_map.patch`,
`i3_old_rules_sweep_docs.patch`, `i4_universe_map_roi.patch`, `i5_orchestration_health.patch`
(plus this audit's own slice patch `i6_completeness_audit.patch`). After applying, register
`QM_StrategyFarm_StrategyWikiSync_60min` (installer in i1) and the lineage health task (i2) to make
STRATEGY_WIKI_SYNC self-sustaining.

### Blocking review findings

**None are RED / blocking** (i1–i4 ACCEPT, i5 ACCEPT_WITH_FIXES, all `red:false`). Two **major
non-blocking** findings from the i5 review the orchestrator must reconcile at apply time:
1. **Applier docstring / `STALE_TASKS_DISPOSITION` safety claim is inaccurate** — `agent_router._update_task_once`
   runs `verdict=COALESCE(?, verdict)` (line ~2903), which **overwrites** the task-lifecycle
   annotation when `--apply` passes a verdict; the "appends a verdict; existing verdicts untouched"
   wording must be corrected to "overwrites the task-lifecycle annotation". Not a gate verdict / trade
   stream; candidate-gated; no `--apply` was run.
2. **`ORCHESTRATION_HEALTH_2026-09-15.md` prose overstates its own read-model** — the static MD showed
   Kimi `fetch_status=ok` and `research_guard allowed=true / RAM 30 GB free`, whereas the machine
   read-model was `auth_error/token_stale` and (at that instant) `RAM_LOW`. The read-model is honest;
   the prose must be reconciled or stamped as a RAM/token-volatile snapshot. (Re-verified now: the
   live guard reads `allowed=true`, scratch C: 46 GB, RAM 28.5 GB — the RAM_LOW was transient.)

---

*Generated by the i6 completeness-audit slice. Every number above was re-verified read-only against
runtime state (`D:/QM/reports/state/*`, `D:/QM/reports/book_evolution*`), the Vault
(`09 Strategy Wiki/`), the sealed research ledger, `Get-ScheduledTask QM_*`, the farm DB via
orchestration/factory read-models, and `git log 6019af7a17..HEAD` at audit time.*


---

## Orchestrator close-out annex (2026-09-15 ~17:2xZ)

- Phase-I patches i1–i6 APPLIED and committed (`0a19623231`, `b5ef49ac77`, `32afb00057`, `e5844fb090`, `2bfc27dece`, `743dbc716f`, `8672210f57`, `dba804196e`); gap #3 ("Phase-I not self-sustaining") is closed: `QM_StrategyFarm_StrategyWikiSync_60min` (lineage map → build → index → lint) and the extended `QM_StrategyFarm_BookEvolutionReadModels_15min` (adds orchestration health, universe map, research ROI) are registered and Ready.
- Stale-task disposition plan applied with `--allow-candidate-park` (receipt in the evidence dir): 324 rows executed (COMMISSION 49, PARK incl. build_ea candidates, KEEP 59 untouched); the 16 candidate `CLOSE` rows were deliberately NOT executed (candidate-pool action, needs `--allow-candidate-close`, left for the weekly review). Note per review finding 1: the applier passes a task-lifecycle annotation through `agent_router` `verdict=COALESCE(?, verdict)`, i.e. it OVERWRITES that annotation column on the touched agent_tasks rows; this column is not a gate verdict or trade stream.
- Review finding 2 (ORCHESTRATION_HEALTH prose vs read-model): the read-model is authoritative; the prose figures are RAM/token-volatile snapshots.
- Test-suite state at close-out: the four real regressions from the FTMO rules refresh were fixed (`aabacec330`, `769cf3f0e5`, `c30b121289`, `0c52cefb02`, `6794e1b8fb`, `871dc4ca58`, `4aaedf94db`). A residual class of ~44 static tests (review-rework set-file cohorts, set_priority_track, atomic-claim SH-3, v4 readiness) flips with the live working tree — the factory writes stress `.set` files into `framework/EAs/*/sets` (367 untracked today) and those tests read `C:/QM/repo` absolute paths; they fail on the untouched baseline export as well and are not programme regressions. Ticket-worthy: make those tests tree-independent.
