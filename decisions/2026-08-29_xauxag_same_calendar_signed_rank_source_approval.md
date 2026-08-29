# XAU/XAG Paired Same-Calendar Signed-Rank Seasonality - Source Approval

Date: 2026-08-29

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 enqueue if the active factory remains below its CPU ceiling.
Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified directional
XAU/SP500/NDX/XNG book, explicitly names a market-neutral XAU/XAG basket as an
acceptable candidate, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xauxag-samecal-srank`
- proposed strategy ID:
  `KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026_S01`
- proposed source ID: `KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- decision clock: first tradable host D1 bar after each genuine broker-month
  transition
- signal: direction of a one-sample signed absolute-rank sum over five to ten
  synchronized prior-year same-calendar relative returns `r_xau-r_xag`

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

The complete bounded packet is
`strategy-seeds/sources/KELOHARJU-WILCOXON-XAUXAG-SAMECAL-SR-2026/source.md`.
Its four parent packets were read completely and are bound by
`artifacts/qm5_xauxag_samecal_srank_source_provenance_20260829.json`.

Keloharju, Linnainmaa, and Nyberg (2016), *Journal of Finance* 71(4),
1557-1590, DOI `10.1111/jofi.12398`, supply same-calendar commodity return
information, monthly renewal, and a five-year history floor. Fuertes, Miffre,
and Rallis (2010), *Journal of Banking & Finance* 34(10), 2530-2548, DOI
`10.1016/j.jbankfin.2010.04.009`, supply the governed XAU/XAG cross-sectional
commodity carrier. Complete pinned R Core source and manual fix the
one-sample positive absolute-rank sum.

No source tests the exact paired signed-rank conjunction, strict no-tie
reduction, Darwinex CFD basket, execution plumbing, or current book. No
source return, significance, p-value, density, cost, drawdown, hedge,
futures/CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first tradable `XAUUSD.DWX` D1 bar after a genuine broker-month
transition in `(Y,M)`:

1. Repair owned exposure and persist `yyyymm` before every fallible gate. No
   flat, blocked, failed, rejected, stopped, or restarted month retries.
2. For exact years `Y-1..Y-10`, reconstruct synchronized completed
   same-calendar log returns for XAU and XAG from the prior-month endpoint to
   the target-month endpoint. Skip invalid years without substitution and
   require five to ten paired observations.
3. Form `d=r_xau-r_xag`. Require every `d` finite and outside `+/-1e-12`, and
   all `abs(d)` pairwise distinct beyond `1e-12`.
4. Rank `abs(d)` strictly from 1 through `n`, sum ranks for positive `d` as
   `V_plus`, and compute `S=2*V_plus-n*(n+1)/2`.
5. Positive `S` buys XAU and sells XAG; negative `S` sells XAU and buys XAG;
   exact zero or invalid state consumes the month flat. Magnitude never
   changes size.
6. Split one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` package budget equally by per-leg stop risk. Attach
   frozen `3.5*ATR(20,D1)` stops and no targets.
7. Close at the next broker-month boundary; 40 elapsed days repairs only a
   survivor. Flatten any orphaned, duplicated, same-direction, wrong-magic,
   or stopless package immediately.

Both news axes, legacy news mode, and framework Friday close are OFF. There is
no p-value, mean/median/hit-rate fallback, ratio z-score, residual fit,
fixed-month list, recent-trend gate, oscillator, inventory, event, curve,
volume, optimizer artifact, or external runtime feed.

## Reputable-Source Criteria

- R1 `PASS_WITH_STATISTIC_PAIR_AND_CFD_TRANSLATION_RISK`: two complete
  peer-reviewed trading lineages plus complete pinned primary software for
  the operative statistic; the exact conjunction remains untested.
- R2 `PASS`: synchronized endpoints, years, sample, epsilon, ties, ranks,
  score, side, attempt, shared risk, stops, atomicity, and lifecycle are
  locked before Q02.
- R3 `PASS_WITH_LONG_WARMUP_AND_CONTINUOUS_CFD_BASIS_RISK`: registered native
  XAU/XAG D1 history and MT5 state supply every runtime input.
- R4 `PASS`: deterministic date, log-return, sort, integer, ATR-risk, and
  execution arithmetic only; no trained output, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,702 registry identities, 1,348 card files,
and all 45 current Strategy Wiki nodes. It found no exact collision and
surfaced two expected fuzzy neighbors. Receipt:
`artifacts/qm5_xauxag_samecal_srank_preallocation_dedup_20260829.json`,
SHA-256
`C78FF4F0AF253B7E7889A0C1989A554F510DDB3D30B11497531B64E830871139`.

Manual review establishes functional non-equivalence:

- `QM5_20186` uses the arithmetic mean of the synchronized relative-return
  observations. For `[.01,.02,.03,.04,-.20]`, this candidate buys (`S=5`)
  while the existing mean rule sells.
- `QM5_41191` applies the statistic to one WTI return series and owns a single
  oil position. This candidate ranks paired XAU-minus-XAG returns and always
  owns an opposite-direction two-metal package.
- `QM5_41177` is a two-sample Mann-Whitney/rank-sum recent-window shift rule,
  not a one-sample signed-rank same-calendar rule.
- Existing ratio, residual, channel, current-month rank, weekday, weekend,
  and contiguous-momentum XAU/XAG EAs use different states.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_PAIRED_SAMECAL_SIGNED_ABSOLUTE_RANK_SUM_MONTHLY_BASKET_RENEWAL`.

## Kill And Safety Boundary

Q02 retires at zero trades, fewer than five completed packages in any full
post-warm-up year, nonpositive governed economics, or any calendar, endpoint,
synchronization, sample, zero/tie, rank, score, side, attempt, atomicity,
fixed-risk, stop, lifecycle, or determinism defect. No weak result may be
rescued by changing the estimator, sample, epsilon, carrier, direction, risk,
hold, spread caps, or adding a filter.

The opposite legs target relative precious-metal seasonality, but only
unchanged Q09 may establish realized book decorrelation. This approval
excludes manual backtests; live/demo/shadow/stress/optimization setfiles;
terminal control; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers.
