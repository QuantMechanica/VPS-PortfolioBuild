# Completeness-critic review — slice i6 (QUANTMECHANICA Completeness & Gap Audit)

**Reviewer:** completeness critic (independent, read-only).
**Subject:** `docs/ops/QUANTMECHANICA_COMPLETENESS_AND_GAP_AUDIT_2026-09-15.md`
delivered as patch `<scratchpad>/patches_i/i6_completeness_audit.patch`; slice report
`.../design/i6_completeness_audit_report.md`.
**Verdict:** ACCEPT_WITH_FIXES. **Date:** 2026-09-15. **Method:** every material fact below was
re-derived from runtime by the reviewer (read-only SQLite / `D:/QM/reports/state/*.json` / Drive
vault counts / `Get-ScheduledTask` / `git`), not read out of the audit's prose.

---

## 1. Numeric spot-checks against runtime (14 claims — target was >=8)

| # | Audit claim | Runtime re-measurement | Result |
|---|---|---|---|
| 1 | STRATEGY_WIKI_SYNC GREEN; canonical 3820 / valid 3820 / nodes 5265; all 7 drift counts 0 | `strategy_wiki_sync.json`: GREEN, 3820/3820/5265, missing=stale=dup=orphan=invalid_link=unresolved_source=unresolved_lineage all 0 | **MATCH** |
| 2 | Vault generated .md = 5266; class subdirs ACTIVE 3820/REJ 893/RET 356/DRAFT 130/HIST 55/DUP 7/SUP 4 | `find G:/.../09 Strategy Wiki/generated -name *.md` = 5266; per-subdir counts identical | **MATCH** |
| 3 | book_evolution_dxz: incumbent live_24 (24), 20 challengers, exactly 1 material = 10700:XAUUSD.DWX (delta_obj +0.01216), next 2026-09-20T10:00Z, ADD_SLEEVE | `book_evolution_dxz.json`: live_24/24, 20 challengers, 1 material (10700 XAUUSD, marginal_value +0.0121591), next 2026-09-20T10:00:00, proposal ADD_SLEEVE | **MATCH** |
| 4 | FTMO readiness NOT_READY; best FUND_SCORE 0.41 vs floor 1.0; max-DD -10.26%; challenge_survival FAIL | `ftmo_challenge_readiness.json`: NOT_READY, best_fund 0.4076, floor 1.0, max_dd_worst -10.2649, challenge_survival FAIL | **MATCH** |
| 5 | FTMO demo cycle: 8 sleeves, 2.5% total risk, roster_hash 6c5383d87777..., cycle_start 2026-09-15T14:12:11Z, representative=false, material_changes [] | `ftmo_demo_cycle.json`: 8, 2.5, 6c5383d8777728ba..., 2026-09-15T14:12:11Z, representative false, [] | **MATCH** |
| 6 | strategy_universe_map: 14,939 pairs, qualified 29, DXZ 24, FTMO 8 | `strategy_universe_map.json.totals`: pairs 14939, qualified 29, dxz_incumbent 24, ftmo_incumbent 8 | **MATCH** |
| 7 | research_roi: external yield 0.935%, internal 2.273%, pnl EVIDENCE_MISSING; ext funnel 4307->2781->229->33->26 | `research_roi.json`: external yield_admit_per_q02_pct 0.935 / internal 2.273 / pnl EVIDENCE_MISSING; ext funnel exactly 4307/2781/229/33/26; registry_eas total 4876 | **MATCH** |
| 8 | orchestration_health AMBER; routing 40/40 mismatch 0; critic same_vendor_share 0.80 (4/5); 2 stale IN_PROGRESS + 308 stale TODO; research_guard C:/20 GB floor, allowed=true, scratch 46, RAM 28.5 | `orchestration_health.json`: AMBER; 40/40/0; 0.8 (4/5, independence_degraded true); stale 3e0c8b83+42a437a4 + stale_todo 308; research_guard scratch C:, min 20, allowed true, scratch_free 46.0, free_ram 28.5 | **MATCH** |
| 9 | lineage_map: 768 edges over 4098 nodes; exact_clone 264 / close_impl 390 / param_variant 37 / same_edge 60 / child_challenger 1 / superseded 4 / materially_different 12 | `lineage_map.json`: 768 edges, 4098 nodes, edge relations counted = 264/390/37/60/1/4/12 identical | **MATCH** |
| 10 | 31 programme commits since 6019af7a17; HEAD 4aaedf94db == agents/board-advisor | `git log --oneline 6019af7a17..HEAD` = 31; HEAD 4aaedf94dba..., branch agents/board-advisor | **MATCH** |
| 11 | Scheduled: 4x QM_BookEvolution_* + ReadModels_15min + KimiOrchestration_15min all Ready; StrategyWikiSync/Lineage ABSENT | `Get-ScheduledTask`: FridayEvidenceCut/SaturdayAnalysis/SundayRecommendation/RuntimeVerify + BookEvolutionReadModels_15min + KimiOrchestration_15min all Ready; StrategyWikiSync ABSENT, Lineage ABSENT | **MATCH** |
| 12 | Kimi telemetry endpoint wired; current fetch auth_error/token_stale; last_ok Allegro, 5h/7d ratios 0.0 | `kimi_quota_state.json`: source api.kimi.com/coding/v1/usages, fetch auth_error/token_stale, last_ok Allegro NORMAL 0.0/0.0 | **MATCH** |
| 13 | §12 dry-run concluded a real decision (DXZ ADD_SLEEVE, FTMO CONTINUE_OBSERVATION) with full chain files | `.../dryrun-20260915/`: OWNER_DECISION_PACKAGE.md + recommendation_index (dxz ADD_SLEEVE / ftmo CONTINUE_OBSERVATION) + inputs/snapshot/analysis/chain present | **MATCH** |
| 14 | "fixed today" commit table (a5453d3b94, 589858dc66, 7951787c50, 7139ccf959, 81718ab2be, b83f8adbfa, ac2db161ef, e61e6d5261, aaaede446c, 32e130dd03) | `git merge-base --is-ancestor` — all 10 are in HEAD ancestry | **MATCH** |

**14/14 headline facts reproduce; the audit is genuinely runtime-grounded, not answered "from
documents alone" (directive §1 satisfied).** The three deviations below are the only mismatches
found and none overturns a section verdict.

## 2. Deviations found

### MAJOR
- **`D:` free-space figure does not reproduce and its directional claim is contradicted.** The
  audit's RESOURCES/§17 block states *"D: free now **73.3 GB** (`factory_bottleneck.json.resources`),
  up from the 61.2 GB Phase-A reading."* Live `factory_bottleneck.json.resources.d_free_gb = **52.8**`
  at review time — below both 73.3 and 61.2, so the "up from 61.2" narrative is now false. This is a
  volatile metric (10-min tester-cache purge + concurrent backtests), and the §17 conclusion ("guard
  no longer blocking") is independently carried by `research_guard.allowed=true` on the **C:** scratch
  volume (46 GB free, floor 20 GB) — so it is **not verdict-changing**. Fix: label the D: number as a
  volatile point-in-time snapshot and drop the "up from 61.2" direction, or re-read at commit time.

### MINOR
- **"Sealed" rests on the summary read-model, not the durable ledger.** §16 answer "Sealed? YES" cites
  `research_state.json.kimi_campaigns[].sealed=true/status=sealed`, and the audit's own exec block
  elsewhere says the artifacts are *"status `reviewed`"*. The append-only source-of-truth
  `research_source_ledger.jsonl` terminates both `QM-RESEARCH-2026-0001` and `-0002` at status
  **`reviewed`** (4 rows: draft+reviewed each) — there is no `sealed` row in the durable ledger. The
  "Kimi actually researched / cross-vendor critiqued" conclusion stands regardless; reconcile the
  sealed-vs-reviewed wording so the §16 checklist and the durable ledger agree.
- **`validation_days` minor drift.** Audit states demo "validation 0.09 / 14 days"; live
  `ftmo_demo_cycle.json.validation_days = 0.101`. Pure elapsed-time drift between write and review;
  cosmetic.
- **`admitted_pairs` wording.** Audit says "0 admitted sleeves"; the field
  `fitness.fitness_axes.challenge_survival.value.admitted_pairs = EVIDENCE_MISSING` (the "0" is
  `sleeves_at_or_above_floor`). Harmless conflation; the FAIL verdict is correct either way.

## 3. OWNER-question discipline (§21 both-conditions test) — PASS

The audit escalates **no** item that fails the §21 both-conditions bar, and correctly de-escalates a
question a standing directive already answers:
- **A. Sunday DXZ v2 cutover** — genuine OWNER-only (AutoTrading = Hard-Rule OWNER-only; live book
  construction = ROT). Material + unresolvable under AI authority → legitimately human, and it is
  presented as a *standing gate for completeness*, not a new question. Its authorization already
  exists (`decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md`). OK.
- **B. agy OAuth relogin** — a credential action only OWNER can perform (credentials = OWNER-only);
  material to research/critic independence; not resolvable by any AI seat. Legitimate one-line human
  action, not a discretionary decision. OK.
- **C. Codex budget-line exemption** — correctly marked **(Optional)** and self-classified as
  resolvable under existing authority (wait for the 2026-09-19 reset, or apply via the orchestrator
  lane; documentation/read-only-task work is GRUEN under the Stehende Vollmacht). By §21 it is *not* a
  blocking OWNER decision, and the audit says so. OK.
- **D. DXZ ADD_SLEEVE 10700:XAUUSD** — explicitly flagged **"NOT a new OWNER decision"** because
  10700/XAUUSD is already one of the four v2-cutover sleeves covered by the Freifahrtsschein scope-1–3
  approval. This is exactly the "flag any question a standing directive already answers" check — the
  audit performs it itself. OK.

No wrongly-escalated question detected; no §21 flooding; the strict standard is respected.

## 4. Honesty / landed-vs-staged (verified)

The audit's landed-vs-staged partition is accurate: the deliverable and the i1–i5/i3 generator
outputs (`OLD_RULES_SWEEP`, `DOCUMENTATION_COMPLETENESS_MATRIX`) are **not** in HEAD (staged patches),
which `git ls-files` confirms, while the runtime read-models and vault nodes exist on disk. The
declared residuals are real, not glossed: `render_cockpit_v2.py:1384` still renders a live
"Weg zu 25 / ETA zu 25" cockpit header (an ACTIVE_BUT_OBSOLETE UI survivor the i3 sweep names, still
present because Phase-I is not applied); the WikiSync/lineage tasks are genuinely unregistered; FTMO
representative=false and per-EA live PnL = EVIDENCE_MISSING are stated plainly. The "PARTIALLY
(strongly trending to YES)" verdict is well-calibrated to this evidence.

One observation (not a finding): a few of the §11 survivors are GRUEN-safe UI/doc strings the
orchestrator could apply immediately rather than leave staged; the audit is transparent that applying
is the orchestrator's RED-boundary step, so this is a hand-off note, not a defect.

## 5. RED-boundary check

The slice is read-only as claimed: no verdict/gate/T_Live/live/queue writes; patches not applied;
no scheduled task registered. **No RED boundary crossed.**

## 6. Verdict

**ACCEPT_WITH_FIXES.** 14/14 headline numerics reproduce against runtime; the answers are
runtime-grounded; §21 OWNER discipline is correct and self-policing. Reconcile before/at commit:
(a) the `D:`-free 73.3 GB figure + "up from 61.2" direction (volatile, non-load-bearing) and
(b) the sealed-vs-reviewed wording against the durable ledger. Neither blocks acceptance.
