# TREASURE HUNT — False-Fail Audit of the Failure Archive

**Date:** 2026-07-02 · **Mode:** READ-ONLY (no DB writes, nothing enqueued)
**Data:** `D:/QM/strategy_farm/state/farm_state.sqlite` (92,280 work_items, 42,098 ea_metrics rows), `C:/QM/repo/framework/EAs/` (2,608 compiled EA dirs), current `.set` files on disk.
**Method:** per-class detectors over payload_json/detail_json + filesystem cross-checks; a candidate is only counted as *recoverable* if it is **terminal** (last word for its ea+symbol+phase, no pending/active requeue in flight — pending rows with epoch-string timestamps handled).
**Analysis artifacts:** `false_fail_audit.py`, `false_fail_audit_results.json`, `c2b_still_empty.json` (same scratchpad dir).
**Gross-edge evidence** = best PF at Q02/Q03/P2 with ≥20 trades from ea_metrics (Q02/Q03 are gross-of-cost phases).

Headline: **~771 terminal false-fail suspect items across 277 EAs** survive all fix-date and requeue filters, plus one **systemic set-file finding (559 EAs)** that is bigger than any single class.

---

## Class 1 — ONINIT_FAILED family (stale .ex5 / resolver rows)

Detector: verdict INFRA_FAIL/FAIL/INVALID with `ONINIT` in payload; EA now has a compiled `.ex5` with mtime ≥ fail date.

- **850 items / 269 EAs** ever hit ONINIT; the 06-21 bulk recompile + 120-item re-enqueue cleaned up most.
- **Still terminal with fresh .ex5: 20 items / 14 EAs** — never re-run after their recompile.

Top candidates (by gross PF):

| ea_id | symbol | phase | fail date | why suspect | gross evidence |
|---|---|---|---|---|---|
| QM5_1049 (mcconnell-turn-of-month) | AUDJPY | Q02 | 06-10 | ONINIT fail; .ex5 recompiled 06-13; 206 Q02 PASSes on other symbols | PF 1.47 Q02/NZDUSD (39t) |
| QM5_10516 | GBPUSD | Q03 | 06-21 | ONINIT fail same day as recompile (15:53 ex5 vs fail) — raced the fix | PF 1.14 Q02/GBPUSD (24t) |
| QM5_10430 | NDX | Q02 | 05-31 | pre-recompile fail, never re-run post 06-21 rebuild | PF 1.09 Q02/WS30 (26t) |
| QM5_10584 | GBPJPY+USDJPY | Q02 | 05-29/30 | 2 symbols dead pre-recompile | PF 1.00 Q02/USDJPY (51t) |
| QM5_12533 | EURJPY | Q02 | 06-26 | INVALID w/ ONINIT; ex5 rebuilt 06-27 (cointegration family) | PF 0.98 on logical basket (170t) |
| QM5_10792 | EURUSD/GBPUSD/NDX/WS30 | Q02 | 06-25 | 4 symbols; ex5 rebuilt 06-28 | none yet |
| QM5_10772 | GDAXI+WS30 | Q02 | 06-27 | fail hours before 06-27 01:03 rebuild | high-freq, PF 0.7 |

**Recommendation:** requeue the 20 items (14 EAs) — cheap Q02/Q03 re-runs, .ex5 verified fresh on disk.

---

## Class 2 — Set-file param-empty defect (setgen card-lookup failure)

Detector: Q02/Q03 FAIL with ≤2 trades; current `.set` inspected for `strategy_*=` lines; `.mq5` inspected for `input ... strategy_` declarations.

**2a — sets since regenerated WITH params (fail predates regen): 725 items / 151 EAs total; 14 items / 9 EAs are terminal + regenerated-after-fail (prime false fails):**

| ea_id | symbol(s) | fail | evidence |
|---|---|---|---|
| QM5_10094 | WS30 | Q02 05-25, 0 trades | set regen 07-02 w/ params; EA already reclassified as stream-defect victim (Codex ed4d9627) — WS30 leg still dead. **PF 1.89 Q03/GDAXI (69t)** |
| QM5_10009 | AUD_NZD_CAD_COINTEG basket | Q03 06-30, 0 trades | set regen 07-02 (10 params); **PF 1.22 Q02 basket (80t)** |
| QM5_1120 | EURJPY, GBPJPY | Q02 06-22, 0 trades | set regen 06-26 (18 params); PF 1.14 Q03/GBPUSD (236t) |
| QM5_11410 / 11748 / 11369 / 12473 / 12562 / 11446 | various FX/XAU | Q02 06-20..26 | 0–2-trade prescreen FAILs; sets regenerated 06-26..07-01 with 10–16 params |

**2b — SYSTEMIC (biggest single finding): 1,242 terminal 0-trade FAILs across 583 EAs whose sets are STILL param-empty today; 559 of those EAs declare 4–26 `strategy_` inputs in their .mq5.** Every one of those verdicts rode on compiled defaults (`card_defaults_source=not_found` pattern — same defect class the 07-02 audit confirmed for 12836/12847/12567/12845/12821, Codex b4c4d179). Whether each verdict is false depends on whether compiled defaults == card values, so this is an **audit queue, not a blind requeue queue**. Highest-value members:

| ea_id | strategy inputs in mq5 | gross evidence |
|---|---|---|
| QM5_10307 narang-blend | 19 | **PF 4.84 Q02/SP500 (28t)** — 0-trade fails on EURGBP/GDAXI/NZDUSD/NDX |
| QM5_1328 brooks-3bar-reversal | 16 | **PF 3.16 Q02/AUDUSD (36t)** — 12+ symbols 0-trade-failed 06-21 (known ID-collision EA) |
| QM5_12510 bt-tsmom-median | 4 | PF 2.82 Q02/USDJPY (33t) |
| QM5_10478 mql5-bago | 13 | PF 2.55 Q02/USDJPY (32t) |
| QM5_10141 rsi-meanrev | 7 | PF 2.46 Q02/USDJPY (21t) |
| QM5_12534 nnfx-canonical (fidelity rebuild) | 14 | PF 2.30 Q02/GBPUSD (23t) |
| full list (559) | — | `c2b_still_empty.json` |

**Recommendation:** extend Codex b4c4d179 scope: diff compiled defaults vs card for the 559-EA list; regen sets + invalidate/requeue only where they diverge.

---

## Class 3 — Prescreen-window artifact (seasonal EAs on H2-only window)

Detector: Q02 FAIL/INVALID with payload `from_date` in H2 and same-year `to_date` (the `2024.07.01→2024.12.31` prescreen — 20,285 Q02 items used it) + seasonal slug.

- **16 items / 2 EAs, both terminal:**
  - **QM5_1214 vidal-holiday-effect** — GER40 Q02 INVALID 06-25 on 2024-H2 window (12 INVALIDs total; 36 re-runs pending on other symbols, GER40 leg has none).
  - **QM5_12836 turnaround-tuesday-ws30** — GDAXI Q02 FAIL 07-02 on 2024-H2 window (the discovery case; NDX re-runs already pending — GDAXI leg not).
- **Adjacent finding (not H2-window, but seasonal 0-trade fails on windows that DO cover their season → logic/set defect, likely calendar-cadence family f55040e44):** QM5_1093 qp-preholiday-sp500 (0 trades in 10 years), QM5_1171 qp-gold-global-holiday, QM5_12576 eia-wti-season, QM5_12917 xti-driving-season-swing (0 trades 2018–2024 for an Apr–Sep seasonal = impossible if entry logic fired). These deserve a code/set audit, not a straight requeue.

**Recommendation:** requeue 1214/GER40 + 12836/GDAXI on full windows; route 1093/1171/12576/12917 to the calendar-primitive audit (Codex 85582fe4 family).

---

## Class 4 — Q04 PASS_SOFT fall-through bug (DL-071 verdicts silently FAILed until 2026-06-23)

Detector: Q04 FAIL before 06-23 where the stored fold data itself shows ≥2/3 folds pf_net>1.0 (with ≥12 OOS trades) — i.e. **the DL-071 PASS_SOFT criterion was met inside the evidence that got stamped FAIL.**

- **626 would-be PASS_SOFT verdicts pre-fix; 70 items / 55 EAs are still terminal** (never caught by the 15-forex re-enqueue or the ~3,029 bulk drip).
- This is the highest-confidence class: the false verdict is provable from detail_json alone, no re-run needed to demonstrate it.

Top terminal victims (fold pf_net / trades from detail_json):

| ea_id | symbol | fail | folds (pf_net) | OOS trades | gross evidence |
|---|---|---|---|---|---|
| QM5_10919 | XTIUSD | 06-19 | 2/3 pos, pooled pf 12.1 | 13 | **PF 4.36 Q02/XTIUSD (26t)** |
| QM5_11128 | SP500 | 06-15 | 2/3 pos, pf 3.70 | 44 | **PF 3.43 Q03/SP500 (28t)** |
| QM5_10163 | GDAXI | 06-16 | 1.172 / 1.153 / 0.927 | 312 | PF 3.93 Q03/NDX (70t) |
| QM5_10142 | NDX | 06-11 | 2/3 pos, pf 3.25 | 18 | PF 1.57 Q02/SP500 (55t) |
| QM5_10692 | GDAXI | 06-17 | 1.736 / 0.717 / 2.561 | 116 | **sister of the Q12 candidate 10692/NDX** |
| QM5_10911 | GBPUSD | 06-15 | 0.579 / 1.163 / 1.148 | 157 | **sister of LIVE book sleeve 10911/GDAXI** |
| QM5_10440 | XAUUSD | 06-13 | 0.790 / 1.154 / 1.034 | 238 | sister of nucleus 10440/NDX |
| QM5_10920 | XAUUSD | 06-19 | 2/3 pos, pf 2.96 | 30 | PF 1.09 Q02/NDX (52t) |
| QM5_10949 | NDX+SP500 | 06-22 | 2/3 pos, pf 2.24/1.23 | 38 | PF 1.64 Q03/XAUUSD (22t) |
| QM5_10943 | NDX | 06-17 | 2/3 pos, pf 1.76 | 41 | PF 1.68 Q03/SP500 (23t) |
| QM5_10115 | GDAXI | 06-11 | 0.975 / 1.180 / 1.066 | 165 | PF 2.89 Q03 — ⚠ OWNER adjudicated 10115 dead 07-01 (PF 1.01); verify before requeue |
| QM5_10815 | XAUUSD | 06-15 | 2/3 pos, pf 1.21 | 43 | PF 2.13 Q02/GDAXI (62t) |
| + 43 more EAs | — | — | full list in results JSON | — | — |

**Recommendation:** these 70 items should be the continuation of the 07-02 rescue wave (10467/EURUSD was rescued as "the last PASS_SOFT-bug victim" — it was not the last; there are 55 more EAs).

---

## Class 5 — Gate recalibrations (DL-075 / DL-078 / DL-076)

**Q08 pre-recal hard fails:** the 06-21 DL-075 conversion (INVALID 96 → FAIL_SOFT 130) already re-adjudicated this class in place. Only **1** terminal FAIL_HARD predating the recals fails purely on now-soft subgates:
- **QM5_10069 / XAUUSD — Q08 FAIL_HARD 06-21**: only true-FAIL subgate = 8.4_seasonal (now SOFT). But the deeper defect: **baseline_trades=3 in the Q08 stream while Q04–Q07 all PASSed with 20 trades (PF 1.29–1.41)** → this is really a Class-6 truncated stream + pre-DL-078 kill of a **nucleus EA**. Cost-cushion EDGE_HARD is an artifact of the 3-trade stream.

**Q04 low-freq pre-DL-076:** Q04 FAILs before 06-23 with avg <15 trades/yr that satisfy DL-076 guards (≥12 pooled, ≥2/3 active years) and pooled-PF-plausible ≥0.95: **392 items, 26 terminal**. Top: QM5_10260/NDX (pf 16.4, 18 pooled — later Q08 attempts were cost-killed, but the Q04 verdict itself was pre-DL-076), QM5_10919/XTIUSD, QM5_11132/NDX, QM5_11128/SP500, QM5_10023/NDX+SP500 (PF 1.39 P2/NDX), QM5_10888/SP500 (risk-tom-index), QM5_10145/WS30, QM5_10127/NDX, QM5_10513/XAUUSD (nucleus sister).

**Recommendation:** the 26 terminal low-freq items overlap heavily with Class 4 — requeue once under the current Q04 runner (it now applies both DL-071 and DL-076 paths).

---

## Class 6 — Truncated-stream / trade_count_mismatch family

Detector: `trade_count_mismatch` / `native_report_guard_fallback` / truncation markers in payload or detail_json, plus Q08 rows with baseline_trades>0 but subgate `got=0`, plus report-vs-stream contradictions.

- **7 marked items / 6 EAs + 2 found via other detectors (10069, 10094) → 8 EAs total.**

| ea_id | symbol | phase/verdict | status of repair |
|---|---|---|---|
| QM5_10569 | XAUUSD | Q08 FAIL_SOFT 07-01 | redump in progress per 07-01 ops — **verify it completed**; PF 1.96 Q03 (25t) |
| QM5_10938 | GDAXI | Q08 FAIL_SOFT 07-01 | same redump wave; PF 1.61 Q02 (41t) |
| QM5_11124 | SP500 | Q08 FAIL_SOFT 07-01 | same redump wave; PF 1.43 Q02 (54t) |
| QM5_11132 | SP500 | Q08 FAIL_SOFT 06-27 | REPAIRED → 11-sleeve book (validates class); GDAXI+NDX Q04 legs still carry pre-fix FAILs (Class 4/5) |
| QM5_10940 | XAUUSD | Q08 FAIL_SOFT 06-27 | REPAIRED → book sleeve (validates class) |
| QM5_12847 | SP500+NDX | Q04 INVALID 07-02 | already routed (Codex 05a836a7 — mechanic defect + requeue) |
| QM5_10069 | XAUUSD | Q08 FAIL_HARD 06-21 | **NOT yet routed** — 3-trade stream vs 20-trade report; nucleus EA (see Class 5) |
| QM5_10094 | GDAXI/WS30 | Q04 | already routed (Codex ed4d9627) |

**Recommendation:** the only un-routed recovery here is **QM5_10069/XAUUSD**: redump q08_trades stream, requeue Q08.

---

## Class 7 — Non-DWX broker-symbol backtests — CLEAN

After excluding logical basket symbols (legitimately non-DWX custom symbols: `QM5_*_COINTEGRATION_D1`, `FX8_TWIN_*`, etc.): **0 broker-symbol FAIL verdicts remain that were never re-run on .DWX**. The 2026-06-12 invalidation (196 `OBSOLETE_NON_DWX_SYMBOL` marks) fully covered the class. No action.

---

## Class 8 — launch_fault / watchdog-kill era terminal INFRA_FAIL

Detector: terminal INFRA_FAIL, attempts ≥2, updated in 2026-06-22..24 or 07-02, no pending requeue. Dominant failure string: `summary_missing_retries_exhausted` = the watchdog clean-slate respawn sawing off in-flight backtests (memory 8d665bfc4) — these EAs got 2 attempts *both inside the kill storm*.

- **631 terminal items / 188 EAs** in the specified windows (06-22..24 wedge + 07-02: 41 items).
- Additionally **310 terminal items / 79 EAs** from the 06-18..20 meltdown (9857-INFRA_FAIL day family) that repair never requeued — same recovery mechanics, outside the requested windows.

Top by gross edge (dedup by EA): QM5_10478/GBPUSD (**PF 2.55**), QM5_10454/GBPUSD (PF 1.91), QM5_9458/GBPUSD (PF 1.80), QM5_9459/NZDCAD+USDCAD (PF 1.70), QM5_9975/GBPUSD (PF 1.48), QM5_10789/GBPUSD (PF 1.40), QM5_9638/EURUSD (PF 1.27), QM5_12110/USDJPY (PF 1.24), QM5_10950/EURUSD (PF 1.22), QM5_10710+10711/XAUUSD (Edge-Lab EAs, PF 1.16), QM5_1238/NZDUSD, QM5_10587/XAUUSD.

**Recommendation:** bulk sweep-requeue of the 631 (attempt_count reset), throttled behind current queue backpressure; prioritize the ~50 EAs with gross PF ≥1.2 first.

---

## TOP-20 RECOVERY LIST (dedup by ea_id, ranked)

Ranking = provability of the false verdict × gross-edge evidence (PF ≥1.2 prioritized) × strategic value. "Requeue" = create fresh work item at the named phase; READ-ONLY audit did not touch the DB.

| # | ea_id | classes | best gross evidence | recommended action |
|---|---|---|---|---|
| 1 | **QM5_10069** | C6+C5-Q08 | Q04–Q07 PASS chain PF 1.29–1.41 (20t) — nucleus | Redump q08 stream → requeue Q08 XAUUSD (FAIL_HARD came from a 3-trade stream, pre-DL-075/078) |
| 2 | **QM5_11128** | C4+C5-LF | PF 3.43 Q03/SP500; folds 2/3 pos, pf 3.70, 44 OOS t | Requeue Q04 SP500 — provable PASS_SOFT fall-through |
| 3 | **QM5_10919** | C4+C5-LF | PF 4.36 Q02/XTIUSD; pooled pf 12.1 | Requeue Q04 XTIUSD+NDX (crude = low-cost class, gross≈net) |
| 4 | **QM5_10163** | C4 | PF 3.93 Q03/NDX; GDAXI folds 1.17/1.15/0.93 @312t | Requeue Q04 GDAXI (NDX leg already at Q08 06-27) |
| 5 | **QM5_10911** | C4 | folds 0.58/1.16/1.15 @157t; **sister of live sleeve 10911/GDAXI** | Requeue Q04 GBPUSD — book-diversifier potential |
| 6 | **QM5_10692** | C4 | GDAXI folds 1.74/0.72/2.56 @116t; **sister of Q12 candidate** | Requeue Q04 GDAXI |
| 7 | **QM5_10440** | C4 | XAUUSD folds 0.79/1.15/1.03 @238t; nucleus sister | Requeue Q04 XAUUSD |
| 8 | **QM5_10307** | C2b | **PF 4.84 Q02/SP500 (28t)**; 19 strategy inputs, set param-empty | Card-vs-default diff → regen set → requeue failed symbols |
| 9 | **QM5_1328** | C2b | PF 3.16 Q02/AUDUSD; 12+ symbols 0-trade w/ empty set | Regen setfile (known collision EA — verify ID first) → requeue |
| 10 | **QM5_10478** | C8+C2b | PF 2.55 Q02/USDJPY | Requeue Q02 GBPUSD+NDX (watchdog-kill 06-22) |
| 11 | QM5_10815 | C4+C5-LF | PF 2.13 Q02/GDAXI; XAU folds 2/3 pos | Requeue Q04 XAUUSD (GDAXI leg hit Q08 06-27 separately) |
| 12 | QM5_10920 | C4+C5-LF | Q04 pf 2.96, 30 OOS t | Requeue Q04 XAUUSD |
| 13 | QM5_10949 | C4+C5-LF | PF 1.64 Q03/XAUUSD; NDX+SP500 both 2/3 pos | Requeue Q04 NDX+SP500 |
| 14 | QM5_10142 | C4+C5-LF | PF 1.57 Q02/SP500; pf 3.25 | Requeue Q04 NDX (its SP500 sister hit Q08 FAIL_HARD 06-28 — family has legs) |
| 15 | QM5_10943 | C4+C5-LF | PF 1.68 Q03/SP500; pf 1.76 @41t | Requeue Q04 NDX |
| 16 | QM5_10260 | C5-LF | PF 1.89 Q03/NDX; Q04 pf 16.4 @18 pooled | Requeue Q04 NDX under DL-076 pooled path |
| 17 | QM5_1049 | C1 | PF 1.47 Q02/NZDUSD; 206 Q02 PASSes | Requeue Q02 AUDJPY (ONINIT fail, ex5 rebuilt 06-13) |
| 18 | QM5_10009 | C2a | PF 1.22 Q02 cointeg basket | Requeue Q03 basket (set regenerated 07-02 with 10 params) |
| 19 | QM5_1214 | C3 | holiday-effect; 0-trade INVALID on 2024-H2 prescreen | Requeue Q02 GER40 with full-year window |
| 20 | QM5_10454 | C8 | PF 1.91 Q02/XAUUSD | Requeue Q02 GBPUSD+XAUUSD (watchdog-kill 06-22) |

Bubble-under (21–30): 10375/SP500 (C4; NDX leg already rescued 07-02), 10513/XAUUSD (C4+C5-LF, nucleus sister), 10468/XAUUSD, 1061/NDX, 10588/XAUUSD, 10781/GDAXI (also C1), 9929/SP500+GBPUSD, 10023/NDX+SP500, 9458/GBPUSD (C8), 10888/SP500 (C5-LF, tom-index).
Already routed / in flight (excluded from ranks): 12847 (Codex 05a836a7), 10094 (Codex ed4d9627), 12836/NDX (requeued; GDAXI leg = rank-19-equivalent, add to same batch), 10569/10938/11124 (07-01 redump — verify completion), 10940+11132 (repaired → book; their pre-fix Q04 legs on other symbols appear above), 10467 (rescued 07-02).

## Caveats

- Everything here is *suspicion of a false verdict*, not proof of edge — the pipeline re-run remains the judge. Gates are deliberately conservative (OWNER doctrine); the recommendation is re-adjudication under current fixed machinery, not gate softening.
- Class 4 is the exception: the FAIL-vs-PASS_SOFT contradiction is provable from stored fold data without any re-run.
- Class 2b (559 EAs) must be diffed (card vs compiled defaults) before requeue — a param-empty set is only a false-fail generator when defaults diverge from the card.
- Counts exclude anything with a pending/active requeue already in the queue at audit time (5,212 Q02 items pending overall).
