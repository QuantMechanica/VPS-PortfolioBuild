# XTI/XNG Monthly Spearman Ratio-Rank Reversion — Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue is not authority to
dispatch a manual tester or work above the active factory resource ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission permits one new market-neutral
or structural low-frequency commodity edge, requires reputable-source
criteria and `RISK_FIXED` backtests, and forbids live and portfolio-gate
mutations.

## Candidate Identity

- proposed slug: `xtixng-mspearman-rv`
- proposed strategy ID:
  `VILLAR-SPEARMAN-XTIXNG-MRANK-RV-2026_S01`
- proposed source ID: `VILLAR-SPEARMAN-XTIXNG-MRANK-RV-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1
- companion/traded slot 1: `XNGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a new broker month
- signal: fade an inclusive `abs(T)>=104` Spearman time-rank trend in thirteen
  consecutive synchronized completed month-end oil-minus-gas log ratios

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following governed packets were read completely before this decision:

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, SHA-256
   `4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`.
   It preserves complete reads of Villar-Joutz's U.S. EIA oil/gas report and
   Ramberg-Parsons' peer-reviewed *Energy Journal* article, including their
   weak-tie, regime-instability, and adverse evidence.
2. `strategy-seeds/sources/MOP-SPEARMAN-WTI-MRANK-TREND-2026/source.md`,
   SHA-256
   `38B53FD42A8E9CBA533957D5A376D8F8D4E5CA0F8EBB249D8464F761C8D2AB98`.
   It preserves Spearman's named journal record and the complete pinned R Core
   implementation and manual defining rho as correlation after rank
   transformation.
3. The exact bounded composite extraction is
   `strategy-seeds/sources/VILLAR-SPEARMAN-XTIXNG-MRANK-RV-2026/source.md`.

The original Spearman paper body is not represented as completely read. The
sources do not specify this statistic/carrier conjunction, horizon, threshold,
direction, continuous-CFD mapping, or trade. The synchronized sample,
contrarian mapping, fixed risk, stops, spread caps, atomicity, and lifecycle
are disclosed QM hypotheses. No source performance or portfolio claim
transfers.

## Locked Mechanic

On the first synchronized executable `XTIUSD.DWX`/`XNGUSD.DWX` D1 tick after
each genuine broker-month transition:

1. Consume broker `yyyymm` before every fallible gate and never retry it.
2. Reconstruct exactly thirteen consecutive synchronized completed broker-
   month endpoints ending in the immediately prior month; reject gaps,
   duplicate months, timestamp mismatch, stale or nonpositive endpoints.
3. Form chronological `s[i]=ln(XTI_close[i])-ln(XNG_close[i])`, assign strict
   ranks `R[i]`, and reject every ratio tie.
4. Calculate `D=sum((R[i]-(i+1))^2)` and `T=364-D`; prove the rank permutation,
   range, and parity invariants.
5. `T>=104` maps to SELL XTI / BUY XNG; `T<=-104` maps to BUY XTI / SELL XNG;
   the interior consumes the month flat.
6. Open at most one atomic opposite-leg package with equal target absolute USD
   notionals, aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`; split stop risk equally across `3.5*ATR(20,D1)` hard
   stops, attach no targets, and require no more than 20% notional mismatch.
7. Submit XTI then XNG and flatten all owned exposure after any partial or
   invalid package.
8. Close both legs at the next broker-month boundary, after forty calendar
   days, or immediately on any package-integrity defect.

Entry spread ceilings are 1,500 XTI points and 3,000 XNG points. Both news
axes, legacy news mode, and Friday close are OFF.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete government and
  peer-reviewed oil/gas evidence, named original Spearman record, and complete
  pinned R Core method files; exact conjunction disclosed untested.
- R2 `PASS`: clock, synchronization, ratio order, strict ranks, integer score,
  threshold, sides, attempt, aggregate risk, stops, atomicity, and exits lock.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  XTI/XNG D1 history and MT5 state supply every runtime input.
- R4 `PASS`: deterministic calendar/arithmetic/execution state only; no ML,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The canonical fail-closed checker authenticated 4,679 registry identities,
1,330 card files, and 45 Company Reference Strategy Wiki nodes and returned
`CLEAN` with no exact or fuzzy match. Evidence is
`artifacts/qm5_xtixng_mspearman_rv_preallocation_dedup_20260827.json`, SHA-256
`A4FF1F602456C41BC719B6357629E68388515AF4DDDE281F9A62C9AC0B668AC8`.

Manual review separates the candidate from the closest functional neighbors:

- `QM5_41173` follows Spearman on outright WTI; this candidate fades a
  synchronized XTI/XNG ratio and owns two atomic opposite legs.
- `QM5_41174` uses the same method on a precious-metal carrier; this candidate
  contains only energy legs and targets exposure different from the current
  directional index/metal/XNG book.
- `QM5_41175`, `QM5_41178`, and `QM5_41179` respectively use a searched
  change point, all 36 cross-block comparisons, and seven fixed paired signs.
  This candidate uses every ratio's displacement from its absolute time rank,
  with no split or pair-sign statistic.
- `QM5_20237` estimates a daily OLS residual and z-score; this candidate
  estimates no coefficient, center, scale, or residual.
- Certified `QM5_12567` is a two-day long-only XNG cumulative-RSI pullback,
  not a monthly paired-energy rank-reversion package.

Verdict:
`CLEAN_XTIXNG_MONTHLY_SPEARMAN_TIME_RATIO_RANK_T104_CONTRARIAN_BASKET`.

## Kill And Safety Boundary

Q02 retires below five completed packages in any full post-warm-up year, at
zero trades, with nonpositive governed economics, or on any mechanical or
determinism defect. Q09 alone owns realized portfolio correlation; market-
neutral style is not a neutrality or decorrelation claim.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after current
strict compile and review PASS. If the factory resource ceiling is binding,
do not dispatch, reserve, stop, reap, reprioritize, or otherwise control a
tester.
