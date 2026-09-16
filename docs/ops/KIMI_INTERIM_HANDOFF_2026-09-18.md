# KIMI INTERIM HANDOFF — CONSOLIDATED CURRENT STATE

**File owner:** Kimi (interim operator, OWNER_DIRECT_SESSION_DELEGATION 2026-09-15 → Fable return).
**As of:** 2026-09-16T16:57Z (all numbers re-queried live this pass: git, farm DB, watchdog, population read-model regenerated 16:27:06Z, quota snapshots, second-chance funnel/register, prescreens re-run; both background agents' outputs re-checked after landing).
**Companion machine-readable state:** `D:/QM/reports/state/kimi_interim_handoff.json` (schema-bound, same as-of).
**Supersedes:** every prior interim snapshot in `# HISTORICAL INTERIM LOG / SUPERSEDED STATES` below. If history contradicts this snapshot, history is stale.
**Readiness:** consolidation COMPLETE; **interim handoff READY for Fable (handoff_ready = true)** — **both** background agents' outputs have landed and are incorporated: agent-39 RAM-479/Q09 analysis (`c389c4b2bf`, on origin) and agent-38 E1-C follow-through + critic-prep verification (`efe25cf89a`, on origin: 9973 drift hold released 16:44:43Z, Option-A remeasurement enqueued, `docs/ops/evidence/2026-09-17_critic_prep/VERIFY.md`). One material drift from agent-38's verification is surfaced as a known follow-up: **H-MR branch setfiles carry real `build_hash` stamps and must be reset to `pending` before `enqueue-compile`** (see FTMO section + KNOWN DEFECTS).

---

# CURRENT SNAPSHOT

- **As-of:** 2026-09-16T16:57Z.
- **Canonical repo/branch/HEAD:** `C:\QM\repo` @ `agents/board-advisor`, content HEAD `efe25cf89ae1b1c76eda8aca401de065c2845673` (agent-38's E1-C follow-through on top of agent-39's `c389c4b2bf`; both on origin); on top sit **only** the handoff-consolidation doc commits (this file + its lint test). **Divergence vs origin: 0 behind; ahead = the handoff doc commit(s) only.** Local `main` ref remains stale/divergent (18 ahead / 7,233 behind origin/main) — never use as an execution base (house rule: `agent_worktree_preflight.py`).
- **Dirty tree:** 490 paths (dominated by ops evidence + hold receipts from the concurrent E1-C follow-through; counts churn live), plus `docs/ops/FTMO_CHALLENGE_READINESS.md` modified (regenerated 16:22:06Z).
- **Active worktrees (of 90 registered; 49 agent/rework slots):** canonical checkout plus three FTMO build worktrees — `C:\QM\worktrees\kimi-hcw-20260915` @ `86e166f26f`, `kimi-hmr-20260916` @ `04f10839b2`, `kimi-fxmr-20260916` @ `ea38197cc0` (ex5 + build staging untracked by design, EX5_COMMIT_GUARD).
- **Outstanding leases/agents:** `spawn_leases` — zero active (all expired, newest 2026-09-12); preflight lease scan 0 active leases / 92 active claims. **Both background agents LANDED on origin:** agent-39 `c389c4b2bf` (16:34Z, RAM-479/Q09 analysis) and agent-38 `efe25cf89a` (16:56Z, E1-C follow-through). Nothing in-flight at snapshot.
- **Factory state (read-model regenerated this pass, 16:27:06Z):** health RUNNING; **four counts — OPEN_PIPELINE_ROWS 981 · SELECTOR_CLAIMABLE_ROWS 1102 · TRUE_CLAIMABLE_WORK 1097 · RESOURCE_FEASIBLE_RUNNABLE_WORK 0 · ACTIVE_ECONOMIC_BACKTESTS 6** (4 active lanes at 16:57Z — census/news cells complete continuously); parked 3,780 (pending total 4,767); BUFFER_LOW GREEN · IDLE_WITH_RUNNABLE_WORK GREEN (feasible=0, so no idle violation); host free RAM 18.7 GB of 63.1 GB at read-model time.
- **Active economic backtests (farm DB 16:57Z):** 4–6 (churns as cells complete) — OPT_CENSUS ×1 (QM5_41478) · Q03 ×1 (QM5_12724 multisym) · Q10_NEWS ×4 (QM5_1567/12567/10513/1230).
- **Resource-feasible runnable:** 0 rows right now (true-claimable head-of-line classes need more free RAM than available); runnable-now forecast 0.0 h.
- **Forecast hours (governed unlock menu, from read-model):** 66.33 h total = RAM-44GB class 42.35 h (391 rows) · Q08 DSR context cohort 12.4 h (38 rows) · news-runner silent-abort 6.13 h · Q09 sealed-plan derivation 4.08 h · artifact-binding drift 0.78 h · compile-worker rollout 0.5 h · second-chance wave-1 0.09 h.
- **41478 census (DL-089):** RUNNING — 126/1,085 cells done (11.6%), 959 pending; first completion 12:12:46Z today, sustained ≈26–28 cells/h; census is 1 of the 4–6 active lanes (not monopolizing).
- **News-lane state:** E1-C APPLIED (b85f9d3084, executed 14:00–15:00Z) — 99-row census cohort reconciled exactly: 91 UNCHANGED_EQUIVALENT released with tamper-evident markers, 8 EVIDENCE_INCOMPLETE → Option A remeasurement **enqueued 16:56Z (agent-38: canonical Q08/Q07 append-only reruns live for QM5_10815/13301/1567; 5 rows documented with exact blockers)**, 0 flips. **9973 drift row revalidated byte-identical (record `779492a0…`, UNCHANGED_EQUIVALENT vs current clean bytes) and RELEASED 16:44:43Z** via the governed E1-C marker path (receipt `20260916T164443Z`; **agent-38 LANDED**). **8 NEWS_CALENDAR_TAINTED holds remain active — exactly the 8 Option-A census rows** (held by design until remeasurement). Taint config bytes untouched.
- **D1 final state (OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916):** COMPLETE — 16/16 cards amended under the governed two-batch plan; cohort outcome **13× FAIL_HARD · 1× FAIL_SOFT (QM5_9973) · 2× INVALID (QM5_10211 setfile class, QM5_10269 sealed-calendar class)**; QM5_10280 parked pre-burn via admission lint (`SETFILE_EMPTY_STRATEGY_PARAMS`, now fail-closed at enqueue). Failure analysis: §8.2 DSR sole economic cause; setfile defect exonerated as verdict-bias. Batch-2 STOP + 0-rows-newly-claimable divergence preserved in the receipt for OWNER disposition.
- **D1 final state (OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916):** COMPLETE — 16/16 cards amended under the governed two-batch plan; cohort outcome **13× FAIL_HARD · 1× FAIL_SOFT (QM5_9973) · 2× INVALID (QM5_10211 setfile class, QM5_10269 sealed-calendar class)**; QM5_10280 parked pre-burn via admission lint (`SETFILE_EMPTY_STRATEGY_PARAMS`, now fail-closed at enqueue). Failure analysis: §8.2 DSR sole economic cause; setfile defect exonerated as verdict-bias. Batch-2 STOP + 0-rows-newly-claimable divergence preserved in the receipt for OWNER disposition.
- **D4 (QM5_11731):** APPLIED — canary EURUSD-M5 rebuilt/rebound under D4 force-rebuild authority (scope: 11731 only), fanout released, rebuild receipts in `docs/ops/evidence/2026-09-16_requeue_lifts/`.
- **D5 (QM5_41478):** APPLIED — seal → allocation (414780000) → promotion → COMPILE_OK (gate caught + fixed `ZeroMemory(req)`) → DL-089 service applied → Q02 seed → census. All preserved-artifact hashes in `docs/ops/evidence/2026-09-16_seal_41478/RECEIPT_D5.md`.
- **D4/D5 receipts:** `docs/ops/evidence/2026-09-16_requeue_lifts/` (D2A/D2B/D4 receipts for 11731) and `docs/ops/evidence/2026-09-16_seal_41478/` (RECEIPT.md + RECEIPT_D5.md) — verified present.
- **Second-Chance state:** all four commissioned candidates now at **new-lineage-card / REVIEW** (cards drafted under `PENDING_*` in `cards_review`, awaiting controller/Codex allocation & review; codex weekly window resets 2026-09-19 08:29Z). 11373 is REVIEW too — the old "IN_PROGRESS" label is superseded.
- **FTMO critic-ready state:** agent-38's pre-critic verification (`docs/ops/evidence/2026-09-17_critic_prep/VERIFY.md`, 16:45–17:05Z) **confirms this snapshot's prescreens**: H-CW 41475 **KEEP** (verify ok, no drift) · H-MR 41476 REJECT (8× `MISSING_FIELD:critic.*` + NEAR_DUPLICATE 10140) · H-FXMR 41477 REJECT (8× `MISSING_FIELD:critic.*` only, no drift). **One material drift flagged (DRIFT-1, independently re-verified): the 6 committed H-MR branch setfiles carry real `build_hash` stamps** (H-CW/H-FXMR correctly `pending`) — `enqueue-compile` refuses `BOUND_SETFILE_HASH_EXISTS` until they are reset to `pending` on the branch before merge. All three mechanically ready and frozen; none economically validated anywhere. Critic receipts must come from a non-Kimi seat (claude weekly reset 09-17 22:00Z; codex 09-19 08:29Z).
- **Kimi quota state (16:26Z):** Allegro plan, rolling-5h 0% used (reset 20:31Z), rolling-7d 0% used (reset 2026-09-22 09:31Z) — fully available; interim-delegation window is not quota-bound.
- **Open OWNER/Fable decisions (packages ready, see `# OPEN DECISIONS`):** D6/V4+6b · RAM-479 · Q09 sealed-plan (10148/11476) · news receipt-chain human apply · E1-C next-pass drift. Nothing else awaits OWNER.

---

# FABLE FIRST 60 MINUTES

1. **Read this file's CURRENT SNAPSHOT + OPEN DECISIONS, then the machine-readable twin** `D:/QM/reports/state/kimi_interim_handoff.json`. — artifact: this file + JSON; **read-only**.
2. **Verify canonical state:** `git fetch && git status -sb` on `C:\QM\repo`; branch `agents/board-advisor` must be 0 behind origin (ahead = handoff doc commits only; content HEAD `c389c4b2bf`). Do not execute from local `main` (18/7,233 divergent). — tool: git; **read-only**.
3. **Read both landed agent outputs before dispositioning:** agent-39 `docs/ops/RAM479_ANALYSIS_2026-09-16.md` (on origin, `c389c4b2bf`) for RAM-479 + Q09; agent-38 `docs/ops/evidence/2026-09-17_critic_prep/VERIFY.md` + `docs/ops/evidence/2026-09-16_e1c_drift_revalidate/` (on origin, `efe25cf89a`) for the critic wave + E1-C closure. — **read-only**.
4. **News receipt-chain human apply** (kein AI-Commit stands): review + apply `docs/ops/evidence/2026-09-15_news_calendar_repin_repair/prepared_registry_patch.md` (38 field writes restoring receipt-000016 attested calendar identity), human commit, then let the next scheduled refresh mint receipt 000017. Details in `# HUMAN / OWNER ACTIONS`. — **authority-sensitive (OWNER/Fable human hands only)**.
5. **Critic wave for H-MR + H-FXMR** (H-CW's gate is already cleared): run the non-Kimi critic per `docs/ops/CRITIC_TO_Q00_TRANSITION_2026-09-16.md` §3, place `critic_receipt.json` in the 0006/0005 store dirs, re-seal, verify, re-run prescreen, then `enqueue-compile`. **H-MR pre-step (DRIFT-1, from agent-38's verification): reset the 6 branch setfiles' `; build_hash:` stamps to `pending` and re-commit — real stamps make `enqueue-compile` refuse (`BOUND_SETFILE_HASH_EXISTS`).** Exact commands in the transition doc §2. — **authority-sensitive** (merge to main + factory entry are Fable/OWNER seats).
6. **H-CW 41475 transition** (prescreen already KEEP): merge `agents/kimi-hcw-20260915` → main per transition doc §5, then `farmctl.py enqueue-compile QM5_41475_cash-window-index-continuation-h1` + governed release + smoke. — **authority-sensitive**.
7. **Disposition the four queued decisions** with their packages (`# OPEN DECISIONS`): D6/V4+6b, RAM-479 (after agent-39), Q09 sealed-plan, receipt-chain (item 4). — **authority-sensitive**.
8. **Watch the DXZ ceremony first live run — FRI 2026-09-18 23:15 CEST (21:15Z)** (`QM_BookEvolution_FridayEvidenceCut`, weekly Friday, State Ready, never run). Verify Saturday analysis + Sunday recommendation chain fires. — scheduled task; **read-only / monitoring**.
9. **Live Factory check:** work mix + census share + buffer from `D:/QM/reports/state/factory_population.json` (regenerate via `tools/strategy_farm/factory_population.py` if stale >15 min). — **read-only**.
10. **Resume permanent orchestration; retire the interim Kimi factory-watch cron `01M2MDAC7H6S7B9CBCM3Z6MNM8`** once your own watch is standing. — **reversible**.

---

# CURRENT FACTORY STATE

Machine-readable block (lint-enforced to equal `D:/QM/reports/state/kimi_interim_handoff.json` → `factory`):

```json
{
  "generated_at_utc": "2026-09-16T16:27:06+00:00",
  "four_counts": {
    "OPEN_PIPELINE_ROWS": 981,
    "SELECTOR_CLAIMABLE_ROWS": 1102,
    "TRUE_CLAIMABLE_WORK": 1097,
    "RESOURCE_FEASIBLE_RUNNABLE_WORK": 0,
    "ACTIVE_ECONOMIC_BACKTESTS": 6
  },
  "parked_rows": 3780,
  "forecast_runnable_hours": 66.33,
  "forecast_runnable_now_hours": 0.0,
  "host_free_ram_gb": 18.7
}
```

- **Four counts (read-model 16:27:06Z):** OPEN 981 · claimable 1,102 · true claimable 1,097 · resource-feasible runnable **0** · active 6. Watchdog 16:20:03Z record agreed (claimable 1,106 / true 1,101 / 6 active — small live churn vs the 16:27 read-model is normal).
- **Forecast:** 66.33 h of governed unlock hours (menu below); runnable-right-now 0.0 h because free RAM (18.7 GB) is below the flat-44 GB class floor for the claimable head-of-line.
- **PARKED_RECOVERABLE:** 1,011 rows = RECOVERABLE_WITHOUT_OWNER 998 + RECOVERABLE_WITH_EXISTING_AUTHORITY 13; plus REQUIRES_NEW_OWNER_DECISION 17 · RESOURCE_BLOCKED 5 · INTENTIONALLY_INERT 2,747.
- **Active gates/programmes:** Q02 531 · Q04 288 · Q12 106 · Q08 87 · Q09_NEWS 55 · Q03 54 · Q10_NEWS 53 pending rows in flight behind the 6 active; DL-089 census lane live; governed unlock work authorized for the RAM-44GB class (ticket 6cdc6811) and the Q08 DSR cohort (D1 V3).
- **Worker utilization (watchdog 16:20:03Z):** 10/10 workers expected; 5 metatester64 + terminal activity; REAL-STALL candidate correctly suppressed (multisym Q03 + 6 active-progress items).
- **Current highest-value unlocks (read-model `recoverable_backlog`, ranked):** ① RAM-44GB reservation class — 391 rows/190 EAs, 42.35 h, authority ticket 6cdc6811, status AUTHORIZED_PENDING_EXECUTION, DXZ-relevant; ② Q08 DSR context cohort — 38 rows/32 EAs, 12.4 h, authority OWNER-DEC-Q08-CONTEXT-REPAIR-V3, DXZ+FTMO; ③ news-runner silent-abort 6.13 h; ④ Q09 sealed-plan derivation 4.08 h; ⑤ artifact-binding drift 0.78 h; ⑥ compile-worker rollout 0.5 h; ⑦ second-chance wave-1 0.09 h.
- **Resource bottlenecks:** host RAM — the flat/measured 44 GB reservation class (NDX measured 39.5 GB) is unwinnable at 18.7 GB free and head-of-line blocks the selector; the 479-row parked cohort awaits the RAM-479 disposition (analysis landed `c389c4b2bf`; OWNER/Fable decide per OPEN DECISIONS #2). CPU/disk healthy (disk 68.4 GB free at watchdog).
- **OPEN ≠ RUNNABLE ≠ ACTIVE semantics:** OPEN_PIPELINE_ROWS = Mission-Control "Queue" number (pending rows in MT5-tester phases, 981). TRUE_CLAIMABLE = Level-1 selector minus Level-2 Q08 DSR precheck failures (1,097; RAM not counted). RESOURCE_FEASIBLE_RUNNABLE = true-claimable rows whose measured reservation + class floor fits free RAM right now (0). ACTIVE = rows literally running (6). A row can be OPEN and claimable yet not runnable — that is today's state.
- **HISTORY (labeled, not current):** the OWNER-observed "981 open / 2,011 parked" display mystery was reconciled row-exact on 2026-09-16 (`docs/ops/evidence/2026-09-16_factory_reconciliation/`); parked churns with claims/dispositions (2,011 display → 3,780 census-inclusive now). 981/2011 are historical figures only.

---

# PROGRAMME STATUS

| Programme | Current state | Latest evidence | Next action | Owner |
|---|---|---|---|---|
| Continuous Book Evolution | RUNNING | `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md`; health read-model 16:22Z: research FRESH, book-evolution read-models AMBER (DXZ/FTMO STALE at last 15-min tick) | Verify Friday ceremony chain fires (item 8) | Kimi (interim) → Fable |
| DXZ weekly recomposition | RUNNING | Task `QM_BookEvolution_FridayEvidenceCut` weekly Fri 23:15+02:00, State Ready, **never run (LastTaskResult 267011)** — first live run **FRI 2026-09-18 21:15Z** | Observe first live run Fri night; then Sat/Sun chain | Fable (monitor) |
| FTMO Demo/Challenge Readiness | MONITORING | `docs/ops/FTMO_CHALLENGE_READINESS.md` (16:22:06Z): **NOT_READY** — prior demo cycle realized max-DD −10.26% vs 10% limit; current cycle day 1.09/14, running, representative=False | Continue demo validation; re-evaluate after ≥14 days | OWNER (purchase decision) |
| H-CW (QM5_41475) | READY_FOR_CRITIC | Prescreen **KEEP** (live re-run 16:29Z); verify ok (`fcc8f2dc…`); card 6ac0419e…4011 | Merge → `enqueue-compile` per transition doc §5/§2c | Fable (authority-sensitive) |
| H-MR (QM5_41476) | REVIEW_PENDING | Prescreen REJECT — 8× `MISSING_FIELD:critic.*` + NEAR_DUPLICATE QM5_10140 (adjudicated false positive, needs 1 differentiation sentence); agent-38 VERIFY.md confirms + flags DRIFT-1 (committed setfiles carry real build_hash) | Reset setfiles to `pending` → non-Kimi critic receipt → seal → prescreen → enqueue | Fable + critic seat |
| H-FXMR (QM5_41477) | REVIEW_PENDING | Prescreen REJECT — 8× `MISSING_FIELD:critic.*` only; agent-38 VERIFY.md confirms, no drift | Non-Kimi critic receipt → seal → prescreen → enqueue | Fable + critic seat |
| H-PY / aggressive-family | REVIEW_PENDING | `strategy-seeds/sources/QM-RESEARCH-2026-0008/` store-only; verify REJECT (8× `MISSING_FIELD:critic.*`); L3 proven structurally unreachable → honest 2-level variant; tail-risk programme RESEARCH+SPEC | Critic receipt + EA build after critic wave; tail-risk risk contract review | Fable |
| Second-Chance | REVIEW_PENDING | Funnel 16:11Z: 4 candidates at new-lineage-card/REVIEW (`PENDING_*` cards); register: 1,285 total / 542 eligible / 731 still-invalid / 12 suppressed-clone | Controller/Codex allocation & review of the 4 cards (codex window resets 09-19 08:29Z) | Codex/controller |
| 41478 census | RUNNING | 121/1,084 done (11.2%), ≈26 cells/h since 12:12Z; lane share ~1/6 active | None — normal lanes own advancement; watch share | Factory (autonomous) |
| E1-C News | MONITORING | `docs/ops/evidence/2026-09-16_e1c_optionb/REPORT.md` — 99-row exact reconciliation, 91 released, 8 Option-A rows **enqueued 16:56Z** (agent-38), 9973 drift **released 16:44:43Z**; 8 taint holds left = Option-A only; critic-prep VERIFY.md landed | Human registry apply, then one post-apply revalidation pass | Fable/OWNER |
| PatternFilter | BLOCKED_FABLE | `docs/research/PATTERN_ABLATION_PROGRAMME_2026-09-16.md` — design-only, plan pinned (`pattern_ablation.v1.json`); DL-089 census closed 27/27 NO_FILTER_CHANGE | Fable signs commission artifact under `decisions/` | Fable |
| Tail Risk | RUNNING | `docs/research/TAIL_RISK_PROGRAMME_2026-09-16.md` — research+specification, no EA implementation, no economic validation; register tail_risk_flagged=4 | Continue spec; joint-tail protocol per directive 3 | Kimi (interim) → Fable |
| Strategy Wiki | MONITORING | Health read-model: `strategy_wiki_sync` AMBER; D1 proof (e) noted wiki not GREEN | Fix build/lint second-chance asymmetry (see defects) | Kimi (interim) → Fable |
| AI routing/benchmark | MONITORING | `ai_capability_scorecard.json` 16:15Z-era data: 6 runs/4 cells (Kimi coding 1.0 correctness, 1.0 pass-rate); ba6-2 benchmark incomplete | Complete ba6-2 benchmark (worktree `8d203c053e`) | Codex/Kimi |
| Factory resource scheduling | RUNNING | Population read-model live; bottleneck = unwinnable 44GB reservation head-of-line block; unlock menu 66.33 h; RAM-479 analysis LANDED (c389c4b2bf: 52 measured-necessity / 427 fail-safe + S1 night-lane/S3 wave menu) | OWNER/Fable disposition of RAM-479 (menu item decision a/b/c in OPEN DECISIONS #2) | OWNER/Fable |

---

# FTMO CANDIDATES READY FOR NEXT STEP

Critic gate (all four): non-Kimi `critic_receipt.json` (schema `qm.agent-chain.receipt.v1`) in the prereg store dir → `research_source.py seal` → `verify` ok → prescreen KEEP → merge → `farmctl.py enqueue-compile <label>` → `release_compile_wave.py --apply` → build_check stamps `build_hash` → governed smoke → `intake-first-q02 --apply`. Full commands + per-EA merge paths: `docs/ops/CRITIC_TO_Q00_TRANSITION_2026-09-16.md` (verified against tooling; pre-critic verification landed as `docs/ops/evidence/2026-09-17_critic_prep/VERIFY.md`). Individual verdicts, never combined. **All candidates below are mechanically ready / critic-ready where stated — none is economically validated anywhere.**

### QM5_41475 — H-CW (cash-window index continuation, session-flat H1)

- **Strategy summary:** cash-window index continuation on NDX/GDAXI/SP500 H1, session-flat, news-blackout + daily-loss guards.
- **Provenance:** QM-RESEARCH-2026-0002 · **card hash (computed this pass):** `6ac0419e5b98e72023d4082f13f666a948b5704f23c64dd97209b62bc3e4011` · **preregistration hash:** `cd661891447f6bb2ef2465607f7df40138e6a9de0879d0242b5dc7c35554322e`.
- **Implementation state:** complete on `agents/kimi-hcw-20260915` @ `86e166f26f` (worktree `C:\QM\worktrees\kimi-hcw-20260915`); EA dir + SPEC + viz spec + 6 setfiles (`build_hash: pending`).
- **Compile state:** ex5 built, sha256 `99126310ab17af2c67de1ebf7f0d61fb7d42db954fae231c474f4baf7d560461` — uncommitted/untracked (EX5_COMMIT_GUARD); zero farm DB rows (verified).
- **Magic allocation:** 414750000/NDX.DWX (slot 0), 414750001/GDAXI.DWX, 414750002/SP500.DWX — active, "Codex governed allocator" 2026-09-15; registry row active.
- **Prescreen (live 16:29Z):** **KEEP, reasons [], warnings []** — the lineage re-seal landed (ledger tail `fcc8f2dc…`; verify exit 0). The transition doc's older REJECT (`HASH_MISMATCH:lineage.json`) is superseded.
- **Exact critic blocker:** none remaining for the gate; the pre-existing claude-seat receipt predates the lineage edit — refresh it only if Fable wants the receipt post-dating the final seal (not a prescreen reason).
- **Exact next transition command:** merge to main per transition doc §5 (H-CW), then `python tools/strategy_farm/farmctl.py enqueue-compile QM5_41475_cash-window-index-continuation-h1` + `release_compile_wave.py --work-item-ids <id> --apply` + smoke (NDX.DWX) + `intake-first-q02 --apply`.
- **Mechanics-frozen:** yes (g0 APPROVED card + prereg binding; review_status REVIEW_PENDING).
- **Known duplicate concerns:** none.

### QM5_41476 — H-MR (cash-open index mean reversion, session-flat H1)

- **Strategy summary:** cash-open mean reversion on NDX/GDAXI/SP500 H1 — deliberately the *opposite* trade sign of a breakout-continuation thesis.
- **Provenance:** QM-RESEARCH-2026-0006 · **card hash:** `a6c1f343317b98e02d380a8d847de73bf358ef97a916dc6aabd799035823e7c5` · **preregistration hash:** `8129b0fc617229c40f7898c64a79072ff93019eb08fc7fa7faef69987b140d2d`.
- **Implementation state:** complete on `agents/kimi-hmr-20260916` @ `04f10839b2` (worktree `C:\QM\worktrees\kimi-hmr-20260916`); EA dir + SPEC + 6 setfiles — **DRIFT-1 (agent-38-verified, independently re-confirmed): the committed branch setfiles carry 6 distinct real `build_hash` stamps instead of `pending`**.
- **Compile state:** ex5 built, sha256 `89d1107a00ef0365d2a50b7a2a5621c31cba60df9aab39afb131a70d2cf3a702` — uncommitted/untracked; zero farm DB rows.
- **Magic allocation:** 414760000/1/2 — NDX/GDAXI/SP500, active 2026-09-16.
- **Prescreen (live 16:29Z):** **REJECT** — two reasons: (1) `INTERNAL_SOURCE_UNRESOLVED:MISSING_FIELD:critic.chain_id,MISSING_FIELD:critic.plan.creator.vendor,MISSING_FIELD:critic.plan.creator.model,MISSING_FIELD:critic.plan.critic.vendor,MISSING_FIELD:critic.plan.critic.model,MISSING_FIELD:critic.critic_verdict,MISSING_FIELD:critic.critic_seat_final,MISSING_FIELD:critic.generated_at_utc`; (2) `NEAR_DUPLICATE:QM5_10140_tv-london-session-break.md:score=1.0000`.
- **Exact critic blocker:** the 8 `MISSING_FIELD:critic.*` fields above (placeholder skeleton receipt in store dir 0006).
- **Exact next transition command:** **pre-step (DRIFT-1): on `agents/kimi-hmr-20260916`, reset all 6 setfiles' `; build_hash:` lines to `pending` and re-commit** (else `enqueue-compile` refuses `BOUND_SETFILE_HASH_EXISTS`) → non-Kimi critic session (transition doc §3) → place `critic_receipt.json` in `strategy-seeds/sources/QM-RESEARCH-2026-0006/` → `python tools/strategy_farm/research_source.py seal QM-RESEARCH-2026-0006 --status preregistered` → `verify --id QM-RESEARCH-2026-0006` → add the one-sentence differentiation marker phrase to the card body + `farmctl.py approve-card --card artifacts/cards_approved/QM5_41476_cash-open-mean-reversion-h1.md --reasoning "source_hash rebind + dedup differentiation after critic seal"` → prescreen re-run (expect KEEP, NEAR_DUPLICATE demoted to warning) → merge → `enqueue-compile QM5_41476_cash-open-mean-reversion-h1` → release wave → smoke (NDX.DWX) → `intake-first-q02 --apply`.
- **Mechanics-frozen:** yes (card `source_hash: 1887b25e…` still binds; rebind is part of the command sequence above).
- **Known duplicate concerns:** NEAR_DUPLICATE vs QM5_10140 score=1.0000 — adjudicated FALSE positive (reversion vs continuation thesis, bigram collision; evidence `docs/ops/evidence/2026-09-16_hmr_near_duplicate_adjudication/`); resolved by the differentiation sentence, not by any mechanics change.

### QM5_41477 — H-FXMR (FX session mean reversion, session-flat M15)

- **Strategy summary:** FX session mean reversion on EURUSD/GBPUSD/USDJPY M15, session-flat.
- **Provenance:** QM-RESEARCH-2026-0005 · **card hash:** `5a52229b2eac826f630b0dc722e41aa85cbd5a3ea420e4a82b7a228fed88a724` · **preregistration hash:** `c408f534bc8825783d44487dd51def684227955988b680fbd4228d4578027475`.
- **Implementation state:** complete on `agents/kimi-fxmr-20260916` @ `ea38197cc0` (worktree `C:\QM\worktrees\kimi-fxmr-20260916`; ex5 + inc_staging untracked); EA dir + SPEC + 6 setfiles.
- **Compile state:** ex5 built, sha256 `4e07143ac4e07ed644ba7865a7b1d8a7b262f16696386bb2f7e1248117c1219b` — uncommitted/untracked; zero farm DB rows.
- **Magic allocation:** 414770000/EURUSD.DWX, 414770001/GBPUSD.DWX, 414770002/USDJPY.DWX, active 2026-09-16.
- **Prescreen (live 16:29Z):** **REJECT** — sole reason: `INTERNAL_SOURCE_UNRESOLVED:MISSING_FIELD:critic.chain_id,MISSING_FIELD:critic.plan.creator.vendor,MISSING_FIELD:critic.plan.creator.model,MISSING_FIELD:critic.plan.critic.vendor,MISSING_FIELD:critic.plan.critic.model,MISSING_FIELD:critic.critic_verdict,MISSING_FIELD:critic.critic_seat_final,MISSING_FIELD:critic.generated_at_utc` (the fail-closed critic gate working as designed).
- **Exact critic blocker:** the same 8 `MISSING_FIELD:critic.*` fields.
- **Exact next transition command:** critic session → receipt in `strategy-seeds/sources/QM-RESEARCH-2026-0005/` → `research_source.py seal QM-RESEARCH-2026-0005 --status preregistered` → `verify --id QM-RESEARCH-2026-0005` → `farmctl.py approve-card --card artifacts/cards_approved/QM5_41477_fx-session-mean-reversion-m15.md --reasoning "source_hash rebind after critic seal"` → prescreen re-run → merge → `enqueue-compile QM5_41477_fx-session-mean-reversion-m15` → release wave → smoke (EURUSD.DWX) → `intake-first-q02 --apply`.
- **Mechanics-frozen:** yes (card `source_hash: ba89005b…` binds until the re-seal).
- **Known duplicate concerns:** none (universe figure corrected to 0.86% with provenance in the store).

### QM5_41479 — H-PY2L (bounded 2-level pyramid; aggressive family)

- **Strategy summary:** bounded 2-level pyramid variant — L3 proven structurally unreachable, so the honest 2-level form is preregistered; sits in the aggressive-family/tail-risk perimeter.
- **Provenance:** QM-RESEARCH-2026-0008 · **card hash (store mechanical-spec card `H_PY2L_card.md`):** `b8a85a485999e7a2078f538e87dd2a6e34813f84e8396799f6821e90c06f681b` · **preregistration:** store `preregistration.json` present; live verify (16:28Z) REJECT on the same 8 `MISSING_FIELD:critic.*` fields.
- **Implementation state:** mechanized only (`mechanization_result.json`, pilot) — **no EA-id allocation, no registry rows, no magic**; EA build after the critic wave.
- **Compile state:** not applicable (nothing enqueued).
- **Prescreen status:** not in `cards_approved`; store-only.
- **Exact critic blocker:** the 8 `MISSING_FIELD:critic.*` fields (placeholder receipt in store dir 0008).
- **Exact next transition command:** critic receipt → `research_source.py seal QM-RESEARCH-2026-0008 --status preregistered` → verify → then card approval + governed allocation of a fresh ea-id before any build (no `enqueue-compile` until an EA exists).
- **Mechanics-frozen:** yes at prereg level (spec + falsifiers pinned); no mechanics exist to freeze beyond that.
- **Known duplicate concerns:** none recorded.

---

# SECOND-CHANCE PROGRAMME

- **Funnel (`D:/QM/reports/state/second_chance_funnel.json`, generated 16:11Z):** stages commissioned → review → new-lineage-card → intake-q00 → factory-work-item → mt5-evidence → portfolio-evaluated. Commissioned population in flight: **4 candidates, all at new-lineage-card / task state REVIEW** — none yet into intake-q00.
- **The 4 key candidates (agent_tasks live query 16:26Z):**
  - **QM5_11563** connors-rsi2-sma200-mean-reversion-d1 (INFRA_FAIL, wave-1) — task `b0ef5d66…`, REVIEW, card `D:\QM\strategy_farm\artifacts\cards_review\PENDING_B0EF5D66_connors-rsi2-sma200-mean-reversion-d1.md`.
  - **QM5_11211** ft-binhv45 (SCALPING, wave-2) — task `f05399de…`, REVIEW, card `PENDING_F05399DE…`.
  - **QM5_11855** (wave-2) — task `8eaa5bf9…`, REVIEW, card `PENDING_8EAA5BF9…` (retest card must add `expected_trade_frequency`).
  - **QM5_11373** (wave-2) — task `27ae17d6…`, REVIEW, card `PENDING_27AE17D6…` (multi-position doctrine: explicit per-slot magic allocation in card).
  - All four: "pending controller/Codex allocation & review"; new-lineage Q00→Q02 rerun with fresh ea-id via farmctl allocation; never reopen old verdicts.
- **Register (`D:/QM/reports/state/second_chance_register.json`, 2026-09-15T18:11Z):** 1,285 population → 542 ELIGIBLE_FOR_RECONSIDERATION · 731 STILL_INVALID · 12 SUPPRESSED_CLONE_OF · tail_risk_flagged 4 · portfolio-utility challengers 0.
- **Docs:** register `D:/QM/reports/state/second_chance_register.{json,csv}` · ranked shortlist `docs/research/SECOND_CHANCE_SHORTLIST_2026-09-16.md` · programme doctrine `docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` · evidence `docs/ops/evidence/2026-09-15_second_chance_wave1/`, `2026-09-16_second_chance_continuation/` (+`wave2/`).

---

# OPEN DECISIONS

### 1. D6 / V4+6b — Q08 DSR remainder

- **Title/scope:** `OWNER-DEC-Q08-CONTEXT-REPAIR-V4-20260916` — extend the approved V3 single-configuration repair pattern to the **12 SAME_V3_CLASS rows** (same defect: approved card without `qm-dsr-single-configuration` declaration + no recorded build identity) **+ sub-decision 6b**: §8.5 neighborhood regeneration mechanism for the remainder cohort (13137 mechanism pinned).
- **Why authority:** repair pattern changes verdict-relevant evidence shape; V3's own execution showed a pre-existing `BUILD_IDENTITY_MISMATCH:mq5` divergence that stopped batch 2 — same risk class here.
- **Recommendation:** approve V4 as drafted (smallest extension of an already-approved pattern); decide 6b after the D1 failure analysis (§8.5/§8.7 were INVALID across the V3 cohort).
- **Evidence path:** `docs/ops/OWNER_DECISION_PACKAGE_D6_DSR_REMAINDER_2026-09-16.md` + `docs/ops/evidence/2026-09-16_dsr_remainder/` (AUDIT.md, audit_rows_raw.json, classification_live.json).
- **Expected impact:** 12 rows back into governed Q08 repair; part of the 12.4 h / 38-row DSR unlock.
- **What remains blocked:** the 12 rows + §8.5 regeneration until OWNER signs; no agent can self-authorize.

### 2. RAM-479 — parked heavy rows (44 GB reservation class)

- **Title/scope:** disposition of the **479 rows** parked under `RAM_RESERVATION_44GB_NOT_WINNABLE_20260914`: measured-necessity split (NDX measured 39.5 GB full-window peak; SP500 45.7/46.8 GB) vs fail-safe, plus a scheduling menu. Explicitly: **no lowering, no hardware purchase** (OWNER 2026-09-15 binding).
- **Why authority:** reservation class calibration changes what the factory will attempt to run; governed-release holds require OWNER-class authority.
- **Recommendation (analysis LANDED 16:34Z, commit `c389c4b2bf`):** census decomposition — **class A 52 rows = measured necessity** (48 SP500 + 2 NDX + 2 GDAXI; class peaks 35.4–46.8 GB) · **class B 427 rows = fail-safe with n=0 measurements — keep parked** (lowering forbidden) · class C fx-basket: 0 parked but the flat 32 GB is stale-low vs the measured 33.5 GB max. Menu: ① keep the 427 parked, revisit via S3 census-cell measurement waves (~1 h fleet time each, compounding); ② run the 52 index rows only under the S1 exclusive night-lane preconditions (≥2 idle terminals AND fleet free-RAM >50 GB, ≤4 exclusive claims/UTC day; ~5–6 h tester time over ~4–7 weeks, 48 SP500 Q04 first); ③ raise `multi_leg_fx_basket` flat 32→36 GB with a follow-on measurement wave — separate ticket; ④ not permitted: lowering any 44 GB label, relaxing the 14 GB floor/reaper, any hardware change.
- **What Fable must decide:** (a) authorize governed release of the 52 index holds under menu ② (S1 preconditions as release note), (b) approve the S3 measurement-wave cadence for class B, (c) approve the fx-basket 32→36 raise as a separate ticket.
- **Evidence path:** `docs/ops/RAM479_ANALYSIS_2026-09-16.md` (LANDED) + calibration receipt `docs/ops/evidence/2026-09-16_deterministic_repairs/2026-09-16_ram44_calibration_receipt.json` + release journal (52 metal-pair rows already released under ticket 6cdc6811).
- **Expected impact:** up to 391 rows / 42.35 h runnable unlocked (read-model), DXZ-relevant.
- **What remains blocked:** the entire 479-row cohort + head-of-line selector pressure until disposition; class-B rows until S3 waves produce measurements.

### 3. Q09 sealed-plan — rows 10148 + 11476

- **Title/scope:** (a) QM5_10148 — remeasure vs retire; (b) QM5_11476 — no-Q07 path handling.
- **Why authority:** both change verdict-relevant plans for sealed Q09 material; derivation item was STOPped and packaged per OWNER policy.
- **Recommendation (landed with the RAM-479 analysis, same commit):** **QM5_10148 → REMEASURE** (Q08 PASS on the exact symbol is intact; blocked only at the final news gate; bounded spend of ~2 terminal slots vs writing off an economically proven card at its last gate). **QM5_11476 → RETIRE** (no Q07 exists at all — a rebuild would be a verdict programme from nothing on the book's worst base-rate family; retire costs essentially nothing, evidence stays immutable; sibling row QM5_11422 unaffected).
- **Evidence path:** `docs/ops/evidence/2026-09-16_deterministic_repairs/2026-09-16_q09_sealed_plan_derivation_owner_package.md` (+ `.json`) + recommendations in `docs/ops/RAM479_ANALYSIS_2026-09-16.md` Part 2.
- **Expected impact:** 4.08 h unlock component; unblocks two long-held rows.
- **What remains blocked:** the 2 sealed-plan rows (held `Q09_AWAITING_SEALED_PLAN`) until Fable/OWNER signs the decision ids.

### 4. News receipt-chain — human apply (kein AI-Commit)

- **Title/scope:** restore the 19 receipt-000016-attested calendar-identity fields (38 writes: 19× sha256 + 19× coverage_end) in `framework/registry/dxz23_execution_contracts.json`; the Sep-15 un-attested `git restore` reverted them; the refresh `record` now REFUSES (exit 2) because the registry pin no longer continues the receipt-chain tail.
- **Why authority:** OWNER-DEC-CALENDAR-REPIN (Sep 5) — dxz23 repins run through the governed flow, **kein AI-Commit**; a human reviews, applies, and commits.
- **Recommendation:** apply the prepared patch exactly as written; the next scheduled refresh then mints receipt 000017 and the chain self-heals.
- **Evidence path:** `docs/ops/evidence/2026-09-15_news_calendar_repin_repair/` (evidence_receipt.md, prepared_registry_patch.{md,json}, apply_registry_patch.py, verify_patch_readonly.py).
- **Expected impact:** news refresh chain unblocked; prerequisite for re-certifying E1-C equivalence after the 2025-05..2026-06 backfill; stops the sweep from re-holding drift rows on a stale pin.
- **What remains blocked:** scheduled calendar refresh (`record` REFUSED), E1-C re-certification path.

### 5. E1-C next-pass drift

- **Title/scope:** re-run delta revalidation over any new drift holds after the human registry apply. The one drift row known at snapshot — **QM5_9973 / NDX.DWX (sweep-applied 14:08Z)** — was **revalidated by agent-38 against current clean calendar bytes (record byte-identical, `779492a0…`, UNCHANGED_EQUIVALENT) and RELEASED 16:44:43Z** via the governed E1-C marker path (receipt `20260916T164443Z`; evidence `docs/ops/evidence/2026-09-16_e1c_drift_revalidate/`). Remaining scope: any *new* drift holds appearing after the human registry apply (bytes change → equivalence must be re-certified, per the E1-C report's own condition).
- **Why authority:** E1-C release semantics are byte-conditioned; releasing on changed bytes without revalidation would break the tamper-evident contract.
- **Recommendation:** none needed for 9973 (closed). After the registry apply, run one governed revalidation pass over the sweep's drift output before any further Option-B-style release.
- **Evidence path:** `docs/ops/evidence/2026-09-16_e1c_optionb/` (REPORT.md, summary.json, rows/, release receipts 14:45–14:48Z) + `docs/ops/evidence/2026-09-16_e1c_drift_revalidate/` (9973 receipt + row record).
- **Expected impact:** news lane now has only the 8 Option-A census holds left; taint hygiene nearly clean.
- **What remains blocked:** nothing from this item; it stays open only as the post-apply re-certification reminder.

# RECENT OWNER DECISIONS — CLOSED

- **D1 (V3, OWNER-DEC-Q08-CONTEXT-REPAIR-V3-20260916):** CLOSED — executed + failure analysis complete (13 FH / 1 SOFT / 2 INVALID; 10280 parked); receipts in `docs/ops/evidence/2026-09-16_q08_amend_v3/` + `2026-09-16_d1_failure_analysis/`.
- **D2A (11731 requeue lift):** CLOSED — enqueue executed, receipts in `2026-09-16_requeue_lifts/`.
- **D2B → D4 (11731 force-rebuild authority):** CLOSED — D4 registered + executed, scope 11731 only; receipts in `2026-09-16_requeue_lifts/`.
- **D3 → D5 (41478 re-compile authority):** CLOSED — COMPILE_OK + DL-089 service applied; `2026-09-16_seal_41478/RECEIPT_D5.md`.
- **E1-C Option B:** CLOSED — applied b85f9d3084, exact 99-reconciliation, 91 released / 8 Option-A enqueued; `2026-09-16_e1c_optionb/`.
- **Clarification 6 (provider determination):** CLOSED — local compile is canonical; codex compile not mandated. Standing for the critic wave.

---

# HUMAN / OWNER ACTIONS

1. **News receipt-chain human apply** — **OWNER/Fable only (kein AI-Commit).**
   - **Exact action:** review `docs/ops/evidence/2026-09-15_news_calendar_repin_repair/prepared_registry_patch.md`; apply the 38 field writes to `framework/registry/dxz23_execution_contracts.json` (via `apply_registry_patch.py` or by hand from `prepared_registry_patch.json`); verify with `verify_patch_readonly.py`; **human commits** the registry change; let the next scheduled `QM_NewsCalendar_Refresh` mint receipt 000017.
   - **Why:** un-attested `git restore` (Sep 15) broke receipt-chain continuity; the refresh `record` now REFUSES. Only a human commit satisfies OWNER-DEC-CALENDAR-REPIN.
   - **Duration:** ~15–30 min (review + apply + verify).
   - **Verification:** `news_calendar_repin.py verify` exits 0 (chain continues); next refresh mints receipt 000017; sweep stops re-holding drift on the stale pin.
2. **Antigravity (gemini) relogin** — **OWNER (credential holder).** `agy_quota.json` 16:20Z: HTTP 401, `token_expired: true` (expired 14:45+02:00), agy lane dead until re-auth. Re-login in the Antigravity surface; verify by re-running `kimi_quota_fetcher.py`/agy fetch → `fetch_status ok`.
3. **Live AutoTrading / DXZ cutover — Sun 2026-09-20 window, OWNER-only** per `docs/ops/BOOK_SPRINT_2026-09-20.md`. Not preparable by agents; authority tag: **OWNER-only, irreversible-live**.
4. **FTMO Challenge purchase — OWNER-only.** Readiness is NOT_READY (`docs/ops/FTMO_CHALLENGE_READINESS.md`); the buy decision and its timing are the OWNER's personal authority regardless of readiness automation output.

---

# KNOWN DEFECTS / FOLLOW-UPS

1. **ba6-2 benchmark incomplete** — severity low; impact: AI-routing benchmark evidence gap (scorecard holds at 6 runs/4 cells); owner: Kimi/codex; blocks profit: no; disposition: finish benchmark in worktree `wf_717b9d36-ba6-2` (checkpoint `8d203c053e`).
2. **H-MR setfile `build_hash` drift (DRIFT-1)** — severity medium; impact: `enqueue-compile QM5_41476` refuses (`BOUND_SETFILE_HASH_EXISTS`) while the 6 committed branch setfiles carry real stamps; owner: Fable/critic-wave operator; blocks profit: no (pre-pipeline); disposition: reset the 6 setfiles' `; build_hash:` to `pending` on `agents/kimi-hmr-20260916` and re-commit before merge/enqueue (agent-38 `VERIFY.md` + `verify_raw.json` document it).
2. **strategy_wiki_sync build/lint second-chance asymmetry** — severity medium; impact: wiki health stuck AMBER (D1 proof (e) non-GREEN); owner: Kimi (interim) → Fable; blocks profit: no; disposition: align build vs lint paths for second-chance cards, then re-lint.
3. **RAM-479** — see OPEN DECISIONS #2; owner: OWNER/Fable (analysis landed `c389c4b2bf`; disposition only); blocks profit: indirectly (42.35 h unlock parked).
4. **Q09 sealed-plan cases (10148/11476)** — see OPEN DECISIONS #3; owner: OWNER/Fable; blocks profit: no (4.08 h); disposition: decide remeasure-vs-retire / no-Q07 path.
5. **Receipt-chain apply** — see OPEN DECISIONS #4 / HUMAN ACTIONS #1; owner: OWNER/Fable human; blocks profit: indirectly (news refresh + E1-C re-certification).
6. **Worktree / local-main housekeeping** — severity low; impact: local `main` 18 ahead / 7,233 behind origin/main; 90 registered worktrees (49 agent/rework slots); owner: Fable; blocks profit: no; disposition: fetch + reconcile main ref; prune dead worktrees at Fable's leisure (never mid-task).
7. **10280 setfile backfill (card-owner)** — severity medium; impact: QM5_10280 parked pre-burn with `SETFILE_EMPTY_STRATEGY_PARAMS` (admission lint fail-closed, 2 active hold rows); owner: card owner; blocks profit: no (row was already FAIL-class); disposition: backfill setfile strategy params on the card, then normal re-admission.
8. **DSR remainder classes B (24 rows, subclassed)** — severity medium; impact: 24 Q08 rows in subclass-B limbo beyond the 12 class-A D6 rows; owner: OWNER/Fable (via D6/6b decisions); blocks profit: indirectly (part of the 12.4 h DSR unlock); disposition: covered by D6/V4+6b scope decisions.

(No fixed-incident items listed: none unresolved.)

---

# HISTORICAL INTERIM LOG / SUPERSEDED STATES

**Everything below is HISTORICAL / SUPERSEDED — evidence only. The CURRENT SNAPSHOT above is the only current truth.**

- **HISTORICAL — interim chronology (2026-09-15 → 09-16):** Kimi interim delegation begins (OWNER_DIRECT_SESSION_DELEGATION). Wave-1 merge, scheduled-task repair (RunAs), Directive-3 audit: commits `db4bd1fa83`→`68cf5caff2`; receipts under `docs/ops/evidence/2026-09-15_*` (`2026-09-15_scheduled_task_runas_repair/`, `2026-09-15_directive3_wave1_merge/` + merge_map, `2026-09-15_second_chance_wave1/`, `2026-09-15_news_calendar_repin_repair/`).
- **HISTORICAL — E1-C narrative (superseded):** earlier snapshot said "prescreen KEEP after re-seal" for H-CW while the transition doc recorded a REJECT — the re-seal subsequently landed (ledger tail `fcc8f2dc…`, verify ok); the KEEP in the current snapshot is the live re-run.
- **HISTORICAL — factory counts (superseded):** 2026-09-16T12:42Z read-model: OPEN 987 · true claimable 1,077 · feasible 4 · active 4, parked 3,881; OWNER display mystery "981 open / 2,011 parked" reconciled row-exact (`docs/ops/evidence/2026-09-16_factory_reconciliation/`). Current: 981 / 1,097 / 0 / 6, parked 3,780.
- **HISTORICAL — old buffer plans (superseded):** the 16:30Z-era snapshot lines (census 111/1,087 at ~49/h, TRUE_CLAIMABLE≈1,077, BUFFER_GREEN notes) are replaced by the live numbers in the snapshot.
- **HISTORICAL — news/MAX_PATH + RAM calibration (complete, receipts kept):** news-runner MAX_PATH root cause fixed (`1f88c6ac8a`), wave-3 releases 7/7 (`466c455b86`); RAM-44GB recalibrated to measured peaks under ticket 6cdc6811 (`c29b4196d1`, `72ca156588`), 52 metal-pair rows released (`8f942431ba`), 479 parked → RAM-479 open decision.
- **HISTORICAL — 41478 D-chain (complete):** D3→D5 seal/allocation/compile/service receipts in `docs/ops/evidence/2026-09-16_seal_41478/`; Q02 seed + census start recorded there.
- **HISTORICAL — agent landings (16:34Z + 16:56Z):** agent-39 `docs/ops/RAM479_ANALYSIS_2026-09-16.md` committed `c389c4b2bf` (52/427 decomposition + menu; Q09 10148 remeasure / 11476 retire). agent-38 E1-C follow-through committed `efe25cf89a` (9973 drift revalidated byte-identical + released 16:44:43Z; Option-A remeasurement enqueued; `2026-09-17_critic_prep/VERIFY.md` + `verify_raw.json`; repin-patch freshness note). Both folded into the sections above — those are current, not these lines.
- **HISTORICAL — evidence index (canonical paths, still valid):** `docs/ops/evidence/`: `2026-09-15_scheduled_task_runas_repair/` · `2026-09-15_directive3_wave1_merge/` (+merge_map) · `2026-09-15_second_chance_wave1/` · `2026-09-15_news_calendar_repin_repair/` · `2026-09-15_kimi_hcw/` · `2026-09-16_kimi_hmr/` · `2026-09-16_kimi_fxmr/` · `2026-09-16_tail_risk_programme/` · `2026-09-16_pattern_ablation/` · `2026-09-16_second_chance_continuation/` + `wave2/` · `2026-09-16_dl089_matrix_service_q12_queue_disposition/` · `2026-09-16_opt_sibling_10911/` · `2026-09-16_seal_41478/` (incl. RECEIPT_D5) · `2026-09-16_q08_amend_v3/` (batches 1–2 + repair) · `2026-09-16_d1_failure_analysis/` · `2026-09-16_admission_lint/` · `2026-09-16_requeue_lifts/` (D2A/D2B/D4) · `2026-09-16_first_backtest_restored/` · `2026-09-16_q08_dsr_unblock/` + `dsr_remainder/` · `2026-09-16_e1c_optionb/` · `2026-09-16_factory_reconciliation/` · `2026-09-16_deterministic_repairs/` · `2026-09-16_hmr_near_duplicate_adjudication/` · `2026-09-16_hpy_l3_analysis/`.
- **HISTORICAL — research/ops docs:** `docs/research/TAIL_RISK_PROGRAMME_2026-09-16.md` · `docs/research/PATTERN_ABLATION_PROGRAMME_2026-09-16.md` · `docs/research/SECOND_CHANCE_SHORTLIST_2026-09-16.md` · `docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` · `docs/research/CONTINUOUS_BOOK_EVOLUTION.md` · `docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` · `docs/ops/BOOK_SPRINT_2026-09-20.md` (earlier drafts misfiled the two BOOK_* docs under `docs/research/` — corrected; the tail-risk/pattern/shortlist trio really is in `docs/research/`).
- **HISTORICAL — older "recommended next actions" lists:** replaced by FABLE FIRST 60 MINUTES.
- **HISTORICAL — interim cron:** `01M2MDAC7H6S7B9CBCM3Z6MNM8` (Kimi factory watch) — to be retired by Fable after handoff (item 10).
