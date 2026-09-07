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
