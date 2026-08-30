# G0 Decision — QM5_41228 WTI Same-Calendar Shortest-Half Midmean

Date: 2026-08-30

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval
`decisions/2026-08-30_wti_same_calendar_shorth5_source_approval.md` and the
complete candidate packet committed at `e47e02f84`.

Approved card:
`strategy-seeds/cards/approved/QM5_41228_wti-samecal-shorth5_card.md`.

## Identity

- EA ID: `QM5_41228`, pending atomic deterministic registry verification
- slug: `wti-samecal-shorth5`
- strategy ID: `KELOHARJU-MOP-WTI-SAMECAL-SHORTH5-2026_S01`
- source ID: `KELOHARJU-MOP-WTI-SAMECAL-SHORTH5-2026`
- host / slot 0: exact `XTIUSD.DWX`, D1, intended magic `412280000`
- mechanic: at each genuine normalized broker-month transition, reconstruct
  the exact prior five matching-calendar-month WTI returns, sort them, select
  the earliest narrowest adjacent three-value window, follow its arithmetic
  mean sign, and renew next month

## Gate Findings

- R1 `PASS_WITH_SHORTEST_HALF_AND_SINGLE_CFD_TRANSLATION_RISK`: two
  complete-read, DOI-bearing, peer-reviewed trading papers support recurring
  same-calendar commodity information, explicit WTI membership, own-return
  direction, and monthly renewal. An official NIST reference defines and
  limits the shortest-half midmean. The trading conjunction remains untested.
- R2 `PASS`: month clock, label normalization, exact endpoints, exact five
  years, ascending sort, three adjacent windows, full spans, strict earliest
  tie rule, selected-triplet divisor, epsilon, side, attempt, risk, stop,
  spread, and lifecycle are mechanical and locked.
- R3
  `PASS_WITH_FIVE_YEAR_WARMUP_SESSION_LABEL_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered 2017-2025 XTI D1 history and native MT5 state provide every
  runtime field. Warm-up, label, roll, financing, gap, and CFD-basis risks
  remain binding Q02 items.
- R4 `PASS`: deterministic timestamps, logarithms, finite arithmetic,
  sorting, comparisons, and V5 execution plumbing only; no trained signal,
  prohibited runtime feed, grid, martingale, scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_samecal_shorth5_preallocation_dedup_20260830.json`,
SHA-256
`1746429DEBD16310E7E5A7A55311DC447CF751EF8D65EF30A1FDEC6A951C4F94`,
found no exact identity across 4,727 registry identities, 1,365 cards, and 45
Strategy Wiki nodes. Its one fuzzy result is the expected raw-mean family
neighbor `QM5_20099_wti-samecal`.

- On sorted `[-0.20,-0.19,+0.001,+0.20,+0.21]`, this card sells from the
  shortest-three location `-0.1296666667`; the raw mean, individual median,
  fixed middle-three trim, and endpoint-Winsor mean are all positive.
- On exact-binary
  `[-0.03125,-0.015625,0,+0.015625,+0.03125]`, all spans tie. This card's
  earliest-window rule sells from `-0.015625`, while raw mean and median are
  flat.
- `QM5_41227_wti-samecal-blockmed` preserves year order and takes an even
  median of chronological rolling pair means. This card sorts away year order
  and selects one data-dependent compact interval in return space.
- Hodges-Lehmann, Huber, signed-rank, t-score, sign-score, recency-weight,
  regime-shift, contiguous-month, and within-month siblings use different
  state objects or economic clocks.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_SHORTEST_THREE_MIDMEAN_SIGN_MONTHLY_SLEEVE`.

## Approved Build Contract

Development may build exactly the approved card after deterministic registry
and magic verification with:

- exact `XTIUSD.DWX` D1 slot 0 under registered magic `412280000`;
- native same-day or one uniform `+1` energy-label normalization, with the
  normalized current D1 date equal to broker date;
- first genuine broker-month transition and one persistent `yyyymm` attempt
  recorded before every fallible entry gate;
- exact years `Y-5..Y-1`, strict adjacent calendar endpoints, later
  confirming bars, no substitute year, and no current-month data;
- ascending sort of exactly five returns, three spans `x2-x0`, `x3-x1`, and
  `x4-x2`, the earliest minimum-span index, and exact selected-triplet mean;
- location above `+1e-12` mapped to buy, below `-1e-12` mapped to sell, and
  the inclusive tie band consumed flat;
- exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` in one D1
  backtest setfile;
- a frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
  ceiling;
- both current news axes and legacy news OFF, framework Friday close OFF,
  malformed-position repair, next-month renewal, and a 40-day survivor guard;
  and
- deterministic reference fixtures, card lint, strict compile, registry,
  resolver, setfile, and static Q01 validation before Q02 handoff.

No raw-mean, median, trim, winsor, midpoint, tied-window blend, pseudomedian,
iterative robust-location, sign-vote, recency-weight, regime-gate, current-
month price, fixed-month direction, recent trend, curve, storage, inventory,
event, volume, optimizer output, trained signal, external runtime input,
retry, scale-in, grid, martingale, pyramid, or after-result rescue is approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one `RISK_FIXED`
backtest setfile, strict Q01, and one paced Q02 enqueue only if the exact-path
tester count and whole-host CPU are below the governed ceilings. It does not
authorize a manual tester dispatch or tester control.

Q02 must retire on zero positions, fewer than five in any full post-warm-up
year, nonpositive governed economics, wrong endpoints, missing exact years,
wrong sort/window/span/tie/divisor, current-month leakage, wrong side,
repeated entry, missing stop, wrong lifecycle, nondeterminism, invalid risk
mode, or insufficient history. Q09 alone may establish realized portfolio
correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
