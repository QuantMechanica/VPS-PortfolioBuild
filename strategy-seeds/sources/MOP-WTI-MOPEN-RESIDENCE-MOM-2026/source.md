---
source_id: MOP-WTI-MOPEN-RESIDENCE-MOM-2026
title: WTI completed-month fixed-open residence momentum extraction
publisher: QuantMechanica governed extraction of peer-reviewed trading research
source_type: peer_reviewed_trading_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-23_wti_monthly_open_residence_momentum_source_approval.md
parent_source_ids:
  - MOP-TSMOM-2012
  - SCHWEIKERT-CME-XAUXAG-MOPEN-RESIDENCE-RV-2026
parent_sha256:
  MOP-TSMOM-2012: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
  SCHWEIKERT-CME-XAUXAG-MOPEN-RESIDENCE-RV-2026: CB9B22CA3B0EAAD7AB3D606E1E07C1A049D80C6AD0D09EAF5394093C16D35D32
created: 2026-08-23
created_by: Research+Development
cards_extracted:
  - wti-mopen-residence-mom
---

# WTI Completed-Month Fixed-Open Residence Momentum Source Packet

## Approved trading source of record

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

The deterministic residence-statistic lineage is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MOPEN-RESIDENCE-RV-2026/source.md`.
That approved packet fixes exhaustive close-residence counting, strict ties,
integer ceiling arithmetic, endpoint-side confirmation, and monthly lifecycle
for a two-leg metals carrier. Only the auditable statistic convention is
reused. Its carrier, contrarian direction, sources, and any downstream result
do not support or transfer to WTI.

The durable OWNER source approval is
`decisions/2026-08-23_wti_monthly_open_residence_momentum_source_approval.md`,
committed before this extraction at `751e7cc4d`. No blocked page, inferred
source-table value, secondary summary, or unrecorded performance claim is
used.

## Trading-source findings used

Moskowitz, Ooi, and Pedersen:

- test each instrument's own monthly return at lags one through sixty and
  report positive continuation over the first twelve monthly lags;
- form time-series-momentum positions from the sign of own past returns,
  renew mechanically each month, and report a `k=1`, `h=1` pooled commodity-
  futures portfolio; and
- explicitly include NYMEX WTI crude in the commodity universe.

Those findings support only a structural hypothesis that WTI's completed own-
price month may contain continuation information. They do not establish a
WTI-specific one-month result or the within-month residence rule below.

The source implementation uses rolling commodity futures, pooled portfolios,
excess returns, and ex-ante volatility scaling. This extraction instead uses
one immediately completed broker month of 17-23 D1 closes, one adjacent older
boundary close, a fixed three-quarter residence gate, a continuous WTI CFD,
fixed-dollar risk, and an ATR hard stop. Every difference is a QM
falsification choice.

No source alpha, return, probability, density, Sharpe ratio, drawdown, trade
count, cost, WTI-only result, CFD equivalence, or portfolio-correlation
statistic transfers.

## Bounded QM mechanization

At the first executable `XTIUSD.DWX` D1 bar of a new broker-calendar month,
reconstruct every completed D1 close whose normalized timestamp belongs to
the immediately preceding calendar month plus the adjacent older close.
Require 17 through 23 month-session closes.

For older boundary close `P` and chronological completed-month closes
`Q[0]..Q[n-1]`:

```text
above    = count(Q[j] > P), j=0..n-1
below    = count(Q[j] < P), j=0..n-1
required = ceil(3*n/4) = (3*n+3)//4
N        = ln(Q[n-1] / P)

above >= required and N > 0 => BUY XTIUSD.DWX
below >= required and N < 0 => SELL XTIUSD.DWX
otherwise                    => FLAT
```

Every month close occupies the denominator once. Exact ties count toward
neither side. Require positive finite closes and finite arithmetic. Form every
chronological log return from `P` into the month and require its sum to equal
`N` within `1e-10`. Residence surplus and endpoint magnitude never change
risk.

The fixed prior-month-end anchor translates the source's monthly return sign
into an auditable path-quality gate: the close path must occupy the eventual
endpoint side for at least three quarters of the completed month. The D1
horizon, residence fraction, fixed anchor, CFD mapping, risk, and execution
lifecycle are untested QM choices rather than paper claims.

## Exact event contract

1. Require exact `XTIUSD.DWX`, D1, and entry no later than 180 elapsed minutes
   after the raw first host D1 bar open of a new broker month.
2. Require the newest completed D1 bar to belong to the immediately preceding
   calendar month. Within a fixed 45-bar buffer, require 17 through 23 unique
   completed-month bars in strict reverse-time order and one immediately older
   bar from the adjacent calendar month. Exclude current-month closes.
3. Reverse the selected closes into chronological order beginning with `P`.
   Require positive finite values and form one log return ending on every
   completed-month session, without gap, overlap, duplicate, or omitted
   endpoint.
4. Count every month close strictly above and below `P`, retaining exact ties
   only in `n`. Compute `required=(3*n+3)//4`, `N=log(Q[n-1]/P)`, and the
   chronological return sum. Require endpoint identity within `1e-10`.
5. Follow `N` only when the matching residence count is at least `required`.
   Equality, endpoint disagreement, or invalid state consumes the month flat.
6. Persist current decision `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, or order submission. No outcome may retry that month.
7. Open at most one position with aggregate `RISK_FIXED=1000`, a frozen
   `3.5 * ATR(20,D1)` hard stop, no target, and a 1,500-point spread ceiling.
8. Close on the first tick in a later broker month, with a forty-calendar-day
   stale repair. Flatten malformed, duplicated, wrong-symbol, wrong-magic, or
   stopless owned exposure immediately.

## Non-duplicate boundary

The fail-closed canonical checker found no exact or fuzzy collision across
4,629 registry identities, 1,297 cards, and 45 Strategy-Wiki nodes. Evidence
is
`artifacts/qm5_wti_mopen_residence_mom_preallocation_dedup_20260823.json`.

Manual semantic review fixes a new WTI mechanic:

- `QM5_20187_wti-tsmom1m` uses only the completed-month endpoint return. This
  extraction also requires exhaustive fixed-anchor close residence.
- `QM5_41111_wti-mdaybreadth-mom` counts signs of adjacent daily returns and
  discards the cumulative path. This extraction compares every close with one
  immutable older boundary; the two statistics can disagree.
- `QM5_41114`, `QM5_41115`, and `QM5_41117` vote on halves, thirds, or the
  late half. This extraction has no fixed calendar block.
- `QM5_41122` orders extremes. This extraction counts every close without
  selecting or ordering extreme states.
- `QM5_41124`, `QM5_41126`, and `QM5_41127` use return magnitudes, path norms,
  or adjacent centered-return products. This extraction uses only strict
  fixed-anchor close comparisons and the endpoint sign.
- `QM5_41120_xauxag-mopen-residence-rv` uses a synchronized two-leg relative
  ratio, an in-month first-close anchor, and a contrarian package. This
  extraction uses an older WTI boundary close and outright continuation.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback.

The exact WTI carrier, completed month, older boundary, all month closes,
strict comparison and tie handling, integer ceiling three-quarter gate,
endpoint confirmation, continuation side, consumed monthly attempt, fixed
risk, and next-month exit are jointly load-bearing. Verdict:
`CLEAN_WTI_COMPLETED_MONTH_FIXED_OPEN_RESIDENCE_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Reputable-source criteria

- R1: `PASS_WITH_OPEN_RESIDENCE_TRANSLATION_RISK`. The governed child
  preserves a named peer-reviewed trading paper, DOI, complete-read evidence,
  durable hashes, explicit WTI membership, own-return momentum, monthly
  renewal, and deterministic residence-statistic lineage. The D1 residence
  gate and continuation mapping are untested translations.
- R2: `PASS`. Month membership, observation bounds, chronology, fixed anchor,
  exhaustive counts, ties, threshold, endpoint identity, direction, attempt,
  risk, stop, spread gate, and lifecycle are fixed.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered `XTIUSD.DWX` D1
  history plus native MT5 calendar, ATR, spread, quote, position, deal, and
  persistent state provides every runtime input.
- R4: `PASS`. Deterministic timestamps, logarithms, integer arithmetic,
  comparisons, ATR, and execution state only; no trained output, banned
  signal, external runtime feed, grid, martingale, scale-in, or pyramid.

## Claim and kill boundary

A seeded zero-drift Gaussian design reference with 20,000 paths qualifies
64.200%, 65.170%, and 60.825% of months at 17, 20, and 23 sessions. That is
roughly seven to eight decisions/year and is only a pre-result code-path and
density sanity check. Q02 must retire below five completed positions in any
full post-warm-up year, at zero trades, or with nonpositive governed
economics.

Different WTI exposure does not prove decorrelation from the certified XAU,
SP500, NDX, and XNG book. Q09 alone owns the realized portfolio result. No
failure may be rescued by changing the anchor, residence fraction, tie rule,
side, session bounds, risk, hold, or by adding a fitted mean, scale, return
threshold, volatility state, sign count, block vote, sequence, range,
seasonality, event, external, or prior-result state.

## Safety boundary

This packet supports one Strategy Card, one V5 build, strict compile/Q01, and
one paced non-live Q02 handoff only. It does not authorize a manual backtest,
live artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or decorrelation claim.
