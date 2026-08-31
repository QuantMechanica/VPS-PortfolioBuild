# WTI Centered-Sum-of-Squares Variance-Shift Trend - Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded direct-WTI structural-trend
Strategy Card, deterministic EA-ID and one-slot magic allocation, one
branch-only non-live build, strict Q01 validation, and one paced Q02 enqueue
only while the governed whole-host CPU ceiling remains clear. This decision
does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG carrier set, reputable-source criteria, a `RISK_FIXED`
backtest preset, committed non-duplicate work, and one Q02 handoff. It forbids
live, AutoTrading, portfolio-gate, and `T_Live` manifest mutations.

## Candidate identity

- proposed slug: `wti-css-volshift-tr`
- proposed strategy ID: `AI-CODEX-WTI-CSSVOLSHIFT-20260831_S01`
- source ID: `AI-CODEX-WTI-CSSVOLSHIFT-20260831`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: a one-pass centered cumulative sum of squares over 252 completed
  D1 log returns, followed by the sign of the return after the dominant
  interior variance-shift location
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Single governed source and supporting evidence

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-WTI-CSSVOLSHIFT-20260831/source.md`.
`processes/qb_reputable_source_criteria.md` expressly permits an AI-originated
strategy when its prompt/output trail, claim boundary, and source ID are
durable.

Supporting evidence is bounded to:

- a complete read of Inclan and Tiao (1994), *Use of Cumulative Sums of
  Squares for Retrospective Detection of Changes of Variance*, *Journal of
  the American Statistical Association* 89(427), 913-923, DOI
  `10.1080/01621459.1994.10476824`, supporting the centered cumulative-sum-of-
  squares statistic, change-location maximum, Brownian-bridge normalization,
  and the finite-sample quantile used as the pre-data activity boundary; and
- the existing complete governed read of Moskowitz, Ooi, and Pedersen (2012),
  *Time Series Momentum*, *Journal of Financial Economics* 104(2), 228-250,
  DOI `10.1016/j.jfineco.2011.11.003`, supporting NYMEX WTI, monthly decisions,
  and own-return continuation over one through twelve months.

The variance statistic transfers from the statistical paper. The WTI carrier
and continuation direction transfer from the trading paper. Their conjunction,
the rolling-window centering, interior split guard, threshold, risk, stop,
spread, and lifecycle are disclosed pre-result QM choices. Retrieval evidence
is `strategy-seeds/sources/AI-CODEX-WTI-CSSVOLSHIFT-20260831/retrieval_route_20260831.json`.

## Locked mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized month key before history, signal, news, spread,
   quote, stop, sizing, margin, or order checks. Never retry the same month.
2. Reconstruct 253 strictly chronological completed WTI D1 closes and form
   exactly 252 adjacent log returns, excluding the current D1 bar.
3. Subtract the arithmetic mean of all 252 returns. Square the centered
   returns. Let `C_k` be their cumulative sum through observation `k`, and
   let `C_T` be the total with `T=252`.
4. For every interior split `k=21..231`, compute
   `D_k=C_k/C_T-k/T` and `M_k=sqrt(T/2)*abs(D_k)`. Select the largest `M_k`;
   an exact tie selects the most recent `k`.
5. Consume flat if `C_T<=1e-16`, any arithmetic is nonfinite, or the maximum
   score is below `0.63`. The inclusive `0.63` boundary is the paper's
   reported 25th-percentile finite-sample value for both `T=200` and `T=300`;
   it is an activity boundary, not a significance claim.
6. Sum the uncentered raw returns strictly after the selected split. Buy when
   that post-shift return is positive, sell when negative, and consume flat on
   exact zero.
7. Open at most one exact-WTI slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` broker hard stop, no target, and a 1,500-point spread cap.
8. Close at the next genuine month or after forty calendar days. Both news
   axes and Friday close remain off so the month hold is not rewritten.

The 21-observation interior guard is a declared trading adaptation that keeps
at least one trading month on both sides of the estimated variance shift. The
paper scans all split points and does not prescribe a trading direction.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_BOUNDARY`: exactly one durable AI source ID, one
  complete-read peer-reviewed statistical paper, and one complete governed
  peer-reviewed WTI trading packet.
- R2 `PASS`: month clock, data window, mean centering, squares, cumulative
  sums, split range, normalization, tie rule, threshold, side, attempt, fixed
  risk, hard stop, spread, and exits are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 state provide all runtime inputs; roll,
  financing, basis, gap, and broker-month-label risks remain.
- R4 `PASS`: completed prices, logarithms, finite arithmetic, comparisons,
  ATR risk control, and native position/deal state only; no ML, trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-duplicate decision

The corrected-root canonical receipt
`artifacts/qm5_wti_css_volshift_tr_preallocation_dedup_20260831.json` scanned
4,751 registry identities, 1,389 cards, and 45 Strategy Wiki nodes. It found
no exact or fuzzy match.

Manual family review additionally separates this candidate from:

- `QM5_41245`, which searches a centered cumulative sum of **monthly return
  levels** for a mean shift; this candidate searches cumulative **squared
  centered daily returns** for a variance shift and takes direction only from
  the post-shift raw return;
- `QM5_41250`, which tests old-versus-recent monthly MAD expansion across 924
  label permutations; this candidate estimates an interior temporal break
  location from 252 ordered daily squared returns and performs no permutation;
- `QM5_20298`, which ranks monthly volatility-of-volatility against a fixed
  historical window; this candidate uses the source-defined centered CSS path
  and dominant change location, not a volatility rank; and
- certified `QM5_12567`, a long-only two-day XNG oscillator pullback.

Verdict:
`DISTINCT_WTI_MONTHLY_252_D1_CENTERED_CUMULATIVE_SQUARES_DOMINANT_INTERIOR_VARIANCE_SHIFT_POST_BREAK_RETURN_CONTINUATION`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five
completed positions in any full scored post-warm-up year, nonpositive governed
economics, current-bar leakage, wrong centering or square path, wrong split or
tie orientation, boundary error, missing stop, invalid risk mode, malformed
lifecycle, or nondeterminism. Failure may not be rescued by changing the
window, split guard, threshold, direction, stop, or hold.

WTI supplies physical crude-oil exposure absent from the certified book, but
this approval does not assert independence. Q09 alone may evaluate overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or live
manifests; portfolio-gate changes; portfolio admission; decorrelation claims;
and correlation waivers.
