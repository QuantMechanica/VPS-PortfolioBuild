# QM5_41282 XAU/XAG Monthly Van der Waerden Reversion - G0

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- EA: `QM5_41282_xauxag-mvdw-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MVDW-RV-20260902_S01`
- Source ID: `AI-CODEX-XAUXAG-MVDW-RV-20260902`
- Card: `strategy-seeds/cards/approved/QM5_41282_xauxag-mvdw-rv_card.md`
- Source approval:
  `decisions/2026-09-02_xauxag_monthly_van_der_waerden_reversion_source_approval.md`
- Source approval commit: `396bdf003a`

## Authority

The current explicit OWNER mission directs Codex to add one genuinely new
structural commodity/energy sleeve, identifies a market-neutral-style
XAU/XAG basket as eligible, requires reputable-source criteria,
`RISK_FIXED` backtest sets, branch-only committed work, and one paced Q02
enqueue. It forbids portfolio-gate and live-manifest changes, `T_Live`, and
AutoTrading.

This G0 authorizes the exact card for build, deterministic non-live
validation, and Q02 handoff. It does not approve profitability, robustness,
realized neutrality, decorrelation, portfolio admission, deployment, or live
use.

## R1-R4 Decision

| gate | verdict | evidence |
|---|---|---|
| R1 source quality | `PASS_WITH_AI_SYNTHESIS_AND_OFFICIAL_METHOD_EVIDENCE` | One durable AI source; complete governed Schweikert carrier record with adverse findings; official CME spread record; complete bounded NIST and SAS formula/exact-test sections; durable approval and hashes. |
| R2 mechanical completeness | `PASS` | Synchronized month ends, fixed changes/blocks, strict ties, twelve frozen signed normal scores, complete enumeration, absolute inclusive tail 462, contrarian score-sign side, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are frozen. |
| R3 data availability | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5 state provide every runtime input. Continuous-CFD basis, financing, calendar, synchronization, and legging risks remain explicit. |
| R4 allowability | `PASS` | Deterministic bounded arithmetic only; no trained output, prohibited signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Frozen Execution Contract

At the first synchronized tradable D1 boundary of each broker month, consume
one attempt and reconstruct thirteen consecutive completed-month XAU/XAG
close pairs. Form twelve adjacent changes in `ln(XAU)-ln(XAG)`, split six
old/six recent, reject pooled ties, and strictly rank all changes.

Map ranks `r=1..12` to signed Van der Waerden score
`Phi^-1(r/13)`, frozen as exact integer numerators over `10^15`, and sum the
six recent numerators to `S`. Enumerate all 924 six-rank labels and count the
inclusive exact two-sided tail `abs(S_perm)>=abs(S)`. Require tail count at
most 462 and nonzero `S`. Fade positive `S` by selling XAU/buying XAG and
negative `S` with the opposite package.

One logical package targets equal absolute USD notionals under a single
aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` budget.
Each leg receives half the frozen-stop budget at `3.5*ATR(20,D1)`. Reject
rounded notional mismatch above 20 percent and XAU/XAG spreads above
1,500/500 points. Submit XAU first, XAG second, and immediately flatten any
malformed package. Exit on the first later broker month or after forty
elapsed calendar days. News axes, legacy news mode, and Friday close are OFF.
No score-magnitude sizing or intramonth retry is allowed.

## Duplicate Decision

The corrected-root receipt
`artifacts/qm5_xauxag_mvdw_rv_preallocation_dedup_20260902.json`, SHA-256
`F356B42F07A95D6F5929A75AF3C5067D18A3A9EC7B830D2A0DBF40D999790310`,
found no exact identity across 4,781 registry rows, 1,417 cards, and all 45
Strategy Wiki nodes. Expected shared-carrier fuzzy matches were resolved by
formula review and frozen fixtures.

Van der Waerden's signed monotone normal-quantile score sum is not Savage's
harmonic score, Wilcoxon's linear rank sum, Klotz's block-centered squared-
normal score, Conover's squared deviation ranks, Cucconi's correlated
quadratic, or an ECDF path. Fixtures prove Van der Waerden-only, Wilcoxon-
only, and Savage-only decisions.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_FIXED_SIX_BY_SIX_RAW_CHANGE_STRICT_RANK_VAN_DER_WAERDEN_SIGNED_NORMAL_QUANTILE_SCORES_EXACT_924_ABSOLUTE_TAIL_462_SCORE_SIGN_CONTRARIAN_BASKET`.

## Activity And Falsification

The frozen label support produces exactly 462 qualifying assignments, split
231/231 by sign, with twenty exact zero-score flat states. This is a market-
free activity prior, not a trade-count or performance result.

Retire the exact card on zero packages, fewer than five completed packages in
any full post-warm-up year, a failed fixture, nonpositive governed economics,
or any downstream gate failure. No post-result change to sample, scores,
tail, direction, carrier, risk, or hold is authorized. Q09 alone owns
realized portfolio overlap.

## Authorized Next Action

1. Allocate `QM5_41282`, symbol slots 0/1, and resolver rows through the
   governed allocator only.
2. Build one V5 EA, logical `basket_manifest.json`, one logical D1
   `RISK_FIXED=1000` set, component validation sets, reference fixtures, and
   `SPEC.md`.
3. Obtain governed Q01 compile/build evidence.
4. If Q01 passes and CPU admission is open, enqueue exactly one paced
   logical-basket Q02 item; never enqueue component legs.

Excluded: manual tester launches, optimization, stress/live/demo/shadow sets,
portfolio-gate edits, correlation waivers, portfolio admission, deploy/live
manifests, `T_Live`, AutoTrading, and terminal control.
