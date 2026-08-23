---
source_id: MOP-WTI-MPATH-EFF-MOM-2026
title: WTI completed-month path-efficiency momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading research
source_type: peer_reviewed_trading_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_wti_monthly_path_efficiency_momentum_source_approval.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - wti-mpath-eff-mom
---

# WTI Completed-Month Path-Efficiency Momentum Source Packet

## Approved Trading Source Of Record

Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The governed parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It records a complete read
of the 23-page published paper retrieved from author Lasse Heje Pedersen's NYU
faculty site. The reproducible receipt
`strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json` records
the canonical faculty URL, retrieval time, 976,459 bytes, 23 pages, and PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The approved statistic lineage is
`strategy-seeds/sources/MOP-WTI-PATHEFF-2026/source.md`, SHA-256
`7D4F2B86DA31EEA2ECAEE7573E3CF1629883B05A575FFEB694944A99D907DBE8`.
That bounded packet defines net-to-absolute-path efficiency and its numerical
validity contract for twelve adjacent monthly WTI returns.

The durable OWNER source approval is
`decisions/2026-08-23_wti_monthly_path_efficiency_momentum_source_approval.md`,
committed before this extraction at `5d6f31cd2`. No blocked page, inferred
source-table value, secondary summary, or unrecorded performance claim is used.

## Trading-Source Findings Used

- Section 3.1 tests each instrument's own return at monthly lags one through
  sixty and reports positive continuation over the first twelve monthly lags,
  including lag one.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns, renews them monthly, and scales exposure by ex-ante volatility.
- Table 2 explicitly reports the source's `k=1`, `h=1` commodity-futures
  portfolio, while Appendix A includes NYMEX WTI crude.
- The source uses liquid rolling futures excess returns and a 60-day-center-
  of-mass ex-ante volatility estimator; it does not test Darwinex CFDs.

These findings support only a structural hypothesis that WTI's immediately
completed own-price month may contain continuation information and that a
monthly formation/holding clock is source-aligned. They do not establish a
WTI-specific one-month effect and do not test whether the internal daily path
should qualify the endpoint return.

The net-to-absolute-daily-path statistic, fixed 0.20 threshold, continuous-CFD
mapping, broker-calendar reconstruction, fixed-dollar risk, ATR stop, spread
ceiling, persistent attempt state, and lifecycle are transparent QM choices.
No source alpha, return, probability, density, Sharpe ratio, drawdown, trade
count, cost, CFD equivalence, or portfolio-correlation statistic transfers.

## Bounded QM Mechanization

At the first executable `XTIUSD.DWX` D1 bar of a new broker-calendar month,
reconstruct every completed D1 close whose timestamp belongs to the
immediately preceding calendar month plus the adjacent older close that
precedes that month. Require 17 through 23 month-session closes. Starting from
the older boundary close, form exactly one chronological log return ending on
each session in the completed month.

For `n` returns `r[0]..r[n-1]`:

```text
N = sum(r[j])
P = sum(abs(r[j]))
E = abs(N) / P

require finite arithmetic, P > 0, and E in [0,1] within 1e-10

E >= 0.20 and N > 0  => BUY XTIUSD.DWX
E >= 0.20 and N < 0  => SELL XTIUSD.DWX
otherwise             => FLAT
```

The sum of the chronological constituent returns must equal the direct log
return from the older boundary close to the completed month's final close
within `1e-10`. Each return ending in the completed month contributes exactly
once. Exact-zero constituent returns are valid and add zero to both `N` and
`P`. A zero absolute path, exact-zero net, below-threshold efficiency,
nonfinite value, or out-of-range quotient consumes the month flat. Signal
magnitude never changes risk.

This quotient measures how much of the full L1 daily path survives as net
month displacement. It is bounded and scale invariant. It is not a Kaufman
moving-average signal, a fitted efficiency estimator, a volatility forecast,
or an adaptive indicator; the EA calculates the closed-form statistic once
from the fixed completed-month package.

## Exact Event Contract

1. Require exact `XTIUSD.DWX`, D1, and entry no later than 180 elapsed minutes
   after the raw first host D1 bar open of a new broker month.
2. Require the newest completed D1 bar to belong to the immediately preceding
   calendar month. Within a fixed 45-bar buffer, require 17 through 23 unique
   completed-month bars in strict reverse-time order and one immediately older
   bar from the adjacent calendar month. A current-month close is excluded.
3. Reverse the selected closes into chronological order beginning with the
   older boundary close. Form one return into every completed-month session,
   with no gap, overlap, duplicate, or omitted endpoint.
4. Accumulate `N` and `P` from the same bounded loop, verify the endpoint
   identity, then compute the fixed path efficiency without rounding.
5. Follow the sign of `N` only when `E>=0.20`. Every invalid or nonqualifying
   state consumes the month flat.
6. Persist current decision `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, or order submission. No outcome may retry that month.
7. Open at most one position with aggregate `RISK_FIXED=1000`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
8. Close on the first tick in a later broker month, with a forty-calendar-day
   stale repair. Flatten malformed, duplicated, wrong-symbol, wrong-magic, or
   stopless owned exposure immediately.

## Non-Duplicate Boundary

The fail-closed canonical checker found no exact or fuzzy collision across
4,625 registry identities, 1,294 cards, and 45 Strategy-Wiki nodes. Evidence
is `artifacts/qm5_wti_mpath_eff_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes a new mechanic:

- `QM5_20187_wti-tsmom1m` follows the prior month-end return without a path-
  quality gate. This extraction requires all daily returns ending in that
  month to pass a fixed path-efficiency threshold.
- `QM5_20274_wti-path-eff` uses twelve monthly returns and a 0.25 L1 path
  threshold. This extraction uses one completed month of daily returns and a
  0.20 threshold.
- `QM5_20288_wti-volnorm-mom` separately L2-normalizes twelve historical
  month returns and averages them. This extraction has one one-month L1 path
  denominator and no historical average.
- `QM5_41111_wti-mdaybreadth-mom` counts signs while discarding magnitudes.
  This extraction uses every absolute return magnitude.
- `QM5_41124_wti-mrms-coherence-mom` uses an L2/RMS denominator. This
  extraction uses the L1 sum of absolute returns, so concentration in a few
  daily shocks affects the two gates differently.
- `QM5_41114`, `QM5_41115`, and `QM5_41117` use fixed calendar blocks, while
  `QM5_41122` uses extreme-state sequence order. This extraction has no block,
  vote, range location, or sequence state.
- `QM5_41123_xauxag-mpath-eff-rv` uses a synchronized gold-minus-silver ratio,
  contrarian direction, two opposite legs, and atomic basket lifecycle. This
  extraction follows one outright WTI series.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator
  pullback rather than completed-month WTI path structure.

The exact carrier, immediately completed month, older boundary close, every
daily return ending in the month, signed net, absolute path, bounded quotient,
inclusive 0.20 threshold, continuation direction, consumed attempt, fixed
risk, and next-month exit are jointly load-bearing. Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_PATH_EFFICIENCY_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_WITHIN_MONTH_GATE_TRANSLATION_RISK`. The canonical child
  preserves a peer-reviewed trading paper, DOI, author-hosted complete-paper
  evidence, durable hashes, explicit WTI membership, source-declared one-month
  formation/hold, and a previously approved closed-form path statistic. The
  daily horizon and threshold are untested translations.
- R2: `PASS`. Month membership, observation bounds, chronology, return
  inclusion, endpoint identity, signed and absolute sums, normalization,
  threshold, direction, attempt, risk, stop, spread gate, and lifecycle are
  fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history plus native MT5 calendar, ATR, spread, quote, position, deal, and
  persistent state provides every runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, absolute values, addition,
  division, comparisons, ATR, and execution state only; no trained output,
  banned signal, external runtime feed, grid, martingale, scale-in, or pyramid.

## Claim And Kill Boundary

A seeded zero-drift Gaussian design reference with twenty returns qualifies
approximately 48% of months at `E>=0.20`, corresponding to about 5.8
decisions/year. This is a pre-result density sanity check, not market evidence.
Q02 must retire below five completed positions in any full post-warm-up year,
at zero trades, or with nonpositive governed economics.

Different WTI exposure does not prove decorrelation from the certified XAU,
SP500, NDX, and XNG book. Q09 alone owns the realized portfolio result. No
failure may be rescued by changing the threshold, direction, observation
inclusion, carrier, risk, hold, or by adding a fitted mean, volatility forecast,
sign count, block vote, sequence, range location, seasonality, event, external,
or prior-result state.

## Safety Boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
