---
source_id: MOP-CME-WTI-BRENT-CFM-2026
title: WTI time-series momentum with Brent benchmark confirmation
publisher: Journal of Financial Economics / CME Group / U.S. EIA / ICE
source_type: peer_reviewed_plus_exchange_agency_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-14_qm5_21518_wti_brent_cfm_g0.md
parent_source_ids:
  - MOP-TSMOM-2012
  - CME-WTI-BRENT-SPREAD-2026
created: 2026-08-14
created_by: Research+Development
cards_extracted:
  - wti-brent-cfm
---

# WTI Trend With Brent Benchmark Confirmation Source Packet

## Approved sources of record

This bounded extraction uses two already approved repository packets. Both
packets were read completely before the card was written:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, covering Moskowitz,
   Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. Its complete published-paper receipt and
   SHA-256 are preserved in the parent packet. WTI is explicitly in the
   source commodity universe.
2. `strategy-seeds/sources/CME-WTI-BRENT-SPREAD-2026/source.md`, covering
   CME's exchange-traded WTI-Brent financial contract, ICE's Brent/WTI
   futures-spread contract, and EIA analysis of the two crude benchmarks.

The OWNER commodity/energy mission delivered on 2026-08-14 is the durable
approval authority for one structural WTI card, deterministic allocation,
non-live build, strict Q01 validation, and one paced Q02 handoff. No blocked
page, inferred table, unpublished statistic, or runtime external feed is used.

## Findings used

- Moskowitz, Ooi, and Pedersen define monthly time-series momentum from the
  sign of an instrument's own past return, report a selected twelve-month
  family, and explicitly include WTI crude oil among the commodity futures.
- CME and ICE establish WTI and Brent as separately traded but directly
  related global crude-oil benchmarks. EIA explains that their relationship
  reflects common crude fundamentals as well as location, transport,
  inventory, and geopolitical differences.
- The parent source packets do not test a rule that trades WTI only when
  Brent's independently measured trend has the same sign.

These findings support a falsifiable question: does requiring agreement
between the two principal crude benchmarks reduce idiosyncratic continuous-
CFD noise while retaining WTI's structural trend exposure? The sources do not
answer that question or establish profitability, diversification, or
correlation to the QM book.

## Bounded mechanization

At the first processed `XTIUSD.DWX` D1 bar after a genuine broker-month
transition, reconstruct exactly thirteen consecutive completed broker-month
endpoints for both `XTIUSD.DWX` and read-only `XBRUSD.DWX`. The latest endpoint
must belong to the immediately completed broker month, the endpoints for both
symbols must share exact timestamps, and the newest common endpoint must be no
more than ten calendar days stale.

For each benchmark compute the exact twelve-completed-month log return:

```text
wti_trend   = ln(WTI_month_end_latest / WTI_month_end_12_months_ago)
brent_trend = ln(Brent_month_end_latest / Brent_month_end_12_months_ago)
```

For each leg independently, the endpoint return must match the sum of its
twelve component monthly log returns within `1e-10`.

```text
BUY WTI  when wti_trend > 0 and brent_trend > 0
SELL WTI when wti_trend < 0 and brent_trend < 0
FLAT     otherwise
```

Brent supplies confirmation only. It has no magic slot and may never be
ordered. One `RISK_FIXED=1000` WTI budget is protected by a frozen
`3.5*ATR(20,D1)` broker hard stop. Close before the next monthly decision,
repair malformed owned state immediately, and enforce a forty-calendar-day
stale guard. Persist the month as attempted before any history, signal,
spread, quote, stop, sizing, or order check; there is no same-month retry.

The exact timestamp intersection, twelve-month horizon, strict same-sign
test, continuous CFD mapping, no-magnitude threshold, WTI-only execution,
fixed risk, ATR stop, spread cap, attempt ledger, and lifecycle are transparent
QM hypotheses. No source result transfers to them.

## Non-duplicate boundary

The canonical pre-allocation checker found no exact slug or strategy-ID
collision across 4,390 EA-registry rows and 486 cards. It emitted four lexical
fuzzy matches that were manually separated:

- `QM5_12848_wti-brent-brk` trades both benchmarks as an opposite-leg
  Brent-minus-WTI D1 channel-breakout basket. This card trades only WTI and
  uses two independently reconstructed twelve-month return signs.
- `QM5_12843_wti-brent-spread` and `QM5_12860_wti-brent-rshock` trade paired
  relative-value convergence. This card neither calculates nor orders a
  benchmark spread.
- `QM5_12603_wti-tsmom12m` is unconditional WTI trend and never reads Brent.
- Brent trend and calendar EAs trade Brent itself; internal WTI dual-horizon
  systems compare WTI to its own path rather than require cross-benchmark
  agreement.
- `QM5_12844_commodity-trend-crude` is a daily Donchian/ADX breakout, not a
  monthly completed-return confirmation rule.

The WTI carrier, synchronized thirteen-month endpoint set, independent WTI
and Brent twelve-month signs, strict agreement, Brent read-only boundary,
consumed monthly decision, and single-leg fixed-risk execution are jointly
load-bearing. Verdict:
`CLEAN_AUTHORIZED_WTI_BRENT_BENCHMARK_CONFIRMED_TREND`.

## Reputable-source criteria

- R1: PASS. The single card lineage is this bounded composite packet, backed
  by a completely reviewed peer-reviewed JFE paper and governed CME, ICE, and
  EIA benchmark records.
- R2: PASS. Endpoints, return arithmetic, strict sign mapping, traded/read-only
  roles, attempt state, sizing, stop, spread cap, renewal, and stale exit are
  mechanical.
- R3: PASS. Registered `XTIUSD.DWX` and `XBRUSD.DWX` D1 histories plus native
  MT5 position state supply every runtime input. Only WTI is traded.
- R4: PASS. The runtime uses deterministic calendar, OHLC, logarithm, ATR,
  spread, quote, position, and deal-state arithmetic without a trained signal,
  adaptive PnL fit, grid, martingale, scale-in, or pyramid.

## Claim, kill, and safety boundary

The twelve-month trend family is a diversified-futures source result, not a
WTI-only CFD result. Exchange and agency references establish benchmark
structure, not a confirmation premium. Continuous-CFD rolls, synchronized
history gaps, Brent/WTI structural breaks, near-identical signals, WTI gaps,
ATR-stop slippage, and outright crude beta are first-order risks.

Q02 must retire the card below five completed positions per full post-warm-up
year or on nonpositive governed economics. Downstream gates alone own
robustness and portfolio correlation. Failure may not be rescued by changing
the horizons, sign rule, symbols, traded leg, stop, hold, spread, or retry
contract.

This packet authorizes one non-live V5 build, strict compile/Q01, one
`RISK_FIXED` backtest setfile, and one paced Q02 handoff while factory capacity
permits. It does not authorize a manual backtest, live/demo/shadow/stress
artifact, optimization, AutoTrading, `T_Live`, a deploy manifest, portfolio
admission, a portfolio-gate change, or a correlation waiver.
