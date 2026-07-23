# QM5_20060 XCU/XAG Return-Spread Build And Q02 Enqueue

- Date: 2026-07-23
- Branch: `agents/board-advisor`
- EA: `QM5_20060_xcu-xag-rspread`
- Logical basket: `QM5_20060_XCU_XAG_RSPREAD_D1`
- Host: `XCUUSD.DWX` D1
- Hedge leg: `XAGUSD.DWX`

## Decision

Build one low-frequency, two-leg copper/silver relative-return reversion
package. Each completed host D1 bar measures the 20-bar copper return minus a
fixed 0.75 silver-return hedge, standardizes that spread over 120 observations,
and opens the opposite package beyond 1.9 standard deviations. It exits on
normalization, a 30-day time stop, ATR hard stops, Friday close, or broken-leg
repair.

Repository deduplication found no existing XCU/XAG card, registry row, or EA.
The card distinguishes source evidence from hypothesis transfer: Parnes (2024)
and CME establish reputable metal-ratio and asset context; Q02 onward must
falsify the exact copper/silver reversion rule. The return stream is a
market-neutral industrial-versus-precious spread, not another outright
XAU/index/XNG direction bet.

## Validation And Enqueue

- Strategy Card schema lint: PASS; no missing sections or ML hits.
- Deterministic allocation: EA ID 20060.
- Magic slot 0: `XCUUSD.DWX` = 200600000.
- Magic slot 1: `XAGUSD.DWX` = 200600001.
- Generated resolver contains both rows.
- Strict compile/build check: PASS, 0 errors, 0 warnings.
- Compile log:
  `framework/build/compile/20260723_172154/QM5_20060_xcu-xag-rspread.compile.log`.
- Binary SHA256:
  `274b1e9c2b2197b3a315d20eb5d33229d7730b15fe11ab8a75f61182d7369ee9`.
- Backtest set SHA256:
  `6a6912f9446890aa925d082d08c0bdd6a02b0815a83a8af41dba9ef00fc2ea7f`.
- Backtest risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Q02 work item: `3420d430-38e9-45b0-8039-37ba71daf8b7`, pending,
  attempt 0.
- Build task: `e969c193-9324-421e-b3ee-c70f36718f56`, done.

No manual MT5 backtest was started; first execution is deferred to paced-fleet
Q02. No T_Live path, AutoTrading state, live setfile, deploy manifest,
portfolio gate, portfolio manifest, or T_Live manifest was touched.

## Known Registry Hygiene Warning

`update_magic_resolver.py --strict` regenerated the resolver and retained the
new 20060 rows, but its global audit also reported three pre-existing active
magic rows with missing EA directories: 1001, 1015, and 1016. This unrelated
warning was not repaired in this commodity-sleeve change.
