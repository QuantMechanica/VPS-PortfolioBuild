# QM5_20095 AU/AG Monday Differential — Build And CPU-Ceiling Stop

Date: 2026-07-24

## Scope

One new low-frequency precious-metals relative-value carrier was extracted
from the fully reviewed Lucey and Tully (2006) paper. On synchronized broker
Monday D1 boundaries it buys `XAUUSD.DWX`, sells `XAGUSD.DWX` at equal
absolute USD notional, and closes the package at the next D1 boundary.

The card records that the source calls mean seasonality weak/non-robust and
does not test this two-leg translation. Q02 is required to falsify it after
costs; no profitability or decorrelation claim is made.

Repository-wide exact-mechanic search and the deterministic dedup tool were
CLEAN. `QM5_20019_xauxag-wkend` owns the preceding Friday-close/Monday-open
interval and is flat when this new Monday-session carrier becomes eligible.

## Build evidence

- EA ID: `QM5_20095`; slug: `auag-mon-diff`.
- Magics: `200950000` XAU slot 0; `200950001` XAG slot 1.
- Strategy-card schema lint: PASS, no missing sections or prohibited-library
  hits.
- G0 card lint: PASS.
- Build prerequisite guard: PASS.
- SPEC validator: PASS.
- Framework build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260724_083137.json`
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260724_083055\QM5_20095_auag-mon-diff.compile.log`
- EX5 SHA256:
  `02F4C683EA7A08D0AC4A1A13DD5D130E1029F7475FC9046D4CE984AB984151EA`
- Backtest setfile SHA256:
  `6B60BA79D82616D18D4FF5815FC3A8734F6ABCAD2E7067CBAE313C5A722555AA`
- Setfile build hash:
  `3ec4b8761424e61c1577889937657ff9b3fe5f0e9da2e55df14376527bea03db`
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, one shared two-leg
  budget.
- Basket Q02 window: `2018.07.02` through `2024.12.31`, hosted on
  `XAUUSD.DWX` D1 with both traded symbols in the manifest.

The DXZ-23 live-book execution-contract registry is intentionally unchanged;
it is not an admission artifact for a new Q02 research candidate.

## CPU-ceiling stop

At `2026-07-24T08:35:11+00:00`, the required pre-enqueue MT5 process scan
showed eight active factory terminals:

`T2`, `T3`, `T4`, `T6`, `T7`, `T8`, `T9`, and `T10`.

That exceeds the paced seven-factory-terminal ceiling. The separate T_Live
and FTMO GUI processes were not counted as factory slots and were not
touched. Per the mission stop condition, no Q02 row was inserted and no
tester was dispatched. A post-check returned zero work items for
`QM5_20095`.

Q02 remains pending until a later operator observes capacity below the
ceiling and performs one basket-aware enqueue.

## Safety boundary

No live setfile, T_Live access, AutoTrading action, deploy/T_Live manifest,
portfolio manifest, portfolio admission, portfolio-gate edit, manual
backtest, or terminal mutation occurred.
