---
source_id: BURAKOV-MEHLITZ-WTI-VRCAL-2026
title: WTI physical-season direction conditioned by robust variance-ratio memory
publisher: International Journal of Energy Economics and Policy / The European Journal of Finance
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-06
strategy_ids:
  - BURAKOV-MEHLITZ-WTI-VRCAL-2026_S01
parent_sources:
  - BURAKOV-WTI-HALLOWEEN-2018
  - MEHLITZ-AUER-MEM-2024
---

# WTI Physical-Season / Variance-Ratio Source Packet

## Source identity and complete-read evidence

This bounded packet joins two locally governed, fully read peer-reviewed
lineages that explicitly study West Texas crude oil or include WTI futures:

1. Burakov, Dmitry; Freidin, Max; and Solovyev, Yuriy (2018), "The
   Halloween Effect on Energy Markets: An Empirical Study," *International
   Journal of Energy Economics and Policy* 8(2), 121-126. The official
   complete open text, both calendar definitions, all result tables,
   discussion, conclusion, editorial inconsistencies, and adverse limits are
   recorded in `strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md`.
2. Mehlitz, Julia S., and Auer, Benjamin R. (2024), "Memory-enhanced momentum
   in commodity futures markets," *The European Journal of Finance* 30(8),
   773-802, DOI `10.1080/1351847X.2023.2220118`. The complete open precursor
   chapter and Appendix C were reviewed end-to-end and are recorded in
   `strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md`.

Burakov et al. supply the alternative-two WTI calendar partition: November
through May is the positive winter leg and June through October is the
negative summer leg. Mehlitz and Auer supply a 32-completed-month, `q=2`,
heteroskedasticity-robust Lo-MacKinlay variance-ratio state, a fixed two-sided
10% significance boundary, and the persistence-follow / anti-persistence-
reverse direction matrix.

Neither source tests the Burakov physical-season direction inside the Mehlitz
memory matrix. That conjunction is a transparent QM hypothesis. No historical
return, significance result, portfolio correlation, drawdown, cost, or
continuous-CFD claim transfers from either source.

## Bounded mechanization

`BURAKOV-MEHLITZ-WTI-VRCAL-2026_S01` locks one monthly WTI rule:

- carrier: `XTIUSD.DWX`, D1, magic slot 0;
- decision clock: first processed D1 bar of each genuine broker-month
  transition;
- memory history: exactly thirty-three consecutive completed broker-month
  closes defining thirty-two chronological monthly log returns;
- memory state: the published `q=2` robust variance-ratio z-statistic,
  actionable only when `abs(z) > 1.64485362695147`;
- calendar direction: LONG for current broker months November through May and
  SHORT for June through October;
- direction matrix: significant persistence follows the calendar direction;
  significant anti-persistence reverses it;
- flat state: insignificant memory, incomplete/nonconsecutive endpoints,
  zero variance, invalid arithmetic, or unavailable risk inputs;
- lifecycle: close the prior package before each new monthly decision,
  persist one consumed attempt per month before fallible gates, and hold no
  longer than forty calendar days;
- risk: one frozen `3.0 * ATR(20,D1)` hard stop, no target, 1,500-point spread
  cap, no scale-in, and Friday close disabled; and
- Q02 contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

For chronological returns `r_0 ... r_31`, the locked statistic is:

```text
mean       = average(r_0 ... r_31)
S          = sum((r_i - mean)^2), i=0...31
rho_1      = sum((r_i - mean)(r_i-1 - mean), i=1...31) / S
VR(2)      = 1 + rho_1
robust_se  = sqrt(sum((r_i - mean)^2(r_i-1 - mean)^2, i=1...31) / S^2)
z          = (VR(2) - 1) / robust_se
season_dir = +1 in months {11,12,1,2,3,4,5}; -1 in {6,7,8,9,10}
trade_dir  = season_dir * sign(z), only when abs(z) > 1.64485362695147
```

The seasonal side uses the current entry month, while every price input is
completed before that month begins. The rule therefore has no forward data.
The monthly clock offers at most twelve decisions per full post-warm-up year.
The parent memory extraction estimated six to ten significant months per year;
that is only a density prior. Q02 retires below five completed packages per
full post-warm-up year.

Runtime reads native MT5 OHLC, ATR, broker calendar, spread, quotes, positions,
deal history, and framework state only. It does not read futures curves,
inventory releases, volume, open interest, files, APIs, analyst inputs, trained
outputs, or portfolio results.

## Non-duplicate boundary

The deterministic pre-allocation checker scanned 4,304 EA-registry rows and
421 canonical cards. It found no exact identity and no fuzzy match above its
threshold. Manual mechanic review fixes the nearest boundaries:

- `QM5_13134_energy-vr-mom` uses the newest one-month return sign inside the
  same memory matrix; this candidate uses a fixed physical-season direction.
- `QM5_20245_wti-vr-rsm` uses twelve-month binary return-sign breadth and a
  fixed probability threshold; it has no calendar direction state.
- `QM5_20015_wti-halloween-winter` is unconditional November-May long and
  flat otherwise; it has no memory estimator, summer short, significance gate,
  or anti-persistent reversal.
- `QM5_20046_wti-halloween-ls` is an unconditional November-April long /
  May-October short regime from the source's alternative-one partition; it has
  no memory state and uses different month boundaries.
- `QM5_20222_wti-seas-sign` requires fixed-season agreement with twelve-month
  return-sign breadth; it neither estimates serial dependence nor reverses a
  valid seasonal state in an anti-persistent regime.
- `QM5_20227`, `QM5_20231`, and `QM5_20241` condition physical season on,
  respectively, the latest month, twelve-month cumulative return, and a
  52-week price anchor; none computes a robust variance ratio.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator pullback
  with a different carrier, clock, state, and hold.

The 32-return robust `q=2` test, fixed significance boundary, alternative-two
calendar direction, persistence-follow / anti-persistence-reverse mapping, and
monthly consumed attempt are jointly load-bearing. Removing the calendar state
recreates the published memory parent; removing the memory state recreates an
existing seasonal carrier.

## Reputable-source criteria

- R1: PASS. One tier-A and one tier-B named-author peer-reviewed source with
  durable complete-read records and explicit WTI scope.
- R2: PASS. Completed endpoints, exact robust statistic, significance boundary,
  month partition, direction matrix, attempt state, hard stop, rollover, stale
  exit, and spread cap are frozen.
- R3: PASS. Registered `XTIUSD.DWX` D1 history and native MT5 state supply every
  runtime input.
- R4: PASS. Deterministic calendar, logarithm, variance, and ATR arithmetic
  only; no trained model, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramiding.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk backtest setfile,
and one paced Q02 enqueue under the 2026-08-06 OWNER mission. It does not
authorize a manual backtest; live, demo, shadow, or optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio admission;
portfolio-gate changes; correlation waivers; or post-result parameter repair.
