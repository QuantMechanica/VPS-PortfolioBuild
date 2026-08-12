---
source_id: MOP-WTI-SIGNRUN-2026
title: WTI dominant sign-run extraction from Time Series Momentum
publisher: QuantMechanica governed extraction of Journal of Financial Economics source
source_type: peer_reviewed_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-10_qm5_20273_wti_signrun_tr_g0.md
parent_source_id: MOP-TSMOM-2012
created: 2026-08-10
created_by: Research+Development
cards_extracted:
  - wti-signrun-tr
---

# WTI Dominant Sign-Run Source Packet

## Approved Source Of Record

Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen (2012), "Time
Series Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The governed parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. It records a complete read
of the 23-page published paper retrieved from author Lasse Heje Pedersen's NYU
faculty site. The reproducible receipt
`strategy-seeds/sources/MOP-TSMOM-2012/retrieval_route_20260731.json` records
the retrieval time, canonical faculty URL, 976,459 bytes, page count 23, and
PDF SHA-256
`7682F8E97EB4B77591DC85E36731FF51ED031970CDDE81678108734DB9478379`.

The durable OWNER approval for this child extraction is
`decisions/2026-08-10_qm5_20273_wti_signrun_tr_g0.md`. No new online page,
blocked content, or inferred source-table value is used.

## Source Findings Used

- Section 3.1 tests each instrument's own return at monthly lags one through
  sixty and reports positive continuation over the first twelve monthly lags.
- Section 3.2 forms mechanical time-series-momentum positions from own past
  returns and renews them monthly.
- Appendix A includes NYMEX WTI crude among the commodity futures.
- The source uses liquid rolling futures, excess returns, and ex ante
  volatility scaling; it does not test a Darwinex continuous CFD.

These findings support only the broad structural hypothesis that persistence
inside WTI's prior-year own-price path may contain directional information.
They do not establish a longest-run statistic, a four-month threshold, or the
candidate's performance.

## Bounded QM Mechanization

At the first D1 bar of a genuine broker-month transition, reconstruct thirteen
consecutive completed `XTIUSD.DWX` month-end closes, oldest to newest. Form the
twelve chronological adjacent log returns. Scan their strict signs to find the
longest consecutive positive run and the longest consecutive negative run.
Buy when the positive run is at least four and strictly longer than the
negative run. Sell under the symmetric negative condition. Exact zeros break
both runs, and thresholds, ties, invalid states, and unavailable history
consume the month flat. Renew at the next broker-month boundary.

The path-run estimator, fixed four-month threshold, strict unique-direction
rule, exact endpoint count, CFD mapping, fixed-risk sizing, stop, spread cap,
and lifecycle are transparent QM mechanizations. The paper does not prescribe
them. No source return, alpha, Sharpe ratio, drawdown, trade count, cost,
WTI-only result, CFD equivalence, or portfolio-correlation statistic transfers.

## Exact Statistical Contract

For thirteen positive finite completed month-end closes `C[0]..C[12]`, oldest
to newest:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11

positive return: extend current positive run; reset current negative run
negative return: extend current negative run; reset current positive run
zero return:     reset both current runs

L+ = maximum positive-run length over r[0]..r[11]
L- = maximum negative-run length over r[0]..r[11]

signal = BUY  when L+ >= 4 and L+ > L-
         SELL when L- >= 4 and L- > L+
         FLAT otherwise
```

The scan is chronological. A run may begin at any location in the twelve-
return window, but may not cross an exact-zero return or the window boundary.
Return magnitude and run location do not scale risk. The current decision
month contributes no endpoint. There is no fallback to a cumulative return,
fixed quarterly partition, nested-horizon vote, unordered sign count, mean,
median, trimmed mean, regression, rank statistic, moving average, oscillator,
calendar direction, external series, or prior pipeline result.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,333 EA-registry rows and
446 intake cards. It found no exact identity and no fuzzy match above its
threshold.

Manual review separates this rule from pure WTI TSMOM, which uses one
cumulative endpoint return; sign-count cards, which discard adjacency;
`QM5_20258_wti-mom-vote`, which votes nested cumulative horizons;
`QM5_20272_wti-qtrvote-tr`, which votes four fixed quarterly blocks; OLS,
ordinal, and Theil-Sen trend estimators over price levels; and median or
trimmed-mean aggregators that sort returns and retain magnitude.

The thirteen endpoints, twelve chronological adjacent returns, strict sign
classification, zero reset, maximum-run update, four-month threshold, unique-
direction tie rule, symmetric map, monthly attempt, and renewal clock are
jointly load-bearing. Verdict: `CLEAN`.

## Reputable-Source Criteria

- R1: PASS. Named authors, peer-reviewed *Journal of Financial Economics*
  article, DOI, author-hosted published paper, durable retrieval hash, complete
  read, and explicit WTI membership.
- R2: PASS. Endpoint count and order, log-return orientation, run update, zero
  reset, fixed threshold, strict tie rule, direction, attempt, fixed risk,
  hard stop, spread cap, rollover, and stale exit are exact and mechanical.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every runtime
  input.
- R4: PASS. Deterministic logarithm, comparisons, counters, and native
  execution state only; no trained output, prohibited signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramiding.

## Frequency Reference And Kill Boundary

Enumerating all 4,096 equiprobable non-zero sign paths of length twelve gives
a 52.44% decision-state frequency for the locked condition `max(L+,L-) >= 4`
with unequal longest runs, or about 6.29 monthly packages/year before costs,
missing history, and execution gates. This is a transparent design reference,
not market evidence. Q02 must retire the card below five completed packages per
full post-warm-up year or on nonpositive governed economics.

Downstream gates alone own robustness and correlation. No failure may be
rescued by changing the lookback, run definition, threshold, tie treatment,
direction, carrier, stop, hold, spread cap, or retry contract.

## Safety Boundary

This packet supports research, one V5 build, strict compile/Q01, and one paced
non-live Q02 handoff only. It does not authorize a manual backtest, live
artifact, `T_Live`, AutoTrading, deploy manifest, portfolio-gate change,
portfolio admission, correlation waiver, or claim that the sleeve is already
uncorrelated.
