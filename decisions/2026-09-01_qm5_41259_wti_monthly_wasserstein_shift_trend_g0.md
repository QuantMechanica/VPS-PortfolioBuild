# QM5_41259 WTI Monthly Wasserstein-1 Shift Trend - G0 Decision

- Date: 2026-09-01
- Owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- Build authorization: branch-only Q01 plus one paced non-live Q02 enqueue
- Portfolio/live authorization: none

## Identity

- EA ID: `QM5_41259`
- Slug: `wti-mwasser-shift-tr`
- Strategy ID: `AI-CODEX-WTI-MWASSER-20260901_S01`
- Source ID: `AI-CODEX-WTI-MWASSER-20260901`
- Host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- Intended magic after governed allocation: `412590000`

The atomic registry reservation is present in
`framework/registry/ea_id_registry.csv` and binds this identity before magic
allocation.

## Source preflight

Source approval was committed first at `f87ed68648` in
`decisions/2026-09-01_wti_monthly_wasserstein_shift_trend_source_approval.md`.
The bounded record is
`strategy-seeds/sources/AI-CODEX-WTI-MWASSER-20260901/source.md`.

The source chain contains complete governed peer-reviewed WTI evidence, a
public Wasserstein two-sample paper, pinned official SciPy documentation and
source, retrieval hashes, and an explicit boundary: no source reports this
trading conjunction or a performance result.

## Mechanic locked at G0

At the first tradable D1 bar of a genuine new broker month, reconstruct
thirteen consecutive completed month-end WTI closes and twelve adjacent log
returns. Split them into fixed old/recent blocks of six. Sort each block and
compute the equal-weight empirical Wasserstein-1 distance as the mean of six
absolute sorted-pair differences. Enumerate every one of 924 six-label
assignments and qualify only when the inclusive upper tail is at most 554 and
`5*tail_count<=3*assignment_count`. Continue the sign of the recent-minus-old
six-value median difference for one month.

One month is consumed before any fallible gate. Use fixed USD 1,000 backtest
risk, a frozen `3.5*ATR(20,D1)` hard stop, no target, a 1,500-point spread
ceiling, next-month exit, and forty-calendar-day stale repair. No current-
month price enters the signal.

## Frequency preflight

The exhaustive equally spaced reference has 540 qualifying label states out
of 924, or `12*540/924 = 7.012987...` decisions/year before execution gates.
Squared and exponential spacing fixtures remain near 6.9-7.1/year. The design
therefore clears the five/year prior without a market test. Q02 must still
prove at least five completed positions in every full scored year or the EA is
retired.

## Dedup adjudication

`artifacts/qm5_wti_mwasser_shift_tr_preallocation_dedup_20260901.json` found no
exact identity across 4,758 registry rows, 1,395 cards, and 45 Wiki nodes. The
three fuzzy neighbors are manually resolved:

- `QM5_41258` uses energy distance over all cross and within-block pairs;
- `QM5_41255` uses pooled-rank integrated squared ECDF paths;
- `QM5_41250` uses within-block median absolute deviation expansion.

This card instead uses monotone sorted-quantile transport and retains return
spacing. Fixed squared and exponential fixtures produce both disagreement
directions against energy distance and integrated ECDF. The candidate is not
an alias or a parameter variant.

## G0 criteria

| Gate | Verdict | Reason |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Reputable WTI and statistical sources, pinned implementation evidence, hashes, and explicit no-alpha boundary. |
| R2 | `PASS` | Month clock, endpoints, returns, sorting, W1 formula, 924 assignments, tolerance, tail, side, attempt, risk, stop, spread, and exits are fully mechanical. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_RISK` | Registered native WTI D1 supplies every runtime input; roll, basis, gap, financing, and broker-label risks remain. |
| R4 | `PASS` | Native deterministic arithmetic/state only; no ML, banned indicator, optimizer output, grid, martingale, or external runtime feed. |

## Decision and boundaries

`G0 APPROVED` for
`strategy-seeds/cards/approved/QM5_41259_wti-mwasser-shift-tr_card.md`.
Approval authorizes deterministic magic allocation, card-faithful
implementation, reference tests, strict Q01 compilation, one canonical
`RISK_FIXED=1000` backtest setfile, and one paced Q02 enqueue if CPU admission
permits.

It does not approve profitability, robustness, decorrelation, portfolio
admission, a correlation waiver, optimization, manual tester launches,
T_Live, AutoTrading, deployment, any live manifest, or gate changes. Q09 alone
may measure realized overlap.
