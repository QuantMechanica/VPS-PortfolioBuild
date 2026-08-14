# QM5_21517 XAU/XAG Seasonal-Surprise Reversion Q02 Enqueue

Date: 2026-08-14

Branch: `agents/board-advisor`

Owner: Codex

## Edge built

- EA: `QM5_21517_xauxag-seas-rv`
- Strategy ID: `KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026_S01`
- Logical basket: `QM5_21517_XAU_XAG_SEASRV_D1`
- Host/slot 0: `XAUUSD.DWX`, D1, magic `215170000`
- Companion/slot 1: `XAGUSD.DWX`, D1, magic `215170001`
- Signal: subtract the prior-ten-year same-calendar XAU-minus-XAG monthly
  return mean from the just-completed synchronized relative month, divide by
  the prior sample standard deviation, and fade only a strict standardized
  surprise beyond `+/-0.50`.
- Exit: next broker-month transition, 40-day stale guard, malformed-package
  repair, and frozen `3.5 * ATR(20,D1)` per-leg hard stops; no take-profit or
  Friday flatten.
- Backtest risk: one aggregate package budget with `RISK_FIXED=1000`,
  `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, split equally by stop risk.

## Source and claim boundary

The governed composite packet uses only prior approved repository reviews:

- Keloharju, Linnainmaa, and Nyberg (2016), *The Journal of Finance* 71(4),
  DOI `10.1111/jofi.12398`, for recurring same-calendar return structure;
- Schweikert (2018), *Journal of Banking & Finance* 88, DOI
  `10.1016/j.jbankfin.2017.11.010`, and Yaya, Vo, and Olayinka (2021),
  *Resources Policy* 72, DOI `10.1016/j.resourpol.2021.102045`, for a
  state-dependent gold/silver relation; and
- CME Group's governed gold/silver ratio-spread carrier.

Those sources do not test the exact standardized contrarian conjunction,
ten-year cap, five-sample floor, half-standard-deviation band, continuous CFD
port, fixed risk, costs, cadence, performance, neutrality, or book
correlation. Those are explicit falsifiable QM choices. R1-R4 are PASS; no ML,
external runtime series, banned indicator, optimizer, or PnL adaptation is
used.

## Non-duplicate boundary

- `QM5_20186_xauxag-samecal` follows the historical same-calendar mean; it
  does not observe and fade a realized seasonal surprise.
- `QM5_20189_xauxag-calmom1` follows only seasonal and prior-relative-return
  sign agreement; this EA subtracts the expectation, sample-standardizes the
  residual, and takes the opposite side.
- `QM5_20057_xauxag-xmom1` follows raw prior relative-month momentum.
- `QM5_12862_xauxag-rspread` fades a rolling ten-D1 score rather than a
  completed broker month relative to recurring calendar history.
- Ratio-level, OLS, quantile, C-MTAR, robust-tail, channel, run, variance-ratio,
  moment-rank, and long-horizon sleeves use different state objects or clocks.

The canonical pre-allocation checker returned CLEAN across 4,389 registry rows
and 485 intake cards. Verdict:
`CLEAN_AUTHORIZED_XAUXAG_STANDARDIZED_SEASONAL_SURPRISE_REVERSION`.

## Artifacts

- Card: `strategy-seeds/cards/xauxag-seas-rv_card.md`
- Approved card: `strategy-seeds/cards/approved/QM5_21517_xauxag-seas-rv_card.md`
- Source packet:
  `strategy-seeds/sources/KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026/source.md`
- G0 decision: `decisions/2026-08-14_qm5_21517_xauxag_seas_rv_g0.md`
- EA: `framework/EAs/QM5_21517_xauxag-seas-rv/QM5_21517_xauxag-seas-rv.mq5`
- EX5: `framework/EAs/QM5_21517_xauxag-seas-rv/QM5_21517_xauxag-seas-rv.ex5`
- Basket manifest: `framework/EAs/QM5_21517_xauxag-seas-rv/basket_manifest.json`
- Q02 setfile:
  `framework/EAs/QM5_21517_xauxag-seas-rv/sets/QM5_21517_xauxag-seas-rv_QM5_21517_XAU_XAG_SEASRV_D1_D1_backtest.set`
- Build record: `artifacts/qm5_21517_build_result.json`

## Q01 validation

- Card schema lint: PASS on root, approved, and EA-doc copies; no ML hits or
  missing sections.
- SPEC schema: PASS, 1/1.
- Deterministic arithmetic reference: PASS, 8/8, covering sample denominator,
  history floor, exact threshold tolerance, direction, flat band, and January
  rollover.
- Symbol scope: `BASKET_OK`, 0 violations; both registered manifest symbols.
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log:
    `C:\QM\repo\framework\build\compile\20260814_053215\QM5_21517_xauxag-seas-rv.compile.log`
  - EX5 size: 381502 bytes.
- Framework build check: PASS, 0 failures, 0 warnings.
  - Report:
    `D:\QM\reports\framework\21\build_check_20260814_053252.json`.
- EX5 SHA-256:
  `6378EC7EC790846684685BEC488492FB7B63F7A00289384BD72D554C7ACB6049`.

## Q02 queue

The targeted governed never-tested sweep selected exactly one priority row.
Its first apply attempt met a transient SQLite lock and created no work item;
readback confirmed zero rows. The idempotent targeted retry then created one
row, which was read back before handoff.

- Work item: `774d944c-7220-4c22-8a74-93a0791168c8`
- Phase/kind: `Q02` / `backtest`
- Logical symbol/timeframe: `QM5_21517_XAU_XAG_SEASRV_D1` / D1
- Physical host: `XAUUSD.DWX`; traded basket: `XAUUSD.DWX`, `XAGUSD.DWX`
- Setfile:
  `C:\QM\repo\framework\EAs\QM5_21517_xauxag-seas-rv\sets\QM5_21517_xauxag-seas-rv_QM5_21517_XAU_XAG_SEASRV_D1_D1_backtest.set`
- Status at verification: `pending`, attempt count 0, unclaimed.
- Created UTC: `2026-08-14T05:34:46+00:00`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`

The capacity scan at `2026-08-14T05:34:19+00:00` showed one active factory
terminal (`T5`) out of ten and three total `terminal64` processes including
non-factory terminals. The backtest CPU ceiling was not hit. No terminal was
started, stopped, reserved, released, or reaped by this work, and no manual
tester or smoke run was launched; the paced fleet owns Q02.

## Safety

No MT5 live trading, AutoTrading toggle, `T_Live` file, deploy/T_Live
manifest, portfolio gate, portfolio admission, correlation waiver, or
portfolio KPI file was touched.
