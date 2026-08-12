# QM5_10025 Diverse-FX Q02 Corset Recovery

Date: 2026-08-06 local / 2026-08-05 UTC

Branch: `agents/board-advisor`

Operator: Codex paced fleet

## Unit selected

No approved, unbuilt Strategy Card remained in the canonical build backlog, so
this unit used mission priority 2: recover the low-frequency seven-host FX
cointegration EA `QM5_10025_rw-fx-broad-pairs` from deterministic Q02/build
infrastructure blockers.

Farm claim: `5b64357c-132b-4d97-bc7e-e434a3fde412`

Claim key: `manual:codex:agents/board-advisor:QM5_10025:q02-corset-rework-20260806`

The prior Codex review task `84638446-0d92-45aa-b36f-e6af47977d75` identified
three mechanical violations: a hand-rolled monthly time key, a second
file-scope H4 timestamp gate, and use of the basket order path for the chart
host. Recent Q02 rows also exhausted cold-cache retries with `BARS_ZERO`:

- USDJPY: `7337e624-4253-44fe-a941-d0ffdbac705b`
- NZDUSD: `fcb19233-33a5-4ec6-8ce4-940940ba0c49`
- USDCHF: `e10922e9-9ec4-460d-a338-7992e91187be`

## Repair

- Monthly selection now uses `QM_CalendarPeriodKey(PERIOD_MN1, ...)`.
- `QM_IsNewBar(_Symbol, PERIOD_H4)` is the sole H4 cadence gate; the spread
  state is refreshed once behind that gate and reused by exit and entry hooks.
- The foreign partner opens first through `QM_BasketOpenPosition`; the chart
  host is returned as `QM_EntryRequest` and opened through
  `QM_TM_OpenPosition`. A rejected host immediately rolls back the partner.
- Fixed or percent package risk is divided between host and partner according
  to the absolute OLS weights. Every backtest setfile remains
  `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Added `basket_manifest.json`, registered the seven approved `.DWX` symbols
  with `QM_SymbolGuardInit`, and invoked the framework's one-time H4 basket
  warm-up. The warm-up is the framework-prescribed repair for foreign-symbol
  tester history returning zero bars.

## Verification

- Strict compile: PASS, 0 errors, 0 warnings.
  Log: `C:/QM/repo/framework/build/compile/20260805_234956/QM5_10025_rw-fx-broad-pairs.compile.log`
- Compiled EX5 SHA-256:
  `aafa4214b9f2d51cf985da8c608073620fa83ebc7f634ec01ee541286ba92651`
- Framework build check: PASS, 0 failures, 0 warnings.
  Report: `D:/QM/reports/framework/21/build_check_20260805_235028.json`
- Build guardrails: PASS with no findings.
- Symbol-scope validation: `BASKET_OK`, 0 violations.

## Governed Q02 handoff

At `2026-08-05T23:51:34Z`, `farmctl.py mt5-slots` reported every factory
terminal `T1` through `T10` running (`terminal64_running_count=12`, including
non-factory T_Live and FTMO processes). This is the backtest CPU ceiling, so no
new work item and no manual MT5 dispatch were created.

The existing non-duplicate USDJPY Q02 canary
`050dd2ea-e9d0-475f-b5ad-40c2206867ff` remains `pending` in the farm and will
consume the repaired branch artifact only through normal governed dispatch
after capacity returns. No in-place historical result was altered.

No `T_Live`, AutoTrading, deploy manifest, portfolio gate, portfolio KPI, or
Q08 contribution file was touched.
