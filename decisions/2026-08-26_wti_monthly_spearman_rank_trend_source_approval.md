# WTI Monthly Spearman Price-Rank Trend — Source Approval

Date: 2026-08-26

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue does not authorize tester dispatch or
work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. The mission permits one new structural,
low-frequency `XTIUSD` edge, requires reputable-source criteria and
`RISK_FIXED` backtests, and forbids live and portfolio-gate mutations.

## Candidate Identity

- proposed slug: `wti-mspearman-tr`
- proposed strategy ID: `MOP-SPEARMAN-WTI-MRANK-TREND-2026_S01`
- proposed source ID: `MOP-SPEARMAN-WTI-MRANK-TREND-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: continue WTI only when the Spearman association between thirteen
  completed month-end price ranks and their calendar ranks has exact integer
  score magnitude at least 104

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded records were reviewed before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves complete-paper Moskowitz-Ooi-Pedersen time-series-momentum
   evidence, explicit NYMEX WTI membership, and monthly renewal.
2. C. Spearman (1904), "The Proof and Measurement of Association between Two
   Things," *The American Journal of Psychology* 15(1), DOI
   `10.2307/1412159`. Crossref confirms the bibliographic identity. The
   article body is not represented as completely read because the
   deterministic source router classified the publisher route
   `DEFERRED:SOURCE_POLICY`.
3. The R Core Team `stats::cor` source and manual in public `wch/r-source`
   branch `trunk`, commit
   `7344a2d9d96b3c2b997535d3abc8c3a44af16e82`. After the deterministic router
   selected the GitHub API path, both relevant files were read completely.
   They define Spearman rho as ordinary correlation of rank-transformed
   inputs. Exact blob and SHA-256 evidence is in
   `strategy-seeds/sources/MOP-SPEARMAN-WTI-MRANK-TREND-2026/retrieval_route_20260826.json`.
4. The governed composite packet
   `strategy-seeds/sources/MOP-SPEARMAN-WTI-MRANK-TREND-2026/source.md`,
   SHA-256
   `38B53FD42A8E9CBA533957D5A376D8F8D4E5CA0F8EBB249D8464F761C8D2AB98`.

Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
continuation experiment. Spearman supplies named statistical lineage, while
the complete R files supply the exact rank-transform definition. No source
tests this WTI-only thirteen-endpoint, integer-threshold conjunction. The
threshold, continuous-CFD mapping, fixed-dollar risk, stop, attempt state, and
lifecycle are disclosed QM hypotheses.

No source return, alpha, probability, Sharpe ratio, density, drawdown,
transaction cost, WTI-only result, CFD equivalence, statistical significance,
decorrelation, or portfolio-correlation statistic transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` as consumed before all fallible gates.
2. Reconstruct the latest D1 close from exactly thirteen immediately prior,
   consecutive completed broker months; reject ties and malformed history.
3. Assign strict ranks `R[0..12]`, compute
   `D=sum((R[i]-(i+1))^2)` and `T=364-D`, and prove all permutation, parity,
   and range invariants.
4. Buy only when `T>=104`, sell only when `T<=-104`, and otherwise consume the
   month flat. This is exactly `abs(rho)>=2/7`; no p-value or fallback exists.
5. Use one position, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop, no target, and a
   1,500-point entry-spread ceiling.
6. Close at the next broker-month transition or after forty calendar days and
   repair invalid owned exposure immediately.

Both news axes, legacy news mode, and Friday close are OFF. The threshold was
fixed before market testing. Exact enumeration of all 13! no-tie rank paths
produced a random-order qualification rate of `0.3436382463986631`, or about
4.12 decisions per year; this is a density design fact, not a significance or
WTI-performance claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete-read,
  peer-reviewed WTI trading evidence; named original Spearman journal record;
  and complete pinned R Core method files. The original article body and exact
  trading conjunction remain explicitly untested.
- R2 `PASS`: clock, endpoint reconstruction, strict ranks, integer score,
  threshold, side, attempt, risk, stop, and lifecycle are fixed.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 plus MT5
  state supplies every runtime input.
- R4 `PASS`: deterministic price ranks and native execution state only; no
  trained output, banned signal method, external feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical checker scanned 4,672 EA-registry rows, 1,323 card
files, and 45 Strategy Wiki nodes. It found no exact or fuzzy match. Evidence
is `artifacts/qm5_wti_mspearman_tr_preallocation_dedup_20260826.json`,
SHA-256 `B7296C4BDEEC4624F25909AD9AD48A1F0020D57955676B84819855373EAD91F8`.

Manual functional review fixes a new statistic rather than a renamed horizon:

- `QM5_20264_wti-rank-trend` counts 78 concordant/discordant pairs and gates
  `abs(S)>=28`; the new rule squares displacement from each exact time rank.
- `QM5_41167`, `QM5_41169`, `QM5_41170`, `QM5_41171`, and `QM5_41172` use,
  respectively, fixed lag pairs, running records, adjacent rank movement,
  local extrema, and a central cumulative-rank change point. None calculates
  the price-rank/time-rank correlation.
- `QM5_10473_mql5-spearman` is an H4 FX zero-crossing system with a different
  carrier, clock, inputs, event, lifecycle, and exposure.
- Fixed rank vectors in the approved packet prove both Mann-Kendall and
  Pettitt qualify/flat disagreements in each direction.
- Certified `QM5_12567_cum-rsi2-commodity` is a two-day long-only XNG
  oscillator pullback with neither WTI exposure nor monthly rank logic.

Verdict: `CLEAN_WTI_MONTHLY_SPEARMAN_TIME_PRICE_RANK_T104_CONTINUATION`.

## Kill And Safety Boundary

The pre-result density prior is four to eight completed WTI positions per full
post-warm-up year. Q02 must retire the candidate below four in any full year,
at zero trades, with nonpositive governed economics, or on any month,
endpoint, rank, displacement, threshold, side, attempt, risk, lifecycle, or
determinism defect.

WTI is a direct crude-oil carrier absent from the stated XAU/SP500/NDX/XNG
book, but this does not prove low or negative realized correlation. Q09 alone
owns the overlap verdict. No failed result may be rescued by changing the
sample, rank rule, threshold, direction, risk, hold, or by adding a seasonal,
volatility, external, or prior-result gate.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
start/stop; and a second queue row. Q02 may be enqueued once only after a
current strict compile and review PASS. If the factory resource ceiling is
binding, do not dispatch, reserve, stop, reap, reprioritize, or otherwise
control a tester.
