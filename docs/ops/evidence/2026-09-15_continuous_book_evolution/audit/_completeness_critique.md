# PHASE A COMPLETENESS CRITIQUE — Continuous Book Evolution snapshot

**Role:** read-only completeness critic. **Target:** `docs/ops/evidence/2026-09-15_continuous_book_evolution/PHASE_A_TRUTH_SNAPSHOT.md`.
**Method:** independently re-derived a SQLite count, a scheduled task, a drifted vault statement, the DXZ sleeve count and the FTMO terminal, plus §68A / §1 coverage checks. As-of 2026-09-15 ~14:5xZ, branch `agents/board-advisor`, live DB opened `?mode=ro`.

## Headline (3 lines)

1. **The snapshot is substantively accurate.** All five mandated spot-checks confirmed it: DXZ = 24 deployed presets, FTMO terminal pid 10836 exists, `QM_StrategyFarm_Cockpit_2min` LastResult=0x800710E0 (abort) confirmed, `_HOME.md` drift #8 confirmed, `candidate_qualifications` = 0 rows confirmed.
2. **Three defects to fix before the implementing phases act on it:** (a) a re-derived scheduled-task count disagreement (80 QM tasks, not 74); (b) one broken evidence path (`research_env.py` is under `research/`, not the cited location) that would send Phase C/§8 to a nonexistent file; (c) four §1-mandated vault sources are not cited/read.
3. **No unsafe recommendation.** Nothing in the Phase B–H breakdown crosses directive §71 or the CLAUDE.md ROT zone. Two directive-authorized items (25-trigger removal, ROT_SEALED 0.50 correlation-cap relaxation) require a minted dated decision *first*; the plan already sequences both that way.

---

## Findings

### A. §68A / §1 coverage

1. **§68 Phase A list is fully covered, each with evidence paths.** DXZ live book (§1), FTMO Demo book (§2), valid candidates (§3), robust rebuilds (§4), pipeline state (§5), AI quotas (§6), Kimi state (§7), resource constraints (§5+§8), documentation drift (§9); the two reconciliation orders ("reconcile contradictory candidate counts" / "one definition of qualified") are satisfied by §3 + "Contradictions resolved". No §68A item is uncovered or path-less. Evidence: 18 source audits confirmed present in `.../audit/` (28 files incl. `candidate_universe.{md,csv}`, `robust_rebuild_census.{md,csv}`, `kimi_quota_discovery.md`, `vault_doc_drift.md`).

2. **Four §1-mandated "read the CURRENT version of at least" vault pages are NOT cited/read in the snapshot** — and all four exist:
   - `02 Org/Company Structure.md` (directive §1: "Company Structure")
   - `04 Processes/Lessons Learned Loop.md` (directive §1: "Lessons Learned")
   - `08 Current State/Current Operating State.md` (directive §1: "current operating state")
   - `02 Org/Stehende Vollmacht Claude 2026-08-20.md` (directive §1: "Standing Authority / OWNER delegation") — referenced only via CLAUDE.md, not read from the Vault.
   Evidence: `find "G:/My Drive/QuantMechanica - Company Reference/"` returned all three named pages; none appears in the snapshot's §9 drift register or any section citation. This is material for the Rule Effectiveness Audit (§20/§21) and §67 (lesson→system-improvement), which lean directly on Lessons Learned.

3. **Directive §1 "current Git status and branch state" is not analyzed.** The snapshot names the branch in its header but reports no git-state reconciliation (the tree is heavily dirty — see gitStatus). Low business impact, but it is an explicit §1 inspection item covered without evidence.

### B. Re-derived numbers vs the snapshot

4. **Scheduled-task total DISAGREES.** Snapshot §6: "74 QM_* tasks; 6 Running healthy; 8 Disabled." Re-derived: **80 QM tasks**, Disabled = 8 (agrees), Running = 5 at my sample (Running is transient — two of my samples returned 5 and 9). Query: `Get-ScheduledTask -TaskName 'QM_*'` → `.Count = 80`. The "74" total is a real undercount (6 tasks short); "6 Running" is not reproducible (Running fluctuates 5–9). The Disabled=8 claim holds.

5. **`candidate_qualifications` = 0 rows — CONFIRMED** (snapshot §5). Query: `SELECT COUNT(*) FROM candidate_qualifications` → 0.

6. **`work_items` totals — consistent with live-DB advancement, not a defect.** Snapshot §5: total 149,116 / done 96,100 / failed 49,229 / pending 3,783 / active 4. Re-derived: total 149,117 / done 96,107 / failed 49,229 / pending 3,777 / active 4. Deltas (done +7, pending −6, total +1, failed identical) are monotone forward motion between the snapshot window and now — expected on a live queue; not a disagreement.

7. **`agent_tasks` TODO 326 vs snapshot's 325 unassigned** — live drift (+1), consistent. Re-derived state histogram: TODO 326, PASSED 1319, PIPELINE 219, APPROVED 102, BLOCKED 73, FAILED 251, IN_PROGRESS 2, OPS_FIX_REQUIRED 6, RECYCLE 10.

8. **DXZ sleeve count = 24 — CONFIRMED.** `ls C:/QM/mt5/T_Live/MT5_Base/MQL5/Presets/*.set` → exactly 24 presets 01–24; the three named dark sleeves present (06=12778/AUDUSD, 17=12969/USDJPY, 24=13117/EURGBP). Matches snapshot §1.1 and overrules the "55-pair book" phrasing correctly.

9. **FTMO terminal — CONFIRMED.** `Get-Process terminal64` → pid **10836** `C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe`; T_Live pid **9288** also confirmed (snapshot §1.1). `ftmo_trial_pulse.json` equity **99,811.51**, verdict WARN — matches §2.

### C. Evidence-path defects

10. **`research_env.py` path is wrong in the snapshot (§8, drift #24, Phase C).** Cited as `research_env.py:51 / :66`. Actual file: **`tools/strategy_farm/research/research_env.py`** (the `research/` subdir is omitted). The *values* are correct — `:51 RESEARCH_DISK_MIN_FREE_GB = 80.0`, `:66 DEFAULT_RESEARCH_DRIVE = Path("D:/")`, and a test pins it (`tests/test_research_observe_projector.py:132`). But an implementer following the cited path hits "file not found." Fix the path in the snapshot and in Phase C/E task rows before dispatch.

### D. Spot-checked drift confirmations

11. **_HOME.md drift #8 CONFIRMED.** `_HOME.md:52` = "Kanonische Quelle ist `…gate_manifest.v2.json`"; `:54` = "Standardweg Q00–Q13 und Optimierungszweig Q14–Q16." Genuinely stale vs runtime v4 linear Q00–Q17 (`gate_manifest.v4.json` active). Snapshot's drift #8 is correct; only its line span (53–55) is one line high (content is at 52/54).

12. **tester purge drift #14 CONFIRMED both sides.** `tester_cache_purge.ps1:30` default `[int]$LowWaterGB = 150` (comment `:28` "2026-07-21 raised 80->150"); the **live task action** runs `…tester_cache_purge.ps1 -LowWaterGB 60` (verified via `(Get-ScheduledTask QM_StrategyFarm_TesterCachePurge).Actions`). The script default (150) is the stale value; the effective floor is 60, consistent with measured D: ≈ 61 GB free. This also confirms the §8 invariant premise (research floor 80 > purge low-water 60 ⇒ research structurally refused on D:).

### E. Unsafe-recommendation scan (Phase B–H vs §71 / ROT)

13. **No outright §71 or ROT violation found.** Scanned §12 Phase A–I for: gate-threshold changes, T_Live/AutoTrading toggles, purchases, evidence/verdict deletion, trade-stream rewriting, qualification bypass. The plan explicitly preserves each guard ("keep OWNER-order + fail-closed on unqualified", "live toggle stays OWNER-only", "purchase stays OWNER-only", "paid purchase cannot occur through automation", "keep CLUSTER_CORRELATION_UNVERIFIED fail-closed", "never delete canonical evidence"). Three items to watch (all directive-authorized, none a violation as written):
   - **(a) `book_build_guard.py:31,238-242` <25 refusal → diagnostic + drop `qualified_candidates_ge_25`** (Phase B). This edits a contract criterion — nominally ROT — but is *explicitly ordered* by directive §4 and §68 Phase B, and §71 forbids "bypassing candidate qualification," which the plan does not (it keeps per-candidate qualification + fail-closed). Compliant *provided* the superseding decision (`decisions/2026-09-15_owner_continuous_book_evolution.md`, Phase B item) is minted first. Quote: *"`book_build_guard.py:31,238-242` <25 refusal → diagnostic (keep OWNER-order + fail-closed on unqualified)."*
   - **(b) `portfolio_correlation.py:77` (ROT_SEALED) hard corr → admit-with-WARN** (Phase B; §11 "two pre-existing tensions"). Authorized by directive §8, but the line is ROT_SEALED, so a **dated decision record must precede the edit**; the plan states "dated decision" and keeps the fail-closed CLUSTER path. Compliant only in that order. Quote: *"`portfolio_correlation.py:77` / `build_book_ftmo.py:196` hard corr → admit-with-WARN + dependence panel; keep CLUSTER_CORRELATION_UNVERIFIED fail-closed; dated decision."*
   - **(c) "Reconcile `portfolio_candidates` 13213/USDJPY + 13301/GDAXI off EVIDENCE_STALE"** (Phase A). `portfolio_candidates` is a status table, not a Q-gate verdict or trade stream, so correcting a stale flag to match live runtime is drift-correction, not §71 "evidence rewriting" — acceptable **only** as an additive, evidence-cited reconciliation (never a silent verdict overwrite).

### F. Missing modalities (a source nobody read)

14. Beyond the §1 vault pages in Finding 2: **Notion is not consulted at all** (directive §1 item 8 / §65 / §72 — context-only, so acceptable, but unstated). **Live trade streams** `Bases/Darwinex-Live/trades/4000090541/deals_*.dat` and the **DXZ D-Score** are self-flagged as MISSING by the snapshot (§1.3, §5) — correctly acknowledged, not a hidden gap. The **book_guard qualified = 26** number was NOT independently re-derived by me (would require `book_build_guard --status` against the live DB); I neither confirm nor dispute it — the snapshot's internal reconciliation of 26/28/29/34 is self-consistent and path-cited.

---

## Drift table (critique-level: snapshot says vs runtime says)

| # | Snapshot says | Runtime says | Path / query |
|---|---|---|---|
| 1 | "74 QM_* tasks; 6 Running healthy" (§6) | **80** QM tasks; Running transient (5–9); Disabled 8 | `Get-ScheduledTask -TaskName 'QM_*' \| Measure` |
| 2 | `research_env.py:51/66` (§8, drift #24, Phase C) | file is at `tools/strategy_farm/research/research_env.py` (values 80.0 / D:/ correct) | `find … -name research_env.py` |
| 3 | work_items total 149,116 / done 96,100 / pending 3,783 (§5) | 149,117 / 96,107 / 3,777 (live advancement, consistent) | `SELECT status,COUNT(*) FROM work_items` |
| 4 | drift #8 span `_HOME.md:53-55` | content at `_HOME.md:52,54` (v2 manifest, Q00–Q13+Q14–Q16) — drift itself correct | `sed -n '50,58p' _HOME.md` |
| 5 | 4 §1-required vault reads implied covered | Company Structure / Lessons Learned Loop / Current Operating State / Stehende Vollmacht not cited | `find "G:/…Company Reference/"` |

## Open questions strictly requiring OWNER

None. Consistent with snapshot §11 — no new blocking OWNER decision arises from this critique. (Standing OWNER-only gates — Sunday cutover Market-Watch + AutoTrading, FTMO purchase, agy relogin — are pre-existing and unchanged.)

## Recommended actions for the implementing phases

1. **Correct the task count** in `PHASE_A_TRUTH_SNAPSHOT.md §6` to 80 (or re-count and cite the query); drop "6 Running healthy" or mark Running as transient. Re-audit the failing-task list against the true 80 so no failing task is missed (all four spot-checked — NewsCalendar 0x1, Public_Snapshot 0x1, WorkItemLogPruner 0x1, EvidenceCohortWatch 0x3, Cockpit 0x800710E0 — reproduced).
2. **Fix the `research_env.py` path** to `tools/strategy_farm/research/research_env.py` in §8, drift #24 target, and Phase C item ("`research_env.py:51/66/65`") before Codex is dispatched, else the edit targets a nonexistent file.
3. **Read the four un-read §1 vault pages** (`02 Org/Company Structure.md`, `04 Processes/Lessons Learned Loop.md`, `08 Current State/Current Operating State.md`, `02 Org/Stehende Vollmacht Claude 2026-08-20.md`) and fold any drift into §9 + the Phase B vault-rewrite list — Lessons Learned especially feeds the §21 `RULE_EFFECTIVENESS_AUDIT_2026-09.md` and §67.
4. **Sequencing guard:** mint `decisions/2026-09-15_owner_continuous_book_evolution.md` (and the dated correlation-cap decision) BEFORE editing `book_build_guard.py:238-242` / `gate_manifest.v4.json:373-383` and `portfolio_correlation.py:77`. Keep the `portfolio_candidates` EVIDENCE_STALE reconciliation additive and evidence-cited.
5. Refresh the two live-drift numbers (work_items, agent_tasks TODO) at Phase B time rather than treating the snapshot's frozen figures as current.
