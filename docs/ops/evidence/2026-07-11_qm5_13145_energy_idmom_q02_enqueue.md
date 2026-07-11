# QM5_13145 Energy Idiosyncratic Momentum - Q02 Enqueue Evidence

**Date:** 2026-07-11

**Branch:** agents/board-advisor

**EA:** QM5_13145_energy-idmom

**Status:** Q01 PASS; one logical Q02 basket pending

## Edge And Evidence Boundary

The new edge is the source-best eleven-month formation and one-month hold from
Shpak, Human, and Nardon, "Idiosyncratic Momentum in Commodity Futures," SSRN
3035397 and the complete article on pages 56-85 of the July 2018 *Cross Border
Benefits Alliance-Europe Review*. The paper's 28-commodity universe explicitly
includes WTI and natural gas.

The source removes systematic commodity-factor exposure, sums ranking
residuals without subtracting fitted alpha, buys high residual-momentum
commodities, and shorts low residual-momentum commodities. Its full model uses
market, term-structure, and size factors. QM5_13145 implements only a bounded
price-native falsification: one fixed equal-weight XTI/XNG/XAU/XAG market
factor and two traded energy legs. Missing curve/open-interest factors are not
invented, and no source return, significance, drawdown, cost, or correlation
number is imported.

Primary source:
https://www.cbba-europe.eu/wp-content/uploads/2018/07/CBBA-Europe-review_July-2018.pdf

SSRN record: https://ssrn.com/abstract=3035397

## Locked Mechanical Baseline

On the first tradable XTIUSD.DWX D1 bar of broker month t:

1. Reconstruct eleven completed monthly log returns for XTIUSD.DWX,
   XNGUSD.DWX, XAUUSD.DWX, and XAGUSD.DWX from bounded D1 history.
2. For every completed month j, set the market proxy to the equal-weight
   return of those four fixed CFDs.
3. Fit a closed-window OLS beta separately for XTI and XNG and compute the
   source-aligned score `sum(return_i,j - beta_i * factor_return_j)`. Do not
   subtract fitted alpha from the ranking residual.
4. Buy the higher-score energy leg and short the lower-score leg; reject ties,
   stale/missing endpoints, degenerate factor variance, invalid arithmetic, or
   invalid execution metadata. XAU and XAG remain read-only factor inputs.
5. Allocate one `RISK_FIXED=1000` package as equal fixed-risk halves with
   independent frozen ATR(20) times 3.5 hard stops. Close at the next monthly
   transition or after 35 days, flatten invalid composition/orphans, and
   prohibit same-month re-entry.

## Non-Duplicate Decision

The canonical pre-allocation check returned CLEAN across 4,031 registry rows
and 333 cards. The post-allocation exact match is QM5_13145's own reservation.
Manual signal/input/window/direction review found no duplicate:

- QM5_12567 is a two-day RSI pullback.
- QM5_12733 ranks recent raw XTI/XNG returns without factor residualization.
- QM5_13113 requires raw momentum and residual-volatility ranks to agree.
- QM5_13133 ranks idiosyncratic volatility, not residual return.
- QM5_13141 ranks residual tail-probability asymmetry.
- QM5_13144 ranks one isolated t-11/t-10 return slice.

Verdict: `CLEAN_PRE_ALLOCATION; POST_ALLOCATION_EXACT_MATCH_IS_SELF`.

## Identity And Registry Evidence

- EA reservation:
  `13145,energy-idmom,SHPAK-IDMOM-2017_XTI_XNG_S01,active`.
- Magic slot 0: XTIUSD.DWX to `131450000`.
- Magic slot 1: XNGUSD.DWX to `131450001`.
- The clean staged resolver retains 14,883 rows and both new magic values.
- Clean magic-registry SHA256:
  `2697207EEBA0694894F7A04462D696CED8AD265497B490B18F5B95649059BD8F`.
- Resolver SHA256:
  `8DA381CAD906D2078F808D83C780F55435921384B71762F7B55770A17CA3C12F`.

The staged resolver preserves the pre-existing QM5_13122 binding and drops
only historical missing-directory IDs 1001, 1015, and 1016. Unrelated dirty
fleet allocations were excluded from build commit
`051319ac337d02cf253375d5a07fc81b02f4f875`.

## Q01 Build Evidence

- Build commit: `051319ac337d02cf253375d5a07fc81b02f4f875`.
- Strict clean-staged-resolver compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `D:/QM/reports/compile/20260711_170610/QM5_13145_energy-idmom.compile.log`.
- Build check: PASS, 0 failures, 0 warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260711_170610.json`.
- Card schema lint, G0 lint, SPEC validator, build guard, basket symbol-scope
  validator, and setfile validation: PASS.
- Symbol-scope verdict: `BASKET_OK` for XTI, XNG, XAU, and XAG.
- MQ5 SHA256:
  `431A7C33BBF05A32F8A3D2DE9B0EB87E958F4A54841FE5242A900980405DF5DF`.
- EX5 SHA256:
  `450B1C1CE5CAD5CF37599E0F2FEEBD4F29A5B2B8ABEFE96DB8FE9D097C803164`.

## Risk And Setfile Evidence

- Logical symbol: `QM5_13145_ENERGY_IDMOM_D1`; host XTIUSD.DWX, D1.
- Traded symbols: XTIUSD.DWX and XNGUSD.DWX.
- Read-only factor symbols: XAUUSD.DWX and XAGUSD.DWX.
- Setfile:
  `framework/EAs/QM5_13145_energy-idmom/sets/QM5_13145_energy-idmom_QM5_13145_ENERGY_IDMOM_D1_D1_backtest.set`.
- Setfile SHA256:
  `CC017DD6E948AB5574C13EC20D31C6C76F582CFEB0FAF521412D13FEA5FE4AB1`.
- Setfile build hash:
  `0fc196fdfd555073ec890b3dfc2f93e4eee0814523f1e0aa49f960243b48c4b1`.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Friday close is disabled only for the source-aligned monthly hold.

## Q02 Queue Evidence

- Build task: `4bc3ccc2-8021-46e1-8130-8c3b3e96dc92`, done.
- Work item: `613e2613-e9b1-4a30-befe-79ac8bc0e2d1`.
- Phase/kind: Q02 / backtest.
- Logical basket: `QM5_13145_ENERGY_IDMOM_D1`.
- Host/timeframe: XTIUSD.DWX / D1.
- Status at handoff: pending, attempt 0, unclaimed.
- Enqueued at: `2026-07-11T17:14:40+00:00`.
- `farmctl record-build` enqueued one item and skipped none.

No dispatch tick, worker tick, terminal launch, smoke test, or backtest was
started by this work. Q02 owns the first CPU-bearing validation pass.

## Safety And Kill Boundary

- Structural D1/monthly price arithmetic and closed-window OLS only; no ML or
  banned indicator.
- No live setfile, T_Live artifact, AutoTrading action, deploy manifest,
  T_Live manifest, portfolio gate, portfolio admission, or portfolio KPI was
  touched.
- The complete source is working-paper/professional-publication evidence, not
  a peer-reviewed journal result; source quality remains a kill risk.
- The missing source term-structure/size factors, four-CFD factor proxy,
  continuous-CFD basis, two-name rank, XNG gaps, legging, and costs are kill
  risks, never waiver grounds.
- Opposite directions and equal fixed-risk halves reduce common direction but
  do not establish dollar, beta, volatility, factor, or realized market
  neutrality. Realized book orthogonality remains unclaimed until a later
  portfolio gate measures it.
