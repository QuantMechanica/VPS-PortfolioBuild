# OWNER Vorlage 2026-09-04 — Path to 25: census shortening, Amendment C, bundle rule

Status: submitted 2026-09-04 ~16:40Z by the CEO (Claude). Three decisions. None executes without an explicit OWNER receipt (all three touch gate criteria, the OWNER slot order, or the book rule = ROT; the 12 h Auffangregel does not apply).

## Evidence (as of 16:35Z)

Counter: 8/25 (book_build_guard, census-based). Terminal pairs and their optimization outcome:

| pair | Q12 filter census | Q13 parameter census | Q14 head-to-head |
|---|---|---|---|
| QM5_10706 GBPUSD | PASS (candidate) | NO_PARAMETER_CHANGE | KEEP_INCUMBENT (2026-08-25) |
| QM5_11421 EURUSD | NO_FILTER_CHANGE | NO_PARAMETER_CHANGE | KEEP_INCUMBENT (09-02) |
| QM5_11422 USDCAD | NO_FILTER_CHANGE | NO_PARAMETER_CHANGE | KEEP_INCUMBENT (08-25) |
| QM5_13054 XTIUSD | NO_FILTER_CHANGE | NO_PARAMETER_CHANGE | KEEP_INCUMBENT (09-03) |
| QM5_1537 XAGUSD | NO_FILTER_CHANGE | NO_PARAMETER_CHANGE | KEEP_INCUMBENT (09-03) |
| QM5_20048 XTIUSD | NO_FILTER_CHANGE | NO_PARAMETER_CHANGE | KEEP_INCUMBENT (09-04) |
| QM5_21505 XAGUSD | NO_FILTER_CHANGE | NO_PARAMETER_CHANGE | KEEP_INCUMBENT (09-04) |
| QM5_11910 NZDUSD | NO_FILTER_CHANGE | NO_PARAMETER_CHANGE | KEEP_INCUMBENT (09-04) |

Eight of eight kept the incumbent. CORRECTION 16:51Z: no Q12 run ever produced a filter candidate (0 of 11); the two Q12 rows with verdict `PASS` (11421, 10706, 2026-08-26) are baseline run-smoke results, and both Q14 receipts read `NO_CHALLENGER_BOTH_UPSTREAM_STAGES_NO_CHANGE`. Two of the eight counted pairs carry a terminal Q14 from 2026-08-25 although their pattern census is incomplete: 10706/GBPUSD 329/1085 cells (years 2019–2021), 11422/USDCAD 254/1085 (2019–2020); their re-baseline programs (41161, 41163: 756 and 831 pending cells) are completing the census. Formally terminal per OWNER-DEC-A1, substantively six fully optimized plus two pending re-census. What the cells show: for 11421/EURUSD (3–19 trades per year) 132 of 154 arms are byte-identical to the baseline in every year — the pattern never coincided with an entry, so the blacklist blocked nothing; the remaining arms differ in a single year by one blocked trade. For 10706/GBPUSD (32–37 trades per year, 3 years measured) six arms show +17 % to +23 % mean uplift in 2 of 3 years (buy blacklists PIN_BAR_BEAR, LOWER_LOW, VOL_CONTRACTION; sell blacklists NR7, BELT_HOLD_BULL, LONG_UPPER_WICK) — promising, not yet at the 2/3-of-7 bar. The optimization fork has adopted zero changes so far. It does deliver robustness evidence (no incumbent was beaten by its own parameter or filter neighbourhood), but at ~1000 census cells per pair (~10 factory hours on four census slots) it is currently a counting toll.

Census pipeline (16:35Z): 11 programs, 8005 pending cells, throughput 44/h (last hour, CPU/RAM throttled), 72–83/h (3–6 h), 114/h (12 h). Nine programs serve new pairs (21507/XAUUSD 317 cells, 12710/XTIUSD, 20266/XTIUSD, 41097/USDJPY, 11881/GBPUSD, 10513/XAUUSD, 10145/XAUUSD, 10403/XAUUSD, 10700/XAUUSD); two are re-baselines of already counted pairs (10706, 11422). Projection without change: ~17/25 around 2026-09-08.

Thirteen Q11-complete pairs have NO census program yet: 11294/XAUUSD, 11660/NDX, 11708/EURUSD, 12849/XTIUSD, 12855/XTIUSD, 13013/NDX, 20086/EURUSD, 20086/NDX, 21501/USDJPY, 21502/XAUUSD, 41219/XAUUSD, 41221/EURUSD (+1). Eight of them are needed for 25. NDX pairs additionally sit behind the 44 GB single_index_tick admission (Vorlage 1, RAM). Without a decision: 25 not before ~2–3 weeks.

## Decision 1 — shorten the census (CORRECTED 16:43Z; RECOMMENDED: Option B2)

Correction: the 1085-cell programs ARE the pattern census (7 baseline + 539 buy + 539 sell = 77 patterns x 2 directions x 7 years). The Q13 numeric sweep declared zero parameters in 11 of 11 runs (`NO_NEW_PARAMETER_SWEEP`, no cells). Skipping Q13 therefore saves nothing; the original Option A is withdrawn.

Option B1 — fewer years: census 2021–2025 instead of 2019–2025 (775 cells, −29 %). Simple, weakens the walk-forward base.

Option B2 (recommended) — two-stage screening: stage 1 measures all 154 arms on two screening years (2 x 155 = 310 cells); only arms that beat the baseline by >= +5 % in BOTH screening years enter stage 2 (the remaining five years). Expected ~350–450 cells per pair (−60 % to −65 %); the declared trial count stays 154 (DSR deflation unchanged), the selection rule (consistency >= 2/3 folds at +5 %) applies to stage 2. Pre-registered, append-only, no change to the head-to-head. Effect: 25 reachable in ~1.5 weeks instead of ~3.

Option B3 — curated pattern subset (e.g. the arms that ever produced a candidate). Changes the declared trial count and the selection rule = ROT; not recommended without a separate study.

Option B5 (recommended together with B2) — fire-count pre-screen: derive from the baseline run's trade log and the OHLC history how often each of the 154 arms would actually block an entry over 2019–2025; run census cells only for arms that fire at least N times (proposal N = 5). Deterministic, performance-blind (no selection bias), append-only; for low-frequency EAs it removes ~85 % of cells (11421: 132 of 154 arms never fire). Declared trial count stays 154.

Option B4 — status quo (1085 cells per pair; ~2 weeks of factory time for the remaining programs plus the 13 uncovered pairs).

## Decision 2 — Amendment C to the slot order (RECOMMENDED: YES)

Mint census programs for the thirteen uncovered Q11 pairs, in this order: FX/metal/oil pairs first (11708/EURUSD, 12849/XTIUSD, 12855/XTIUSD, 20086/EURUSD, 21501/USDJPY, 41221/EURUSD, 21502/XAUUSD, 41219/XAUUSD, 11294/XAUUSD), the NDX rows (11660, 13013, 20086/NDX) last and only after Vorlage 1 (RAM) opens a 44 GB window. Programs are enqueued behind the current seven ordered programs; nothing running is displaced. Rollback: programs can be parked with a hold. If Decision 1 = YES, the new programs are minted in the shortened form.

## Decision 3 — bundle rule for Q08 FAIL_SOFT (RECOMMENDED: align with the census rule)

`assemble_stream_bundle.py` binds only Q08 rows with verdict `PASS`. The census (`rebaseline_census.GATE_SCOPED_PASS = {"Q08": {"FAIL_SOFT"}}`, per OWNER-DEC-DL082-EXT Option D) and the pipeline treat Q08 FAIL_SOFT as contiguous book evidence, which is why pair 8 (11910/NZDUSD, soft gates 8.4/8.6/8.7) counts. Its sealed stream of the current identity exists since 16:05Z (work item 977a478e, identity_status BOUND_STREAM_BUILD_SETFILE_SOURCE_AND_REPORT, content 555bbee2…) but the bundle refuses it (`no_q08_stream_bound_to_identity`). Recommendation: the bundle accepts the same Q08 PASS-class as the census (PASS, FAIL_SOFT). Rollback: revert the one-line filter. Cost of waiting: none before the ceremony; at 25 the ceremony would stall on every FAIL_SOFT pair.

## Not in this Vorlage

Vorlage 1 (RAM/CPU): 553 pending rows >= 40 GB, 32 GB basket admission at ~25 GB free (reservation is paper), Q05 outliers, XAUUSD Q07 at 11–12 GB each, CPU saturation at ~9 testers, calibration run in a Factory-OFF window. Separate card.
