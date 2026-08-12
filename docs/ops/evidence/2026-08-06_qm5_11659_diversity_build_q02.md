# QM5_11659 diversity build and Q02 handoff

Date: 2026-08-06

Branch: `agents/board-advisor`

Agent task: `c6e4a251-a789-4e44-9ea4-85f09de92e26`

Build task: `8a648367-c586-4473-af53-505d00fdaae6`

## Outcome

`QM5_11659_pp-triangle` was rebuilt from its OWNER-approved H4 Strategy Card
and handed to staged Q02. The basket adds two FX hosts alongside gold and two
indices: `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX`, `GDAXI.DWX`, and `NDX.DWX`.

The old source was not a mechanical card build. It substituted a 60-bar swing
and converging-trendline breakout model for PatternPy's rolling three-bar mask,
added an ATR take-profit absent from the card, and omitted the card's opposite
label exit. Version 5.1 removes those deviations and translates the cited
`detect_triangle_pattern` comparisons literally on completed bars.

## Selection and collision control

- The live farm DB was used, not the stale repository snapshot:
  `D:\QM\strategy_farm\state\farm_state.sqlite`.
- Claim key:
  `manual:codex:agents/board-advisor:QM5_11659:q01-build-q02-handoff:20260806T024747Z`.
- The standard `farmctl build-ea` prebuild path created the build task, which
  was atomically claimed `pending -> active` with a DB backup at
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11659_build_claim_20260806T025153Z.sqlite`.
- The provisional higher-ranked `QM5_11658` claim was released and blocked
  after primary-source inspection proved its literal rolling-close inequality
  cannot produce a signal. No invented replacement mechanic was built.
- Five existing deterministic magic rows, `116590000` through `116590004`,
  were activated and the resolver regenerated. A concurrent fleet commit
  (`67ffdfc20`) incorporated the shared registry/resolver files while this EA's
  scoped files remained uncommitted; no unrelated fleet artifact is included
  in this unit's commit.

## Mechanical implementation

- Baseline signal window: 3 completed H4 bars.
- Ascending label: rolling high >= prior high, rolling low <= prior low, and
  latest close > prior close.
- Descending label: rolling high <= prior high, rolling low >= prior low, and
  latest close < prior close.
- Entry: next-bar market entry, one position per magic.
- Exit: opposite label, completed close beyond the actual execution bar's
  adverse extreme, or 12 completed bars.
- Emergency stop: ATR(14) at 2.0 times ATR; no take-profit or stop mutation.
- News checks gate new entries only; management and exits remain available.
- MAE sampling runs before all per-tick early returns.

## Build evidence

| Check | Result | Evidence |
|---|---|---|
| Approved card copy | PASS | repository copy matches the approved card line-for-line |
| SPEC validator | PASS | `framework/scripts/validate_spec_doc.py` |
| Full framework build check | PASS, 0 failures, 0 warnings | `D:\QM\reports\framework\21\build_check_20260806_030429.json` |
| Strict compile | PASS, 0 errors, 0 warnings | `D:\QM\reports\compile\20260806_030521\summary.csv` |
| EX5 | PASS | SHA-256 `5E385FE2912651EDB57440D25C23D33710E720F7A5C730B2223377872655150D` |
| Fixed-risk setfiles | PASS | five H4 files; `RISK_FIXED=1000`, `RISK_PERCENT=0`, slots 0 through 4 |
| Farm DB integrity | PASS | `PRAGMA quick_check = ok` after record/enqueue |

The canonical build result is
`D:\QM\strategy_farm\artifacts\builds\8a648367-c586-4473-af53-505d00fdaae6.json`.

## CPU ceiling and Q02 state

No Q01 smoke was launched. At `2026-08-06T03:05:56Z`, `farmctl mt5-slots`
reported 8 running MT5 terminals and `farmctl work-items --status active`
reported 8 active work items. The supported `deferred_p2_smoke` result preserved
that ceiling and let the farm's staged Q02 scheduler own subsequent capacity.

Build recording completed at `2026-08-06T03:08:06Z` with task status `done`.
The first diversity wave was created as:

| Symbol | Q02 work item | State at verification |
|---|---|---|
| EURUSD.DWX | `76f302b3-3de9-4f1b-9afa-9b9944fe3ff1` | active on T6 |
| GDAXI.DWX | `3dd46641-083d-4066-9724-635a55934572` | active on T4 |
| XAUUSD.DWX | `f6636592-7e10-4430-9315-24f54a866550` | pending |

`GBPUSD.DWX` and `NDX.DWX` are durably present in
`D:\QM\strategy_farm\state\q02_deferred_symbols.json` as the staged second
wave for this five-symbol cohort.

## Safety boundary

No T_Live file, AutoTrading state, deploy manifest, live setfile, portfolio
gate, portfolio admission artifact, or pipeline phase beyond the normal Q02
enqueue was touched.
