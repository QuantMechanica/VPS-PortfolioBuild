---
source_id: MOP-WTI-TSMOM4-2026
title: WTI exact four-completed-month own-return extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-11_qm5_20280_wti_tsmom4m_g0.md
parent_source_id: MOP-TSMOM-2012
parent_sha256: C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042
created: 2026-08-11
created_by: Research+Development
cards_extracted:
  - wti-tsmom4m
---

# WTI Four-Month Time-Series Momentum Source Packet

## Approved Source Of Record

Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The governed parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It records a complete read
of the 23-page published paper retrieved from author Lasse Heje Pedersen's NYU
faculty site. The reproducible receipt
`strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json` records
the retrieval time, faculty URL, 976,459 bytes, page count 23, and PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The durable OWNER approval for this bounded child extraction is
`decisions/2026-08-11_qm5_20280_wti_tsmom4m_g0.md`. No new online page,
blocked content, or inferred source-table value is used.

## Source Findings Used

- Section 3.1 tests each instrument's own return at monthly lags one through
  sixty and reports positive continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from the sign
  of each instrument's own past return and renews positions monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.

These findings support only a pre-result test of WTI's own completed-month
return sign. The paper does not report a standalone four-month WTI result.
No source performance or CFD equivalence transfers.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct exactly
five consecutive completed `XTIUSD.DWX` month-end closes, oldest to newest.
Take the log return from the oldest endpoint to the newest. Buy when it is
positive, sell when it is negative, and consume an exact-zero or invalid state
flat. Renew at the next broker-month transition.

The fixed four-completed-month interval is selected and locked before any
Q02 result. The continuous-CFD carrier, broker-month endpoint reconstruction,
one-attempt ledger, `RISK_FIXED` sizing, ATR hard stop, spread ceiling, and
stale exit are transparent QM mechanizations. The paper does not prescribe
them. No alpha, Sharpe ratio, drawdown, trade count, cost, WTI-only result,
correlation statistic, or portfolio conclusion is imported.

## Exact Statistical Contract

For five positive finite completed month-end closes `C[0]..C[4]`, oldest to
newest:

```text
four_month_return = ln(C[4] / C[0])

signal = BUY  when four_month_return > 0
         SELL when four_month_return < 0
         FLAT when four_month_return == 0 or state is invalid
```

All five month keys must be consecutive, timestamps must increase strictly,
and `C[4]` must be the immediately prior completed broker month. Interior
endpoints prove continuity and may not be interpolated or omitted. There is
no D1-bar approximation, threshold, sign vote, average, sort, clipping,
regression, fitted parameter, moving average, oscillator, calendar direction,
external series, or prior pipeline result. Signal magnitude never scales risk.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,345 EA-registry rows and
456 cards. It found no exact identity and returned expected fuzzy matches from
the shared MOP source and `tsmom` tokens. Manual registry and mechanic review
found no WTI exact four-completed-month carrier.

Existing WTI exact-horizon systems use one, two, three, six, nine, or twelve
months, while `QM5_20056` combines six and twelve months and `QM5_20258`
votes one, three, and twelve months. `QM5_20055` also uses a fixed 63-D1-bar
approximation rather than five consecutive broker-month endpoints. Regression,
rank, robust-return, path, sign-run, recency-weighted, calendar, event, XNG,
and XAU/XAG systems observe different state objects.

The five endpoints, continuity, exact endpoint orientation, symmetric sign,
consumed attempt, and monthly renewal are jointly load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_SHARED_SOURCE_FUZZY_REVIEW`.

## Reputable-Source Criteria

- R1: PASS. Named authors, peer-reviewed *Journal of Financial Economics*
  article, DOI, author-hosted published paper, durable receipt and hash,
  complete read, and explicit WTI membership.
- R2: PASS. Endpoint count/order, continuity, return orientation, direction,
  attempt, fixed risk, hard stop, spread cap, rollover, and stale exit are
  exact and mechanical.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state provide every
  runtime input.
- R4: PASS. Deterministic logarithm and comparison only; no trained output,
  prohibited signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramiding.

## Claim And Kill Boundary

The source supports testing an own-return WTI carrier, not the efficacy of the
four-month horizon. Q02 must retire the card below five completed packages per
full post-warm-up year or on nonpositive governed economics. Downstream gates
alone own robustness and correlation. No failure may be rescued by changing
the horizon, direction, carrier, stop, hold, spread cap, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that the sleeve is already
uncorrelated.
