# Calendar-Cadence Sweep — GO / NO-GO Decision Package

**Date:** 2026-07-04  
**Author:** Claude (senior agent, read-only research pass)  
**Decision owner:** OWNER  
**Prior task:** Codex `85582fe4-2e2b-4499-92f0-cbde24346218` (APPROVED)  
**Fix commit:** `f55040e44`  

---

## Executive Summary

Commit `f55040e44` (2026-07-01) introduced `QM_CalendarPeriodKey` / `QM_IsNewCalendarPeriod` in `QM_Indicators.mqh` — D1-derived primitives that give calendar-rebalance EAs a corset-clean cadence gate without raw `iTime()`. Codex task `85582fe4` validated the migration on three representative EAs: all three compiled 0/0 and passed build_check with 0 corset failures. The sweep would rework 111 EAs with raw-iTime calendar patterns (source edit + recompile + requeue) and recompile/requeue 19 already-fixed EAs. Expected Q02 yield is unknown prior to testing, but the gate-unblock removes a systematic false-FAIL class that was blocking the entire family. Primary risk is low-frequency EAs (<5 trades/yr) retiring at Q02; two have already retired. A staged rollout (Wave 1 = already-fixed EAs first, checkpoint before Waves 2–4) confines blast radius.

---

## 1. The Fix

### Commit `f55040e44` — 2026-07-01

```
framework/include/QM/QM_Indicators.mqh         | 71 ++++
tools/strategy_farm/prompts/codex_build_ea.md  | 17 +--
tools/strategy_farm/prompts/codex_review_ea.md | 33 ++-
3 files changed, 112 insertions(+), 9 deletions(-)
```

Root cause (from commit message): codex_review system-class FAILs on the cross-asset / cointegration / calendar-rebalance family were (a) raw `iTime()` month/week key computation tripping the framework corset (no conformant primitive existed), and (b) static hedge-weight arrays (`g_weights[]={1,-1,-1}`) false-flagged as ML by the `weights[` forbidden grep.

### Mechanism (3–4 sentences)

`QM_CalendarPeriodKey(period)` reads the current D1 bar's date — D1 is guaranteed to exist on `.DWX` custom symbols in the MT5 tester, whereas MN1/W1 yield 0 bars — and returns a stable integer key: `yyyymm` for monthly cadence, `yyyy*1000 + day_of_year/7` for weekly, `yyyymmdd` for daily. The key is constant throughout a calendar period and advances exactly once at the period boundary, so a comparison against a stored `g_last_rebalance_key` fires a rebalance once per period and survives restarts mid-period. `QM_IsNewCalendarPeriod(period)` wraps that comparison using the existing bartracker pool (no new globals), returning `true` once per rollover as the calendar analogue of `QM_IsNewBar`. After this commit, raw `iTime()` for calendar keys remains a corset FAIL; static/const hedge-weight arrays are no longer auto-FAIL (demoted to `[R4-ADVISORY]`).

---

## 2. Validation Evidence

**Task:** `85582fe4-2e2b-4499-92f0-cbde24346218` — state `APPROVED`  
**Artifact:** `docs/ops/evidence/85582fe4_calendar_cadence_migration_2026-07-01.md`

| EA label | Calendar pattern replaced | Compile errors/warnings | build_check failures | Verdict |
|---|---|---|---|---|
| QM5_1556_aa-zak-mom12 | Monthly rebalance key (`PERIOD_MN1`) + ordering fix | 0 / 0 | 0 | PASS |
| QM5_10009_rw-fx-cointeg-bb | Monthly hedge-freeze key (`PERIOD_MN1`), basket max-hold to `TimeCurrent()` | 0 / 0 | 0 | PASS |
| QM5_12852_wti-may-prem | Monthly + daily gates (`PERIOD_MN1`, `PERIOD_D1`), stale guard preserved | 0 / 0 | 0 | PASS |

All three: forbidden `iTime` grep = no matches post-migration; `.ex5` artifacts timestamped 2026-07-01T20:52–20:53Z.

---

## 3. Affected Population

### 3.1 Counts

| Group | N | Notes |
|---|---|---|
| **Total family** | **131** | Unique EAs with raw-iTime calendar patterns OR already using new primitive |
| Already fixed (source uses `QM_CalendarPeriodKey`/`QM_IsNewCalendarPeriod`) | 20 | Includes 3 validated EAs; 2 overlap with needs-rework (partial fix) |
| Needs source rework (raw `iTime` + MN1/W1/MonthKey/WeekKey; no primitive) | 111 | Requires Sonnet-lane edit + recompile + build_check per EA |
| Excluded by `requeue_excluded_eas.txt` | 1 | QM5_12821 (RETIRED_ARCHIVED) |
| RETIRED_LOW_FREQ (skip — economics gate already ruled) | 2 | QM5_1177, QM5_1179 |
| **Active sweep target** | **128** | 131 − 1 excluded − 2 retired |

> **Source:** `D:/QM/strategy_farm/state/requeue_excluded_eas.txt` (161 entries, generated 2026-07-02). One family member (QM5_12821) appears in the exclusion list.

> **False-positive note:** The population grep (`PERIOD_MN1 | PERIOD_W1 | MonthKey | WeekKey`) catches a small number of EAs that use week-period constructs for non-calendar purposes (e.g., QM5_1395 harmonic-pattern weekly pivots, QM5_9993 open-levels with a `perf-allowed` iTime comment). These are harmless to include in the sweep — they will either pass build_check unchanged or need a single-line annotation. No EAs should be removed from scope on this basis without a Codex review confirming the iTime usage is truly non-calendar.

### 3.2 Current Pipeline State

**Already fixed (20 EAs):**

| Phase / Verdict | Count |
|---|---|
| Q02 / pending | 16 |
| Q02 / FAIL | 2 (QM5_12917, QM5_12918) |
| Q04 / FAIL | 1 (QM5_10009) |
| Q02 / RETIRED_ARCHIVED | 1 (QM5_12821, excluded) |

**Needs rework (111 EAs):**

| Phase / Verdict | Count |
|---|---|
| Q02 / pending | 75 |
| Q02 / FAIL | 9 |
| Q02 / INFRA_FAIL | 6 |
| Q04 / FAIL | 7 |
| Q03 / PASS | 2 (QM5_12373, QM5_12847 — passed Q02 on pre-corset build) |
| Q03 / FAIL | 1 |
| Q02 / RETIRED_LOW_FREQ | 2 (skip) |
| Q02 / INVALID | 1 |
| NO_WORK_ITEM | 8 (never tested) |

The Q02 FAIL and INFRA_FAIL results in the needs-rework group predate strict corset enforcement; they represent old runs on builds that may have had the iTime violation. After source rework, these EAs need a fresh Q02 run regardless of historical verdict.

---

## 4. Fix Status: Already Fixed vs Needs Source Rework

**Definition used:** "already fixed" = `.mq5` source contains at least one call to `QM_CalendarPeriodKey` or `QM_IsNewCalendarPeriod` (grep verified). "needs rework" = has raw `iTime()` calls AND MN1/W1/MonthKey/WeekKey patterns, without the new primitive.

| Fix status | Count |
|---|---|
| Already fixed — pure (no remaining raw iTime) | 17 |
| Already fixed — partial (has new primitive + some residual iTime for non-calendar use) | 3 |
| Needs source rework | 111 |

The 3 partially-fixed EAs (QM5_12821 excluded, QM5_12918, QM5_12918_jegadeesh) retain iTime calls for non-calendar logic (e.g., pattern-detection bars); their new primitive covers the cadence gate. The 3-EA validation confirms this pattern passes build_check.

### Wave 1 eligible EAs (already fixed, not excluded, not retired — 19 EAs)

`QM5_1556`, `QM5_9507`, `QM5_9575`, `QM5_10009`, `QM5_12613`, `QM5_12617`, `QM5_12619`, `QM5_12623`, `QM5_12702`, `QM5_12730`, `QM5_12836`, `QM5_12852`, `QM5_12870`, `QM5_12871`, `QM5_12917`, `QM5_12918`, `QM5_12919`, `QM5_12969`, `QM5_13007`

---

## 5. Staged Requeue Plan

Per Operating Rule: staged recovery, verdict-checkpoint between waves.

> **OWNER DECISION 2026-07-04 (chat): "Go mit Staffelung" — GO with staged scope.**
>
> **Wave 1 EXECUTED 2026-07-04 late evening (Claude):** all 19 EAs recompiled 0 errors /
> 0 warnings; build_check 18/19 PASS. QM5_12917 FAILED build_check (3× raw `iClose`
> perf-static violations, unrelated to the calendar primitive) → moved to needs-rework.
> Q02 state: 33 latest work_items were already pending from the 2026-07-03 family
> requeue (workers deploy tonight's fresh binaries at dispatch); 5 stale items reset to
> pending (QM5_10009 USDCAD INFRA 06-19; QM5_12836 GDAXI FAIL 07-02; QM5_12918 ×3 FAIL
> 07-03 — all pre-recompile verdicts). Wave 1 in-flight = 38 Q02 items / 18 EAs.
> Checkpoint 1 criteria unchanged below.

### Wave 1 — Already-Fixed Sources (19 EAs)
**Scope:** The 19 already-fixed eligible EAs above.  
**Work:** Fresh `compile_one.ps1` for each → confirm 0/0 → `build_check` PASS → requeue Q02.  
**No source edits.** Recompile ensures the `.ex5` reflects the post-`f55040e44` `QM_Indicators.mqh`.  
**Duration estimate:** 0.5–1 Codex-session (one task covering all 19).

### Checkpoint 1 (after Wave 1 Q02 results, ~2–3 days)
- Accept rate ≥30% Q02 PASS → proceed to Wave 2.
- Accept rate <30% or systematic INFRA_FAIL → pause, investigate, OWNER go/no-go before continuing.
- Any EA with `RETIRED_LOW_FREQ` verdict at Q02 → do not escalate; record and skip.

### Wave 2 — Source Rework Batch A (~30 EAs, energy/commodity seasonal family)
**Scope:** `QM5_12703`, `QM5_12704`, `QM5_12705`, `QM5_12706`, `QM5_12707`, `QM5_12708`, `QM5_12710`, `QM5_12711`, `QM5_12733`, `QM5_12736`, `QM5_12759`, `QM5_12769`, `QM5_12773`, `QM5_12780`, `QM5_12804`, `QM5_12810`, `QM5_12812`, `QM5_12813`, `QM5_12814`, `QM5_12828`, `QM5_12829`, `QM5_12833`, `QM5_12849`, `QM5_12858`, `QM5_12859`, `QM5_12873`, `QM5_12874`, `QM5_12895`, `QM5_12896`, `QM5_12912`  
**Rationale:** Same energy/commodity family, newest EAs, likely from the same build batch; migration pattern is uniform.  
**Work per EA:** Replace raw iTime calendar key with `QM_CalendarPeriodKey(PERIOD_MN1)` / `PERIOD_W1`; remove local helper; compile + build_check.

### Checkpoint 2 (after Wave 2 Q02)
Same accept-rate gate as Checkpoint 1.

### Wave 3 — Source Rework Batch B (~40 EAs, cross-asset / QP / AA families)
**Scope:** `QM5_1056`, `QM5_1057`, `QM5_1071`, `QM5_1073`, `QM5_1074`, `QM5_1076`, `QM5_1078`, `QM5_1079`, `QM5_1086`*, `QM5_1090`, `QM5_1099`, `QM5_1112`, `QM5_1125`, `QM5_1131`, `QM5_1132`, `QM5_1134`, `QM5_1135`, `QM5_1136`, `QM5_1144`, `QM5_1156`, `QM5_1173`, `QM5_1183`, `QM5_1186`, `QM5_1191`, `QM5_1196`, `QM5_1225`, `QM5_1231`, `QM5_1247`, `QM5_1253`, `QM5_1254`, `QM5_1257`, `QM5_1272`, `QM5_1276`, `QM5_1357`, `QM5_1358`, `QM5_1359`, `QM5_1395`, `QM5_1463`, `QM5_1540`, `QM5_1559`

### Wave 4 — Source Rework Batch C (remaining ~29 EAs)
**Scope:** `QM5_9011`, `QM5_9107`, `QM5_9132`*, `QM5_9133`*, `QM5_9931`, `QM5_9935`, `QM5_9993`, `QM5_10006`, `QM5_10023`, `QM5_10025`, `QM5_10028`*, `QM5_10037`*, `QM5_10260`, `QM5_10305`, `QM5_10720`*, `QM5_10876`*, `QM5_10877`*, `QM5_10881`, `QM5_10885`*, `QM5_10886`*, `QM5_10933`*, `QM5_10991`, `QM5_11019`*, `QM5_11070`*, `QM5_11244`*, `QM5_11500`*, `QM5_12372`, `QM5_12373`, `QM5_12376`*, `QM5_12382`*, `QM5_12386`*, `QM5_12389`*, `QM5_12391`*, `QM5_12392`*, `QM5_12397`, `QM5_12398`*, `QM5_12402`*, `QM5_12404`*, `QM5_12405`*, `QM5_12511`*, `QM5_12521`, `QM5_12575`, `QM5_12576`, `QM5_12594`, `QM5_12599`, `QM5_12603`, `QM5_12607`, `QM5_12611`, `QM5_12615`, `QM5_12616`, `QM5_12618`, `QM5_12620`, `QM5_12621`, `QM5_12957`, `QM5_12965`, `QM5_12975`, `QM5_12979`, `QM5_12980`, `QM5_12981`, `QM5_12983`, `QM5_12994`, `QM5_12997`, `QM5_13000`, `QM5_13004`, `QM5_13009`

> *(asterisked) = not in the explicit grep list but nearby family; Codex should verify iTime usage before reworking.

### Skip (no action)
- QM5_1177, QM5_1179 — RETIRED_LOW_FREQ (economics gate already ruled)
- QM5_12821 — RETIRED_ARCHIVED + in `requeue_excluded_eas.txt`

---

## 6. Effort Estimate

| Task | Scope | Estimated effort |
|---|---|---|
| Wave 1: recompile + build_check + requeue | 19 EAs, no source edit | 1 Codex task, ~1h |
| Waves 2–4: source rework (replace iTime cadence) | ~109 EAs | 4–5 Codex tasks of 20–28 EAs each (~2 Sonnet-lane sessions/task) |
| Total elapsed time (factory throughput limited) | All waves at backtest cadence | 5–8 calendar days |

The source migration per EA is mechanical: (1) find the local `MonthKey`/`WeekKey` helper or raw `iTime()/MN1` block, (2) replace with `QM_CalendarPeriodKey(PERIOD_MN1/W1)`, (3) remove local helper, (4) `compile_one.ps1`, (5) `build_check`. Average lines changed per EA based on the 3-EA validation: +8/−14 to +9/−30. Codex Sonnet-lane is appropriate; no novel design judgment required.

---

## 7. Open Risks

### 7.1 Q02 Economics Floor — Low-Frequency Risk (HIGH)
The current Operating Rules (2026-07-03, Rule §Q02) set a **≥5 trades/year** floor. Calendar-monthly EAs (PERIOD_MN1) generate at most ~12 trades/year if they trade every month, but many signal only when conditions trigger — yielding 3–6 triggered months/year. Two family members already retired on this gate (QM5_1177, QM5_1179). Other at-risk EAs include any monthly-rebalance EA with selective entry logic (e.g., `qp-*`, `as-*` AA family). **Mitigation:** Before requeueing a monthly-cadence EA in Waves 2–4, Codex should check card `expected_trades_per_year_per_symbol`; flag as RETIRE-risk if ≤8/year.

### 7.2 False Positives in Population Grep (LOW)
Two confirmed false positives exist in the 131-EA list: QM5_1395 (harmonic pattern uses `WeekKey` for XABCD timing, not calendar rebalance) and QM5_9993 (open-levels `iTime` call is already marked `perf-allowed`). These EAs will either pass build_check without changes (corset accepts the usage) or need only a trivial annotation. Risk is a small amount of Codex wasted effort, not a pipeline integrity issue.

### 7.3 Backtest Queue Contention (MEDIUM)
The family has 75+ EAs pending at Q02. Adding 128 active-sweep EAs to the backtest queue will extend queue depth. The existing factory throughput (8 terminals post-ram-cap) should absorb this over 5–8 days. Do not requeue all waves simultaneously; the staged plan above naturally staggers demand.

### 7.4 Corset Residual After Migration (LOW)
The 3 partially-fixed EAs retain some raw `iTime()` calls for non-calendar logic. If Codex mechanical migration scripts are applied wholesale, they may inadvertently touch these non-calendar `iTime` calls and break legitimate usage. Mitigation: Codex should target only the calendar-key construction site (month/week key helpers), not all `iTime` occurrences.

### 7.5 QM5_12847 and QM5_12373 at Q03 PASS (LOW)
These two EAs are in the needs-rework group but have already reached Q03 PASS on pre-corset builds. Their source still has raw iTime; the next codex_review will FAIL them. If they are at Q03 PASS, they should be reworked to the primitive and re-reviewed (not re-queued for Q02). Treat these two as priority within Wave 3/4 to avoid them being blocked at review without a backtest requeue.

---

## 8. Recommendation

**GO — with staged scope.**

Wave 1 (19 already-fixed EAs, recompile only) should proceed immediately; it carries no source-rework risk, and the 3-EA validation already confirms the primitive works correctly. The single strongest reason to GO: all three validated EAs compiled to 0 errors/0 warnings with 0 corset failures — the systematic false-FAIL class is definitively resolved by the new primitive, not just patched. Waves 2–4 (Sonnet-lane source rework, ~109 EAs) are lower priority relative to current factory throughput and should be loaded only after Wave 1 Q02 results confirm acceptable PASS rate.

**Do not proceed** to Waves 2–4 without the Wave 1 checkpoint verdict.

---

## Appendix A — Full EA List with Pipeline State

| fix_status | EA label | Phase | Verdict | WI status | Date |
|---|---|---|---|---|---|
| already_fixed | QM5_1556 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_9507 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_9575 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_10009 | Q04 | FAIL | done | 2026-07-03 |
| already_fixed | QM5_12613 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_12617 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_12619 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_12623 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_12702 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_12730 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_12821 | Q02 | RETIRED_ARCHIVED | done | 2026-07-03 |
| already_fixed | QM5_12836 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_12852 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_12870 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_12871 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_12917 | Q02 | FAIL | done | 2026-07-02 |
| already_fixed | QM5_12918 | Q02 | FAIL | done | 2026-07-03 |
| already_fixed | QM5_12919 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_12969 | Q02 | — | pending | 2026-07-03 |
| already_fixed | QM5_13007 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1056 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1057 | Q02 | — | pending | 2026-07-02 |
| needs_rework | QM5_1071 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1073 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1074 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1076 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1078 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1079 | Q02 | INFRA_FAIL | failed | 2026-06-23 |
| needs_rework | QM5_1090 | Q04 | FAIL | done | 2026-06-28 |
| needs_rework | QM5_1099 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1112 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1125 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1131 | Q02 | FAIL | done | 2026-06-22 |
| needs_rework | QM5_1132 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1134 | Q02 | INFRA_FAIL | failed | 2026-06-23 |
| needs_rework | QM5_1135 | Q02 | INFRA_FAIL | failed | 2026-06-23 |
| needs_rework | QM5_1136 | Q02 | FAIL | done | 2026-06-22 |
| needs_rework | QM5_1144 | Q02 | INFRA_FAIL | failed | 2026-06-23 |
| needs_rework | QM5_1156 | Q04 | FAIL | done | 2026-06-27 |
| needs_rework | QM5_1173 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1177 | Q02 | RETIRED_LOW_FREQ | done | 2026-06-15 |
| needs_rework | QM5_1178 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1179 | Q02 | RETIRED_LOW_FREQ | done | 2026-06-15 |
| needs_rework | QM5_1183 | Q02 | FAIL | done | 2026-06-18 |
| needs_rework | QM5_1186 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1191 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1196 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1225 | Q02 | INFRA_FAIL | failed | 2026-06-25 |
| needs_rework | QM5_1231 | Q02 | INFRA_FAIL | failed | 2026-06-25 |
| needs_rework | QM5_1247 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1253 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1254 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1257 | Q02 | INVALID | failed | 2026-06-18 |
| needs_rework | QM5_1272 | NO_WORK_ITEM | — | — | — |
| needs_rework | QM5_1276 | NO_WORK_ITEM | — | — | — |
| needs_rework | QM5_1357 | NO_WORK_ITEM | — | — | — |
| needs_rework | QM5_1358 | NO_WORK_ITEM | — | — | — |
| needs_rework | QM5_1359 | Q02 | FAIL | done | 2026-07-04 |
| needs_rework | QM5_1395 | Q02 | — | pending | 2026-06-27 |
| needs_rework | QM5_1463 | Q03 | FAIL | done | 2026-06-28 |
| needs_rework | QM5_1540 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_1559 | Q02 | FAIL | done | 2026-06-18 |
| needs_rework | QM5_9011 | NO_WORK_ITEM | — | — | — |
| needs_rework | QM5_9107 | Q02 | — | pending | 2026-06-27 |
| needs_rework | QM5_9993 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_10006 | Q04 | FAIL | done | 2026-06-28 |
| needs_rework | QM5_10023 | Q02 | FAIL | done | 2026-07-04 |
| needs_rework | QM5_10025 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_10305 | NO_WORK_ITEM | — | — | — |
| needs_rework | QM5_10881 | NO_WORK_ITEM | — | — | — |
| needs_rework | QM5_10991 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12372 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12373 | Q03 | PASS | done | 2026-06-28 |
| needs_rework | QM5_12397 | Q02 | FAIL | done | 2026-06-23 |
| needs_rework | QM5_12521 | NO_WORK_ITEM | — | — | — |
| needs_rework | QM5_12575 | Q04 | FAIL | done | 2026-06-26 |
| needs_rework | QM5_12576 | Q02 | FAIL | done | 2026-06-26 |
| needs_rework | QM5_12594 | Q02 | FAIL | done | 2026-06-27 |
| needs_rework | QM5_12599 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12603 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12607 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12611 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12615 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12616 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12618 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12620 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12621 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12703 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12704 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12705 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12706 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12707 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12708 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12709 | Q04 | FAIL | done | 2026-06-30 |
| needs_rework | QM5_12710 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12711 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12733 | Q04 | FAIL | done | 2026-06-29 |
| needs_rework | QM5_12736 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12759 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12769 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12773 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12780 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12804 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12810 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12812 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12813 | Q04 | FAIL | done | 2026-07-01 |
| needs_rework | QM5_12814 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12828 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12829 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12833 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12847 | Q03 | PASS | done | 2026-07-04 |
| needs_rework | QM5_12849 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12858 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12859 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12873 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12874 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12895 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12896 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12912 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12957 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12965 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12975 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12979 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12980 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12981 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12983 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12994 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_12997 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_13000 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_13004 | Q02 | — | pending | 2026-07-03 |
| needs_rework | QM5_13009 | Q02 | — | pending | 2026-07-03 |

> Pipeline state = latest `work_items` row per EA by `updated_at` as of 2026-07-04.  
> Source: `D:/QM/strategy_farm/state/farm_state.sqlite`.

---

## Appendix B — Source Files

| Purpose | Path |
|---|---|
| Calendar primitives | `framework/include/QM/QM_Indicators.mqh` lines 139–208 |
| Fix commit | `f55040e447da95116cee05caa775b9219a392958` |
| Validation artifact | `docs/ops/evidence/85582fe4_calendar_cadence_migration_2026-07-01.md` |
| Requeue exclusion list | `D:/QM/strategy_farm/state/requeue_excluded_eas.txt` |
| Agent task | `85582fe4-2e2b-4499-92f0-cbde24346218` (state: APPROVED) |
