# Execution record — OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907 = YES

- Receipt: `617abd80-f0d9-49b4-b817-e82abf0ad381` (OWNER via chat 2026-09-07 ~05:35Z: "OWNER-DEC-CALENDAR-CRITERIA-B-PRIME-20260907: JA"; recorded by the Orchestrator with card + plan binding).
- Execution task (Claude lane): `bb814520-3364-5355-97b6-27f662f3ed8b` (mode APPLY_AND_VERIFY). Depends on OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907 = YES (task 60cd31a8, consumer B active, 0/47 admissible under the D1-only rule).
- Boundary: criterion "measured gates + declared residuals" formalized in the calendar gate contract; consumer B admissibility extended beyond D1 for USD-only exposure (rows with non-USD exposure or event-by-event overlap stay held); marker + footnote on every released row; re-adjudication ticket 235e5119 stays bound; NO production repin/publish, no T_Live/AutoTrading, no Q-gate threshold change.

## Steps
1. Codex ticket (high): gate-contract criterion (measured + declared residual classes: event-by-event without official schedule, footprint instants beyond the custom-history boundary 2024-12-31, non-USD classes without confirmed anchors), consumer B admissibility for all timeframes when exposure is USD-only (declared exclusions per row keep the row held), tests, new production dry run listing admissible rows (expect 11196/XAUUSD a909ee18 among them).
2. After integration (+ worker reload if the claim guard / taint module changes): release admissible rows row by row (append-only), 11196 first (priority_track kept); observe the first adjudications (PASS/FAIL, not INVALID).
3. OPEN_ITEMS + Vault (03 Pipeline/Q10_NEWS) + Mission Control until independent acceptance.

## Acceptance (independent, after step 2)
Criterion recorded with exact residual classes; B admits USD-only rows of any timeframe and still refuses non-USD-exposed rows; released rows carry marker + footnote; first adjudications terminal; no repin/publish/threshold/verdict change.

## Progress 2026-09-07 07:20Z — B′ implemented (934e6104 APPROVED), release wave 1

- B′ contract sealed (measured PASS + three declared residual kinds; publication/hold-release authority false); consumer B-prime admits USD-only rows of any timeframe with a sealed Q10 window → production dry run **12 ADMISSIBLE / 19 EXCLUDED**, a909ee18 (11196/XAUUSD H4) admissible.
- Worker reload chunk 58 (claim-guard semantics): 9/10 done, T3 finishing a Q07 cell.
- **Wave 1 release 07:16Z** (`release_scoped_b_rows.py`, receipt `2026-09-07_scoped_b_release_bprime_wave1_0716Z.json`): **a909ee18 (11196/XAUUSD) and f625d9aa (11167/XAUUSD) released** with marker + footnote; taint hold inactive; priority_track kept; awaiting a free XAUUSD slot. 10 rows refused by design: 8 scoped window successors are review-only/non-claimable with `Q09_AWAITING_SEALED_PLAN` holds, 10771/11129 carry `NEWS_RUNNER_SPAWN_SILENT_ABORT` holds → Codex wave-2 ticket (P92).

## Progress 2026-09-07 08:15Z — wave 2: 11 of 12 admissible rows released; first adjudication running

- Codex 253814f1 APPROVED (0fc9a30c19): eight scoped window successors converted to claimable Q10_NEWS rows with contract-v3 plans and Q09-PASS anchors, then released via `release_scoped_item` (marker + footnote); 10771 released after the runner PID-reuse fix; **745671a4 (11129/SP500) deferred** — its bound Q07 evidence file is missing (DL-090 loss class) → lineage-regeneration ticket (P70). Total released: 11 (wave 1: a909ee18, f625d9aa; wave 2: 9).
- **First B′ adjudication:** f625d9aa (11167/XAUUSD) active on T2 since 07:18Z. a909ee18 (11196) waits for a free XAUUSD slot (priority_track). Reload chunk 58: 9/10 (T3 on a Q07 cell).
