# WTI Monthly Wasserstein-1 Shift Trend - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded direct-WTI structural trend hypothesis, one Strategy Card,
  one branch build, strict Q01, and one paced non-live Q02 enqueue
- Proposed strategy ID: `AI-CODEX-WTI-MWASSER-20260901_S01`
- Source ID: `AI-CODEX-WTI-MWASSER-20260901`

## Authority and ordering

The current explicit OWNER mission authorizes one new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG book, identifies direct WTI trend/seasonality as an eligible
route, requires reputable-source criteria and fixed-risk backtesting, and
requests Q02 enqueue. This durable decision approves the bounded source before
Strategy Card extraction. It does not pre-approve economics, robustness,
decorrelation, portfolio admission, deployment, or live use.

## Approved source record

The complete bounded source is
`strategy-seeds/sources/AI-CODEX-WTI-MWASSER-20260901/source.md`.
Its supporting evidence is:

1. Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`; complete-read governed packet
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
2. Ramdas, Garcia, and Cuturi (2015), *On Wasserstein Two Sample Testing and
   Related Families of Nonparametric Tests*, arXiv `1509.02237`; public PDF
   retrieval and SHA-256 receipt in
   `strategy-seeds/sources/AI-CODEX-WTI-MWASSER-20260901/retrieval_route_ramdas_wasserstein_20260901.json`.
3. SciPy 1.13.1 official `wasserstein_distance` documentation and source,
   pinned at commit `44e4ebaac992fde33f04638b99629d23973cb9b2`; blob and
   SHA-256 receipt in
   `strategy-seeds/sources/AI-CODEX-WTI-MWASSER-20260901/retrieval_route_scipy_wasserstein_20260901.json`.

The WTI paper supports carrier, monthly cadence, and own-return continuation
only. The method sources support one-dimensional Wasserstein comparison and
the quantile representation only. The trading conjunction is disclosed QM
synthesis fixed before market testing.

## Approved bounded extraction

At the first tradable D1 bar of a genuine broker month transition:

- reconstruct thirteen consecutive completed WTI month-end closes and twelve
  adjacent log returns, excluding every current-month price;
- compare fixed old/recent blocks of six by sorting each and computing the
  equal-weight empirical Wasserstein-1 distance as the mean of six absolute
  sorted-pair differences;
- enumerate all 924 six-label assignments and require the inclusive exact
  upper tail to satisfy both `tail_count<=554` and
  `5*tail_count<=3*assignment_count`;
- continue the sign of the recent-minus-old six-value median difference;
- consume one attempt per broker month before fallible gates;
- use exact `XTIUSD.DWX`, D1, fixed-risk USD 1,000, frozen
  `3.5*ATR(20,D1)` hard stop, no target, 1,500-point spread ceiling, next-month
  exit, and forty-calendar-day stale repair.

The 60% tail is an activity boundary, not a p-value or statistical
significance claim. The locked exhaustive prior yields about 7.01 annual
decisions on the equally spaced reference and therefore clears the five/year
design floor before execution gates. Q02 must prove realized activity.

## Reputable-source criteria

| Gate | Verdict | Basis |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_PRIMARY_METHOD_EVIDENCE` | Complete governed peer-reviewed WTI record, public method paper, pinned official SciPy docs/source, hashes, explicit translation boundary. |
| R2 | `PASS` | Exact clock, endpoints, returns, sort, W1 arithmetic, all 924 assignments, inclusive boundary, side, attempt, risk, stop, spread, and lifecycle. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_RISK` | Registered native `XTIUSD.DWX` D1 supplies all runtime inputs; roll/basis/gap/label risks remain. |
| R4 | `PASS` | Deterministic native arithmetic and framework state only; no ML, banned indicator, external runtime feed, grid, or martingale. |

## Dedup decision

The fail-closed canonical check
`artifacts/qm5_wti_mwasser_shift_tr_preallocation_dedup_20260901.json` found no
exact identity and three expected fuzzy family neighbors. Manual review
resolves them as distinct:

- `QM5_41258`: energy distance uses all cross and within-block pairs;
- `QM5_41255`: integrated ECDF uses pooled rank membership only;
- `QM5_41250`: robust scale uses within-block MAD only.

Wasserstein-1 uses monotone sorted quantile coupling and preserves value
spacing. Squared and exponentially spaced fixed fixtures produce both
Wasserstein/energy disagreement directions and both Wasserstein/integrated-
ECDF disagreement directions. The candidate is not an alias or parameter
variant of any fuzzy neighbor.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_FIXED_SIX_BY_SIX_WASSERSTEIN_ONE_SORTED_QUANTILE_DISTANCE_EXACT_PERMUTATION_SHIFT_CONTINUATION`.

## Kill and safety boundaries

Retire on a failed reference fixture, non-deterministic enumeration, zero
positions, fewer than five completed positions in any full scored year, or
failed governed economics. Q09 alone can establish correlation; there is no
waiver or portfolio promise.

Authorized after card G0 and registry gates: branch-only EA build, reference
tests, strict Q01 compile, one canonical `RISK_FIXED=1000` D1 backtest setfile,
and one paced Q02 enqueue if CPU admission permits. Excluded: manual tester
launch, optimization, live/demo/shadow/stress presets, T_Live, AutoTrading,
deploy/live manifest, portfolio-gate changes, admission, or threshold changes.
