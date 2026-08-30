# G0 Decision — QM5_41225 XNG Median Same-Calendar Seasonality

Date: 2026-08-30

Decision: `APPROVED`

Authority: the OWNER commodity/energy sleeve mission delivered to Codex on
the `agents/board-advisor` branch, bounded by the durable source approval
`decisions/2026-08-30_xng_median_same_calendar_source_approval.md` at commit
`e17fe575d555b857493d3414a4bd00094978085b`.

Approved card:
`strategy-seeds/cards/approved/QM5_41225_xng-medcal_card.md`.

## Identity

- EA ID: `QM5_41225`, allocated atomically by the deterministic registry
- slug: `xng-medcal`
- strategy ID: `KELOHARJU-XNG-MEDCAL-2026_S01`
- source ID: `KELOHARJU-RETSEAS-2016`
- carrier: exact `XNGUSD.DWX`, D1, slot 0, intended magic `412250000`
- mechanic: at each genuine broker-month transition, compute the sample
  median of five to ten exact prior-year completed XNG returns for that same
  calendar month, trade its absolute sign, and renew next month

## Gate Findings

- R1 `PASS_WITH_TRANSLATION_RISK`: named-author, peer-reviewed *Journal of
  Finance* source with DOI, complete-read evidence, natural gas explicitly in
  the source universe, and the median/standalone CFD reductions disclosed as
  untested QM translations.
- R2 `PASS`: label normalization, month clock, endpoints, exact years, sample
  bounds, even/odd median, sign, attempt, risk, spread, and lifecycle are
  mechanical and locked.
- R3 `PASS_WITH_HISTORY_AND_SESSION_LABEL_RISK`: registered native
  `XNGUSD.DWX` D1 history, timestamps, quotes, broker calendar, positions,
  deals, and terminal state supply every runtime input. The five-year warm-up
  and native-versus-`+1` energy label are binding Q02 risks.
- R4 `PASS`: deterministic timestamps, calendar arithmetic, sorting,
  logarithms, comparisons, and V5 execution plumbing only; no trained signal,
  prohibited runtime feed, grid, martingale, scale-in, hedge, or pyramid.

## Duplicate Review

The canonical receipt
`artifacts/qm5_xng_medcal_preallocation_dedup_20260830.json` found no exact
identity across 4,724 registry rows, 1,362 cards, and 45 Strategy Wiki nodes.
It surfaced the expected WTI median carrier sibling for manual review.

- `QM5_41055_wti-medcal` uses the same estimator on WTI; this card is the
  explicitly authorized XNG carrier port and owns only XNG risk/PnL.
- `QM5_20100_xng-samecal` uses an arithmetic mean and can take the opposite
  side under one extreme year.
- `QM5_41205_xng-samecal-huber10` requires ten of ten years, a nonzero robust
  scale, and 32 location updates; this card directly uses a five-to-ten sample
  median.
- `QM5_41214_xng-samecal-signscore` discards magnitudes and can abstain when
  the median is nonzero.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon cumulative-RSI2 pullback
  under a 200-D1 trend state, not calendar seasonality.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XNG_SAME_CALENDAR_MEDIAN_SIGN_MONTHLY_CARRIER_PORT`.

## Approved Build Contract

Development may build exactly the approved card with:

- exact `XNGUSD.DWX` D1 slot 0 and registered magic `412250000`;
- native same-day or one uniform `+1` energy-label normalization, with the
  normalized current D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-1..Y-10`, strict adjacent calendar-month endpoint identity,
  confirming following bars, and no current-month signal data;
- five to ten valid returns, ordinary odd/even median, no substitution year,
  arithmetic-mean/Huber/sign-score fallback, weighting, or interpolation;
- median above `+1e-12` mapped to BUY, below `-1e-12` mapped to SELL, and the
  inclusive tie band consumed flat;
- exactly one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1` D1 backtest setfile;
- one frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 3,000-point entry
  spread ceiling;
- both current news axes and legacy news OFF, framework Friday close OFF,
  next-month renewal, and a 35-day stale repair; and
- deterministic reference fixtures, card lint, strict compile, registry,
  resolver, setfile, and static Q01 validation before Q02 handoff.

No current-month OHLC/volume, mean or iterative fallback, favorable-month
selection, recent trend/return, storage, inventory, weather, event, curve,
volume, volatility signal, oscillator, external runtime input, retry,
scale-in, grid, martingale, hedge, pyramid, optimization surface, or
after-result rescue is approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one `RISK_FIXED`
backtest setfile, strict Q01, and one paced target-only Q02 enqueue only if the
exact-path tester count and host CPU are below the governed ceilings. It does
not authorize a manual tester dispatch or tester control.

Expected cadence is approximately ten to twelve completed positions per full
post-warm-up year. Q02 must retire on zero trades, fewer than five/year,
nonpositive governed economics, wrong endpoints, current-month leakage,
invalid sample, incorrect median/sign, fallback estimator, repeated entry,
wrong lifecycle, nondeterminism, invalid risk mode, or insufficient history.
Q09 alone may establish realized portfolio correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles,
AutoTrading, `T_Live`, deploy or T_Live manifests, portfolio-gate edits,
portfolio admission, decorrelation claims, and correlation waivers.
