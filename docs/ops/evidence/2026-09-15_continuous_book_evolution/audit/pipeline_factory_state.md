# Pipeline & Factory State Audit — 2026-09-15

Read-only audit for the CONTINUOUS BOOK EVOLUTION directive (§22–§23 pipeline continuity, §68 PHASE-A truth
reconciliation, §72 FACTORY reporting). Snapshot taken 2026-09-15 ~12:28Z on the canonical runtime host.
Sources: `farm_state.sqlite` (RO), `D:/QM/reports/state/pipeline_state.json` (gen 12:27Z), worker logs, live counters.

## Headline (3 lines)
1. The book precondition is already MET for BOTH venues (`book_guard.qualified_pairs=26 ≥ 25`, DXZ + FTMO OWNER order artifacts present) yet no Q15 construction has run; the marginal value now is book *quality*, which is gated by a near-frozen Q11→Q12→Q14 frontier — only 2 pairs have cleared Q12, 51 wait at Q11.
2. The factory is severely under-saturated RIGHT NOW: 6 of 10 terminals have been idle ~2.95 h stuck in `drain_predrain_open` for a single un-winnable 44 GB RAM reservation (QM5_10025), and census throughput has fallen to 0/hour despite 732 claimable un-held pending rows.
3. The highest-value factory bottleneck and the costliest process rule are the same object: the flat 44 GB `heavy_or_unknown_multisymbol` RAM reservation + `drain_predrain` head-of-line claim preflight, which is un-winnable on this 67.8 GB box and poisons the claim head for the majority of workers.

## Findings

### 1. work_items state × gate matrix (`farm_state.sqlite`, query below)
Query: `select status,phase,count(*) from work_items group by status,phase`. Totals: done 96,100 / failed 49,229 / pending 3,783 / active 4 (total 149,116).

Phase-2/3 frontier detail (v4 contract rows unless noted), `phase × status × verdict`:

| gate (v4) | done | pending | notable verdicts |
|-----------|------|---------|------------------|
| Q09 Baseline Full Run | 308 | 6 | 270 PASS, 35 FAIL, 3+23 INFRA_FAIL |
| Q10_NEWS | 254 | 56 | 70 CONFIG_LOCKED, 95 REVIEW_REQUIRED, 48 INVALID_EVIDENCE, 39 SUPERSEDED, 12 INFRA_FAIL |
| Q11 Incumbent Confirm | 33 | 0 | 32 PASS, 1 ARTIFACT_READY |
| Q12 Pattern Filter | 35 | 74 | 33 NO_FILTER_CHANGE, 2 PASS, 2 failed INVALID |
| Q13 Param Opt & Freeze | 35 | 0 | 35 NO_PARAMETER_CHANGE |
| Q14 Head-to-Head (terminal) | 47 | 2 | v4: 33 KEEP_INCUMBENT (29 distinct pairs); legacy: 11 OPT_ELIGIBLE + 3 OPT_REJECTED |

Storage is STAMP_DONT_RENAME so `phase` mixes v3/v4 ids; `gate_contract_version` distribution: legacy 111,646 / v3 24 / v4 37,446. The authoritative progress view is `pipeline_state.json.by_gate_v4` (metric = `highest_contiguous_valid_gate`), see Finding 2.

### 2. The frontier (rows at Q12–Q14 and what they wait on)
`D:/QM/reports/state/pipeline_state.json` → `by_gate_v4` (highest-contiguous-valid-gate census, v4 contract):
`Q01:3 Q02:2089 Q03:1085 Q04:569 Q05:334 Q06:306 Q07:242 Q08:52 Q09:107 Q10:32 Q11:51 Q12:2 Q13:0 Q14:29 Q15:0 Q16:0 Q17:0`.

- **29 pairs have reached the terminal optimization gate Q14** (raw work_items: 33 v4 Q14 done rows = 29 distinct (EA,symbol) = 29 distinct EAs, all KEEP_INCUMBENT). `book_guard` reports a stricter `qualified_pairs=26`, `distinct_eas=26`, `strategy_families=21`.
- **51 pairs are stuck with Q11 as their frontier**, i.e. they wait on **Q12 Pattern Filter Selection** — this is the single largest advanceable frontier band. Only 2 pairs have Q12 as highest-contiguous; Q13 has 0. The Q12 lane has 74 pending work_items (54 un-held) and shows almost no forward motion.
- Q14 pending = 2; Q13 done = 35 but all NO_PARAMETER_CHANGE (dev freeze produced no better parameters); Q12 done = 33 NO_FILTER_CHANGE. The optimization phase is running but producing overwhelmingly "no change" requalifications — it confirms incumbents rather than improving them.
- **Book trigger status** (`pipeline_state.json.operator_surface.book_guard`): `minimum_qualified_pairs=25`, `qualified_pairs=26`, DXZ `allowed=true` (`decisions/2026-09-13_owner_book_order_dxz.md`), FTMO `allowed=true` (`decisions/2026-09-14_owner_book_order_ftmo.md`), both `owner_order_present=true`. The fixed-25 gate the directive §68B orders removed is currently SATISFIED, so it is no longer the binding constraint; book *composition* is.

### 3. Factory near-idle: un-winnable 44 GB reservation head-of-line-blocks 6/10 terminals (LIVE INCIDENT)
Evidence: `D:/QM/strategy_farm/logs/terminal_worker_{T3,T5,T9}.log` (and T4,T8,T10), latest `claim_result` events ~12:29Z:
- Every idle worker reports `skips: {longrun_cap_skipped: 26, ram_class_skipped: 251}` and `reason: no_pending_claimable`.
- `ram_class_skipped` sample: `ea QM5_10025, ram_class heavy_or_unknown_multisymbol, reservation_gb 44.0, free_ram_gb ~26, post_reservation_free_gb -18.3, threshold_gb 14.0` — the 44 GB flat reservation cannot be satisfied on a 67.8 GB machine (RAM now: total 67.8 GB, used 40.0, avail 27.7).
- Each idle worker is in `drain_predrain_open` for `QM5_10025` item `d16ec281…` with `waited_seconds ≈ 10,600` (≈2.95 h) and `reservation_gb 44.0`. The drain will never complete → permanent idle.
- `farm_state.sqlite`: QM5_10025 has **6 pending Q02 rows, none held** (`d16ec281…`, `3af8c03c…` created 2026-09-09, plus 4 older). They sit at the claim head and poison it for every worker.
- `drain_window.json`: `pre_drain.ea_id=QM5_10025`, `reservation_gb=44.0`, `opened_iso=2026-09-15T12:27:56Z`; `custom_history_containment_mode.json enabled=false` (healthy).
- Live process check (`hourly_watch_0909.py`, run once RO): `workers=10 terminals=MT5_Base,FTMO,T1,T7,T2,T6` → only **4 factory terminals doing real work** (T1,T2,T6,T7); T3,T4,T5,T8,T9,T10 idle. `census_done_60m=0`. CPU 92.5% / 16 cores is idle-claim-scan spin, not throughput (matches the known "1 core/worker idle scan" class). `q08_head_of_line_claim_starvation` health check reads OK (392 unblocked pending exist) but MASKS the reality: workers are self-parked in drain_predrain rather than claiming the 732 available rows.

This is the "claim head-of-line preflight starvation" + "RAM 44 GB not-winnable" class (memory 2026-09-14/15). The 144-item `RAM_RESERVATION_44GB_NOT_WINNABLE_20260914` hold was applied to some heavy rows but NOT to QM5_10025's 6 rows, which is why they still block the head.

### 4. Backlog hygiene (holds & unheld pending)
Active holds total **3,062** (`work_item_holds` where `released_at is null`), top classes:

| hold_code | count | proposed deterministic disposition |
|-----------|-------|-------------------------------------|
| PRESCREEN_SKIPPED | 2,555 | BENIGN — deliberately inert prescreen exclusions (all `OPT_CENSUS` pending, 7–30 d). Not backlog debt; keep. |
| RAM_RESERVATION_44GB_NOT_WINNABLE_20260914 | 144 | Reclassify to measured RAM footprint, or keep parked; also apply this hold to QM5_10025's 6 un-held rows to clear the claim head (GREEN: re-queue/park, no verdict touch). |
| NEWS_CALENDAR_TAINTED | 99 | Rebind to current calendar bundle SHA + append-only rerun (`enqueue-backtest --append-only-rerun-of`), or park with reason. |
| Q08_DSR_CONTEXT_UNAVAILABLE (+…_20260915) | 38 + 11 | Regenerate DSR context window then rerun; currently diagnosed-only (memory 2026-09-14). |
| SIBLING_MEASUREMENT_ONLY_CHAIN_HOLD | 23 | Chain-scoped; release when parent measurement completes. |
| REVIEW_FAIL / REVIEW_NOT_COMPLETED pipeline entry | 19 + 13 | Claude review lane — closure by orchestrator. |
| ARTIFACT_BINDING_* (content changed / rebuild / successor) | 18+3+2 | Rebind artifact hashes; deterministic. |
| COMPILE_EA / Q12_DL089 worker rollout pending | 13 + 5 | Worker-generation rollout; self-clears on next compile wave. |
| FTMO_BOOK3_* isolated-only | 12 + 2 | FTMO book-3 diagnostic isolation; intentional. |

Unheld pending (claimable): **732** rows — Q02 389, Q04 219, Q12 54, Q07 23, Q03 19, COMPILE_EA 18, Q08 5, others. These are what the idle workers *should* be draining.

Age of pending (`created_at`): Q02 542 pending with 395 **>30 d** old; Q03 14 >30 d; Q04 13 >30 d; oldest pending row 2026-06-08. The "thousands of old early-stage items" (§23) = the 2,089 candidates whose frontier is still Q02 (`by_gate_v4.Q02`) + 2,555 held OPT_CENSUS prescreen rows; these are early-stage and must NOT globally block book improvement.

Review / agent-task backlog (`agent_tasks`): TODO build_ea 274, TODO review_ea 22, TODO ops_issue 20, and **325 TODO rows with no assigned_agent** (uncommissioned). APPROVED ops_issue 81. Q10_NEWS REVIEW_REQUIRED 95 + INVALID_EVIDENCE 48 are an evidence-review backlog for the Claude lane.

### 5. Throughput (last 1 h / 6 h / 24 h, done work_items by phase)
Query: `count(*) … status='done' and updated_at > now(-window)`.
- **24 h:** OPT_CENSUS 259 cells, Q04 293, Q05 70, Q06 36, Q07 18, Q08 17, Q09 6, Q02 6, Q03 3 (~700 completions ≈ 29/h).
- **6 h:** Q04 78, Q05 17, Q07 8, Q06 7, Q08 2, Q02 4 — **no OPT_CENSUS at all** (census lane stalled ≈6 h ago).
- **1 h:** Q04 9, Q05 4, Q02 3, Q06 1, Q07 1; **census/h = 0**. Active now: Q04 1, Q05 1, Q07 2 (4 rows).

Effective current MT5 saturation ≈ 40% (4/10 terminals), census throughput ≈ 0/h against 732 claimable rows — a live throughput collapse, not a lack of work.

### 6. Live books (context, RO)
- `live_book_pulse.json`: effective_state RUNNING (expected RUNNING), verdict WARN, gen 12:30Z. `live_sleeve_drift`: 19 OK, 3 ALARM (known-dark set 12778/12969/13117, repair staged — not new), 2 WARN (10440 NDX, 1556 XAUUSD).
- `ftmo_trial_pulse.json`: RUNNING, verdict WARN, 8 magics, 0 open positions, equity 99,811.51 (Demo).
- Disk: D: free **61 GB** (LowWater purge fires at 60 GB — margin thin); C: free 93 GB.

## Top-3 bottlenecks ranked by business value
1. **[CRITICAL] Un-winnable 44 GB RAM reservation head-of-line-blocks 6/10 terminals** (Finding 3). Business value: the factory is the only engine that advances candidates toward book eligibility and clears backlog; losing ~60% of MT5 capacity for ≈3 h (and counting) directly stalls both frontier progression (§23 objective 1) and backlog hygiene (§23 objective 2). Evidence: worker-log `ram_class_skipped=251`, `drain_predrain_open waited_seconds≈10,600`, 6 un-held QM5_10025 rows, `census_done_60m=0`.
2. **[HIGH] Frontier frozen at Q12 Pattern Filter** (Finding 2). 51 pairs wait at Q11 for Q12; only 2 have cleared it; Q13 produces only NO_PARAMETER_CHANGE. Since the fixed-25 book gate is already met (26), the *only* remaining lever on book quality is pushing more/better pairs through Q12→Q14 — and that lane is nearly static. Evidence: `by_gate_v4 Q11:51 Q12:2 Q13:0`, Q12 74 pending / 54 un-held.
3. **[MEDIUM] Un-dispositioned hold & review backlog** (Finding 4): 99 NEWS_CALENDAR_TAINTED, 49 Q08_DSR_CONTEXT_UNAVAILABLE, 95 Q10_NEWS REVIEW_REQUIRED + 48 INVALID_EVIDENCE, 325 unassigned TODO agent_tasks. These are repairable with deterministic dispositions and, under §23, must be worked as capacity permits without blocking the books.

## Which process rule currently costs the most business value (§72)
The **flat 44 GB `heavy_or_unknown_multisymbol` RAM reservation combined with the `drain_predrain` head-of-line claim preflight**. On a 67.8 GB host this makes the reservation permanently un-winnable, and the claim-order rule keeps the head row (a 44 GB EA) at the front so every worker either skips 251 rows or self-parks in a drain that never completes — idling the majority of the factory while 732 claimable rows and a book-quality frontier wait. The old "global drain barrier" doctrine (§23, now superseded) is the second-costliest rule, but the directive already lifts it; the RAM-reservation/claim-preflight rule is live and actively burning throughput today.

## Drift table
| Doc/Vault/counter says | Runtime says | Path |
|------------------------|--------------|------|
| Memory: book counter "Zähler 11/25" (Sep 6) then "3 Buch-Receipts" (Sep 14) | `qualified_pairs=26 / 25`, both venues allowed, OWNER orders present | `pipeline_state.json.operator_surface.book_guard`; `decisions/2026-09-1{3,4}_owner_book_order_{dxz,ftmo}.md` |
| `gate_manifest.v4.json` `draft_note`: "PROPOSAL ONLY … DEFAULT_MANIFEST stays gate_manifest.v3.json" | `activation_guard.state=ACTIVE`, activated_by CLAUDE 2026-08-23; runtime writes v4 (37,446 rows), `pipeline_state` renders v4 | `gate_manifest.v4.json` lines 5 vs 421–432; `by_gate_v4_gate_contract_version:"v4"` |
| `candidate_qualifications` is the qualification ledger | Table is EMPTY (count 0); qualification is tracked via `portfolio_candidates` + `by_gate_v4` instead | `farm_state.sqlite` `select count(*) from candidate_qualifications` = 0 |
| health check `q08_head_of_line_claim_starvation = OK` ("392 pending unblocked") | 6/10 terminals idle ≈3 h in drain_predrain; census 0/h; 251 rows skipped at head | `health.json` vs `terminal_worker_*.log` claim_result skips |
| CLAUDE.md: tester cache purge keeps D: healthy | D: free 61 GB, only 1 GB above the 60 GB LowWater trigger | `shutil.disk_usage('D:/')` |
| `portfolio_candidates` Q12_REVIEW_READY rows are current work | 24 such rows dated Jun–Jul 2026 (stale); 9 EVIDENCE_STALE, 6 RETIRED | `farm_state.sqlite` `portfolio_candidates` |

## Open questions strictly requiring OWNER
None. The 44 GB reservation clearance (re-queue/park un-winnable rows, or reclassify RAM to measured footprint) is a GRÜN-zone infra repair under the Stehende Vollmacht (no verdict logic touched); it does not require OWNER authorization. Book construction itself remains OWNER-gated but the order artifacts already exist.

## Recommended actions for implementing phases (§68 B/D/E/F)
- **Factory (immediate, PHASE-A/D):** clear the head-of-line block — apply `RAM_RESERVATION_44GB_NOT_WINNABLE` hold to QM5_10025's 6 un-held Q02 rows (`d16ec281…`, `3af8c03c…`, + 4 older) OR reclassify `heavy_or_unknown_multisymbol` from the flat 44 GB reservation to a measured footprint so ≥6 terminals resume draining the 732 claimable rows. Controller: `tools/strategy_farm/` claim/RAM-reservation logic; state `D:/QM/strategy_farm/state/drain_window.json`.
- **Mission Control (PHASE-D, §72 factory panel):** add a "terminals-idle-in-drain vs claimable-pending" bottleneck tile driven by worker `claim_result.skips`; the current `q08_head_of_line_claim_starvation` health check gives false-OK and must be tightened to fail when `census_done_60m=0` AND `≥N` terminals idle in drain_predrain. Files: `tools/strategy_farm/dashboards/render_dashboards.py`, `render_cockpit.py`, health check in the 15-min task.
- **Frontier (PHASE-E book quality):** prioritise the Q12 Pattern Filter lane for the 51 Q11-frontier pairs (frontier-first backfill per `gate_manifest.v4.json.backfill_planner_contract`); the fixed-25 gate is met, so compute should shift from generating new early-stage census to advancing these pairs Q12→Q14.
- **Backlog hygiene (PHASE-A, §23):** deterministic dispositions for NEWS_CALENDAR_TAINTED (99, calendar rebind + append-only rerun), Q08_DSR_CONTEXT_UNAVAILABLE (49, DSR context regen), Q10_NEWS INVALID_EVIDENCE (48) / REVIEW_REQUIRED (95, Claude review lane); commission or park the 325 unassigned TODO agent_tasks (each needs exactly one assignee per Orchestrator Mandate).
- **Contract cleanup (PHASE-B):** resolve the `gate_manifest.v4.json` draft_note vs ACTIVE drift (the note is stale — v4 is live); note the empty `candidate_qualifications` ledger so the book engine reads the correct qualified source.
