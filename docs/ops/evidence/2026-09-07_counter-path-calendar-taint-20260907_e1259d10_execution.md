# Execution record — OWNER-DEC-COUNTER-PATH-CALENDAR-TAINT-20260907 = YES (Option B)

- Receipt: `e1259d10-5bf7-48d4-8059-594159e98445` (OWNER via chat 2026-09-07 ~04:58 local: "Karte Ja"; recorded by the Orchestrator; card sha d5b9f558…, plan sha 1f94374c…).
- Execution task (Claude lane): `60cd31a8-d479-5900-875b-c611e9c2fdb8` (mode APPLY_AND_VERIFY).
- Boundary: no repin, no calendar publish, no T_Live/AutoTrading, no gate threshold; taint hold lifted ONLY for rows the scoped consumer B adjudicates; every pair counted this way carries the footnote "Kalender scope-begrenzt"; re-adjudication after a later criteria decision (B').

## Steps
1. Codex ticket (high): activate scoped consumer B for Q10_NEWS adjudication (config + taint-policy lift scope limited to B-adjudicated rows; declared exclusions stay held), counter footnote in cockpit/OPEN_ITEMS/Vault, re-adjudication ticket bound to a future full-scope seal; tests; evidence.
2. After integration (+ worker reload if terminal_worker/claim guard changes): release-hold row by row for B-admissible Q10_NEWS rows (append-only), keep priority_track on 11196/XAUUSD a909ee18; verify the first adjudications end PASS/FAIL (not INVALID).
3. OPEN_ITEMS + Vault (03 Pipeline/Q10_NEWS addendum) + Mission Control until independent acceptance.

## Acceptance (independent, after step 2)
Consumer B active only for declared-admissible rows; excluded rows remain held; footnote present in all OWNER surfaces; re-adjudication ticket exists; no repin/publish/threshold/verdict change.

## Progress 2026-09-07 05:30Z — step 1 delivered: consumer B activated fail-closed, **0 of 47 rows admissible**

- Codex f3a94b87 APPROVED (312f37e679): B bound to the E1-D3/D4 candidate (manifest 5f28c2f3…, binding b12615d8…), release only via `release_scoped_item()` under an active taint hold, marker + footnote "Kalender scope-begrenzt" in path_to_25 / cockpit / archive matrix, re-adjudication ticket 235e5119 (BLOCKED until B′ or a measured full-scope seal).
- Production dry run: 47 pending Q10_NEWS rows → **ADMISSIBLE 0**, EXCLUDED 47 (no sealed Q10 window 38, intraday/unknown TF 30, non-USD exposure 19, declared overlap 9). **11196/XAUUSD a909ee18 is H4** → excluded (intraday + declared overlap). No hold released.
- Follow-ups: (a) Codex ticket — seal the Q10 window for the 9 D1/USD rows blocked only by that (12567, 1556×2, 10513×4, 10145/SP500, 1230; append-only successors from the Q09 lineage), then rerun the dry run and release row by row; (b) **B′ criteria card** for the OWNER — adjudicate USD-exposed rows of all timeframes on the repaired-USD candidate (native-export-corrected 08:30-ET rows) with declared residuals for non-USD / event-by-event classes; that is the only path that reaches 11196.
