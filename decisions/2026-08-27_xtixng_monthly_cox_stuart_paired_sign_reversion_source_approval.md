# XTI/XNG Monthly Cox-Stuart Paired-Sign Reversion — Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue is not authority to
dispatch a manual tester or work above the active factory resource ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission permits a new market-neutral or
structural low-frequency commodity edge, requires reputable-source criteria
and `RISK_FIXED` backtests, and forbids live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `xtixng-mcoxstuart-rv`
- proposed strategy ID:
  `VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026_S01`
- proposed source ID:
  `VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1
- companion/traded slot 1: `XNGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a new broker month
- signal: fade the direction supported by at least five of seven fixed
  Cox-Stuart half-sample comparisons across fourteen synchronized completed
  month-end oil-minus-gas log ratios

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following governed packets were read completely before this decision:

1. `strategy-seeds/sources/VILLAR-RAMBERG-OILGAS-2026/source.md`, SHA-256
   `4A03377F4CE8BCA9816DC2D9DBC34131ADC5E50B5ABB9D02AC29CB64E9CC4604`.
   It preserves complete reads of Villar-Joutz's U.S. EIA oil/gas report and
   Ramberg-Parsons' peer-reviewed *Energy Journal* article, including their
   regime instability, weak-tie, and adverse evidence.
2. `strategy-seeds/sources/MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026/source.md`,
   SHA-256
   `7E0D0F9595CCBDB2CA2B2FEDD02BE2E969CC129CE293C48F44C42BDDC9CBC629`.
   It preserves Cox and Stuart's named peer-reviewed record and the complete
   official NIST Dataplot algorithm. For even `n`, NIST fixes `c=n/2`, pairs
   `X_i` with `X_(i+c)`, and applies a sign test to the differences.
3. The exact bounded composite extraction is
   `strategy-seeds/sources/VILLAR-COX-STUART-XTIXNG-MPAIRSIGN-RV-2026/source.md`.

The original Cox-Stuart body is paywalled and is not represented as completely
read. The sources do not specify this statistic/carrier conjunction, horizon,
threshold, direction, continuous-CFD mapping, or trade. The 5-of-7 threshold,
synchronization, contrarian mapping, fixed risk, stops, spread caps, atomicity,
and lifecycle are disclosed QM hypotheses. No source performance or portfolio
claim transfers.

## Locked Mechanic

On the first synchronized executable `XTIUSD.DWX`/`XNGUSD.DWX` D1 tick after
each genuine broker-month transition:

1. Consume the broker `yyyymm` before every fallible gate and never retry it.
2. Reconstruct exactly fourteen consecutive synchronized completed broker-
   month endpoints ending in the immediately prior month; reject gaps,
   duplicate months, timestamp mismatch, stale or nonpositive endpoints.
3. Form chronological `s[i]=ln(XTI_close[i])-ln(XNG_close[i])` for `i=0..13`.
4. Compute only `d[i]=s[i+7]-s[i]`, `i=0..6`; any zero or nonfinite
   difference consumes the month flat.
5. At least five positive signs map to SELL XTI / BUY XNG. At least five
   negative signs map to BUY XTI / SELL XNG. A 4/3 split is flat.
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
  peer-reviewed oil/gas evidence, named peer-reviewed Cox-Stuart record, and
  complete official NIST algorithm; exact conjunction disclosed untested.
- R2 `PASS`: clock, synchronized sample, ratio orientation, fixed pairs, ties,
  threshold, sides, attempt, aggregate risk, stops, atomicity, and exits lock.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  XTI/XNG D1 history and MT5 state supply every runtime input.
- R4 `PASS`: deterministic calendar/arithmetic/execution state only; no ML,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The canonical fail-closed checker authenticated 4,678 registry identities,
1,329 card files, and 45 Company Reference Wiki nodes and returned `CLEAN`
with no exact or fuzzy match. Evidence is
`artifacts/qm5_xtixng_mcoxstuart_rv_preallocation_dedup_20260827.json`, SHA-256
`E75E18D836E67A898CE5B6EFC6E3D8FC545862DBC5E21F1B01D954F7118DF429`.

Manual review separates the candidate from the closest functional neighbors:

- `QM5_41167` follows Cox-Stuart on outright WTI; this card fades the statistic
  on an atomic XTI/XNG ratio basket.
- `QM5_41168` uses a metal carrier; this card uses only energy legs and targets
  exposure different from the directional index/metal/XNG book.
- `QM5_41175` scans possible Pettitt splits; `QM5_41178` compares all 36
  cross-block pairs. This card uses seven disjoint fixed lag-seven signs.
- The two locked rank vectors in the source packet prove both candidate-only
  and candidate-flat disagreements with those XTI/XNG neighbors.
- `QM5_12567` is a two-day long-only XNG cumulative-RSI pullback with no XTI
  hedge and no monthly paired-sign state.

Verdict:
`CLEAN_XTIXNG_MONTHLY_COX_STUART_SEVEN_PAIR_FIVE_SIGN_RATIO_REVERSION`.

## Kill And Safety Boundary

The pre-result density prior is five to eight completed packages per full
post-warm-up year. Q02 retires below five/year, at zero trades, with
nonpositive governed economics, or on any mechanical/determinism defect.
Q09 alone owns realized portfolio correlation; market-neutral style is not a
neutrality or decorrelation claim.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after current
strict compile and review PASS. If the factory resource ceiling is binding,
do not dispatch, reserve, stop, reap, reprioritize, or otherwise control a
tester.
