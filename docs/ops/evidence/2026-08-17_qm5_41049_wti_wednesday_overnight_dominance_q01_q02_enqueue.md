# QM5_41049 WTI Wednesday Overnight Dominance - Q01 And Q02 Handoff

Date: 2026-08-17 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `Q01 PASS; ONE PACED Q02 ITEM ENQUEUED`

## Candidate And Claim Boundary

`QM5_41049_wti-wed-overnight-dom` is a low-frequency single-carrier WTI
candidate on exact `XTIUSD.DWX`, D1. At the first executable broker Thursday
after exact completed Monday, Tuesday, and standard-Wednesday sessions, it
computes:

```text
overnight_flow = ln(WednesdayOpen / TuesdayClose)
session_flow   = ln(WednesdayClose / WednesdayOpen)
day_return     = ln(WednesdayClose / TuesdayClose)
total_flow     = overnight_flow + session_flow
```

It trades only when the two finite nonzero components strictly oppose,
`abs(overnight_flow) > abs(session_flow)`, and `total_flow` reconciles to
`day_return` within `1e-10`. It follows the retained overnight/total sign at
Thursday open, freezes a `3.0 * ATR(20,D1)` hard stop, uses no target, and
exits at the first later D1 boundary. A durable Thursday attempt is consumed
before every fallible entry gate. Friday close remains enabled at broker hour
21 as a fail-safe, and a three-day stale guard bounds malformed lifecycle
state.

The only preset is backtest-only with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. This handoff does not establish profitability,
certification, portfolio admission, or realized decorrelation. Q09 alone may
measure overlap with the certified XAU/SP500/NDX/XNG book.

## Governance And Non-Duplicate Boundary

- source approval commit: `4ab03d72a`
- EA-ID reservation commit: `ddcc7b96c`
- pre-magic directory identity commit: `f6f138bae`
- magic registration/resolver commit: `26abbec15`
- Strategy Card and OWNER G0 commit: `50aaae3ca`
- source implementation commit: `69de5443b`
- Q01 binary/evidence commit: `da9f3b38c`
- registered route: slot 0 `XTIUSD.DWX`, magic `410490000`
- source lineage: official EIA ordinary-Wednesday petroleum clock, complete
  OWNER-supplied Williams close/open versus open/close price-flow extraction,
  and complete-read peer-reviewed Moskowitz-Ooi-Pedersen own-return
  continuation evidence explicitly including WTI
- source boundary: no source tests the exact conjunction, continuous CFD,
  one-D1 horizon, risk, stop, or portfolio relationship

The canonical pre-allocation checker scanned 4,536 EA rows and 625 root cards
and found no exact slug, strategy-ID, or fuzzy mechanic identity. Manual
family review separated this candidate from:

- `QM5_41041`, whose disjoint session-dominant opposition state is faded;
- `QM5_41042`, which requires component sign agreement;
- `QM5_41033` and `QM5_41036`, which aggregate full weeks or months;
- `QM5_12784`, which crosses smoothed fourteen-day flow lines;
- `QM5_41045` and `QM5_41046`, which use a separate 252-session trend; and
- certified `QM5_12567`, a long-only two-day XNG oscillator pullback.

Manual verdict:
`CLEAN_WTI_STANDARD_WEDNESDAY_OPPOSED_FLOW_STRICT_OVERNIGHT_DOMINANCE_CONTINUATION_AFTER_CANONICAL_AND_FAMILY_REVIEW`.

## Fixed-Risk Build And Q01 Evidence

- Independent mechanic suite: 14 tests PASS. Coverage includes native and
  uniform `+1` energy labels, holiday/missing-session rejection, exact weekday
  sequence, Thursday grace, both continuation sides, session dominance,
  agreement/zero/equality/invalid rejection, reconciliation, completed
  endpoints, stable attempt identity, and first-later-D1 exit.
- Both Strategy Card copies are byte-identical and pass schema/ML and G0
  lint.
- Strict targeted MetaEditor compile: PASS, 0 errors and 0 warnings. Log:
  `framework/build/compile/20260817_175414/QM5_41049_wti-wed-overnight-dom.compile.log`.
- Targeted build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260817_175557.json`.
- Static P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_41049/P1/P1_QM5_41049_result.json`.
- Factory symbol-scope validation: `SINGLE_SYMBOL_OK`, zero violations.
- MQ5 SHA-256:
  `611BC4AEF7823DDFADDC897075A5BBC13566206B6D5D07AD2CDAF7938789BDBA`.
- Compiled EX5 SHA-256:
  `8C68C2CB03F79071E2816C0CF32B5E4342DDE37C360BA4C1A41198781399B526`.
- Backtest-set normalized-content build hash:
  `533c40e211991aa23961e3927ce71f10824359ff8f7ecf3974c246659c3d45c9`.

## Q02 Capacity Gate And Enqueue

The target-only canonical dry run selected exactly one fresh Q02 row and no
stranded/recovery row:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41049 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded:     enqueued=0 skipped=0
priority_track items: 1
```

The read-only `farmctl.py mt5-slots` census at
`2026-08-17T17:58:34Z` found five active exact-path research terminals: `T1`,
`T2`, `T6`, `T8`, and `T9`. This was below the governed seven-terminal
backtest ceiling. The census observed `T_Live` and an unrelated FTMO terminal
only to exclude them; neither was touched. The configured
`D:/QM/strategy_farm/state/launch_gate_max.txt` value was `1`.

A five-sample whole-host CPU reading from `2026-08-17T17:58:34Z` through
`17:58:44Z` measured `81.37`, `84.42`, `83.60`, `77.97`, and `83.60`
percent (average `82.19`, maximum `84.42`). The maximum remained below the
explicit `97%` hard host-CPU stop.

The target-only apply therefore created exactly one work item:

- ID: `5b14781d-cb89-4543-9d4d-65d5ef424bde`
- phase: `Q02`
- created: `2026-08-17T17:58:52+00:00`
- route: exact `XTIUSD.DWX`, D1
- setfile:
  `framework/EAs/QM5_41049_wti-wed-overnight-dom/sets/QM5_41049_wti-wed-overnight-dom_XTIUSD.DWX_D1_backtest.set`
- initial state: `pending`, attempt count 0, unclaimed
- priority track: true
- custom-history admission: active, selected symbol `XTIUSD.DWX`

The immediate read-only DB query confirmed that single pending row. The post-
apply target-only dry run selected zero rows, proving the enqueue did not
leave a duplicate candidate. A later read-only query at
`2026-08-17T18:00:01Z` found that the scheduled fleet had claimed it active on
`T10`, still with attempt count 0. The operator did not invoke a dispatcher
tick or start, stop, kill, attach to, or otherwise control any terminal,
worker, tester, or backtest process.

## Safety And Handoff

The Q02 action used the canonical de-duplicating paced queue. The pipeline-
phase skill expressly excludes Q02 from `run_phase.ps1`, so no autonomous
phase runner was invoked.

No manual backtest, terminal or worker mutation, AutoTrading action,
live/demo/shadow/stress/optimization preset, `T_Live` change, deploy/T_Live
manifest, portfolio-gate edit, portfolio admission, decorrelation claim, or
correlation waiver occurred.

The paced fleet owns the active Q02 item. Q02 must retire the identity on
zero trades, fewer than five completed positions per full post-warm-up year,
nonpositive governed economics, wrong weekday/endpoints, component agreement,
absent strict overnight dominance, wrong continuation side, failed
reconciliation, current-bar leakage, late/repeated entry, wrong next-D1
lifecycle, nondeterminism, invalid risk mode, or an unusable standard-
Wednesday proxy.
