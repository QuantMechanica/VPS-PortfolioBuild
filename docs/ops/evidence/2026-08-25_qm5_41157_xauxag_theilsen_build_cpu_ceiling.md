# QM5_41157 XAU/XAG Theil-Sen build and CPU-ceiling handoff

Date: 2026-08-25

Branch: `agents/board-advisor`

Status: `SOURCE_READY_COMPILE_NOT_ENQUEUED_CPU_CEILING`

## New commodity sleeve

`QM5_41157_xauxag-mtheilsen-rv` is a new low-frequency,
market-neutral-style gold/silver relative-value edge. At the first executable
synchronized D1 boundary of a broker month, it selects the latest exact
timestamp-matched XAU/XAG close in each of the immediately prior thirteen
consecutive broker months. In chronological order it forms
`s[i]=ln(XAU[i])-ln(XAG[i])`, enumerates all 78 forward slopes
`(s[j]-s[i])/(j-i)` for `i<j`, sorts them, averages zero-based indexes 38 and
39, and fades the strict robust-slope sign for one broker month. Exact zero or
any malformed state consumes the month flat. Endpoint displacement is logged
but cannot change the decision.

The atomic opposite-side package starts each leg at half of one aggregate
`RISK_FIXED=1000` frozen-stop allowance. Equal-notional balancing may only
reduce a leg, total normalized stop risk may not exceed one, and realized
notional mismatch may not exceed 20%. Both legs use frozen
`3.5*ATR(20,D1)` hard stops, no target, one attempt per month, next-month exit,
and a forty-day stale repair. News and Friday close are OFF.

This mechanic is distinct from the directional certified XAU/SP500/NDX/XNG
book and from existing XAU/XAG endpoint, daily-return location, OLS/CADF, and
monthly daily-Hodges-Lehmann builds. It makes no realized decorrelation claim;
Q09 alone owns that test.

## Governed source and identity

- Source approval and clean pre-allocation dedup: `e6c9d2ae4`.
- Bounded reputable-source packet: `d4e13bb6c`.
- EA-ID reservation: `b0c6b616f`.
- OWNER-authorized G0 card: `5504b25e7`.
- Build-directory scaffold: `e4f4fb9f6`.
- Basket magic rows and resolver regeneration: `5a83a44d1`.
- EA source, SPEC, manifest, exact card copy, reference suite, and three
  fixed-risk backtest setfiles: `74ace92142d24c0171cdd9530ea358c408a059ed`.

Identity is `QM5_41157`, strategy ID
`SCHWEIKERT-MOP-CME-XAUXAG-MTHEILSEN-RV-2026_S01`, logical carrier
`QM5_41157_XAU_XAG_MTHEILSEN_RV_D1`, host magic `411570000`, and companion
magic `411570001`. MQ5 SHA-256 is
`38E8471F64E679568340AB25E5413A99B9E25B11DE61D46613D596333101A3AD`.

## Deterministic verification before the stop

- approved-card schema lint: PASS, zero missing sections and zero ML hits;
- G0 card lint: PASS;
- independent monthly Theil-Sen reference suite: PASS, 7/7;
- `validate_spec_doc.py`: PASS, 1/1;
- `validate_build_guardrails.py`: PASS, four files and zero findings;
- `validate_symbol_scope.py --fail-on-leak`: `BASKET_OK`, zero violations;
- the approved, canonical, and EA-local card copies are byte-identical;
- exactly three `.set` files exist, all `environment: backtest`, all fixed at
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The reference fixtures independently verify year rollover, latest exact
synchronized selection despite asymmetric missing days, exclusion of current-
month observations, consecutive-month failure, endpoint freshness, all 78
`i<j` slopes, indexes 38/39, strict contrarian direction, zero-flat behavior,
diagnostic-only endpoint disagreement, half-risk-only reduction, card-copy
identity, manifest identity, and magic resolution.

## Binding CPU stop

Before any compile or Q02 mutation, a fresh five-sample whole-host
`Processor(_Total)` window returned `100.00, 100.00, 100.00, 100.00, 97.12`
percent (average 99.42%, maximum 100.00%). The maximum exceeds the governed
`CPU_MAX_LOAD_PERCENT=97.0`; the configured resume threshold is 90.0%. The
same read-only snapshot found eight path-anchored `terminal64.exe` and six
path-anchored `metatester64.exe` processes under `D:\QM\mt5`.

The mission requires stopping when that ceiling is hit. Therefore no direct
compile, governed compile enqueue, tester dispatch, terminal claim, backtest,
or Q02 enqueue was attempted. Read-only final checks found no EX5 and zero
work items for EA 41157. Q02 cannot be legally enqueued without a current
strict zero-error/zero-warning compile and hash-bound EX5. The card therefore
correctly remains at `pipeline_phase: Q01`, `q01_status: NOT_BUILT`, and
`q02_status: NOT_ENQUEUED_Q01_PENDING`.

Machine-readable evidence is
`artifacts/qm5_41157_cpu_ceiling_20260825.json`.

## Governed continuation

After sustained CPU recovery below 90%, run exactly one strict source-fresh
compile for `QM5_41157_xauxag-mtheilsen-rv`. Only a compile PASS with a
hash-bound EX5 permits build review and one logical Q02 enqueue using the
committed D1 `RISK_FIXED` preset. Do not dispatch a terminal as part of the
enqueue handoff.

No portfolio gate, `T_Live` manifest, `T_Live` file, AutoTrading state,
terminal process, live/demo/shadow/stress/optimization preset, deploy state,
existing EA, gate threshold, or portfolio verdict was changed.
