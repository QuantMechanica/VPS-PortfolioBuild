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

Eight of eight kept the incumbent; the single filter candidate (10706) lost the head-to-head. The optimization fork has adopted zero changes so far. It does deliver robustness evidence (no incumbent was beaten by its own parameter or filter neighbourhood), but at ~1000 census cells per pair (~10 factory hours on four census slots) it is currently a counting toll.

Census pipeline (16:35Z): 11 programs, 8005 pending cells, throughput 44/h (last hour, CPU/RAM throttled), 72–83/h (3–6 h), 114/h (12 h). Nine programs serve new pairs (21507/XAUUSD 317 cells, 12710/XTIUSD, 20266/XTIUSD, 41097/USDJPY, 11881/GBPUSD, 10513/XAUUSD, 10145/XAUUSD, 10403/XAUUSD, 10700/XAUUSD); two are re-baselines of already counted pairs (10706, 11422). Projection without change: ~17/25 around 2026-09-08.

Thirteen Q11-complete pairs have NO census program yet: 11294/XAUUSD, 11660/NDX, 11708/EURUSD, 12849/XTIUSD, 12855/XTIUSD, 13013/NDX, 20086/EURUSD, 20086/NDX, 21501/USDJPY, 21502/XAUUSD, 41219/XAUUSD, 41221/EURUSD (+1). Eight of them are needed for 25. NDX pairs additionally sit behind the 44 GB single_index_tick admission (Vorlage 1, RAM). Without a decision: 25 not before ~2–3 weeks.

## Decision 1 — shorten the census (RECOMMENDED: YES)

Option A (recommended): skip the Q13 parameter census when the pair's Q08 sub-gate 8.5 (parameter neighbourhood) is PASS; keep the Q12 filter census (~200 cells) and Q14 as the closing head-to-head. Rationale: 8.5 already measures parameter robustness on the same binary and window; Q13 has never overturned it (8/8). Effect: 3–5x fewer cells per pair; 25 reachable in ~1 week instead of ~3. Rollback: re-enable Q13 for any pair on request (append-only rows; nothing is overwritten). Blast radius: gate criterion (DL-089 census plan v3 declared trial count changes; the selection rule itself is untouched).

Option B: keep the full census (status quo). Cost of waiting: ~2 weeks of factory time for a fork that has adopted nothing in 8/8 cases.

Option C: count Q11-complete pairs directly (change of OWNER-DEC-A1). Not recommended: the census is the only proof that the incumbents are not fragile.

## Decision 2 — Amendment C to the slot order (RECOMMENDED: YES)

Mint census programs for the thirteen uncovered Q11 pairs, in this order: FX/metal/oil pairs first (11708/EURUSD, 12849/XTIUSD, 12855/XTIUSD, 20086/EURUSD, 21501/USDJPY, 41221/EURUSD, 21502/XAUUSD, 41219/XAUUSD, 11294/XAUUSD), the NDX rows (11660, 13013, 20086/NDX) last and only after Vorlage 1 (RAM) opens a 44 GB window. Programs are enqueued behind the current seven ordered programs; nothing running is displaced. Rollback: programs can be parked with a hold. If Decision 1 = YES, the new programs are minted in the shortened form.

## Decision 3 — bundle rule for Q08 FAIL_SOFT (RECOMMENDED: align with the census rule)

`assemble_stream_bundle.py` binds only Q08 rows with verdict `PASS`. The census (`rebaseline_census.GATE_SCOPED_PASS = {"Q08": {"FAIL_SOFT"}}`, per OWNER-DEC-DL082-EXT Option D) and the pipeline treat Q08 FAIL_SOFT as contiguous book evidence, which is why pair 8 (11910/NZDUSD, soft gates 8.4/8.6/8.7) counts. Its sealed stream of the current identity exists since 16:05Z (work item 977a478e, identity_status BOUND_STREAM_BUILD_SETFILE_SOURCE_AND_REPORT, content 555bbee2…) but the bundle refuses it (`no_q08_stream_bound_to_identity`). Recommendation: the bundle accepts the same Q08 PASS-class as the census (PASS, FAIL_SOFT). Rollback: revert the one-line filter. Cost of waiting: none before the ceremony; at 25 the ceremony would stall on every FAIL_SOFT pair.

## Not in this Vorlage

Vorlage 1 (RAM/CPU): 553 pending rows >= 40 GB, 32 GB basket admission at ~25 GB free (reservation is paper), Q05 outliers, XAUUSD Q07 at 11–12 GB each, CPU saturation at ~9 testers, calibration run in a Factory-OFF window. Separate card.
