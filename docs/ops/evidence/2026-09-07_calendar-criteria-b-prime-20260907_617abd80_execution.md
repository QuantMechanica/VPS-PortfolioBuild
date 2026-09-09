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

## Progress 16:23Z — first adjudication ended REVIEW_REQUIRED (cell_execution_failed), root cause = pre-sv build

- f625d9aa (QM5_11167/XAUUSD, T2 07:18–16:00Z): verdict `REVIEW_REQUIRED`, reason_codes `cell_execution_failed`, 8/8 cells `TransientCellError` — `run_smoke.ps1:3009 Required fresh structured logger sample was not authenticated` after `logger row is missing 'sv'`. The EX5 (built 2026-07-14) predates the P1 evidence-integrity control 6e92c80626 (2026-07-20) that added the `sv` field to `QM_Logger.mqh`; the Q09 v3 selection runner (`-RequireFreshLoggerSample`, since 2026-08-04) refuses such samples. Not a strategy, calendar or scope defect; the scoped-B marker + footnote are on the row.
- Scope: 10 of 54 pending Q10_NEWS rows are pre-sv builds (10148, 10476, 10771×2, 11179, 11196, 1230×2, 12474, 9573); of the 11 released B′ rows, 3 pending are pre-sv (10771, 11196, 1230), 7 are post-sv and adjudicable.
- Actions: 11196 (a909ee18) taken off the priority track (new single-row `mark-priority-track --unset`, fc6c6f99b1); f15ac955 (10145/SP500) and 136b0e0f (10513/XAUUSD) marked priority so the B′ path continues on post-sv builds; OWNER Vorlage + card **OWNER-DEC-Q09-LEGACY-LOGGER-SAMPLE-20260907** (recommendation A: declared legacy authentication for pre-sv builds in the selection run only). B′ acceptance "first adjudications end PASS/FAIL" is therefore still open; the next adjudication comes from a post-sv row.

## Progress 2026-09-08 14:12Z — OWNER chose A; one new legacy canary

- Actual chat approval A recorded as receipt `821096ac-8f7f-4c28-b0ce-63a09e959de1`.
- Code `07af95fcf1` implements exact Git-archived EX5/OWNER-receipt-bound fresh
  legacy authentication; no file-mtime exception, fabricated sv, or threshold change.
  Selection and holdout retain separate fresh archive/capture evidence and residual labels.
- 124 regression tests passed; native evidence acceptance remains OPEN.
- New 11167 append-only Q10_NEWS row `6797ed1c-597a-4d44-82f9-7379d45b5e06` has its
  own sealed v3 plan. Old `f625d9aa` remains untouched REVIEW_REQUIRED.
- The new row separately passed B′ assessment
  `b7400acdfa5db93b4863931e2b89ef53aab046de5b90621b329b661ac3b01c4f` and received a
  fresh scoped-B marker through `release_scoped_item`, 14:12:23Z; no pin publication.
- 11196 remains deliberately unprioritized and disabled in the legacy allowlist
  until the 11167 native authentication canary succeeds. No further OWNER choice needed.
- Continue from `2026-09-08_q09-legacy-logger-sample-20260907_821096ac_execution.md`;
  do not enqueue a duplicate implementation task or mark the native acceptance complete.

## Progress 2026-09-09 00:56Z — 6797ed1c canary ended REVIEW_REQUIRED; structural blocker, not a scope/calendar defect

- The 11167 native canary (`6797ed1c`) ended `REVIEW_REQUIRED`/`cell_execution_failed`
  again (updated_at 2026-09-08T17:32:10Z), but the cause this time is
  `RunnerError "MT5 report effective input qm_news_calendar_bundle_id mismatch"`,
  not the sv-logger gap. Root cause: QM5_11167's EX5 (committed 2026-07-14)
  predates commit `f0102fbcf` (2026-08-03), which is when the three
  `qm_news_calendar_*` provenance-echo inputs were added to `QM_NewsFilter.mqh`
  — same defect class as `QM5_9936` (2026-08-24 evidence). Full detail and the
  cohort-wide finding (all 9 legacy-logger-allowlist binaries predate 2026-08-03)
  in `2026-09-08_q09-legacy-logger-sample-20260907_821096ac_execution.md`.
- Consequence for B′: "first adjudications end PASS/FAIL" is unreachable for
  the pre-08-03 legacy cohort without a recompile (ROT, not autonomous). No
  hold, verdict or evidence touched; recommend a new OWNER card (rebuild
  pre-08-03 cohort vs. park). This task and 60cd31a8 remain gated on that
  decision for the last unreleased/unadjudicated legacy rows.
