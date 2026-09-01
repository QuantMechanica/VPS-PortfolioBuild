# WTI Monthly Ansari-Bradley Scale Trend - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded WTI structural-trend hypothesis, one Strategy Card, one
  branch build, strict Q01, and one paced non-live Q02 enqueue
- Proposed slug: `wti-mab-scale-tr`
- Proposed strategy ID: `AI-CODEX-WTI-MAB-SCALE-20260901_S01`
- Source ID: `AI-CODEX-WTI-MAB-SCALE-20260901`

## Authority and ordering

The current explicit OWNER mission authorizes one new reputable-source,
structural low-frequency commodity sleeve outside the certified directional
XAU/SP500/NDX/XNG book, identifies direct WTI trend or seasonality as an
eligible route, requires fixed-risk backtesting, and requests Q02 enqueue.
This durable record approves the bounded source before Strategy Card
extraction. It does not pre-approve activity, economics, robustness, realized
decorrelation, portfolio admission, deployment, or live use.

## Approved source record

The complete bounded source is
`strategy-seeds/sources/AI-CODEX-WTI-MAB-SCALE-20260901/source.md`. Its
supporting evidence is:

1. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`; complete-read governed packet
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.
2. Ansari and Bradley (1960), "Rank-Sum Tests for Dispersions," *The Annals
   of Mathematical Statistics* 31(4), 1174-1189, DOI
   `10.1214/aoms/1177705688`; authoritative Crossref metadata and a recorded
   Project Euclid access block in
   `strategy-seeds/sources/AI-CODEX-WTI-MAB-SCALE-20260901/retrieval_route_ansari_bradley_20260901.json`.
3. SciPy 1.13.1 official `scipy.stats.ansari` documentation and pinned source
   at commit `44e4ebaac992fde33f04638b99629d23973cb9b2`; complete bounded read
   receipt in
   `strategy-seeds/sources/AI-CODEX-WTI-MAB-SCALE-20260901/retrieval_route_scipy_ansari_20260901.json`.

The WTI paper supports only the carrier, monthly clock, and own-return
continuation. The statistical records support only the symmetric end-rank
score, scale interpretation, direction of the score, and finite no-tie exact
route. The fixed sample, loose activity boundary, continuation conjunction,
CFD translation, risk, and lifecycle are pre-result QM synthesis.

## Approved bounded extraction

At the first tradable D1 tick of a genuine broker-month transition:

- reconstruct thirteen consecutive completed WTI month-end closes and twelve
  adjacent log returns, excluding every current-month price;
- retain fixed old/recent blocks of six and require all twelve returns to be
  pairwise distinct;
- rank the pooled returns and assign symmetric scores
  `1,2,3,4,5,6,6,5,4,3,2,1`;
- sum the six recent-label scores, enumerate all 924 fixed-size assignments,
  and require `A_recent<=21` plus an inclusive exact lower-tail count no
  greater than 522;
- continue the sign of the actual recent six-return cumulative log return;
- consume one attempt per broker month before fallible gates; and
- use exact `XTIUSD.DWX`, D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
  `3.5*ATR(20,D1)` hard stop, no target, a 1,500-point spread ceiling,
  next-month exit, and forty-day stale repair.

The `522/924` boundary is an activity boundary, not a p-value or statistical-
significance claim. It yields 6.779 market-free strict-rank states per twelve
monthly attempts before cumulative-return and execution gates. Q02 must prove
realized activity and economics.

## Reputable-source criteria

| Gate | Verdict | Basis |
|---|---|---|
| R1 | `PASS_WITH_PRIMARY_SOFTWARE_AND_PAPER_ACCESS_BOUNDARY` | One durable AI source, complete peer-reviewed WTI evidence, authoritative method metadata, pinned official software documentation/source, hashes, and explicit access/translation limits. |
| R2 | `PASS` | Exact clock, endpoints, returns, ties, symmetric score, all 924 assignments, inclusive boundary, side, attempt, risk, stop, spread, and lifecycle. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native WTI D1 and MT5 state only; continuous-CFD roll, basis, financing, gap, and broker-month risks remain. |
| R4 | `PASS` | Deterministic native arithmetic and framework state only; no ML, banned signal indicator, external runtime feed, grid, or martingale. |

## Dedup decision

The fail-closed corrected-root receipt
`artifacts/qm5_wti_mab_scale_tr_preallocation_dedup_20260901.json`, SHA-256
`2A4F4D50F5B36A20BDCC3950C1A334615F2DEF38F42136C05EA422D4DF967E74`,
found no exact or fuzzy identity across 4,760 registry rows, 1,397 cards, and
45 Strategy Wiki nodes.

Manual review resolves the nearest families as distinct. `QM5_41250` uses
magnitude-sensitive within-block MAD differences and recalculates medians
under every permutation; this source uses only pooled symmetric ranks and a
fixed lower-tail distribution. `QM5_41252` uses 252 ordered daily returns and
a searched cumulative-square variance change; this source uses twelve monthly
returns, fixed labels, no squares, and no time-split search. `QM5_41257` uses
only upper-half membership; this source weights both pooled tails
symmetrically.

Fixed linear-rank fixtures give both disagreement directions versus
`QM5_41250`: recent ranks `{1,2,3,4,5,6}` qualify here at score/tail `21/522`
while MAD expansion is zero; recent ranks `{1,2,3,4,6,7}` are flat here at
`22/629` while MAD qualifies at tail 340.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_MONTHLY_FIXED_SIX_BY_SIX_ANSARI_BRADLEY_SYMMETRIC_END_RANK_EXACT_924_LOWER_TAIL522_CUMULATIVE_RETURN_CONTINUATION`.

## Kill and safety boundaries

Retire on a failed reference fixture, accepted pooled tie, wrong enumeration,
zero positions, fewer than five completed positions in any full post-warm-up
year, or failed governed economics. Q09 alone can establish correlation;
there is no waiver or portfolio promise.

Authorized after card G0 and registry gates: branch-only EA build, reference
tests, strict Q01 compile, one canonical `RISK_FIXED=1000` D1 backtest set,
and one paced Q02 enqueue if CPU admission permits. Excluded: manual tester
launch, optimization, live/demo/shadow/stress presets, `T_Live`, AutoTrading,
deploy/live manifest, portfolio-gate changes, portfolio admission,
correlation waiver, or terminal control.
