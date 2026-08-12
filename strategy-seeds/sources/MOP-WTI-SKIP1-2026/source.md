---
source_id: MOP-WTI-SKIP1-2026
title: WTI skip-one-month trend extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-11_qm5_20284_wti_skip1_trend_g0.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-11
created_by: Research+Development
cards_extracted:
  - wti-skip1-trend
---

# WTI Skip-One-Month Trend Source Packet

## Approved Source Of Record

Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The governed parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It records a complete read
of the 23-page published paper retrieved from author Lasse Heje Pedersen's NYU
faculty site. The reproducible receipt
`strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json` records
the retrieval time, canonical faculty URL, 976,459 bytes, 23 pages, and PDF
SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The durable OWNER approval for this child extraction is
`decisions/2026-08-11_qm5_20284_wti_skip1_trend_g0.md`. No new online page,
blocked content, or inferred source-table value is used.

## Source Findings Used

- Section 3.1 tests each instrument's own return at monthly lags one through
  sixty and reports positive continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns and renews them monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.

These findings support only the broad structural hypothesis that a delayed
twelve-month WTI own-return state may retain directional information. They do
not establish that discarding the newest completed month improves results.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct fourteen
consecutive completed `XTIUSD.DWX` month-end closes. The newest close is the
end of month `t-1`; validate but exclude the `t-2` to `t-1` return. Compute the
exact twelve-month log return from the end of `t-14` to the end of `t-2`.
Buy when that delayed return is positive, sell when it is negative, and
consume the month flat when it is exactly zero or invalid. Renew at the next
broker-month boundary.

The skipped-month construction, exact endpoint convention, continuous-CFD
carrier, broker-month reconstruction, one-attempt ledger, `RISK_FIXED`
sizing, ATR hard stop, spread ceiling, and stale exit are transparent QM
mechanizations. The paper does not prescribe them. No source return, alpha,
Sharpe ratio, drawdown, trade count, cost, WTI-only result, CFD equivalence,
or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For fourteen positive finite completed month-end closes in reverse
chronological order:

```text
M0  = end(t-1), deliberately skipped
M1  = end(t-2), trend endpoint
M13 = end(t-14), trend start

skipped_return = ln(M0 / M1)
trend_return   = ln(M1 / M13)

signal = BUY  when trend_return > 0
         SELL when trend_return < 0
         FLAT when trend_return == 0 or state is invalid
```

`skipped_return` must be finite but cannot gate, confirm, reverse, or size the
trade. The current decision month contributes no endpoint. There is no
fallback to a return including `M0`, another horizon, moving average, rank,
regression, vote, calendar direction, external series, or prior result.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,349 EA-registry rows and
460 root cards. It found no exact identity and returned three shared-source
fuzzy matches. Manual review separates the rule from WTI 1/3/12 voting, WTI
four-month trend, and XNG voting. Additional review separates it from the
ordinary trailing WTI twelve-month rule and `QM5_20239` pre-pullback trend.

The ordinary trailing rule ends at `M0`. `QM5_20239` uses `M1/M13` only when
`M0/M1` has the opposite sign. This rule always ignores `M0/M1` and trades the
nonzero sign of `M1/M13`. The fourteen endpoints, excluded newest interval,
absence of a skipped-return gate, monthly attempt, and monthly renewal are
jointly load-bearing. Verdict: `CLEAN_AFTER_FUZZY_AND_MECHANIC_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. Named authors, peer-reviewed *Journal of Financial Economics*
  article, DOI, author-hosted complete paper, durable retrieval hash, complete
  read, and explicit WTI membership.
- R2: PASS. Endpoint count and order, excluded interval, return orientation,
  direction, attempt, fixed risk, hard stop, rollover, and stale exit are exact.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every input.
- R4: PASS. Deterministic logarithm and native execution state only; no trained
  output, prohibited signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing an own-return WTI carrier, not the efficacy of the
skip-one rule. Q02 must retire the card below five completed packages per full
post-warm-up year or on nonpositive governed economics. Downstream gates alone
own robustness and correlation. No failure may be rescued by changing the
horizon, excluded interval, direction, carrier, stop, hold, spread, or retry
contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or a claim of decorrelation.
