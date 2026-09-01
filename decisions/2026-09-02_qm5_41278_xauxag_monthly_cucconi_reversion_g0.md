# QM5_41278 XAU/XAG Monthly Cucconi Reversion - G0

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- EA: `QM5_41278_xauxag-mcucconi-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MCUCCONI-RV-20260902_S01`
- Source ID: `AI-CODEX-XAUXAG-MCUCCONI-RV-20260902`
- Card:
  `strategy-seeds/cards/approved/QM5_41278_xauxag-mcucconi-rv_card.md`
- Source approval:
  `decisions/2026-09-02_xauxag_monthly_cucconi_reversion_source_approval.md`
- Source approval commit: `3cad3fab48`

## Authority

The current explicit OWNER mission directs Codex to add one genuinely new
structural commodity/energy sleeve, identifies a market-neutral-style XAU/XAG
basket as eligible, requires reputable-source criteria, `RISK_FIXED` backtest
sets, branch-only committed work, and one paced Q02 enqueue. It expressly
forbids portfolio-gate and live-manifest changes, `T_Live`, and AutoTrading.

This G0 authorizes the exact card for build, deterministic non-live validation,
and Q02 handoff. It does not approve profitability, robustness, realized
neutrality, decorrelation, portfolio admission, deployment, or live use.

## R1-R4 Decision

| gate | verdict | evidence |
|---|---|---|
| R1 source quality | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Complete governed Schweikert carrier record with adverse findings; official CME spread record; complete 14-page peer-reviewed publisher PDF defining the classical Cucconi statistic and permutation construction; authoritative 2009 metadata; durable source approval and retrieval hashes. |
| R2 mechanical completeness | `PASS` | Synchronized month ends, fixed changes/blocks, strict ties, pooled ranks, squared-rank moments, contrary ranks, rho, Cucconi statistic, all 924 labels, inclusive tail 480, neutral rank sum 39, contrarian side, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are frozen. |
| R3 data availability | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5 state provide all runtime inputs. Continuous-CFD basis, financing, calendar, synchronization, and legging risks remain explicit. |
| R4 allowability | `PASS` | Deterministic bounded arithmetic only; no trained output, prohibited signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Frozen Execution Contract

At the first synchronized tradable D1 boundary of each broker month, consume
one attempt and reconstruct thirteen consecutive completed-month XAU/XAG close
pairs. Form twelve adjacent changes in `ln(XAU)-ln(XAG)`, split six old/six
recent, reject pooled ties, and strictly rank all changes.

For the recent ranks compute the classical Cucconi standardized squared-rank
and squared-contrary-rank components with `E=325`, `SD=sqrt(6955)`, and
`rho=-479/535`. Combine them as
`C=(U^2+V^2-2*rho*U*V)/(2*(1-rho^2))`, enumerate all 924 six-rank labels, and
require inclusive exact tail count at most 480. Fade recent rank sum above 39
by selling XAU/buying XAG; fade a sum below 39 with the opposite package; a
sum of 39 is flat.

One logical package targets equal absolute USD notionals under a single
aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` budget.
Each leg receives half the frozen-stop budget at `3.5*ATR(20,D1)`. Reject
rounded notional mismatch above 20 percent and XAU/XAG spreads above
1,500/500 points. Submit XAU first, XAG second, and immediately flatten any
malformed or incomplete package. Exit on the first later broker month or after
forty elapsed calendar days. News axes, legacy news mode, and Friday close are
OFF. No statistic magnitude sizing or intramonth retry is allowed.

## Duplicate Decision

The corrected-root receipt
`artifacts/qm5_xauxag_mcucconi_rv_preallocation_dedup_20260902.json`, SHA-256
`7410C6B9B94B9B3E5BF1E5964789C42471DA5016F643149624FF4C29DF2B8DE8`,
found no exact identity across 4,777 registry rows, 1,413 cards, and all 45
Strategy Wiki nodes. Four expected shared-carrier fuzzy matches were resolved
by manual formula review and frozen fixtures.

Cucconi's correlated squared-rank/contrary-rank quadratic is not Kuiper's two
ECDF extrema, Anderson-Darling's tail-weighted full ECDF path,
Brown-Forsythe's numeric median-centered absolute-deviation comparison, or
Klotz's separately mean-centered squared-normal score sum. The WTI Lepage
card uses a different carrier, sample, component formula, direction, and
lifecycle. Boundary fixtures in the source and card prove both qualification
disagreement directions.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_RAW_CHANGE_STRICT_RANK_CUCCONI_SQUARED_RANK_CONTRARY_RANK_CORRELATED_QUADRATIC_EXACT_924_TAIL_480_RANK_SUM_CONTRARIAN_BASKET`.

## Activity And Falsification

The frozen label support produces 480 statistic-qualified assignments; 18
are direction-neutral, leaving 462 directional assignments or exactly six per
twelve combinatorial attempts. This is a market-free activity prior, not a
trade-count or performance result.

Retire the exact card on zero packages, fewer than five completed packages in
any full post-warm-up year, a failed deterministic fixture, nonpositive
governed economics, or any downstream gate failure. No post-result change to
sample, split, statistic, tail, direction, carrier, risk, or hold is authorized
inside this variant. Q09 alone owns realized portfolio overlap.

## Authorized Next Action

1. Allocate `QM5_41278`, symbol slots 0/1, and resolver rows through the
   governed allocator only.
2. Build one V5 EA, logical `basket_manifest.json`, one logical D1
   `RISK_FIXED=1000` set, component validation sets, reference fixtures, and
   `SPEC.md`.
3. Obtain governed Q01 compile/build evidence.
4. If Q01 passes and CPU admission is open, enqueue exactly one paced logical-
   basket Q02 item; never enqueue component legs.

Excluded: manual tester launches, optimization, stress/live/demo/shadow sets,
portfolio-gate edits, correlation waivers, portfolio admission, deploy/live
manifests, `T_Live`, AutoTrading, and terminal control.
