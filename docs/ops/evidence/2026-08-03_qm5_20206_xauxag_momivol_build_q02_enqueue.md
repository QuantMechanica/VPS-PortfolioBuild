# QM5_20206 XAU/XAG Momentum–IVol Build And Q02 Enqueue Evidence

Date: 2026-08-03 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency commodity candidate was researched, carded,
allocated, built, strictly validated, committed, and handed to the paced Q02
fleet:

- EA: `QM5_20206_xauxag-momivol`.
- Strategy ID: `FUERTES-MOMIVOL-2015_XAU_XAG_S04`.
- Logical basket: `QM5_20206_XAU_XAG_MOMIVOL_D1`; host: `XAUUSD.DWX` D1.
- Q01: PASS.
- Q02: exactly one priority-track work item,
  `46fef851-87fd-4e85-adef-554ed0022088`, pending at confirmation.

This is an opposite-leg relative precious-metal factor candidate. It does not
establish market, dollar, beta, volatility, or portfolio neutrality. The
unchanged downstream portfolio gate remains authoritative for realized
decorrelation from the XAU/SP500/NDX/XNG book.

## Frozen Edge

On the first tradable XAU D1 bar of each broker month:

1. Align 64 completed D1 closes for XTI, XNG, XAU, and XAG.
2. Form 63 log returns and their equal-weight commodity-factor return.
3. Fit separate intercept-plus-factor OLS regressions for XAU and XAG and
   compute each residual standard deviation using 61 residual degrees of
   freedom.
4. Compare XAU and XAG 63-D1 momentum over the same completed endpoints.
5. Buy XAU / sell XAG only when XAU has higher momentum and lower IVol; sell
   XAU / buy XAG only when XAG has higher momentum and lower IVol.
6. Consume the month and remain flat when ranks disagree, either rank ties
   within `1e-12`, history is malformed, factor variance is zero, or arithmetic
   is invalid.

One shared `RISK_FIXED=1000` package budget is translated toward equal dollar
notional using independent `3.0 * ATR(20,D1)` hard stops. A greater than 20%
rounded notional mismatch rejects the package. Both legs close at the next
month boundary or after 35 calendar days; orphan, duplicate, same-direction,
wrong-magic, or stopless composition is flattened. No same-month retry,
fallback trade, parameter sweep, external runtime feed, trained model, grid,
martingale, scale-in, or pyramid exists.

## Source And Approval

The governed packet is
`strategy-seeds/sources/FUERTES-MOMIVOL-2015/source.md`. The primary source is
Fuertes, Miffre, and Fernandez-Perez (2015), "Commodity Strategies Based on
Momentum, Term Structure and Idiosyncratic Volatility," *Journal of Futures
Markets* 35(3), 274-297, DOI `10.1002/fut.21656`. City Research Online records
the accepted manuscript as refereed and provides the institutional full text:
https://openaccess.city.ac.uk/id/eprint/6418/.

The durable packet records a complete accepted-manuscript review. It supports
monthly momentum/IVol double screens, a 3-month formation case, a one-month
hold, one-top/one-bottom sensitivity, and gold/silver source membership. The
paper does not test this four-CFD factor, two-metal carrier, QM risk translation,
broker costs, restart behavior, or portfolio. No source statistic transfers.

Durable G0 authorization:
`decisions/2026-08-03_qm5_20206_xauxag_momivol_g0.md`. Source/card approval
commit: `13399a080`.

## Non-Duplicate Evidence

Before allocation, `framework/scripts/research_dedup_check.py check` scanned
4,262 EA registry rows and 385 cards. It found no exact duplicate and returned
three expected fuzzy matches:

- `QM5_13113_energy-mom-ivol` trades XTI/XNG while XAU/XAG are read-only.
- `QM5_20192_xauxag-ivol` trades a 252-D1 pure-IVol rank without momentum.
- `QM5_20184_xauxag-xmom3` trades 63-D1 momentum without an IVol gate.

Manual semantic review resolves all three. The new EA's traded XAU/XAG carrier,
four-proxy 63-return OLS factor, 63-D1 relative momentum, strict rank-agreement
gate, and flat disagreement regime are jointly load-bearing. Existing XAU/XAG
ratio, price-residual, quantile, calendar, pure momentum, pure IVol, and
long-horizon reversal systems do not implement that conjunction.

## Deterministic Allocation

- EA registry: `20206,xauxag-momivol,FUERTES-MOMIVOL-2015_XAU_XAG_S04`.
- Magic slot 0: `XAUUSD.DWX` / `202060000`.
- Magic slot 1: `XAGUSD.DWX` / `202060001`.
- Allocation/resolver commit: `20d9b04a3`.
- Resolver registry row count after generation: 15,413; dropped rows: 0.
- Resolver-declared registry SHA-256:
  `2219D2E97D2E90CBDFC7BE552A1CA752F1C719561BC86009EF9F49B967D5D887`.
- Resolver tests: 4 passed.

The strict resolver preflight initially stopped without writing because three
legacy active registry IDs (1001, 1015, 1016) have no current EA directory. To
preserve their already-generated mappings, exact empty untracked helper
directories were present only for the successful regeneration and were removed
immediately afterward. The resulting parsed registry retained every prior row
and appended only the two 20206 mappings; no legacy row was dropped.

## Q01 Build Evidence

- Build commit: `293e2a0cc`.
- Strategy-card schema lint: PASS, no missing section or forbidden-library hit.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile summary:
  `D:/QM/reports/compile/20260803_011438/summary.csv`.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260803_011438/QM5_20206_xauxag-momivol.compile.log`.
- Full strict V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260803_011438.json`.
- P1 artifact validation: PASS:
  `D:/QM/reports/pipeline/QM5_20206/P1/P1_QM5_20206_result.json`.
- Canonical backtest contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; both news axes, legacy news mode, Friday close, and
  stress rejection are OFF.

Artifact SHA-256 values at enqueue:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `111b9d82a6f187441a2949b9f27d3c125b56157439b760b86f734fbcec4ead44` |
| EX5 | `d8ff221533da1564ab71cef2966a15a78573bd81e7d76eded8d16d90643402c4` |
| SPEC | `0a5fc969123df54ec360598220c9627c95f0f09c45134d78bfa50074231b874e` |
| Basket manifest | `492872131de44e06cad301f0a46e3f585753da2d08ad5204c491acd5cfe2de55` |
| Build-time card | `33e1637c1e72203b8a41e6d7535c4ceb89441ebad7425f43de7c67e447b41526` |
| Backtest setfile | `8b5d9e92c457f0ed8ff9e459e7ba2942e2625e55dba5f93e6d85ba54f481625f` |
| Source packet | `a4902a7f351e92c8dd039221fe7243b5351c158abedf506a36ad7383ee5061c2` |
| Magic resolver file | `e0bdec7e2bea0f668b96a0f4526caa14da4642e5eb77bf7af0f47d2f754dfa88` |

## Paced Q02 Handoff

The exact no-mutation dry-run scope was:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20206 --symbols QM5_20206_XAU_XAG_MOMIVOL_D1 --max-part2-per-run 0
```

It selected one never-tested priority-track basket, no stranded retry, and no
deferred promotion. Two apply attempts observed the live factory mutation lock
and made no mutation. The same idempotent scope then acquired the lock and
inserted exactly one row:

- Work item: `46fef851-87fd-4e85-adef-554ed0022088`.
- Created: `2026-08-03T01:18:32+00:00`.
- Phase/kind: Q02 / backtest.
- Logical symbol/timeframe: `QM5_20206_XAU_XAG_MOMIVOL_D1` / D1.
- Host: `XAUUSD.DWX` D1.
- Basket inputs: XTI, XNG, XAU, and XAG; XAU/XAG are the traded legs.
- Timeout: 450 minutes; `priority_track=true`.
- Status at confirmation: pending, attempt 0, unclaimed.
- Queue at apply: 1,845 pending against the 7,000-row ceiling.

The post-enqueue path-anchored process scan at `2026-08-03T01:19:06+00:00`
found six factory terminals (T1, T2, T4, T6, T9, T10), below the seven-terminal
CPU ceiling. The separate T_Live and FTMO processes were identified outside the
factory count. This session did not manually launch, reserve, stop, or alter any
terminal.

## Safety Boundary

- No manual backtest or pipeline phase was launched; the paced fleet owns Q02.
- The backtest CPU ceiling was not reached.
- No live/demo/shadow setfile or deploy artifact was created.
- AutoTrading was not toggled and `T_Live` was not accessed or changed.
- The portfolio gate and T_Live manifest were not touched.
- Q02 enqueue is not certification, profitability evidence, decorrelation
  evidence, or portfolio admission.

