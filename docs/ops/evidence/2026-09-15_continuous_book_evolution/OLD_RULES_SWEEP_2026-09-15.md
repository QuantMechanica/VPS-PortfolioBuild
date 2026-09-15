# Old-Rules Sweep — surviving obsolete assumptions in code / config / UI / vault (2026-09-15)

**Authority:** OWNER follow-up directive §11 (`owner_followup_directive_completeness_verbatim.md`)
under OWNER-DEC-CBE-20260915. **Slice:** `i3_old_rules_sweep_docs`. **Auditor:** Claude
(board-advisor worktree), 2026-09-15.

**Method.** `git grep` across the ENTIRE repo (tools/, framework/, scripts/, docs/,
processes/, decisions/, config JSON, tests, `.ps1`, scheduled-task installers) plus a grep of
the hand-written Company Reference vault dirs (`01`, `02`, `03`, `04`, `06`, `07`, `08`, `12`),
for each obsolete assumption named in §11. Every occurrence is classified
**HISTORICAL_ONLY** / **STILL_ACTIVE_AND_INTENTIONAL** / **ACTIVE_BUT_OBSOLETE** / **UNKNOWN**;
ACTIVE_BUT_OBSOLETE occurrences got a safe fix in this slice (label/comment/wording — never a
gate threshold, verdict semantic, or a validator-pinned JSON token). Machine-readable rows:
`OLD_RULES_SWEEP_2026-09-15.csv` (same directory).

Most code/contract conversions the directive ordered had **already landed** in earlier slices
(b1 book-guard, b2 caps, b3 docs, b4 vault, d2 generators). This sweep confirms them, finds the
**residual survivors those slices missed**, and fixes the safe ones. The authoritative
rule-by-rule dispositions live in `docs/ops/RULE_EFFECTIVENESS_AUDIT_2026-09.md` (F1–F13); this
file is the exhaustive occurrence sweep + the residual fixes.

## Headline

- **3 residual ACTIVE_BUT_OBSOLETE survivors fixed in code/prompt this slice:**
  `render_cockpit_v2.py` dead `_render_path_to_25` "Weg zu 25" heading → diagnostic label;
  `prompts/autonomous_loop.md` HR16 "cannot violate / exactly ONE" → Controlled Parallelism (§24).
  (A third attempted fix — the byte-pinned `gate_manifest.v4.draft.json` book-trigger wording —
  was **reverted**: its bytes are sha256-pinned by `test_gate_manifest` as frozen contract
  provenance; the ACTIVE `gate_manifest.v4.json` already carries the full supersession note, so
  the draft stays as the frozen historical proposal.)
- **4 residual ACTIVE_BUT_OBSOLETE survivors fixed in the vault this slice:**
  Pipeline Operations Workflow ASCII book-trigger "≥25"; Q17 residual "14 days / min-lot"
  cadence/heading lines the b4 rewrite missed; Business Model internal `P(pass 60d)≥0.80`
  hard target.
- **No gate threshold, verdict semantic, qualification predicate, or validator-pinned token was
  changed.** Every "25" that a schema/validator/red-team/byte-hash pins is kept and labelled
  diagnostic.
- **Bulk generated / dated / sealed occurrences are HISTORICAL_ONLY** and were not rewritten
  (thousands of per-EA `SPEC.md` "min-lot" rows; dated 08-notes; sealed OWNER doctrine JSON;
  byte-pinned draft manifest; generated Strategy-Wiki REJECTED projections).

---

## 1. `>= 25` qualified-candidate objective ("Way to 25" / "Weg zu 25" / path_to_25)

| Where | Class | Note |
|---|---|---|
| `book_build_guard.py:40` `MIN_QUALIFIED_PAIRS=25`; `:45` `MIN_VALID_POOL=1`; `:263` empty-pool refusal | STILL_ACTIVE_AND_INTENTIONAL | 25 is a **diagnostic reference_pool_size**; the real trigger is a non-empty valid pool (b1). Labelled. |
| `path_to_25.py:39` `TARGET_QUALIFIED_PAIRS=25`; `:651` `reference_pool_size_superseded_utc` | STILL_ACTIVE_AND_INTENTIONAL | diagnostic; module name kept for backward-compat consumers. |
| `config/gate_manifest.v4.json:375` `qualified_candidates_ge_25`; `:376/:384` supersession note | STILL_ACTIVE_AND_INTENTIONAL | **legacy token pinned by schema (`gate_manifest.v4.schema.json:151`), `gate_manifest.py:794`, `path25_red_team.py:245`**; diagnostic semantics documented in the detail. |
| `config/gate_manifest.v4.draft.json:81/:40` `>= 25` / on_unmet "under 25 only measure" | HISTORICAL_ONLY | **byte-pinned frozen proposal** (`test_gate_manifest.test_v4_sha256_is_stable_and_binds_exact_draft_bytes`); NOT modified; active v4.json is authoritative + superseded-labelled. |
| `render_cockpit_v2.py:1384` `<span>Weg zu 25</span>` (dead `_render_path_to_25`, not in `body`) | ACTIVE_BUT_OBSOLETE → **FIXED** | relabelled heading to "Qualifizierungs-Pool (Diagnostik)", "/25"→"Ref-Pool 25 (hist.)", added a supersession comment. Function still retained-for-history but no objective wording. |
| `build_backup_retention_manifest.py:235,243,321,444,523` `PATH_TO_25` pair_class / `path_to_25_pair_count` | ACTIVE_BUT_OBSOLETE (naming) → **NOT_FIXED** | backup-retention classifier is still valid behaviour; the JSON output key `path_to_25_pair_count` is consumed downstream, so a rename is not a safe wording-only fix. Recommend a rename in the retention slice. |
| `config/owner_decision_execution.v1.json:95` "pairs on the path to the 25 keep their COMPLETE evidence chain" | HISTORICAL_ONLY | sealed dated OWNER retention doctrine (2026-08-31); describes retention scope, not a book objective. |
| `session_tools/m11_close_0906.py:23` `eta_to_25` | HISTORICAL_ONLY | dated 0906 session helper. |
| `framework/EAs/QM5_41324_…-path25-opt/*` (SPEC, card, registry, `.set`) | HISTORICAL_ONLY | an EA slug literally named "path25-opt"; immutable registry/artifacts. |
| Vault `03 Pipeline/Pipeline Operations Workflow.md:41` ASCII "≥25 qualifizierte Kandidaten" | ACTIVE_BUT_OBSOLETE → **FIXED** | ASCII line → "gültiger qualifizierter Pool (≥1)"; superseded note added after the fence (b4 had fixed the prose but missed the diagram). |
| Vault `Q15`, `Mission Control`, `Current Operating State`, `Current Objective` | HISTORICAL_ONLY | already carry supersession markers (b4). |
| Vault `10 Morning Briefing/*.html` "0/25 voll qualifizierte Paare" | HISTORICAL_ONLY | dated generated briefings; the generator was fixed forward by d2; history not rewritten. |

## 2. Global pipeline drain before book analysis

No code occurrence. Vault `Mission Control.md:54` ("continuous, not a global drain barrier, §23")
and `Current Objective` / `10_Pipeline_Leerlauf` state the new continuous-pipeline policy
(b4). **No fix needed.**

## 3. Mandatory min-lot Q17

No operative code gate (Q17 = `authority OWNER, runner MANUAL`). Occurrences:
- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md`, `BOOK_CEREMONY_RUNBOOK_2026-09.md` — **FIXED by b3**
  (SUPERSEDED blocks, evidence-based).
- Vault `Q17 Live Burn-In DXZ.md` — b4 rewrote the header/config/hard-rules table; **this slice
  fixed the 4 residual lines** (kill-switch intro, cadence row, "After Q17 PASS" heading,
  min-lot→evidence-based expansion).
- Thousands of per-EA `framework/EAs/QM5_*/SPEC.md` rows "Live burn-in (Q13) | RISK_PERCENT |
  Min-lot equivalent" — **HISTORICAL_ONLY**, generated per-EA risk-convention text with the old
  "Q13" label; **NOT_FIXED** (bulk generated; belongs in the SPEC template generator, a future
  slice).
- Vault `00_CEO_Masterplan_2026-08-21`, `Consulting Audit 2026-08-22`, `Risk Conventions` —
  dated docs / already fixed by b4.

## 4. Fixed 14-day DXZ wait

No operative code gate. **Distinct 14-day rules that are NOT this one are KEPT:** news-calendar
staleness (`QM_News.mqh`, `Q10`/`Q16` "age < 14 days", class-A safety); farm-state backup
rotation (newest-10 + trailing-14-days). Vault `Q17` residuals **FIXED** (see §3).

## 5. max 2 per symbol / max 3 per family (discrete caps)

`config/ftmo_probability_contract.v1.json:39` `family_max 3 / symbol_max 2` → `status ADVISORY`,
`former_status OWNER_RATIFIED`, `superseded_by OWNER-DEC-CBE-20260915` (b1/b2); **not
builder-enforced** (`build_book_ftmo.py:71` comment explicitly rejects a per-symbol count cap;
`recompose.py:172` "static per-symbol cap advisory"; `test_dual_book_builders.py:135` asserts
both low-corr same-symbol sleeves admitted). The **percent-of-budget** family/symbol caps
(`concentration_tail_limits.v1.json`) are a distinct, still-active economic control. **KEEP.**

## 6. Absolute pairwise-correlation cap (0.50 hard)

`ftmo_probability_contract.v1.json:30` `hard_book_admission 0.50` → `status ADVISORY`,
`former_status ROT_SEALED` (b1); `build_book_ftmo.py:322` admits-with-WARN
(`ADMITTED_CORRELATION_WARN`); `book_reoptimizer.py` `--max-corr` advisory, hard block only via
opt-in `--hard-max-corr`. `CLUSTER_CORRELATION_UNVERIFIED` stays fail-closed (§71). The **Q09
marginal 0.40** (`ftmo_timebox_eval.py:112`) and the **Q08 gate `|r|<0.50`** (vault
`Q08 Davey`) are **distinct, still-active gate criteria (RED)** — not the book-admission cap,
NOT touched. **KEEP.**

## 7. HR16 single-development

No dedicated code gate. `prompts/autonomous_loop.md:253` "HR16 sequence … exactly ONE active
source … cannot violate" → **FIXED** (rewrote to Controlled Parallelism, OWNER-DEC-CBE-20260915
§24; anti-spam pacers + determinism-first retained). Vault `01 Identity/Hard Rules` → **FIXED by
b4** (Controlled Parallelism annex). `agent_router.py` per-lane `max_parallel` / kimi
single-flight lock are distinct pacing mechanisms — **KEEP**. Vault
`12 ToDo/09_Research_Sourcing.md:45` "die nächste (HR16)" parenthetical → **NOT_FIXED**
(low-value cross-reference; canonical supersession is on the Hard Rules page).

## 8. Legacy FTMO speed targets (≤30d, 60-day first-passage as hard rules, "fastest +10%")

- `ftmo/ftmo_fitness.py:163` time-to-target = **SECONDARY** (already reframed, §57); `first_passage`
  is `DIAGNOSTIC_ONLY` (`ftmo_probability_contract.v1.json:13`); horizon 60/30 is the
  **evaluation window** (`TIMEBOX_60_30_CALENDAR`), not a pass/fail speed target — **KEEP**.
- `challenge_book_60d.py:3` "OWNER 2026-07-27 keep 60/30" — dated OWNER evaluation window; §15
  reframes *priority* (probability > speed) — **KEEP** (note only).
- No "fastest +10%" hard target found in code.
- Vault `Business Model.md:40` internal `P(pass 60d)≥0.80` hard "Anspruch" → **FIXED**
  (superseded annex, §15). Vault `FTMO Campaign.md` states the new policy (probability > speed,
  old targets listed as superseded) — **KEEP**. Dated FTMO analyses (Hindernisse, Strategischer
  Fahrplan, CEO-Audit, Schienenplan) — **HISTORICAL_ONLY**.

---

## Fixes applied by this slice

| # | File | Change |
|---|---|---|
| 1 | `tools/strategy_farm/render_cockpit_v2.py` | dead `_render_path_to_25` heading "Weg zu 25"/"/25"/"ETA zu 25" → diagnostic "Qualifizierungs-Pool (Diagnostik)" / "Ref-Pool 25 (hist.)" + supersession comment |
| 2 | `tools/strategy_farm/prompts/autonomous_loop.md` | HR16 hard-boundary → Controlled Parallelism (§24) |
| 3 | Vault `03 Pipeline/Pipeline Operations Workflow.md` | ASCII book-trigger "≥25" → valid pool (≥1) + superseded note |
| 4 | Vault `03 Pipeline/Q17 Live Burn-In DXZ.md` | 4 residual "14 days / min-lot" lines → evidence-based (§10) |
| 5 | Vault `01 Identity/Business Model.md` | internal 60d≥0.80 hard target → evidence-not-eternal-target annex (§15) |
| — | `tools/strategy_farm/tests/test_no_obsolete_rule_wording.py` | **NEW** regression guard: fails if the "Way to 25" objective wording reappears (unmarked) on `render_cockpit_v2` / `morning_brief` / `heartbeat_snapshot` / `operator_surfaces` / `path_to_25` |

## Explicitly NOT fixed (with reason)

- `gate_manifest.v4.draft.json` book-trigger wording — **byte-pinned** frozen proposal (sha256
  in `test_gate_manifest`); the active v4.json carries the supersession note. Editing it breaks
  the stamped contract provenance.
- `build_backup_retention_manifest.py` `PATH_TO_25` naming — the `path_to_25_pair_count` output
  key is consumed downstream; a rename is not wording-only. Recommend to the retention slice.
- Per-EA `SPEC.md` "min-lot / Q13" rows — bulk generated; belongs in the SPEC template generator.
- `owner_decision_execution.v1.json`, dated 08-notes, dated ToDo/Masterplan/audit pages,
  `10 Morning Briefing/*` — HISTORICAL_ONLY dated/sealed records; never rewritten.
- Generated `09 Strategy Wiki/generated/REJECTED|DRAFT/*.md` legacy-symbol mentions (GER40.DWX /
  US500.DWX) — **generated projections of REJECTED/DRAFT historical cards** that faithfully carry
  the card's real (legacy) symbol; the fix belongs in the wiki-sync generator or the source
  cards, not a hand-edit. Recommend to the wiki-sync slice.
- Vault `12 ToDo/AI ToDos/OWNER.md` GER40.DWX — the **subject of an OWNER decision** (rename the
  two cards to GDAXI.DWX); a record, not wording drift.
- Vault `OWNER.md`/`Codex.md` `P0`/`P1`/`P3` "old gate token" lint hits — **priority/coverage
  labels**, not pipeline-gate references (lint false positive; see the drift report).
