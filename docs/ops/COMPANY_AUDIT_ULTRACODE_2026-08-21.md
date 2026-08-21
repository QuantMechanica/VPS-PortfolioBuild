# COMPANY AUDIT (ULTRACODE) — 2026-08-21

**Trigger:** OWNER directive "Factory CEO — Prompt" (Desktop, mirrored 2026-08-21): full audit,
Vault rebuild, gate redesign, framework analysis, ToDo re-orchestration.
**Method:** 8 parallel audit agents (Vault core / Vault pipeline / Vault infra / Vault state+ToDo /
framework reality / pipeline reality / sessions 08-13..08-21 / desktop+website), 867k tokens,
all findings file-evidenced. Synthesis: Claude (orchestrator).
**Companion plan:** Vault `12 ToDo/00_CEO_Masterplan_2026-08-21.md` (canonical ToDo program).

---

## 1 · P0 finding — FIXED in this session

**T_Live AutoTrading authority was mis-documented as "OWNER + Claude" on 5 active Vault pages
(8 occurrences).** Canon (Vault Hard Rules + CLAUDE.md): toggle = **OWNER only**, no AI seat;
Claude verifies pre-flight read-only. Fixed 2026-08-21 in: `03 Pipeline/Pipeline Overview.md`
(L62, L95), `03 Pipeline/Q12 Operational Readiness.md` (L79), `03 Pipeline/Q13 Live Burn-In
DXZ.md` (L24, L33, L70), `06 Infrastructure/Recovery Runbook.md` (L53), `04 Processes/
Source-Harvest Ultracode Prompt Set.md` (L22). `_ARCHIV` left untouched (historical).

## 2 · Vault — identity/governance core

Current & clean: 02 Org (Company Structure, Agent Routing, Stehende Vollmacht), 00 Governance
manifest(+JSON), 07 Decision Rights Overview, _HOME, START_HERE (light drift). Defects:

- `01 Identity/Business Model.md` — self-declared HISTORISCH yet linked as canonical; carries
  paperclip-era roles (DevOps, Controlling, CTO, "Token Controller"); pins live deploy to
  "Q14 PASS" (wrong topology). Needs full rewrite.
- `01 Identity/Hard Rules.md` — Rules 15/16 + exceptions name CEO/CoS/Controlling Agent
  (defunct); none of the four 2026-08 rulings present (Aktivitätskriterium OQ-18, Q09 seeds
  inert, Stehende Vollmacht zones, Factory OFF/ON by Claude).
- FTMO underweighted vs ratified "zwei Motoren" Nordstern (`08 Current State/Current
  Objective.md`): Company Overview mission prose omits FTMO; Business Model lists it 3rd.
- `00 Governance/Lint Company Reference.md` + `lint_company_reference.py` — do not police
  legacy role terms (only P-gates + "paperclip"), which is why the drift lints PASS.

## 3 · Vault — pipeline docs (Q00–Q16)

- **Q00:** R1 = source attribution only (relaxed 2026-05-15; author-agnostic) — already matches
  OWNER's instruction; page wording to be sharpened. R4 = No-ML / 1-pos-per-magic /
  deterministic / no-martingale (Hard Rule 14, binding). OWNER's "R4 kann weg" conflicts with
  HR14 → decision-queue item, recommendation KEEP (OWNER likely meant the retired author-
  reputation criterion, which is already gone).
- **Q02:** thresholds self-contradictory 3 ways (PF>1.20/150 trades/DD<15% vs PF>1.30/200/12%
  vs Overview rate-floor formula). Canonicalize to the 2026-06-26 rate-floor set.
- **Q05:** renamed "Gross Full-History Robustness" but filename/ASCII/wikilinks still "Stress
  MEDIUM". Has a documented fail-soft: dd_above_ceiling + gross PF>1.0 → Q08 salvage
  (2026-07-05); pf_below_floor stays terminal.
- **Q06:** criteria table + Overview still advertise slip×5/spread×3/commission×3 — never
  implemented; binding stress = seeded 10% trade-rejection only (re-ratified 2026-07-06).
  No fail-soft path today.
- **Q09:** Overview still describes retired "default Mode 3 / choose best of 7" workflow;
  actual = two axes (temporal 0-6 + compliance) with CONFIG_LOCKED verdicts. Gate owner
  stated 3 different ways across pages.
- **Q11:** page is DXZ-single-book only; contradicts dual-book reality (DL-084, Q11_DXZ/
  Q11_FTMO lanes, `build_book_ftmo.py`, Ops-Workflow "getrennte Lanes").
- **Q14/Q15/Q16:** vault pages purely qualitative — all numerics deferred to DL-084 + Q15 SOP
  without mirroring them.
- "Gemini" still cited as working agent on several pages (dead since 2026-07-02 → Antigravity).

## 4 · Vault — infrastructure / decisions / state / ToDo

- `VPS Layout.md` — **wrong**: live terminal named `T6_Live`, factory listed as T1–T5 only.
  Ground truth: `C:\QM\mt5\T_Live` + `D:\QM\mt5\T1..T10`. (Explains OWNER's "T6_Live?"
  question.) MT5 Architecture body is correct.
- `Risk Conventions.md` — table intact incl. Q13 min-lot burn-in row (row is CORRECT — it
  describes the 14-day live burn-in stage; recommend keep + rewrite for clarity). Missing:
  the actual live formula `risk_money = equity × (RISK_PERCENT/100) × PORTFOLIO_WEIGHT`
  (per-EA book weights); flat "0.5%" stale (live book ran 0.75).
- `EA Framework.md` — include paths wrong (`QM_Symbols.mqh` etc. don't exist; real =
  `framework/include/QM/*.mqh`, 46 modules), "Aktive EAs" snapshot = 3 EAs vs 3,755 real,
  ea_id namespace stale.
- `DL Decisions Log.md` — stops at DL-059; repo `decisions/` reaches DL-087.
- 08 Current State: 6 of 9 pages stale/misfiled (Secret-Mission trio, DXZ-23 audit, two
  TODO lists). ToDo hub: OWNER decisions split between `_INDEX.md` and empty `OWNER.md`;
  46-item Maintenance ledger (MNT-001..046, KRITISCH items included) runs invisible to the
  assignee model; missing programs: FTMO campaign, DXZ live book, research sourcing.

## 5 · Framework reality (repo)

- 46 `QM_*.mqh` includes + 8 sleeve modules; 3,755 EA dirs (3,405 built). Standard anatomy:
  5 Strategy_* hooks over untouchable skeleton.
- **Pattern filters:** `QM_PatternPermission.mqh` = closed-bar, fail-closed **blacklist veto**
  gate, 77 predicates (incl. Unger-style shapes: open/close relations, HH, close>prev-high,
  3-day-rising, gaps, calendar). Wired into exactly ONE EA (QM5_21501 census), ONE predicate
  per trial. Profile layer supports 8/side but no EA input wiring for 2–3 combos. "Unger
  filters" as require-conditions do NOT exist (confirms OPEN_ITEMS Q14 §1.2).
- **Defects still live:** predicates 31/32 (THREE_INSIDE_UP/DOWN) + 92 (FRACTAL_BREAKOUT)
  mathematically unsatisfiable; 100 (QUARTER_END) over-fires (day>=24). Fixture runner
  results CSV absent → coverage gate silently skipped.
- **Optimization tooling:** Q14/Q15/Q16 runners implemented and LIVE (14 Q14 rows: 11
  OPT_ELIGIBLE; 1 Q15 CHALLENGER_SPAWNED; Q16 waiting on challenger cascade). Supported Q14
  levers: EXIT_SURGERY, VOL_REGIME_FILTER, LOCKED_PORT, MTF_ENTRY, PREDICATE_ABLATION —
  **no news lever, no pattern-combo lever, no numeric dev-sweep emitter** (categorical only).
- `V5_FRAMEWORK_DESIGN.md` — zero mention of Q14–Q16 track; stale "SPEC ONLY" tag on
  run_smoke.ps1 (149KB, fully implemented).

## 6 · Pipeline reality (repo)

- Q00 R-gates enforced in `farmctl.py` `prebuild_validate_card()` (:2156). R1 informational
  (non-empty source_id only). R2/R3/R4 = recorded PASS + body-consistency (fail-closed);
  semantic judgement is agent/human review.
- **Fail-soft feasibility Q05/Q06: NO schema change needed.** Verdict column is free TEXT;
  taxonomy already carries FAIL_SOFT/PASS_SOFT; to advance, add token to
  `cascade_pass_verdicts` (farmctl.py ~:16342) + `phase_prev_verdicts` (~:19934) and make
  `q06_stress_harsh.py` emit it. Prefer PASS_SOFT-style token for honest dashboards.
- Q11 book builders exist (`build_book_dxz.py`, `build_book_ftmo.py`, FUND_SCORE≥1.0),
  both dry-run, lanes 0 rows — unproven end-to-end.
- News handling = 7-enum mode selection (Q09), not optimization; a per-EA news-opt would be
  a new Q14 lever (GELB rules apply), not a q09_news_mode.py change.

## 7 · Sessions 2026-08-13..21 — durable rulings a rebuild must carry

Factory HEALTHY, compute-saturated (queue drains ~08-26/28; capacity not the bottleneck).
Must-carry into Vault: Aktivitätskriterium (OQ-18, entry-day basis; pro-rata OPEN),
Stehende Vollmacht (GRÜN/GELB/ROT + 12h Auffangregel), DL-086 standing unlimited recovery
authorization (distinct from Vollmacht), Variant-A isolation consequences (directory ≠
account isolation; containment stays enabled:false), DL-084 read-inert fork, DL-087 broad
symbol allocation, sizing floor now **0.50×** (not 0.60×), 12%-threshold is verdict-text
only (not enforced), reboot worker-start path = FactoryWatchdog_15min (AT_STARTUP task
Disabled — runbooks wrong), ~1,014 commits on 34 branches unpushed (bundles on G: only).
In-flight, do not break: Q09 A+B v3 (v2 anchor cba63d44), Q09_NEWS/Q09_PORTFOLIO lanes,
~110 REVIEW backlog, Bug#4 short-history lock (precondition for pattern lever),
ea_metrics extractor repair (Codex 59c2e32c — Q14/Q15 DD levers NOT DECIDABLE until done).

## 8 · Desktop + website

- Website EXISTS and is deployed: source `C:/QM/deploy/quantmechanica-ops/Website/`
  (github.com/QuantMechanica/quantmechanica-ops), Netlify siteId
  2fb3e857-479b-4998-8972-3b69bf4ef914, domain quantmechanica.com (easyname DNS→Netlify),
  local-serve shortcut via `tools/Open-LocalWebsite.ps1` :8080. **Zero Vault documentation**
  (OWNER's gap confirmed). `WEBSITE.md` 5 months stale; `public-data/*.json` feed stale
  since 2026-07-28 (export task apparently not running); public contract still uses "T6" /
  "10 phases" vocabulary; hero KPI "15 EAs" unreconciled; deploy commits by unaudited "CTO"
  persona.
- `Strategy_Cards_Overview.md` (08-15, Century Suite 100 cards QM5_30001-41012) +
  `_2.md` (08-18, Master Suite 2, 20 cards QM5_42001-44004): both fresh, complementary,
  desktop-only; internal links broken (cards moved to `strategy-seeds/cards/approved/`).
- `FTMO_Factory_Hindernisse_Analyse_2026-08-16.md`: 8 ranked obstacles; top-3 = (1) net
  drift per drawdown insufficient for 60d sprint, (2) no FTMO-admissible first-passage
  evidence (cost fidelity REFUSED), (3) no atomic account-wide pre-trade risk budgeter.
  → becomes the backbone of the new Vault FTMO program (Masterplan T6/T7).

## 9 · Deliverables of this audit session

1. This document.
2. Vault `12 ToDo/00_CEO_Masterplan_2026-08-21.md` — full ToDo program with assignees +
   decision queue.
3. P0 fix applied (§1).
