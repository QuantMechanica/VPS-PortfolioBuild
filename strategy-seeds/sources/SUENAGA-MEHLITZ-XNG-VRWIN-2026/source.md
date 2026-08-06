---
source_id: SUENAGA-MEHLITZ-XNG-VRWIN-2026
title: XNG physical-volatility windows conditioned by robust variance-ratio memory
publisher: Journal of Futures Markets / The European Journal of Finance
source_type: peer_reviewed_composite_lineage
status: approved
created: 2026-08-06
created_by: Research+Development
last_updated: 2026-08-06
approved_by: "OWNER commodity/energy sleeve mission"
approved_at: 2026-08-06
strategy_ids:
  - SUENAGA-MEHLITZ-XNG-VRWIN-2026_S01
parent_sources:
  - SUENAGA-XNG-SEASVOL-2008
  - MEHLITZ-AUER-MEM-2024
---

# XNG Physical-Volatility Window / Variance-Ratio Source Packet

## Source identity and complete-read evidence

This bounded packet joins two locally governed, fully read peer-reviewed
lineages:

1. Suenaga, Hiroaki; Smith, Aaron; and Williams, Jeffrey C. (2008),
   "Volatility Dynamics of NYMEX Natural Gas Futures Prices," *Journal of
   Futures Markets* 28(5), 438-463, DOI `10.1002/fut.20317`. The complete
   26-page author-hosted paper, including the POTS specification, data,
   estimates, hedging application, conclusion, and limitations, is recorded in
   `strategy-seeds/sources/SUENAGA-XNG-SEASVOL-2008/source.md`.
2. Mehlitz, Julia S., and Auer, Benjamin R. (2024), "Memory-enhanced momentum
   in commodity futures markets," *The European Journal of Finance* 30(8),
   773-802, DOI `10.1080/1351847X.2023.2220118`. The complete open precursor
   chapter and Appendix C were reviewed end-to-end and are recorded in
   `strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md`.

The publisher records confirm the journal identities, author lists, volumes,
pages, and DOIs. Suenaga et al. supply the natural-gas physical-volatility
timing: early May through late September and early November through mid-January.
The existing governed monthly translation admits broker months May-September
and November-January. Mehlitz and Auer supply a 32-completed-month, `q=2`,
heteroskedasticity-robust Lo-MacKinlay variance-ratio state, a fixed two-sided
10% significance boundary, and the persistence-follow / anti-persistence-
reverse direction matrix applied to the latest completed return.

Neither source tests the variance-ratio rule only inside the natural-gas
physical windows. That conjunction is a transparent QM hypothesis. No source
return, significance, drawdown, cost, continuous-CFD, or portfolio-correlation
claim transfers.

## Bounded mechanization

`SUENAGA-MEHLITZ-XNG-VRWIN-2026_S01` locks one monthly natural-gas rule:

- carrier: `XNGUSD.DWX`, D1, magic slot 0;
- decision clock: first processed D1 bar of each genuine broker-month
  transition;
- eligible months: May-September and November-January; February-April and
  October are flat;
- memory history: exactly thirty-three consecutive completed broker-month
  closes defining thirty-two chronological monthly log returns;
- memory state: the published `q=2` robust variance-ratio z-statistic,
  actionable only when `abs(z) > 1.64485362695147`;
- base direction: sign of the immediately completed monthly return;
- direction matrix: significant persistence follows that sign; significant
  anti-persistence reverses it;
- flat state: an off-window month, insignificant memory, zero latest return,
  incomplete/nonconsecutive endpoints, zero variance, invalid arithmetic, or
  unavailable risk inputs;
- lifecycle: close the prior package before each new monthly decision, persist
  one consumed attempt per eligible month before fallible gates, and hold no
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
base_dir   = sign(r_31)
trade_dir  = base_dir * sign(z), only in an eligible month and when
             abs(z) > 1.64485362695147
```

Every price input is completed before the entry month begins. The full-month
translation deliberately over-includes the boundary portions of May,
September, November, and January relative to the paper's within-month timing;
that is the same deterministic broker-month proxy already governed for the
source lineage, not a claim of exact futures replication.

The monthly clock offers eight eligible decisions per full post-warm-up year.
The parent memory extraction estimated six to ten significant months per year
before the physical-window gate, so five to seven completed packages per year
is only a density prior. Q02 retires below five completed packages per full
post-warm-up year.

Runtime reads native MT5 OHLC, ATR, broker calendar, spread, quotes, positions,
deal history, and framework state only. It does not read futures curves,
storage releases, weather, volume, open interest, files, APIs, analyst inputs,
trained outputs, or portfolio results.

## Non-duplicate boundary

Before allocation, `research_dedup_check.py` scanned 4,305 EA-registry rows and
422 canonical cards. It found no exact identity and surfaced only the expected
fuzzy neighbor `QM5_20242_xng-rsm-window`. Manual mechanic review fixes the
nearest boundaries:

- `QM5_20242_xng-rsm-window` trades the same eight physical months from a
  twelve-month binary non-negative-return share and fixed `0.40` threshold. It
  has no serial-dependence estimator, significance gate, latest-return base
  direction, or anti-persistent reversal.
- `QM5_13134_energy-vr-mom` applies the variance-ratio matrix year-round to
  WTI, not natural gas, and has no natural-gas physical-window state.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG oscillator
  pullback using two-day cumulative RSI logic. It has no monthly return,
  physical window, memory test, or short side.
- `QM5_20052_xng-seas-trend` uses a 126-D1 magnitude-return trend inside the
  source windows; it does not estimate serial dependence or reverse
  anti-persistent states.
- `QM5_13116_xng-signmom` is a year-round sign-momentum rule without the
  physical-window or variance-ratio gates.

The two physical windows, thirty-two-return robust `q=2` test, fixed
significance boundary, latest-return base direction, persistence-follow /
anti-persistence-reverse mapping, and eligible-month attempt clock are jointly
load-bearing. Verdict: `CLEAN_AFTER_DETERMINISTIC_AND_MANUAL_REVIEW`.

## Reputable-source criteria

- R1: PASS. Two named-author peer-reviewed sources with durable complete-read
  records, stable DOIs, and direct natural-gas / commodity scope.
- R2: PASS. Completed endpoints, exact robust statistic, fixed significance
  boundary, month windows, direction matrix, attempt state, hard stop,
  rollover, stale exit, and spread cap are frozen.
- R3: PASS. Registered `XNGUSD.DWX` D1 history and native MT5 state supply every
  runtime input.
- R4: PASS. Deterministic calendar, logarithm, variance, and ATR arithmetic
  only; no trained model, banned signal indicator, external runtime feed,
  grid, martingale, scale-in, or pyramiding.

## Safety and claim boundary

This packet authorizes one branch-only Strategy Card, deterministic registry
allocation, non-live V5 build, strict compile, one fixed-risk backtest setfile,
and one paced Q02 enqueue under the 2026-08-06 OWNER mission. It does not
authorize a manual backtest; live, demo, shadow, or optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio admission;
portfolio-gate changes; correlation waivers; or post-result parameter repair.
