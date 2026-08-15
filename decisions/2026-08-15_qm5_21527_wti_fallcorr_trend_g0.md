# QM5_21527 WTI Falling Equity-Correlation Trend — G0 Decision

Date: 2026-08-15

Decision: `APPROVED` for one bounded V5 Strategy Card, one branch-only
non-live build, strict Q01 validation, and one paced non-live Q02 enqueue.
This decision does not authorize a manual tester dispatch.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch and durably recorded before extraction in
`decisions/2026-08-15_wti_fallcorr_trend_source_approval.md` at commit
`0b95083c3`.

## Candidate

- EA: `QM5_21527_wti-fallcorr-tr`
- Strategy ID: `MOP-SILV-WTI-FALLCORR-2026_S01`
- Source ID: `MOP-SILV-WTI-FALLCORR-2026`
- host/traded symbol/slot/magic: `XTIUSD.DWX` / 0 / `215270000`
- read-only factor: `SP500.DWX`, D1, no magic or order path
- driver: exact twelve-completed-month WTI return sign admitted only after
  absolute WTI/SP500 Pearson correlation falls across adjacent disjoint
  63-return blocks
- lifecycle: one consumed monthly attempt, one fixed-risk WTI position,
  frozen `3.5 * ATR(20,D1)` stop, monthly replacement, forty-day stale
  guard, and fixed spread cap

## Source Decision

The approved composite packet is
`strategy-seeds/sources/MOP-SILV-WTI-FALLCORR-2026/source.md`. It binds the
complete governed MOP trend extraction to the complete Silvennoinen-Thorp
commodity/equity correlation-dynamics review.

MOP supplies WTI membership, twelve-month own-return-sign trend, and monthly
renewal. Silvennoinen-Thorp establish time-varying WTI/equity integration and
weaker diversification in higher-integration states. They do not test this
trading conjunction; their WTI/S&P transition is crisis-timed rather than
VIX-driven, and their fitted weekly futures model is not the raw D1 proxy.

No source efficacy, WTI-only alpha, threshold, density, cost, CFD equivalence,
decorrelation, or portfolio result transfers.

## Locked Rule

On the first processed WTI D1 bar after each broker-month transition:

1. Close malformed or prior-month owned exposure before entry-only gates.
2. Persist the new month as consumed before every fallible gate; never retry.
3. Reconstruct exactly thirteen consecutive completed WTI month-end closes
   and verify the endpoint and chained twelve-month log returns agree within
   `1e-10`.
4. Intersect completed WTI and SP500 D1 closes by exact timestamp and retain
   exactly 127 newest common closes, with a ten-calendar-day freshness cap.
5. Form 126 simple returns and split them into newest and immediately
   preceding 63-return blocks, sharing no return observation.
6. Compute block-local sample Pearson correlations with finite positive
   variance. Admit only when
   `abs(rho_recent) + 1e-12 < abs(rho_preceding)`.
7. Buy WTI for a strictly positive twelve-month return and sell WTI for a
   strictly negative return. SP500 is read-only.
8. Open at most one WTI position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, a frozen `3.5 * ATR(20,D1)` hard stop, no target,
   and a 1,500-point spread cap.
9. Close before monthly replacement, after forty calendar days, or on
   malformed owned state. Friday close and all news modes are OFF.

The carrier, month-end support, return types, timestamp intersection, two
disjoint blocks, Pearson estimator, absolute comparison, strict tolerance,
WTI-only order path, risk, stop, and lifecycle are locked.

## Reputable-Source Criteria

- R1 `PASS_FOR_DISCLOSED_PROXY`: two peer-reviewed complete-read sources;
  the untested conjunction and adverse correlation evidence are explicit.
- R2 `PASS`: fixed data counts, estimators, direction, attempt, risk, stop,
  spread, and exit.
- R3 `PASS_FOR_DISCLOSED_PROXY`: registered WTI/SP500 D1 history; SP500 is
  read-only and futures/index fidelity is not assumed.
- R4 `PASS`: deterministic native arithmetic only, without trained output,
  prohibited signal indicator, external feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,499 registry rows and 595 root-card files and
returned `CLEAN`. Manual review separates WTI/XNG one-block correlation
gating (`QM5_21516`), SP500 conditional downside-beta gating
(`QM5_21522`), WTI/gold sign divergence (`QM5_21523`), two-leg energy
DownBeta (`QM5_13203`), oil-to-equity trading (`QM5_1178` and
`QM5_12397`), unconditional WTI TSMOM, and the incumbent XNG oscillator.

Verdict:
`CLEAN_WTI_TREND_FALLING_ABSOLUTE_EQUITY_CORRELATION_AFTER_FAMILY_REVIEW`.

## Allocation And Kill Boundary

The next deterministic registry allocation reserves `QM5_21527`. Expected
cadence is five to seven completed positions per full post-warm-up year; Q02
must retire on zero trades, below five/year, or nonpositive governed
economics. Q09 alone may establish realized book correlation.

## Safety Boundary

Create exactly one XTIUSD.DWX D1 backtest setfile with
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This
decision excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio-gate edits; portfolio admission; and correlation waivers. Enqueue
once, but do not dispatch or control a tester when the factory resource
ceiling is binding.

