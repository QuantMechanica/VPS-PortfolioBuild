# QM5_41281 XAU/XAG Monthly Conover Scale Reversion - G0

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- EA: `QM5_41281_xauxag-mconover-scale-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902_S01`
- Source ID: `AI-CODEX-XAUXAG-MCONOVER-SCALE-RV-20260902`
- Card:
  `strategy-seeds/cards/approved/QM5_41281_xauxag-mconover-scale-rv_card.md`
- Source approval:
  `decisions/2026-09-02_xauxag_monthly_conover_scale_reversion_source_approval.md`
- Source approval commit: `6a88b02d89`

## Authority

The current explicit OWNER mission directs Codex to add one genuinely new
structural commodity/energy sleeve, identifies a market-neutral-style XAU/XAG
basket as eligible, requires reputable-source criteria, `RISK_FIXED` backtest
sets, branch-only committed work, and one paced Q02 enqueue. It forbids
portfolio-gate and live-manifest changes, `T_Live`, and AutoTrading.

This G0 authorizes the exact card for build, deterministic non-live
validation, and Q02 handoff. It does not approve profitability, robustness,
realized neutrality, decorrelation, portfolio admission, deployment, or live
use.

## R1-R4 Decision

| gate | verdict | evidence |
|---|---|---|
| R1 source quality | `PASS_WITH_AI_SYNTHESIS_AND_OFFICIAL_METHOD_EVIDENCE` | Complete governed Schweikert carrier record with adverse findings; official CME spread record; complete bounded NIST formula pages; durable approval and hashes. |
| R2 mechanical completeness | `PASS` | Synchronized month ends, fixed changes/blocks, separate means, absolute deviations, strict ties, pooled ranks, squared scores, all 924 labels, upper-tail 461, contrarian mean-shift side, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are frozen. |
| R3 data availability | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5 state provide every runtime input. Continuous-CFD basis, financing, calendar, synchronization, and legging risks remain explicit. |
| R4 allowability | `PASS` | Deterministic bounded arithmetic only; no trained output, prohibited signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Frozen Execution Contract

At the first synchronized tradable D1 boundary of each broker month, consume
one attempt and reconstruct thirteen consecutive completed-month XAU/XAG
close pairs. Form twelve adjacent changes in `ln(XAU)-ln(XAG)`, split six
old/six recent, compute each block's arithmetic mean, and pool the twelve
absolute deviations from those owning means. Reject any deviation tie.

Rank deviations 1..12, square each rank, and sum the recent six scores.
Enumerate all 924 six-rank labels and count the inclusive upper tail. Require
recent score at least 326 and tail no more than 461. Fade positive raw
recent-minus-old mean shift by selling XAU/buying XAG and negative shift with
the opposite package.

One logical package targets equal absolute USD notionals under a single
aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` budget.
Each leg receives half the frozen-stop budget at `3.5*ATR(20,D1)`. Reject
rounded notional mismatch above 20 percent and XAU/XAG spreads above
1,500/500 points. Submit XAU first, XAG second, and immediately flatten any
malformed package. Exit on the first later broker month or after forty elapsed
calendar days. News axes, legacy news mode, and Friday close are OFF. No score
magnitude sizing or intramonth retry is allowed.

## Duplicate Decision

The corrected-root receipt
`artifacts/qm5_xauxag_mconover_scale_rv_preallocation_dedup_20260902.json`,
SHA-256
`8B4A95C9CE6F1FABDFDE437DC76CDB2CA917C5458EA12639B6415E9D0B49836E`,
found no exact identity across 4,780 registry rows, 1,416 cards, and all 45
Strategy Wiki nodes. Expected shared-carrier fuzzy matches were resolved by
formula review and frozen fixtures.

Conover's separate-mean absolute deviations and polynomial squared-rank upper
tail are not Klotz's signed-residual squared-normal scores,
Brown-Forsythe's numeric median deviations without a label tail, Cucconi's
raw-rank quadratic, Savage's harmonic score, or Kuiper's ECDF extrema.
Fixtures prove Conover-only, neighbor-only, and opposite-side decisions.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_SEPARATE_MEAN_CENTERED_ABSOLUTE_DEVIATION_STRICT_RANK_CONOVER_SQUARED_RANK_SUM_EXACT_924_UPPER_HALF_TAIL461_RAW_MEAN_SHIFT_CONTRARIAN_BASKET`.

## Activity And Falsification

The strict score vector produces 461 recent-expansion assignments, two
neutral assignments, and 461 recent-contraction assignments. The gate
therefore admits 5.987 states per twelve combinatorial monthly attempts. This
is a market-free activity prior, not a trade-count or performance result.

Retire the exact card on zero packages, fewer than five completed packages in
any full post-warm-up year, a failed fixture, nonpositive governed economics,
or any downstream gate failure. No post-result change to sample, centering,
score, tail, direction, carrier, risk, or hold is authorized. Q09 alone owns
realized portfolio overlap.

## Authorized Next Action

1. Allocate `QM5_41281`, symbol slots 0/1, and resolver rows through the
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
