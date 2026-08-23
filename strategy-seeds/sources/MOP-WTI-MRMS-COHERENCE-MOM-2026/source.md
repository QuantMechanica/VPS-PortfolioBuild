---
source_id: MOP-WTI-MRMS-COHERENCE-MOM-2026
title: WTI completed-month mean-to-RMS coherence momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading research
source_type: peer_reviewed_trading_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_wti_monthly_mean_rms_coherence_momentum_source_approval.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - wti-mrms-coherence-mom
---

# WTI Completed-Month Mean-to-RMS Coherence Momentum Source Packet

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

The durable OWNER source approval is
`decisions/2026-08-23_wti_monthly_mean_rms_coherence_momentum_source_approval.md`,
committed before this extraction at `04f9f9b01`. No blocked page, inferred
source-table value, secondary summary, or unrecorded performance claim is
used.

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

The mean-to-RMS coherence statistic, fixed 0.16 threshold, continuous-CFD
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
Q = sum(r[j]^2)
C = abs(N) / sqrt(n * Q)

equivalently:
C = abs(mean(r)) / sqrt(mean(r[j]^2))

require finite arithmetic, Q > 0, and C in [0,1] within 1e-10

C >= 0.16 and N > 0  => BUY XTIUSD.DWX
C >= 0.16 and N < 0  => SELL XTIUSD.DWX
otherwise             => FLAT
```

The sum of the chronological constituent returns must equal the direct log
return from the older boundary close to the completed month's final close
within `1e-10`. Each return ending in the completed month contributes exactly
once. Exact-zero constituent returns are valid and add zero to `N` and `Q`.
A zero squared path, exact-zero net, below-threshold coherence, nonfinite
value, or out-of-range quotient consumes the month flat. Signal magnitude
never changes risk.

This quotient is the absolute projection of the return vector onto the
equal-sign direction, normalized by both vector lengths. It is bounded and
scale invariant. It is not a sample mean t-statistic: there is no demeaning,
sample-variance correction, degrees-of-freedom adjustment, annualization, or
fitted distribution.

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
4. Accumulate `N` and `Q` from the same bounded loop, verify the endpoint
   identity, then compute the fixed mean-to-RMS coherence without rounding.
5. Follow the sign of `N` only when `C>=0.16`. Every invalid or nonqualifying
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
4,623 registry identities, 1,292 cards, and 45 Strategy-Wiki nodes. Evidence
is
`artifacts/qm5_wti_mrms_coherence_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes a new mechanic:

- `QM5_20187_wti-tsmom1m` follows the prior month-end return without a path-
  quality gate. This extraction requires all daily returns ending in that
  month to pass a fixed mean-to-RMS threshold.
- `QM5_20288_wti-volnorm-mom` separately L2-normalizes twelve historical
  months, weights them equally, and uses the final mean sign without a gate.
  This extraction uses one completed month and a bounded 0.16 qualification.
- `QM5_20274_wti-path-eff` uses twelve monthly returns and an L1 denominator.
  This extraction uses one month of daily returns and an RMS/L2 denominator.
- `QM5_41111_wti-mdaybreadth-mom` counts signs while discarding magnitudes.
  This extraction uses all squared magnitudes and is invariant to return order.
- `QM5_41114`, `QM5_41115`, and `QM5_41117` use fixed calendar blocks, while
  `QM5_41122` uses extreme-state sequence order. This extraction has no block,
  vote, range location, or sequence state.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator
  pullback rather than completed-month WTI path coherence.

The exact carrier, immediately completed month, older boundary close, every
daily return ending in the month, signed sum, squared path, bounded
mean-to-RMS quotient, inclusive 0.16 threshold, continuation direction,
consumed attempt, fixed risk, and next-month exit are jointly load-bearing.
Manual verdict:
`CLEAN_WTI_COMPLETED_MONTH_MEAN_RMS_COHERENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1: `PASS_WITH_WITHIN_MONTH_GATE_TRANSLATION_RISK`. The canonical child
  preserves a peer-reviewed trading paper, DOI, author-hosted complete-paper
  evidence, durable hashes, explicit WTI membership, and source-declared
  one-month formation/hold. The coherence gate is an untested translation.
- R2: `PASS`. Month membership, observation bounds, chronology, return
  inclusion, endpoint identity, signed and squared sums, normalization,
  threshold, direction, attempt, risk, stop, spread gate, and lifecycle are
  fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history plus native MT5 calendar, ATR, spread, quote, position, deal, and
  persistent state provides every runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, addition, multiplication,
  square root, division, comparisons, ATR, and execution state only; no trained
  output, banned signal, external runtime feed, grid, martingale, scale-in, or
  pyramid.

## Claim And Kill Boundary

A zero-drift Gaussian design reference qualifies approximately 45.6% to 52.6%
of months across 23 to 17 returns at `C>=0.16`, corresponding to about 5.5 to
6.3 decisions/year. This is a pre-result density sanity check, not market
evidence. Q02 must retire below five completed positions in any full post-
warm-up year, at zero trades, or with nonpositive governed economics.

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
