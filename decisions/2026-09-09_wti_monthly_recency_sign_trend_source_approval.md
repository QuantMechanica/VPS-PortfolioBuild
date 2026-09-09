# WTI Monthly Recency-Sign Trend — Source Approval

- Date: 2026-09-09
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Proposed slug: `wti-mrecency-sign-tr`
- Strategy ID: `AI-CODEX-WTI-MRECENCY-SIGN-TREND-20260909_S01`
- Dedup receipt: `artifacts/qm5_wti_mrecency_sign_tr_preallocation_dedup_20260909.json`

## Authority And Source Quality

The current explicit OWNER pacer mission authorizes one new reputable-source,
structural, low-frequency commodity/energy card and branch-only build, and
explicitly permits a direct `XTIUSD` trend edge. The bounded extraction uses
the completely reviewed governed record
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` (SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`).
That record preserves the complete 23-page published-paper read and retrieval
identity for Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
Economics* 104(2), DOI `10.1016/j.jfineco.2011.11.003`. It documents monthly
own-return continuation through twelve lags and explicitly includes NYMEX WTI.

The paper does not prescribe fixed recency weights on return signs, a centered
score boundary, Darwinex continuous CFDs, fixed-dollar risk, ATR stops, or the
QM portfolio. Those are pre-result mechanization choices. No source return,
alpha, WTI-only result, density, cost, CFD equivalence, or correlation result
transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, consume the month before every fallible gate. Reconstruct thirteen
consecutive completed broker-month-end closes, oldest first, and calculate the
twelve adjacent log returns `r[i]=ln(C[i+1]/C[i])`.

Require every return finite and strictly outside `+/-1e-12`. Assign each
return only its sign and its fixed chronological weight `w[i]=i+1`, so the
oldest sign has weight one, the newest sign has weight twelve, and the total is
78. Define `S=sum(w[i]*sign(r[i]))`. BUY only when `S>=18`, SELL only when
`S<=-18`, and otherwise consume the month flat. Magnitude and magnitude rank
never enter the signal or risk.

Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one
frozen `3.5*ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
Close on the first tick in the next broker month; forty elapsed days is stale
repair only. Both news axes, legacy news, and Friday close are OFF in the
backtest preset but remain unpinned framework inputs.

Complete enumeration of `2^12=4,096` sign paths gives 2,124 paths with
`|S|>=18`, or 6.22265625 market-free states per twelve monthly attempts. This
is an activity prior, not a WTI probability or performance claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_RECENCY_SIGN_TRANSLATION_RISK`: peer-reviewed, complete-read
  WTI monthly-trend evidence supports a bounded test; the exact sign weighting
  and boundary remain untested.
- R2 `PASS`: month clock, endpoint order, returns, zero rule, fixed weights,
  total, centered score, inclusive boundary, side, attempt, risk, stop, spread,
  and lifecycle are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide every runtime input.
- R4 `PASS`: timestamps, logarithms, sign comparisons, fixed integer
  arithmetic, ATR risk plumbing, and execution state only; no trained output,
  banned signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Duplicate Decision

The canonical checker scanned 4,880 registry identities, 1,491 card files,
and 45 Strategy Wiki nodes. It found no exact identity and one expected fuzzy
match, `QM5_41273_wti-msigned-rank-tr`, at score 0.53.

Manual review separates the three nearest families:

- `QM5_41273` discards chronology when it ranks absolute return magnitudes,
  then weights each sign by magnitude rank. This candidate never sorts and
  weights each sign only by its fixed age. If only the newest return is
  positive, this candidate scores `-54`, while assigning that newest return
  absolute rank twelve makes `QM5_41273` score `-54`; but moving the same
  positive sign to the oldest month changes this candidate to `-76` while the
  signed-rank score is unchanged. Chronology is load-bearing here.
- `QM5_20278_wti-linw-mom` multiplies each complete return magnitude by the
  same weights `1..12` and trades every nonzero weighted sum. This candidate
  replaces magnitudes with `+1/-1` and requires `|S|>=18`, so one arbitrarily
  large old return cannot dominate eleven newer signs.
- `QM5_13150_wti-signmom` uses an equal-weight positive-month fraction and a
  0.40 boundary; this candidate uses fixed chronological weights and a
  symmetric centered boundary.

Verdict:
`DISTINCT_WTI_TWELVE_CONTIGUOUS_FIXED_CHRONOLOGICAL_RECENCY_SIGN_SCORE_ABS18_CONTINUATION`.

## Authorization Boundary

This approval permits the bounded source packet, one approved card and G0
record, deterministic identity/magic allocation, branch-only non-live V5
build, mandatory PACER input-pin audit, strict Q01, and one paced Q02 enqueue
below the hard CPU ceiling. It excludes manual backtests, optimization,
portfolio admission, correlation waivers, portfolio-gate changes, deployment,
live manifests, `T_Live`, AutoTrading, and live use.
