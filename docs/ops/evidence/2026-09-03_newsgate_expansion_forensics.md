# Q10_NEWS Expansion Forensics — 2026-09-03

Read-only forensics on the Q10_NEWS expansion bottleneck. Live DB opened `mode=ro`.
Companion data: `2026-09-03_newsgate_expansion_forensics.json` (every number below is keyed there).

---

## OWNER-Zusammenfassung (DE, max 12 Zeilen)

1. Der „Q10_NEWS-Stau" ist kleiner als er aussieht: von 83 REVIEW_REQUIRED sind nur **34 (41%) echte Expansions**; **36 (43%) sind `cell_execution_failed`** (Zuverlässigkeits-Leck, billiger Rerun) und 11 sind terminal (OFF nicht qualifizierbar).
2. Eine Expansion führt **29 Backtests** aus (nicht 105 — die „+105" sind seed-gefächerte Selektor-Zellen; MT5 rechnet 29 Seed-17-Configs).
3. Kernbefund: **6 von 8 frischen Locks wählen `OFF`** — die Expansion bestätigt zu 75% die Null-Hypothese („News-Politik schlägt OFF nicht").
4. **17/17 material-effect-Expansions feuerten mit `max_affected_entries=0`** — der Entry-Block-Kanal (der eigentliche News-Mechanismus) griff NIE; die Deltas kommen von Exit-Modi/Numerik.
5. Das 8-Zellen-Rennen läuft mit Compliance **NONE**, das Kind mit **DXZ** — die Selektion nutzt nur die Ziel-Compliance-Spalte; die 8-Zellen sind für das echte Ziel (DXZ) entscheidungs-unvollständig (Provenance-Defekt, 54 Zeilen).
6. **Jetzt gerade ist Cap-2 NICHT der Engpass**: 0 ungehaltene wartende Kinder, 1 aktiv. Der stehende Engpass ist upstream: **28 `Q09_AWAITING_SEALED_PLAN`-Holds** + 12 klaimbare-aber-nicht-geklaimte 8-Zellen-Eltern.
7. Cap-2 beißt nur in **Bursts** (die letzte 34er-Welle); dann warten Kinder median 8,3h, max 85,8h.
8. Service bei Cap-2: theoretisch ~9/Tag, gemessen nachhaltig ~4/Tag; Gate-Output (CONFIG_LOCKED) 4,0/Tag (7d), 1,0/Tag (30d).
9. RAM: 63,1 GB gesamt, **17,4 GB frei**, 6 Terminals — ein 3. Expansions-Slot (~8 GB) passt knapp.
10. GELB heute machbar: RAM-gated Cap 2→3 als ruhendes Burst-Ventil; GRÜN: Kind-Timeout auf ~900 min straffen, Lineage-Rank auf Expansions ausweiten.
11. **ROT (nur OWNER):** den 8-Zellen-Compliance-Defekt beheben ODER die material_effect-Schwellen für die inert-Seed-Welt neu eichen — das ist der eigentliche Hebel, der die meisten Expansions eliminiert.
12. Empfehlung: heute upstream drainen (GRÜN) + Burst-Ventil vorbereiten (GELB); die ROT-Vorlage für D1/D2 an OWNER.

---

## 1. Mechanism (code-verified)

- **8-cell run** (`matrix_scope=7x1_target_compliance`, `q09_cell_count=8`): 1 `CONTROL_OFF` + 7 `POLICY_ON` temporal modes at the target compliance, seed 17, contract-v3 inert-seed fanout to 5 selector seeds. Source: `q09_news_runner.py::_cell_specs`.
- **Expansion child** (`matrix_scope=7x4`, `q09_cell_count=29`): 1 `CONTROL_OFF` + **4 compliance × 7 temporal** = 29 executed backtests. A **fresh** work item — it re-runs the whole matrix, it does not resume the 8-cell.
- **The +105 vs 29 reconciliation** (both correct, different layers):
  - Logical seed-fanned selector cells added = 4 compliance × 7 temporal × 5 seeds (140) − target column already present (1×7×5 = 35) = **105**.
  - Executed backtests in the child = 1 + 4×7 (seed 17) = **29** (`q09_cell_count=29` on all 39 children).
- **Trigger** (`q09_news_contract.adjudicate`): if any `expansion_reason ∈ {news_or_event_strategy, prop_deployment_target, material_effect}` and the full 4-compliance matrix is absent → `REVIEW_REQUIRED`, `reason_codes=[expanded_7x4_matrix_required]`.
- **Selection scope** (line 739): scores **only** `policy_by_mode[temporal]` at **target compliance** vs control. The 3 non-target compliance columns the expansion computes are recorded but **never scored or selected** — verified: all 8 sampled locks chose `compliance==target`, `ranking` length = 6 (6 non-OFF temporal modes).
- Cell timeout `10800s` (3h). Child whole-job budget observed `11080–22860 min` (7.7–15.9 days) — massively over-provisioned.

## 2. Measured facts

### 2.1 Verdict counts (Q10_NEWS)
- By `created_at`: 7d total 82 (REVIEW 24 / LOCKED 26 / running 27); 14d total 194 (REVIEW 79); 30d total 210 (REVIEW 85 / LOCKED 31 / SUPERSEDED 37 / INFRA 12).
- By `updated_at`: REVIEW 7d=**41**, 14d=85; CONFIG_LOCKED 7d=**28**, 14d=31, 30d=31.
- **Cited "51 in 7 days"** ≈ measured 41 (updated≤7d) + 0 (Q09_NEWS). Same order; the 51 was an earlier snapshot before ~10 rows were SUPERSEDED by reruns. Phenomenon confirmed.

### 2.2 REVIEW_REQUIRED is three different things (83 rows with a test row)
| reason_code | count | meaning |
|---|---|---|
| `cell_execution_failed` | 36 (43%) | reliability leak surfaced as REVIEW — **cheap rerun, no expansion** |
| `expanded_7x4_matrix_required` | 34 (41%) | **genuine expansion demand** |
| `control_or_policy_off_not_qualifiable` | 11 (13%) | terminal, no expansion |
| aggregate file missing | 2 | — |

The bottleneck the task names is really the **34**, not the 83. The 36 `cell_execution_failed` are a *reliability* problem masquerading as expansion appetite.

### 2.3 Expansion durations (hours)
| metric | n | min | median | max | mean |
|---|---|---|---|---|---|
| child total (created→done) | 33 | 2.64 | 20.25 | 90.76 | 28.58 |
| child pending wait (created→claimed) | 38 | 0.04 | **8.28** | 85.82 | 20.89 |
| child execution (claimed→done) | 33 | 2.45 | **5.30** | 13.20 | 5.86 |
| — D1 subset execution | 23 | 2.45 | 4.44 | 13.20 | — |
| — H4 subset execution | 5 | 3.44 | 8.20 | 9.19 | — |
| authoring latency (parent-done→child-created) | 34 | 0.0 | 15.59 | 128.93 | 30.15 |
| 8-cell parent pending (created→claimed) | 89 | 0.04 | 19.15 | **415.23** | 42.53 |
| 8-cell parent execution (claimed→done) | 83 | 0.46 | 2.45 | 42.12 | 4.13 |

The task's "~2.5h for D1" = the D1 **minimum** (2.45h); realistic D1 execution median is 4.44h. **Pending wait (median 8.3h, max 85.8h) — the cap-2 starvation cost — dominates, not execution.**

### 2.4 CONFIG_LOCKED after expansion
- Child work-item final verdicts: **31 CONFIG_LOCKED, 2 REVIEW_REQUIRED (again), 4 INFRA_FAIL, 2 running**. → locked share of concluded children = **31/33 = 94%**.
- Adjudication (`7x4`): 32 LOCKED / 6 REVIEW / 1 INVALID.
- **Recent 8 locks chose temporal: OFF ×6, SKIP_DAY ×2** — reason `off_fallback_no_robust_improvement`. **75% of expansions conclude "no news policy beats OFF."**

### 2.5 material_effect distribution (last 30 REVIEW; 17 carry material detail)
| reason | fires |
|---|---|
| `delta_net_r` | 16 |
| `delta_profit_factor` | 15 |
| `delta_drawdown_pct_points` | 9 |
| `sign_or_gate_flip_3_of_5` | 4 |
| `affected_entries` | **0** |

- **`max_affected_entries` = 0 for ALL 17** (min=med=max=0). The entry-blocking news channel never engaged; deltas are from exit-side temporal modes (SKIP_DAY/CLOSE_ALL_PRE/POST) and/or numerical variation.
- `sign_or_gate_flip_pairs` only ever = **0 or 5** (never 1–4) — because seeds are inert (contract v3), the "3 of 5 seeds" robustness gate **degenerates to 1-of-1**.
- Expansion trigger composition: **17/17 fired on `material_effect` alone** (0 `news_or_event_strategy`, 0 `prop_deployment_target`).

### 2.6 Compliance provenance defect
- 8-cell parents recorded `target_compliance=NONE` (54 of 99 7x1 rows); children `DXZ` (39/39). Mapping **NONE→DXZ for 34/34 material lineages**.
- **54 `q09_news_tests` rows carry `deployment_target=DXZ` but `target_compliance=NONE`**, contradicting `compliance_for_target('DXZ')='DXZ'`. Consequence: the 8-cell ran the NONE column (== control) so its material check is a NONE-vs-NONE comparison dominated by exit-side deltas, and the expansion is the *first* run of the real DXZ column. A data-integrity defect, not just an efficiency one.

### 2.7 Current backlog snapshot (why the cap is not today's constraint)
- 42 pending Q10_NEWS: **30 held** (28 `Q09_AWAITING_SEALED_PLAN`, 2 `NEWS_RUNNER_SPAWN_SILENT_ABORT`), **12 claimable-no-hold**, of which **0 are expansion children**. 1 active Q10_NEWS, 1 active Q07.
- So **cap-2 is not binding now** (0 unheld pending children). The standing constraint is upstream (autoseal holds) + claim starvation (cap-4 total-news has only 1 active while 12 parents sit claimable). Cap-2 bites in **bursts** (the recent 34-request wave).

### 2.8 Gate output & host
- CONFIG_LOCKED/day: 7d=4.0, 14d=2.21, 30d=1.03. Unique EAs locked=28; (ea,symbol) locked=29; (ea,symbol) stuck in REVIEW with no lock sibling=**46**.
- Host: 63.1 GB RAM (17.4 GB free), 16 logical CPU, 6 terminal64 up, per-terminal commit reservation 8.0 GB.

## 3. Capacity math

**Demand:** 34 `expanded_7x4` requests over ~11 active days (Aug 23–Sep 3) = **~3.1 expansions/day**.

**Service at cap 2:** theoretical ceiling = 2 × 24h / 5.30h median = **9.1/day** (D1-only 10.8/day); measured sustained last 7d = 29/7 = **4.1/day**. The gap = median 8.3h pending wait + 15.6h authoring latency + slots not always filled with expansions.

**Queue depth:** 46 (ea,symbol) stuck in REVIEW without a lock; ~41% need expansion → ~19 expansion-needing pairs → **~5–6 days** to drain at 3–4/day. The **dominant drag is not the cap** but (a) 28 `Q09_AWAITING_SEALED_PLAN` upstream holds and (b) 36 `cell_execution_failed` re-reviews.

Raising the cap 2→3 lifts the burst ceiling ~50% but yields little while the queue is upstream-bound; its value is realized on the next demand burst.

## 4. OWNER-decision-shaped proposals

### A — Expanded cap 2→3, RAM-gated  ·  **GELB**
`EXPANDED_NEWS_PARENT_FLEET_CAP 2→3` in `longrun_scheduling_policy.py`, guarded by a claim-time free-RAM precheck (grant the 3rd slot only when free physical RAM ≥ 10 GB > `commit_reservation_gb`). Claim-selection only; no verdict logic. Cost of waiting: low now, high on the next burst. Blast radius ≤1 terminal; short-flow reserve 4→3 only while all news slots busy. Rollback `QM_DISABLE_LONGRUN_SCHEDULING_CAP=1`. **Recommend as a dormant burst valve; secondary — it does not reduce the number of expansions.**

### B — Tighten expansion child timeout budget  ·  **GRÜN**
Cut child `timeout_min` from 11080/22860 (7.7–15.9 days) to **~900 min** (> observed max exec 13.2h + margin). Per-cell 3h stays (avg cell ~11 min, not binding). 4 children INFRA_FAIL; an over-provisioned budget lets a hung/silent-abort child hold a scarce capped slot for days. Reaper timing only, no verdict impact.

### C — Lineage-rank claim ordering for news expansions  ·  **GRÜN**
Apply the existing `priority_track`/`append_only_rerun` lineage rank (already used for Q07/Q08 reruns) to expansion-child claim ordering so Q10-lock-blocking counter-critical lineages take the 2 (or 3) slots before FIFO. Claim ordering only; no cap or verdict change.

### D — Pre-check to skip expansion when material fires only from an inert channel  ·  **ROT (contract/gate-criteria — OWNER only)**
Evidence: 17/17 material expansions had `max_affected_entries=0`; 6/8 recent locks chose OFF; `sign_or_gate_flip` degenerate (0/5) under inert seeds; selection uses the target-compliance column only; the 8-cell ran NONE for DXZ targets.
- **D1 (provenance fix):** correct the 8-cell to run the **actual** target compliance (DXZ) instead of NONE. Then the 8-cell target column is decision-complete and the 29-cell expansion (which only adds non-selected compliance columns) can be **deferred/made lazy** — removing ~all expansion cost for the current target. Highest leverage.
- **D2 (threshold recal):** re-derive `material_effect` thresholds for the inert-seed contract-v3 world (the 3-of-5 flip gate is meaningless; `delta_net_r`/`delta_profit_factor` fire at 0 blocked entries) so exit-side numerical deltas don't force 29-cell runs that 75% conclude OFF.

**Explicit ROT boundary:** any change to *when* expansion fires, the `material_effect` thresholds, or the compliance the 8-cell computes is a gate-criteria/contract change → OWNER only. A/B/C touch no verdict logic (scheduling/claim/timeout).

## 5. What the CEO can do today (GRÜN/GELB)

1. **GRÜN (highest impact now):** the cap is not the live bottleneck — drain the **28 `Q09_AWAITING_SEALED_PLAN`** holds and nudge the **12 claimable-but-unclaimed** 8-cell parents. See `ready_commands` for the read-only listing to hand the drain.
2. **GELB:** land the RAM-gated cap 2→3 (proposal A) as a dormant burst valve; verify against the `QM_DISABLE_LONGRUN_SCHEDULING_CAP` rollback.
3. **GRÜN:** tighten expansion child `timeout_min` (proposal B).
4. **GRÜN:** extend lineage-rank ordering to news expansions (proposal C).
5. **Prepare the ROT Vorlage** for OWNER on D1/D2 — the change that removes most expansions.

*All queries reproducible against `D:/QM/strategy_farm/state/farm_state.sqlite` (`mode=ro`); scripts staged in the session scratchpad. Numbers as of 2026-09-03T15:10Z.*


## CEO verification notes (2026-09-03 15:40Z, workflow wf_c2e17931-047)

Verifier could not refute the load-bearing categories (reproduced from raw
aggregate.json). Snapshot drift only: REVIEW_REQUIRED 85 (packet 83),
cell_execution_failed 38 (36). The per-reason material_effect tally and the
exact duration percentiles were not independently recomputed. Advisory
accepted: proposal A (news fleet cap 2->3) is claim-selection only and sits in
GRUEN; proposal D (8-cell NONE-compliance defect / material_effect thresholds)
is ROT and goes to OWNER.
