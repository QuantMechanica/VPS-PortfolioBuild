# QM5_20172 generation-bound Q02 recovery — 2026-08-21

## Scope and authority

- Router task: `af13cc2d-3a28-4fd5-a226-9e2695b499aa`
- Authority: OWNER `CEO-MP-#7` (2026-08-21)
- EA: `QM5_20172_wti-fri-bear`
- Symbol / phase: `XTIUSD.DWX` / Q02
- Retained incident hold: `STALE_BUILD_RESULT_AUTO_Q02_BYPASS` on
  `88ba4560-fd7f-456f-903f-f4982d8f9cf3`

This recovery does not release the incident hold, change the public-snapshot
guard, enable T_Live or AutoTrading, or manually start a terminal. Historical
work items remain append-only.

## Original bound failure

The original terminal-valid Q02 evidence is:

`D:/QM/reports/work_items/ab8d8b7a-1c17-4cdc-b259-080cab3b75df/QM5_20172/20260726_100002/summary.json`

- actual window: `2018.07.02..2022.12.31`
- symbol / timeframe / model: `XTIUSD.DWX` / D1 / model 4
- source and deployed EX5 SHA-256:
  `f7dde33a57b428bcd4b23b77bbb2b84aad1c5b2c0a24ee699fbe6c44429365d2`
- setfile SHA-256:
  `e1c55fccf6d94ebb837223deba1c50fcb36661e092f607a6431d60ef39853ca4`
- result: `FAIL`, `MIN_TRADES_NOT_MET`, 0 trades
- router verdict: `DRAFT_DEFECT`, reason
  `Q02_ALL_ENQUEUED_SYMBOLS_ZERO_TRADES`
- harness/setup identity: valid and stable; no initialization failure; real-tick
  marker present; news bundle available

The logger recorded 222 `FRIDAY_CLOSE` events over the bound window but no entry
or order events. The first failed layer was therefore the entry hook.

## Root cause

Before repair, the focused build guard failed with:

- finding: `entry_grace_below_session_offset`
- registered measured `XTIUSD.DWX` D1 session offset: 61.6 minutes
- declared nominal-bar grace: 5 minutes
- required minimum: 66.6 minutes (session offset plus five-minute margin)

The EA compared `TimeCurrent()` directly with the nominal D1 bar timestamp. The
first executable XTI tick arrives after the 61.6-minute session offset, so the
five-minute comparison made every intended Friday attempt unreachable. This is
an implementation/setup defect, not evidence against the economic hypothesis.

## Repair

The repair preserves the approved five-minute first-executable-tick intent by
using a 67-minute nominal-bar allowance (61.6 measured minutes plus the five-
minute executable window, rounded to an integer input). No momentum threshold,
direction, stop, spread ceiling, hold rule, position limit, or symbol universe
was changed.

Bounded diagnostics were added at the weekly decision boundary using registered
events:

- `ENTRY_ATTEMPT`
- `ENTRY_REJECTED`
- `ENTRY_SIGNAL_FIRE`

The active Edge Lab mandatory-news overlay is also explicit in source and the
backtest setfile: `QM_NEWS_TEMPORAL_PRE30_POST30` with
`QM_NEWS_COMPLIANCE_DXZ`; legacy news mode remains off. The stale-news maximum
remains exactly 336 hours. Backtest risk remains `RISK_FIXED=1000` and
`RISK_PERCENT=0`.

Generation commits on `agents/board-advisor`:

- `e50e1b035` — deterministic pump commit of the exact repaired setfile
- `8a7339d4e` — source, rebuilt binary, and SPEC

Current bound hashes:

- MQ5: `0d42bd1e2ea5f2be85a07367e3495638a3417f43cd64ff53cc9727ca34f3e92a`
- EX5: `0e01ada7d9f9711e70a20f032f5f0a6e5bb63adb3b5f6d26f1f295202412a2d5`
- setfile: `300e991b723da79eb95973242bdfef88d5d4a094fe1951349915946fba45d55c`

## Focused verification

- `validate_build_guardrails.py`: PASS, no findings; checked maximum news age
  336 hours and the measured session-offset rule.
- strict compile: PASS, 0 errors, 0 warnings.
  - log:
    `C:/QM/repo/framework/build/compile/20260821_074647/QM5_20172_wti-fri-bear.compile.log`
  - summary: `D:/QM/reports/compile/20260821_074647/summary.csv`
- strict build check (`-SkipCompile` after the strict compile): PASS, 0 failures,
  0 warnings.
  - report: `D:/QM/reports/framework/21/build_check_20260821_074704.json`

## Fresh Q02 handoff

The guarded append-only `farmctl seed-fresh-q02` path created:

- new work item: `bf7b7bfe-4dd3-4a11-8904-1a6b081717b0`
- source pre-binding row preserved:
  `88ba4560-fd7f-456f-903f-f4982d8f9cf3`
- expected EX5 SHA-256:
  `0e01ada7d9f9711e70a20f032f5f0a6e5bb63adb3b5f6d26f1f295202412a2d5`
- expected setfile SHA-256:
  `300e991b723da79eb95973242bdfef88d5d4a094fe1951349915946fba45d55c`
- risk binding: fixed 1000, percent 0
- custom-history archive admission: ACTIVE for `XTIUSD.DWX`
- initial queue state: pending, unclaimed, no work-item hold

The scheduler subsequently dispatched the row to T10 without manual terminal
start, interruption, or queue manipulation. It completed at
`2026-08-21T09:46:41Z` with evidence:

`D:/QM/reports/work_items/bf7b7bfe-4dd3-4a11-8904-1a6b081717b0/QM5_20172/20260821_094120/summary.json`

The fresh summary reports:

- `result=PASS`, `reason_classes=[OK]`, one deterministic attempted run;
- 94 trades over the bound `2018.07.02..2022.12.31` XTIUSD.DWX D1 window;
- no OnInit failure and a real-ticks marker;
- required, deployed, observed-after, and post-run EX5 SHA-256 all equal
  `0e01ada7d9f9711e70a20f032f5f0a6e5bb63adb3b5f6d26f1f295202412a2d5`;
- the current canonical EX5 independently hashes to the same value;
- setfile source/deployed/observed-after SHA-256 remains
  `300e991b723da79eb95973242bdfef88d5d4a094fe1951349915946fba45d55c`;
- fixed-risk binding remains `RISK_FIXED=1000`, `RISK_PERCENT=0`; and
- news calendar status is `OK`, with `max_age_hours=336`.

## Required zero-trades recovery record

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| QM5_20172 | original `ab8d8b7a` valid zero-trade Q02; fresh `bf7b7bfe` PASS | 5-minute nominal grace was below the measured 61.6-minute XTI D1 session offset | 67-minute nominal allowance preserving five executable minutes; bounded entry diagnostics; mandatory news blackout | PASS, 0/0; build check PASS, 0/0 | fresh run exercised entry path and completed without OnInit failure | 94 | incident-hold release is deliberately outside this task and remains for the subsequent verifier |

## Current verdict

`GENERATION_BOUND_Q02_PASS` — the task's fresh-evidence acceptance criterion is
met by work item `bf7b7bfe-4dd3-4a11-8904-1a6b081717b0`. This is the recorded Q02
pipeline verdict, not an independent profitability claim and not authority to
release the retained incident hold. Per the task contract, hold release remains
the responsibility of the subsequent verifier and was not performed here.
