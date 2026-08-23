---
source_id: MEHLITZ-MOP-WTI-MDAILY-PERSIST-MOM-2026
title: WTI completed-month daily-persistence momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading research
source_type: peer_reviewed_trading_papers_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_wti_monthly_daily_persistence_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - MEHLITZ-AUER-MEM-2024
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  MEHLITZ-AUER-MEM-2024: A422025CE4C7FA2F9BEB995F496103D0FCCCED899C143771F58DB7E2222D3AC8
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - wti-mdaily-persist-mom
---

# WTI Completed-Month Daily-Persistence Momentum Source Packet

## Approved trading sources of record

The own-return trend and monthly-clock source is:

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

The serial-dependence source is:

Mehlitz, Julia S., and Benjamin R. Auer (2024), "Memory-enhanced momentum in
commodity futures markets," *The European Journal of Finance* 30(8), 773-802,
DOI `10.1080/1351847X.2023.2220118`.

The governed parent packet is
`strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md`. It records an end-to-
end review of the strategy's Chapter 3, methodology, results, robustness,
conclusion, and Appendix C in Julia S. Mehlitz's openly readable 2021 doctoral
manuscript, the peer-reviewed paper's complete precursor.

The durable OWNER source approval is
`decisions/2026-08-23_wti_monthly_daily_persistence_momentum_source_approval.md`,
committed before this extraction at `4a9af0a24`. No blocked page, inferred
source-table value, secondary summary, or unrecorded performance claim is used.

## Trading-source findings used

Moskowitz, Ooi, and Pedersen:

- test each instrument's own monthly return at lags one through sixty and
  report positive continuation over the first twelve monthly lags;
- form time-series-momentum positions from the sign of own past returns,
  renew mechanically each month, and report a `k=1`, `h=1` pooled commodity-
  futures portfolio; and
- explicitly include NYMEX WTI crude in the commodity universe.

Mehlitz and Auer:

- explicitly include WTI in their commodity universe and variance-ratio
  appendix;
- define variance ratios as weighted aggregations of lagged return
  autocorrelations; and
- combine monthly return direction with statistically classified persistence
  or anti-persistence in a memory-enhanced momentum matrix.

These findings support only a structural hypothesis that WTI's completed own-
price month may contain continuation information and that adjacent return
dependence is an auditable path property. They do not establish a WTI-specific
one-month result or the daily within-month rule below.

The source implementations use rolling commodity futures, multi-instrument
portfolios, ex-ante scaling, 32 monthly observations, a heteroskedasticity-
robust significance test, and a continuation/reversal matrix. This extraction
instead uses one immediately completed broker month of 17-23 daily returns,
a fixed short-sample neutralization, persistence-only qualification, a
continuous WTI CFD, fixed-dollar risk, and an ATR hard stop. Every difference
is a QM falsification choice.

No source alpha, return, probability, density, Sharpe ratio, drawdown, trade
count, cost, CFD equivalence, or portfolio-correlation statistic transfers.

## Bounded QM mechanization

At the first executable `XTIUSD.DWX` D1 bar of a new broker-calendar month,
reconstruct every completed D1 close whose normalized timestamp belongs to the
immediately preceding calendar month plus the adjacent older close. Require 17
through 23 month-session closes. Starting from the older boundary, form exactly
one chronological log return ending on every completed-month session.

For `n` returns `r[0]..r[n-1]`:

```text
N   = sum(r[j])
mu  = N / n
S   = sum((r[j] - mu)^2)
A   = sum((r[j] - mu) * (r[j-1] - mu)), j=1..n-1
rho = A / S
J   = rho + 1/(n-1)

require finite arithmetic, S > 0, and rho in [-1,1] within 1e-10

J > 0 and N > 0  => BUY XTIUSD.DWX
J > 0 and N < 0  => SELL XTIUSD.DWX
otherwise         => FLAT
```

The sum of the chronological returns must equal the direct boundary-to-final
log return within `1e-10`. Every return ending in the completed month
contributes once to `N` and `S`; every adjacent pair contributes once to `A`.
Exact-zero constituent returns are valid. Zero variance, exact-zero net,
nonpositive score, nonfinite value, out-of-range autocorrelation, or malformed
month consumes the month flat. Signal magnitude never changes risk.

The fixed `1/(n-1)` term shifts the conventional negative short-sample center
of the demeaned lag-one sample autocorrelation back to a neutral zero score.
It depends only on the locked observed session count, has no fitted WTI
parameter, and is not optimized. The daily horizon, correction, and strict
zero boundary are untested QM translations rather than claims from either
paper.

## Exact event contract

1. Require exact `XTIUSD.DWX`, D1, and entry no later than 180 elapsed minutes
   after the raw first host D1 bar open of a new broker month.
2. Require the newest completed D1 bar to belong to the immediately preceding
   calendar month. Within a fixed 45-bar buffer, require 17 through 23 unique
   completed-month bars in strict reverse-time order and one immediately older
   bar from the adjacent calendar month. Exclude current-month closes.
3. Reverse the selected closes into chronological order beginning with the
   older boundary close. Form one return into every completed-month session,
   with no gap, overlap, duplicate, or omitted endpoint.
4. Accumulate `N`, compute `mu`, accumulate `S` and adjacent `A`, verify the
   endpoint identity, then compute `rho` and `J` without rounding.
5. Follow the sign of `N` only when `J>0`. Equality and every invalid or
   nonqualifying state consume the month flat.
6. Persist current decision `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, or order submission. No outcome may retry that month.
7. Open at most one position with aggregate `RISK_FIXED=1000`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
8. Close on the first tick in a later broker month, with a forty-calendar-day
   stale repair. Flatten malformed, duplicated, wrong-symbol, wrong-magic, or
   stopless owned exposure immediately.

## Non-duplicate boundary

The fail-closed canonical checker found no exact or fuzzy collision across
4,626 registry identities, 1,295 cards, and 45 Strategy-Wiki nodes. Evidence
is `artifacts/qm5_wti_mdaily_persist_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes a new mechanic:

- `QM5_20187_wti-tsmom1m` uses only the completed-month endpoint return.
- `QM5_13134_energy-vr-mom` uses 32 monthly returns, a q=2 robust significance
  test, and both continuation and reversal. This extraction uses one month's
  daily returns, a deterministic short-sample shift, and persistence-only
  continuation.
- `QM5_20245`, `QM5_20253`, `QM5_20256`, and `QM5_20257` estimate robust
  variance-ratio states across multi-month histories and ranking horizons.
- `QM5_41111` counts daily signs; `QM5_41114`, `QM5_41115`, and `QM5_41117`
  vote on calendar blocks; `QM5_41122` orders extremes. This extraction
  multiplies adjacent demeaned return magnitudes and has no count, block, or
  extreme state.
- `QM5_41124` normalizes a monthly mean by daily RMS and `QM5_41126`
  normalizes endpoint displacement by an L1 path. Neither estimates adjacent
  centered dependence.
- `QM5_41123` and `QM5_41125` are two-leg XAU/XAG relative baskets; this is an
  outright WTI continuation carrier.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon XNG oscillator
  pullback.

The exact carrier, completed month, older boundary, all daily returns,
centering, variance denominator, adjacent-product numerator, fixed
`1/(n-1)` shift, strict positive qualification, endpoint direction, consumed
attempt, fixed risk, and next-month exit are jointly load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_DAILY_PERSISTENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-source criteria

- R1: `PASS_WITH_WITHIN_MONTH_PERSISTENCE_TRANSLATION_RISK`. Two governed
  peer-reviewed trading-paper packets preserve named authors, DOIs, complete-
  read evidence, durable hashes, explicit WTI membership, own-return momentum,
  monthly renewal, and autocorrelation lineage. The within-month horizon,
  finite-sample shift, and persistence-only gate are untested translations.
- R2: `PASS`. Month membership, observation bounds, chronology, return
  inclusion, endpoint identity, centering, squared-deviation denominator,
  adjacent-product numerator, correction, threshold, direction, attempt,
  risk, stop, spread gate, and lifecycle are fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history plus native MT5 calendar, ATR, spread, quote, position, deal, and
  persistent state provides every runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, addition, multiplication,
  division, comparisons, ATR, and execution state only; no trained output,
  banned signal, external runtime feed, grid, martingale, scale-in, or pyramid.

## Claim and kill boundary

A seeded zero-drift Gaussian design reference with 20,000 samples at each of
17, 20, and 23 daily returns qualifies 50.385%, 49.595%, and 50.210% of
months. That is approximately six decisions/year and is only a pre-result
code-path/density sanity check. Q02 must retire below five completed positions
in any full post-warm-up year, at zero trades, or with nonpositive governed
economics.

Different WTI exposure does not prove decorrelation from the certified XAU,
SP500, NDX, and XNG book. Q09 alone owns the realized portfolio result. No
failure may be rescued by changing the centering, correction, gate, direction,
observation inclusion, carrier, risk, hold, or by adding a fitted threshold,
robust significance test, reversal state, sign count, block vote, sequence,
range location, seasonality, event, external, or prior-result state.

## Safety boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
