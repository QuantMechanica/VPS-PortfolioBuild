# QM5_20184 XAU/XAG three-month momentum — build and Q02 enqueue

Date: 2026-07-31 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20184_xauxag-xmom3`

Strategy ID: `FMR-MOMTS-2010_XAU_XAG_S04`

## Outcome

One new low-frequency commodity candidate was carded, registered, built,
strictly compiled, and handed to the paced Q02 fleet. At each broker-month
transition it ranks XAU and XAG by the arithmetic average of exactly three
completed monthly returns, buys the stronger metal, and shorts the weaker
metal.

This is a market-neutral construction intent, not a neutrality or
decorrelation result. Q02 and the unchanged downstream gates remain
authoritative. No profitability, certification, correlation, diversification,
or portfolio-admission claim is made here.

## Source and non-duplicate boundary

The governed source is Fuertes, Miffre, and Rallis (2010), “Tactical
Allocation in Commodity Futures Markets: Combining Momentum and Term
Structure Signals,” *Journal of Banking & Finance* 34(10), 2530–2548,
DOI `10.1016/j.jbankfin.2010.04.009`. The existing source packet records a
complete read of the 47-page accepted manuscript. Pages 6–7 and 17–18
explicitly test one-, three-, and twelve-month momentum formation horizons
with a one-month hold.

The deterministic dedup check found no exact strategy/mechanic match. Manual
resolution retained the expected horizon siblings:

- `QM5_20057_xauxag-xmom1` ranks one completed monthly return.
- `QM5_20050_xauxag-xmom12` averages twelve completed monthly returns.
- XAU/XAG ratio, z-score, OLS-residual, return-spread, conditional-quantile,
  and C-MTAR EAs use different state variables and entry mechanics.

The locked three-month horizon is therefore the missing source-declared
carrier, not a post-result parameter variation. The two-CFD XAU/XAG
translation, equal fixed-risk split, ATR stops, and execution rules are
explicit QM hypotheses; no broad commodity-futures performance statistic is
imported.

## Frozen baseline

- Logical basket: `QM5_20184_XAU_XAG_XMOM3_D1`.
- Host/slot 0: `XAUUSD.DWX`, D1, magic `201840000`.
- Companion/slot 1: `XAGUSD.DWX`, D1, magic `201840001`.
- Decision: first tradable XAU D1 bar of each broker month.
- Formation: four consecutive completed month-end closes whose month keys and
  timestamps match across both legs.
- Signal: arithmetic average of exactly three simple monthly returns; an
  absolute difference no greater than `1e-10` stays flat.
- Direction: long the higher-return leg and short the lower-return leg.
- Attempt ledger: persist the month before history, signal, news, quote,
  spread, sizing, stop, or order gates; no same-month retry.
- Risk: one `RISK_FIXED=1000` package split equally after independent
  `3.5 * ATR(20,D1)` stop normalization.
- Lifecycle: next-month close, 40-calendar-day stale close, and immediate
  orphan, duplicate, same-direction, or missing-stop repair.
- News axes: OFF. Friday close: disabled.
- No live setfile, parameter sweep, external runtime feed, banned/ML
  indicator, grid, martingale, scale-in, or pyramiding.

## Deterministic identity and hashes

- Q01 build commit:
  `950270557c38914a8aeb07a16da2e299b020f60b`.
- Q01 build-bound card SHA-256:
  `8CF315F7B15C4D5699C8977B77EECEE6B88A75F9E8C22137F596AD03E63A1BDE`.
- Post-enqueue metadata card SHA-256:
  `C259D7B142D0E278168FB8C2D4311E29DE5D1230C7977BBC601A7D01B7BC1D3B`.
- Source packet SHA-256:
  `1F4F4977B0D9646A8BF56543D1881CCBC1513D4644DE72C350614580F3FF7417`.
- MQ5 SHA-256:
  `EF06DE429471B6C299111EC6AD297B7785532B7E5C916287460B3FEEB6497AFE`.
- EX5 SHA-256:
  `2978064EECB1470B9B599B666623E4BFC39D76087E5830898A30F31DE9EEA489`.
- SPEC SHA-256:
  `8824AEC0564B004491CBDE64A4623BB7510B6BD928113DF6654FD8E07B3A9D93`.
- Basket manifest SHA-256:
  `1B192BAAA79D21E3927EB3F04240589D2F165C1017953D8F26E921191AA499AB`.
- Setfile SHA-256:
  `FB2F60AD5EA89DBDB3820DCC711B53A5481FFE8D1F36A18EAFBB42CBCC948417`.
- Setfile build hash:
  `e703bfe790ebc5142d3d11813f7728bf222dc7d12cb7d4b79d0a570c017870fc`.
- EA-ID registry SHA-256:
  `EE34E2C5F7A94E4A9B088CDF307B458BB6D85F5188E35CAED14E94F8D026A4E0`.
- Magic registry SHA-256:
  `22F6DB7DE9472BF53A9BCEE58CF6C6FCA87D7CD185B74590EB12601200690567`.
- Generated resolver SHA-256:
  `08D940893F204E3B092E0E2D1CFF6BC9C939E803C713653CEF22F8D09956943C`.

The strict-default resolver precheck exposed the existing missing-directory
condition for active IDs 1001, 1015, and 1016. The final deterministic
generation used `--keep-obsolete`, retaining all 15,357 active registry rows
and dropping none. This preserved the committed legacy resolver population
while adding the two registered QM5_20184 slots; candidate-scoped identity
and build checks passed.

## Validation evidence

- Strategy-card schema lint: PASS; no missing sections and no ML hits.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Candidate build guard: PASS; approved G0 card, EA registry, magic rows,
  exact folder, and slug agree.
- V5 build guardrails: PASS, zero findings.
- Basket symbol-scope validation: `BASKET_OK`, zero violations.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260731_085813/QM5_20184_xauxag-xmom3.compile.log`.
- V5 strict build check: PASS, zero failures and zero warnings.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260731_085838.json`.

## Paced Q02 handoff

- Build task: `1818ec0b-73e9-4ce0-b474-bffe559d474c`, status `done`.
- Build result SHA-256 after recording:
  `E9E1E7577915F06096E8FC9AF7BC695B88DA9C3B5D80CA2BC8CF67C861218225`.
- Q02 work item: `76bd82c9-8cbf-4ac6-a811-26326c1e984f`.
- Phase/kind: `Q02` / `backtest`.
- Logical symbol/timeframe: `QM5_20184_XAU_XAG_XMOM3_D1` / D1.
- Status at handoff: `pending`, attempt 0, unclaimed, no evidence yet.
- Enqueued: `2026-07-31T09:02:29+00:00`.
- Auto-enqueue result: one logical-basket item enqueued, zero skipped.

No manual smoke tester or backtest was launched. The immediate pre-enqueue
scan observed six factory terminals (`T1,T2,T7,T8,T9,T10`) out of the
seven-terminal ceiling, plus the separate pre-existing T_Live process. The
CPU ceiling was therefore not hit, and Q02 owns the first CPU-bearing
validation pass.

## Safety boundary

No `T_Live` file, T_Live manifest, deploy manifest, portfolio gate, or
portfolio-admission artifact was read or changed. AutoTrading was not toggled.
The existing T_Live process was observed only to exclude it from the factory
capacity count.
