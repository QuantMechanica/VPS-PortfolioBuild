# QM5_41285 XAU/XAG Monthly Jonckheere-Terpstra Reversion - G0

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- EA: `QM5_41285_xauxag-mjt-rv`
- Strategy ID: `AI-CODEX-XAUXAG-MJT-RV-20260902_S01`
- Source ID: `AI-CODEX-XAUXAG-MJT-RV-20260902`
- Card: `strategy-seeds/cards/approved/QM5_41285_xauxag-mjt-rv_card.md`
- Source approval:
  `decisions/2026-09-02_xauxag_monthly_jonckheere_terpstra_reversion_source_approval.md`
- Source approval commit: `9c63983aa8`

## Authority

The current explicit OWNER mission directs Codex to add one genuinely new
structural commodity/energy sleeve, identifies a market-neutral-style XAU/XAG
basket as eligible, requires reputable-source criteria, `RISK_FIXED` backtest
sets, branch-only committed work, and one paced Q02 enqueue. It forbids
portfolio-gate and live-manifest changes, `T_Live`, and AutoTrading.

This G0 authorizes the exact card for identity allocation, non-live build,
deterministic Q01 validation, and Q02 handoff. It does not approve
profitability, robustness, realized neutrality, decorrelation, portfolio
admission, deployment, or live use.

## R1-R4 Decision

| gate | verdict | evidence |
|---|---|---|
| R1 source quality | `PASS_WITH_AI_SYNTHESIS_PEER_REVIEW_AND_OFFICIAL_METHOD_EVIDENCE` | One durable AI source; complete governed peer-reviewed gold/silver evidence with adverse findings; official exchange carrier; complete bounded NIST and peer-reviewed R Journal method sections; original peer-reviewed metadata; durable approval and claim boundary. |
| R2 mechanical completeness | `PASS` | Synchronized month ends, fixed changes/groups, strict ties, 48 comparisons, complete 34,650-label enumeration, two-sided tail 18,034, equivalent 19/29 bounds, contrarian sides, consumed attempt, aggregate fixed risk, atomicity, and lifecycle are frozen. |
| R3 data availability | `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories and MT5 state provide every runtime input. Continuous-CFD basis, financing, calendar, synchronization, and legging risks remain explicit. |
| R4 allowability | `PASS` | Deterministic bounded arithmetic only; no trained output, prohibited signal indicator, external runtime feed, grid, martingale, scale-in, or pyramid. |

## Frozen Execution Contract

At the first synchronized tradable D1 boundary of each broker month, consume
one attempt and reconstruct thirteen consecutive completed-month XAU/XAG
close pairs. Form twelve adjacent changes in `ln(XAU)-ln(XAG)` and fix three
chronological groups of four. Reject pooled ties and count all 48
earlier-group/later-group ordered wins as `J`.

Enumerate all `C(12,4)*C(8,4)=34,650` labeled rank assignments and count the
inclusive two-sided tail `abs(J_perm-24)>=abs(J-24)`. Require tail at most
18,034, equivalent to `J<=19` or `J>=29`. Fade an ascending state by selling
XAU/buying XAG and a descending state with the opposite package.

One logical package targets equal absolute USD notionals under a single
aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` budget.
Each leg receives half the frozen-stop budget at `3.5*ATR(20,D1)`. Reject
rounded notional mismatch above 20 percent and XAU/XAG spreads above
1,500/500 points. Submit XAU first, XAG second, and flatten malformed exposure
immediately. Exit on the first later broker month or after forty elapsed days.
News axes, legacy news, and Friday close are OFF. No score-magnitude sizing or
intramonth retry is allowed.

## Duplicate Decision

The corrected-root receipt
`artifacts/qm5_xauxag_mjt_rv_preallocation_dedup_20260902.json`, SHA-256
`E103D2C5F4751B0AB5B228C898DFC85AD49C4C801D29939FB1A4D0C753CBB944`,
found no exact identity across 4,784 registry rows, 1,420 cards, and all 45
Strategy Wiki nodes. The five fuzzy hits are shared-carrier channel, OLS,
fixed-horizon reversal, realized-jump, and median/MAD systems.

Manual review separates the closest functional families: within-month
three-block vote, direct-WTI daily three-block classifier, and fixed six/six
Mann-Whitney or normal-score baskets. Frozen ranks prove candidate-only,
neighbor-only, and opposite-side outcomes.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_THREE_BY_FOUR_CLASSIC_JONCKHEERE_TERPSTRA_48_ORDERED_WINS_EXACT_34650_TWO_SIDED_TAIL18034_CONTRARIAN_BASKET`.

## Activity And Falsification

Complete market-free enumeration qualifies 18,034 of 34,650 strict-rank
assignments, split 9,017 ascending and 9,017 descending. This is a pre-data
activity prior, not a trade-count, p-value, independence, or performance
result.

Retire the exact card on zero packages, fewer than five completed packages in
any full post-warm-up scored year, failed fixtures, nonpositive governed
economics, or any downstream gate failure. No post-result change to sample,
groups, statistic, tail, direction, risk, or hold is authorized. Q09 alone
owns realized portfolio overlap.

## Authorized Next Action

1. Allocate `QM5_41285`, symbol slots 0/1, and resolver rows through the
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
