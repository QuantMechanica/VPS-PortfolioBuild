# QM5_20012 XAU/XAG C-MTAR Basket - Q02 Enqueue Evidence

**Date:** 2026-07-20

**Branch:** `agents/board-advisor`

**EA:** `QM5_20012_xauxag-cmtar`

**Status:** Q01 PASS; one logical XAU/XAG Q02 item pending

## Edge And Source Boundary

The structural edge comes from Mighri and Al Saggaf (2018), “Gold - Silver
Nexus: A Threshold Cointegration Approach,” *International Journal of
Economics and Financial Issues* 8(5), 210-219.

- Official article: https://www.econjournals.com/index.php/ijefi/article/view/6838
- Complete official text: https://www.econjournals.com/index.php/ijefi/article/download/6838/pdf/17184

The complete paper was reviewed. Its tables specify a fixed silver-on-gold
relation and a consistent momentum-threshold adjustment branch. The executable
residual is:

`e = log10(XAG) + 0.99823 - 0.71970 * log10(XAU)`.

At each new broker month, the EA joins the two latest consecutive completed
month ends only when XAU and XAG have the exact same D1 endpoint timestamp.
It trades only when `e[t-1] - e[t-2] < 0.021`. A negative residual buys XAG
and sells XAU; a positive residual sells XAG and buys XAU. XAU:XAG target
notionals are `0.71970:1`.

The paper's abstract says weekly, its data section says natural logs, and a
Table 4 footnote reverses the equation orientation. Its 581-observation
1968-2016 span, reported log means, row label, and coefficient identity prove
monthly sampling, base-10 values, and silver as the dependent leg. Those
reconciliations were fixed before testing. The signed fade, notional
application, residual buffer, monthly close/reopen carrier, joint risk sizing,
and ATR stops are disclosed QM translations; the paper publishes no trading
backtest.

## Non-Duplicate Decision

The exact mechanic audit was `CLEAN_AFTER_MANUAL_REVIEW`. Existing XAU/XAG
families use rolling ratio z-scores, ratio channels, standardized return
spreads, rolling OLS/half-life residuals, stochastic ratios, Kalman variants,
or conditional-quantile envelopes. None uses the fixed published residual
together with the one-sided residual-momentum regime `delta(e) < 0.021`.

The C-MTAR gate, fixed coefficients, monthly cadence, and signed two-leg fade
are jointly load-bearing. Removing or inverting the gate would collapse the
non-duplicate boundary and is not authorized.

## Identity And Q01 Evidence

- EA reservation:
  `20012,xauxag-cmtar,MIGHRI-XAUXAG-CMTAR-2018_S01,active`.
- Magic slot 0: `XAUUSD.DWX` to `200120000`.
- Magic slot 1: `XAGUSD.DWX` to `200120001`.
- Foreign slot 1 is explicitly registered with the framework kill switch.
- Resolver retains 14,949 rows and embeds magic-registry SHA256
  `D4BCE7820A554E3407549230AF8B4376C23AA2F6C98B7324318B36E3E2E80753`.
  Strict regeneration retained QM5_20012 and separately reported the
  pre-existing missing EA directories for IDs 1001, 1015 and 1016; those
  unrelated rows were not changed.
- Final strict build check: PASS, 0 failures, 0 warnings; report
  `D:/QM/reports/framework/21/build_check_20260719_232240.json`.
- Its compile stage: PASS, 0 errors, 0 warnings; log
  `C:/QM/repo/framework/build/compile/20260719_232240/QM5_20012_xauxag-cmtar.compile.log`.
- Card schema, G0 approval, build guard, and SPEC validation: PASS.
- Independent source-to-code and lifecycle reviews: PASS after rework.
- MQ5 SHA256:
  `C2EE7CF6EBAE7C06DD84A4F49FD4F3417477C51BD393632107E6F3B5B0BF7AB7`.
- EX5 SHA256:
  `F4A884080185396DCB8F1D26A0F01A1FEDD382DCFA8024EC57F9DCE3C71FBE22`.

The adversarial rework made month-expiry close attempts persistent across
ticks and restarts, required exact endpoint synchronization, rejected zero
residuals, validated actual filled-volume/open-price hedge error after entry
and on every tick, and evaluated a replacement signal only after the prior
package was closed. Any orphan, malformed pair, or hedge breach closes both
owned legs.

## Risk And Logical-Basket Evidence

- Logical symbol/timeframe: `QM5_20012_XAU_XAG_CMTAR_D1` / D1.
- Runner host: `XAUUSD.DWX` / D1.
- Traded legs: `XAUUSD.DWX` and `XAGUSD.DWX`.
- One logical setfile only:
  `framework/EAs/QM5_20012_xauxag-cmtar/sets/QM5_20012_xauxag-cmtar_QM5_20012_XAU_XAG_CMTAR_D1_D1_backtest.set`.
- Setfile build hash:
  `4aeb0be546486ac842bf7600133d3d8aa053c41eecb65b8e97944a236d1dc80f`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Both lots are solved jointly so requested combined ATR-stop risk is at most
  one framework budget. Actual post-fill notionals must remain inside the 20%
  Q02 hedge-error cap.
- No physical-leg or live setfile is part of the build result.

## Q02 Queue Evidence

- Build task: `2b40b0cd-ffe3-4306-8084-82cdb68ca2d4`, done.
- Work item: `34f0fd25-452f-40ec-a739-94cd00b26db2`.
- Phase/kind: Q02 / backtest.
- Status at handoff: pending, attempt 0, unclaimed.
- Logical symbol/timeframe: `QM5_20012_XAU_XAG_CMTAR_D1` / D1.
- Host and basket payload: `XAUUSD.DWX` host; XAU/XAG two-symbol basket;
  `portfolio_scope=basket`.
- Window: `2018.07.02` through `2024.12.31`; the end is capped at the
  validated XAG history endpoint.
- Tester: USD, deposit 100000, `RISK_FIXED=1000`, percentage risk zero,
  portfolio weight one.
- Enqueued at `2026-07-19T23:25:24+00:00` by `farmctl record-build`; exactly
  one item was enqueued and none skipped.

The generic tester counts both legs. Its automatic 35-trade floor is not
package-density proof: the card requires at least 35 completed paired packages
(approximately 70 completed leg trades) across the seven Q02 year labels.
Future evidence must pair legs by owned magic/reason/month before declaring
the five-completed-packages/year kill rule satisfied.

## CPU Ceiling And Safety Boundary

The paced-fleet scan at `2026-07-19T23:17:22Z` found nine `terminal64`
processes and active pipeline work on T1, T3, T6, T7, T8, and T9. Smoke was
recorded as `deferred_p2_smoke`. This mission did not run a dispatch tick,
worker tick, terminal launch, Strategy Tester, optimization, smoke test, or
backtest.

- Structural price/calendar arithmetic and ATR safety stops only; no banned
  indicator, ML, external runtime feed, grid, martingale, or pyramiding.
- The package is cointegration-beta hedged, not strictly dollar neutral.
  Realized book decorrelation remains unproven and belongs only to later
  portfolio gates after pipeline survival.
- No `T_Live` file, AutoTrading setting, deploy manifest, T_Live manifest,
  portfolio gate, admission artifact, or portfolio KPI path was touched.
