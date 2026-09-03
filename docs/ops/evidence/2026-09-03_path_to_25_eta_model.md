# Path-to-25 ETA model — data-driven counter forecast (2026-09-03)

READ-ONLY analysis. No verdict, gate, queue, runtime or T_Live change was made. All
inputs are queries or files, cited inline. Companion numbers:
`docs/ops/evidence/2026-09-03_path_to_25_eta_model.json`.

---

## OWNER-Zusammenfassung (DE)

- **Zähler steht bei 5/25** (`book_build_guard --status --venue both`: `qualified_pairs=5`),
  Terminalgate = **Q14**. Die 5: 10706/GBP, 11421/EUR, 11422/USDCAD, 13054/XTI, 1537/XAG.
- **Struktureller Deckel: nur 19 Paare sind Q11-kontiguierend** (Zensus-Warteschlange). 5 + 19 = **24**.
  Das 25. Paar muss aus dem 63-Paar-Q09-Pool erst hochklettern — 25 ist ohne diesen Zulauf unerreichbar.
- **Einziger echter Engpass für 10/15 = Zensus-Durchsatz.** Gemessen fleet-weit ~138 Zellen/h
  (24h-Schnitt 111, Peak 172), Zelle ~2,0 min, **G_eff = 6 parallele Zellen** (K=8, L=1, cell_slots=6).
- **S0 (heute):** 10→**04.09.**, 15→**06.09.**, 20→**07.09.**, 25→**09.09.** (zentral).
- **S1 (L=2 für 3 Leadprogramme):** hebt NUR aus, wenn wir gerade slot-hungern (gemessene Belegung
  ~4-5 < 6). L allein sprengt die 6er-Decke NICHT. Zieht 10/15 um ~½-1 Tag vor: 25→**08.09.**
- **S2 (L=2 alle + `DL089_CELL_SLOTS`↑ auf 10):** der eigentliche Durchsatzhebel, gedeckelt durch
  RAM-Latch/Flotte (20-50 Zellen/10 min). ~2× schneller: 10→**04.09.**, 25→**06.-07.09.**
- **Zwei Nebenengpässe für 20/25:** News-Expansion (Cap 2 parallel, ~2,5 h, 105 Zellen) und die
  **Sibling-Pflicht** (jedes neue Programm braucht 1 approved `_opt`-Sibling; 11708/EUR, 41221/EUR
  fehlen noch). Sofort parallel anstoßen, sonst binden sie 20 um ~½-1 d, 25 um ~1-2 d.
- **Empfehlung:** S0 fahren; S1 als Canary nur wenn Belegung < 6 messbar; S2 vorbereiten
  (cell_slots-Anhebung minten) — sie ist der einzige Hebel, der 25 vor den 09.09. zieht.

---

## 1. Where the counter stands and what "counts"

`python tools/strategy_farm/book_build_guard.py --status --venue both` →
`qualified_pairs=5`, `distinct_eas=5`, `strategy_families=5`,
`qualified_pairs_below_minimum: 5 < 25`.

A pair counts when its `highest_contiguous_valid_gate == terminal_requalification_gate`.
`gate_manifest.load_gate_manifest().terminal_requalification_gate = Q14`
(`book_build_guard.py:190`, `rebaseline_census.summarise_pair`). Running the census over the
live DB (`rebaseline_census.build_pairs`, `mode=ro`) gives the contiguity distribution:

| highest contiguous gate | pairs |
|---|---:|
| **Q14 (QUALIFIED)** | **5** |
| Q11 | **19** |
| Q09 | 63 |
| Q07 | 82 |
| Q06 | 62 |
| Q04 | 136 |
| Q03 | 1505 |
| Q02 | 5139 |

- **Qualified (Q14):** QM5_10706/GBPUSD, QM5_11421/EURUSD, QM5_11422/USDCAD,
  QM5_13054/XTIUSD, QM5_1537/XAGUSD.
- **Q11-contiguous (the candidate pool, 19):** 10145/XAU, 10403/XAU, 10513/XAU, 11660/NDX,
  11708/EUR, 11881/GBP, 11910/NZD, 12710/XTI, 12849/XTI, 12855/XTI, 13013/NDX, 13213/USDJPY,
  20048/XTI, 20266/XTI, 21501/USDJPY, 21505/XAG, 21507/XAU, 41221/EUR, 9641/WS30.

**Structural finding #1 — the 24-pair ceiling.** 5 qualified + 19 candidates = **24**. Reaching
25 is impossible from the current at-or-above-Q10 inventory alone; **at least one pair must climb
from the 63-pair Q09 pool** through Q10 (news), a fresh `_opt` sibling, and a full census. The
recompile-wave pair QM5_10700/XAUUSD (new identity, at Q06 as of today's amendment-B log) is the
natural 25th feeder.

The census→count mechanism: a Q11-contiguous pair jumps straight to Q14-contiguous when its
DL-089 pattern-filter census (the Q14 optimisation branch) **completes** and is admitted through
Q12/Q13. Confirmed empirically — the 3 fully-run programs (11421 1161/1161, 13054 1089/1089,
1537 1090/1091 done cells) are exactly the pairs now sitting at Q14. 10706 and 11422 reached Q14
via a first full program; their current second-pass census rows were deferred to `2099-01-01`
(amendment B, `set_dl089_queue_order.py apply --defer`) because they already count.

## 2. The rate-limiting stage: DL-089 census throughput

Per-program census state (live DB, `phase='OPT_CENSUS'` grouped by `payload.program_id`,
2026-09-03 15:02Z). `remaining = pending cells`; a full census ≈ 1085 cells
(155 arms × 7 years, `ledger.json: arm_count_per_year=155`):

| candidate pair | census carrier | done | pending (remaining) |
|---|---|---:|---:|
| 21505/XAG | DL089_QM5_21505 | 778 | **307** |
| 20048/XTI | DL089_QM5_20048 | 582 | 503 |
| 13213/USDJPY | DL089_QM5_41097 (sibling) | 561 | 524 |
| 21507/XAU | DL089_QM5_21507 | 546 | 539 |
| 20266/XTI | DL089_QM5_20266 | 307 | 777 |
| 10513/XAU | DL089_QM5_10513 | 204 | 881 |
| 10145/XAU | DL089_QM5_10145 | 158 | 926 |
| 11881/GBP | DL089_QM5_11881 | 149 | 936 |
| 10403/XAU | DL089_QM5_10403 | 42 | 1043 |
| 12710/XTI | DL089_QM5_12710 | 20 | 1064 |
| 11910/NZD | DL089_QM5_11910 | 1 | 1084 |
| 13013/NDX, 11660/NDX, 21501/USDJPY, 12849/XTI, 12855/XTI, 9641/WS30, 11708/EUR, 41221/EUR | ledger only | 0 | 1085 each |

**Measured throughput** (live DB, `status='done'` OPT_CENSUS by `updated_at`, normalised
`replace(substr(updated_at,1,19),'T',' ')`):
- last 24 h: **2666 cells** → **111 cells/h** fleet-wide (long-run, includes pauses/ramps).
- hourly, 05–12Z steady window: 118/134/215/166/245/122/216/161 → **mean 172 cells/h** (peak).
- 13–15Z: 55/33/2 — the recompile-wave CPU/RAM pause (amendment-B log 02:49–05:58Z), transient.
- cell duration (payload `started_at_iso`→`updated_at`, 8 h, n=334): **median 2.0 min**, mean 2.3.

**Concurrency ceiling.** `dl089_scheduling.effective_limits(workers=10)` with the machine env
`DL089_PROGRAM_SLOTS=8`, `DL089_LANES_PER_PROGRAM=1` (default), `DL089_CELL_SLOTS=6` (default),
allowlist empty → **(K=8, L=1, G_eff=6)**. G_eff is the fleet-wide concurrent-cell cap:
`g_eff = min(cell_slots=6, K*L=8, workers=10) = 6`. At 2.0 min/cell, G=6 gives a hard ceiling of
**180 cells/h**; measured 111–172/h ⇒ effective concurrency ~3.7–5.7, i.e. running at 62–96 % of
the G=6 ceiling.

**Reconciliation with "8-9 cells/h per program at L=1"** (amendment-B log, today): with 6 cell
slots rotating across ~8-11 programs, a slow-symbol program (NDX/XTI) sees ~8-10/h (last-2h
sample: 12710≈10/h, 11881≈9/h, 20048≈7/h), while a fast-symbol program (XAG/XAU D1) burns much
faster (21505 did 392 cells in 6 h ≈ 65/h). The **fleet cell rate**, not the per-program rate, is
the robust binding constraint and is what this model uses.

## 3. The model

To reach counter value N we must **complete the census of the (N-5) nearest-to-done candidate
programs**. Ordering the candidates by ascending remaining cells and cumulating:

| N | pair added | remaining | cumulative cells |
|---:|---|---:|---:|
| 10 | 20266/XTI | 777 | **2 650** |
| 15 | 12710/XTI | 1064 | **7 500** |
| 20 | 12849/XTI | 1085 | **12 924** |
| 25 | below-Q11 feeder | 1085 | **18 349** |

Wall-clock to reach N = `cumulative_cells / fleet_rate`, assuming the governed queue focuses the
G_eff cell budget on the nearest-ranked programs (which the amendment-B "adds-a-pair-first" queue
order now enforces: `set_dl089_queue_order.py`, `dl089_matrix_service._queue_order`). Anchor:
`now = 2026-09-03 15:02Z`.

### Scenario rates (cells/h)

| scenario | G_eff | low | central | high | basis |
|---|---:|---:|---:|---:|---|
| **S0** current K=8, L=1 | 6 | 111 | 138 | 172 | 24 h avg → peak-steady; median cell 2.0 min |
| **S1** canary L=2, 3 leads | 6 | 140 | 165 | 180 | **G unchanged**; utilisation lift toward 180/h ceiling *iff* starvation-limited |
| **S2** L=2 all + cell_slots≥10 | 10 | 200 | 240 | 290 | needs `DL089_CELL_SLOTS` raise; ceiling 20-50 cells/10 min; RAM latch caps sustained ~240/h |

### Milestone dates (central; [earliest .. latest])

| | 10 pairs | 15 pairs | 20 pairs | 25 pairs |
|---|---|---|---|---|
| **S0** | **04.09 10:14Z** | **05.09 21:22Z** | **07.09 12:41Z** | **09.09 04:00Z** |
| | [04.09 06Z..14Z] | [05.09 11Z..06.09 11Z] | [06.09 18Z..08.09 11Z] | [08.09 02Z..10.09 12Z] |
| **S1** | 04.09 07:05Z | 05.09 12:29Z | 06.09 21:21Z | 08.09 06:14Z |
| **S2** | 04.09 02:04Z | 04.09 22:17Z | 05.09 20:53Z | **06.09 19:29Z** |

(S0 hours-to-milestone central: 19.2 h / 54.3 h / 93.7 h / 133.0 h.)

## 4. The two secondary bottlenecks (bind 20 and 25, not 10/15)

**News-gate expansion — cap 2, 105 cells.** `pump_task_20260903T145801Z.log` `news_expansions`:
`limit=2`, `read_phases=[Q10_NEWS]`, `candidate_count=31`. Each expansion is the
`expanded_7x4_matrix_required` full-history news confirmation (measured `q09_cell_count=29` for
the 2017–2022 window on the active QM5_10700 row `c0faeb48`; ≈105 cells over the full seam-
reconstructed window) at ≈2.5 h wall (amendment-B log). With only **2 running at once**, draining
the ~4-6 counter-relevant expansions is ~5-15 h serial. This gates a pair's *entry* to Q11, so it
sits **upstream** of the census for the 25th (below-Q11) pair and any recompile-wave pairs.

**Sibling requirement — one approved `_opt` per program.** `dl089_matrix_service` defers a program
with `expected one approved _opt sibling for <pair>, found 0` (pump log, 12-24×/cycle) for:
11708/EUR, 41221/EUR, 21502/XAU, 20086/NDX, 20086/EUR, 11294/XAU, 10911/GDAXI. A sibling is a
rebuilt `_opt` EA (the DL-089 corset: six neutral-default `opt_pp_*` inputs) that must pass
build + compile + a fresh Q02 **before its census can start**. Four were built today
(41321→13013/NDX, 41322→10403/XAU, 41323→11660/NDX, 41324→21501/USDJPY —
`2026-09-03_57bc396f_path_to_25_four_siblings.md`), which is why those four sit high in the ladder.
**11708/EUR and 41221/EUR (ladder #23-24) still need siblings** and cannot begin census until built.

**Combined verdict.** For **10 and 15**, census throughput is the sole binding constraint — every
program is already running. For **20 and 25**, the feeder (siblings for 11708/41221, the below-Q11
climb of 10700, and the news cap-2 queue) must be **commissioned now, in parallel**. If it is, it
finishes inside the multi-day census window and does **not** move the dates above. If it is not, it
becomes the binding constraint and pushes **20 by ~0.5-1 d** and **25 by ~1-2 d** beyond the table.

## 5. Assumptions and sensitivity

1. **Full 1085-cell census per pair.** Confirmed by the 3 completed programs = the 3 pure-census
   Q14 pairs. If admission could fire on a partial census, all dates pull in proportionally;
   no evidence for that today.
2. **Fleet rate is stationary at the scenario value.** The 13-15Z dip (recompile pause) is
   excluded from the steady rate; if such pauses recur, use the S0 *low* column (111/h) — that is
   why the range is quoted. Sensitivity: at 111 vs 172/h the S0 dates span ±~30 %
   (25 pairs: 08.09 vs 10.09).
3. **Priority scheduling wastes no throughput on non-completing far programs.** Enforced by the
   amendment-B queue order; under pure round-robin the *first* increments arrive later (pairs
   cluster near the end) — a reason to prefer S1's front-loading for early milestones.
4. **S1 is a latency lever, not a throughput lever.** `effective_limits` proves L=2 with
   `cell_slots=6` leaves **G_eff=6** — no fleet gain. Its only benefit is lifting utilisation from
   the measured ~4-5 concurrent toward the 6 ceiling **if** the shortfall is program-starvation
   (likely: only ~11 programs have claimable cells and sibling gating idles slots). If the
   shortfall is RAM/CPU, S1 = S0. **S2 is the only real throughput lever** and requires raising
   `DL089_CELL_SLOTS` as well (a new bounded env change; GELB — new lever needs a hypothesis +
   refutation criterion per the Stehende Vollmacht).
5. **10-worker fleet / RAM latch caps S2.** The task ceiling of 20-50 cells/10 min (=120-300/h)
   is the fleet+RAM bound; S2 central 240/h assumes the RAM latch holds sustained rate below the
   50/10-min ceiling. If the latch trips more often, S2 → its low column (200/h).

## 6. Recommended next step

Run **S0** as the baseline. **Commission the 20/25 feeder now** (siblings for 11708/EUR and
41221/EUR; keep the 10700/XAUUSD Q07→Q10 chain + its news expansion moving) so it never becomes
binding. Treat **S1** as a measured canary only — instrument concurrent-cell occupancy first; adopt
it solely if occupancy is provably < 6. Prepare **S2** as the single date-moving lever: mint the
`DL089_CELL_SLOTS` raise as a GELB new-lever Vorlage (hypothesis: raising G 6→10 lifts fleet census
rate ~1.5-2×; refutation: RAM-latch trip rate rises or per-cell time inflates > proportionally),
since only S2 pulls 25 before 09.09.

---

### Evidence / query index

- Counter & qualification: `book_build_guard.py --status --venue both`; `book_build_guard.py:72-80,190`;
  `gate_manifest.terminal_requalification_gate=Q14`; `rebaseline_census.build_pairs/summarise_pair` (mode=ro).
- Census state & throughput: live DB `D:/QM/strategy_farm/state/farm_state.sqlite` (opened `?mode=ro`),
  `work_items` `phase='OPT_CENSUS'` grouped by `json_extract(payload_json,'$.program_id')`, status and
  normalised `updated_at`; cell durations from payload `started_at_iso`/`updated_at`.
- Ledgers: `D:/QM/strategy_farm/artifacts/opt_census/DL089_*/ledger.json` (`arm_count_per_year=155`, cells[]).
- Slot config: `tools/strategy_farm/dl089_scheduling.py` (`effective_limits`, defaults K=4/L=1/G=6, machine
  `DL089_PROGRAM_SLOTS=8`); verified `effective_limits(10)=(8,1,6)`, L=2→(8,2,6), L=2+G_env=10→(8,2,10).
- Governed queue: `DL089_PROGRAM_SLOTS=8 python tools/strategy_farm/set_dl089_queue_order.py list` (30 rows).
- Deferrals: `D:/QM/strategy_farm/logs/pump_task_20260903T145801Z.log` — `PROGRAM_SLOT_WAIT:K=8`,
  `expected one approved _opt sibling …, found 0`, `news_expansions{limit:2, candidate_count:31}`.
- Chain timings: `docs/ops/evidence/2026-09-03_owner_dec_pre0803_recompile_slot_order_amendment_b.md`
  (compile→Q09 ≈4-6 h; news expansion ≈2.5 h; census ≈8-9 cells/h per program at L=1).
- Siblings built today: `docs/ops/evidence/2026-09-03_57bc396f_path_to_25_four_siblings.md`.
- Numbers sidecar: `docs/ops/evidence/2026-09-03_path_to_25_eta_model.json`.


## CEO verification notes (2026-09-03 15:40Z, workflow wf_e1f78de2-ae7)

Adversarial verifier: could not refute the core ETA (all cited counts reproduced
exactly against the live DB). Caveats that change how the model is read:

- The "hard ceiling 180 cells/h at G_eff=6" is contradicted by the model's own
  hourly buckets (07Z=215, 09Z=245, 11Z=216): a single fast metal-D1 program
  (QM5_21505/XAGUSD) sustained up to 133 cells/h alone. S2 (G=10) is therefore
  not the only throughput lever; the fleet already exceeds 180/h when fast
  programs run.
- Rate stationarity is directional, not symmetric: the ~138/h central rate is
  carried by a few fast programs that drain first, so the later milestones are
  biased optimistic beyond the 111-172/h band.
- The cumulative-cells method ignores L=1 per-program serialization: a counter
  step needs one specific program to finish, and a high-remaining program can
  govern a milestone even when fleet throughput is available.
- Last-24h count is 2665, not 2666 (boundary tick, immaterial).
- Structural finding stands: 5 + 19 Q11-contiguous = 24; pair 25 needs at least
  one climber from the Q09 pool (QM5_10700/XAUUSD is the modelled candidate).
