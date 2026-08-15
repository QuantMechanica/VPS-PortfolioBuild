# WTI Falling Equity-Correlation Trend — Source Approval

Date: 2026-08-15

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Q02 enqueue is not authority to dispatch a
manual tester or exceed the active factory resource ceiling.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch. The mission requests one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio mutations.

## Candidate Identity

- proposed slug: `wti-fallcorr-tr`
- proposed strategy ID: `MOP-SILV-WTI-FALLCORR-2026_S01`
- proposed source ID: `MOP-SILV-WTI-FALLCORR-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1
- read-only factor: `SP500.DWX`, D1
- decision clock: first processed WTI D1 bar after a broker-month transition
- signal: follow the exact twelve-completed-month WTI return sign only while
  absolute WTI/SP500 correlation is falling across two adjacent disjoint
  63-return blocks

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The complete governed packet
`strategy-seeds/sources/MOP-SILV-WTI-FALLCORR-2026/source.md` was read before
this decision. It binds:

1. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`, through the governed complete-paper
   extraction `strategy-seeds/sources/MOP-TSMOM-2012/source.md`.
2. Silvennoinen and Thorp (2013), "Financialization, Crisis and Commodity
   Correlation Dynamics," *Journal of International Financial Markets,
   Institutions and Money* 24, 42-65, DOI
   `10.1016/j.intfin.2012.11.007`. The complete 46-page institutional
   preprint was read; retrieved PDF SHA-256
   `55CEAFBD91FB9484474BD8AA2710286F2ED3DC3ECE46A64F6634D64F5C5568AC`.

MOP supplies WTI membership, twelve-month own-return-sign trend, and monthly
renewal. Silvennoinen-Thorp supply evidence that WTI/equity return
correlation is time-varying and that commodity diversification can weaken as
financial integration rises. Their WTI/S&P preferred transition is crisis-
timed, not VIX-driven, and they do not test a trading rule.

The raw-D1 Pearson estimator, two disjoint blocks, strict falling-absolute-
correlation condition, continuous-CFD mapping, WTI-only execution, risk,
stop, spread cap, and restart lifecycle are disclosed QM translations. No
source efficacy, WTI-only alpha, threshold, density, cost, neutrality,
decorrelation, or portfolio result transfers.

## Locked Mechanic

On the first processed `XTIUSD.DWX` D1 bar of every new broker month:

1. Persist the month as consumed before history, signal, news, spread, quote,
   sizing, or order gates. Never retry the same month.
2. Reconstruct exactly thirteen consecutive completed broker-month-end WTI
   closes. Require the endpoint and chained calculations of the exact twelve-
   month log return to agree within `1e-10`.
3. Intersect completed positive finite WTI and read-only SP500 D1 closes by
   exact timestamp. Retain exactly 127 newest common closes, with the newest
   no more than ten calendar days stale.
4. Form exactly 126 simple returns. The recent block is returns `0..62`; the
   preceding block is returns `63..125`. No return observation overlaps.
5. Compute sample Pearson correlation in each block from its own WTI and
   SP500 sample means. Require positive finite variance for both series.
6. Admit only when `abs(rho_recent) + 1e-12 < abs(rho_preceding)`. Equality,
   invalid state, or non-decline consumes the month flat.
7. Buy WTI for a strictly positive twelve-month return and sell WTI for a
   strictly negative return. Exact zero consumes the month flat. SP500 is
   read-only and may never receive a magic, size, or order.
8. Open at most one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, a
   frozen `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread
   ceiling. Signal or correlation magnitude never scales risk.
9. Close before the next monthly replacement, after forty calendar days, or
   when owned exposure is malformed. Friday close and both news axes are OFF
   for the source-aligned monthly hold.

The carrier, completed-month support, trend sign, exact timestamp
intersection, return type, two 63-return blocks, absolute correlation
comparison, strict tolerance, WTI-only order path, risk, stop, and lifecycle
are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_FOR_DISCLOSED_PROXY`: two named peer-reviewed sources with
  complete-review evidence; the untested conjunction is explicit.
- R2 `PASS`: history counts, estimators, direction, attempt, risk, stop,
  spread, and exit are deterministic and locked before Q02.
- R3 `PASS`: registered XTI/SP500 D1 routes supply every runtime input;
  SP500 is read-only.
- R4 `PASS`: deterministic native arithmetic only; no trained output, banned
  signal indicator, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,499 EA-registry rows and 595 root-card files
and returned `CLEAN` with no exact or fuzzy match. Manual review separates:

- `QM5_21516_wti-decoup-trend`: one WTI/XNG block versus a fixed 0.30 cap;
- `QM5_21522_wti-lowdb-trend`: conditional downside-beta slopes over two
  252-return blocks rather than all-row Pearson correlation;
- `QM5_21523_wti-xau-div-tr`: WTI/gold sign disagreement, no correlation;
- `QM5_13203_energy-downbeta`: traded XTI/XNG cross-sectional pair; and
- `QM5_1178`/`QM5_12397`: oil signals that order equity, not WTI.

Verdict:
`CLEAN_WTI_TREND_FALLING_ABSOLUTE_EQUITY_CORRELATION_AFTER_FAMILY_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately five to seven completed positions per
full post-warm-up year. Q02 must retire on zero trades, below five/year, or
nonpositive governed economics. Q09 alone may establish realized correlation
with the certified book. The entry-state statistic is not proof of portfolio
decorrelation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02
may be enqueued once. If the factory resource ceiling is binding, do not
dispatch, reserve, stop, reap, reprioritize, or otherwise control a tester.
