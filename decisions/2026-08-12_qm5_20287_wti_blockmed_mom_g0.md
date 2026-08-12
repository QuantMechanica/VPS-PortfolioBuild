# QM5_20287 WTI Block Median-of-Means Trend G0 Authorization

Date: 2026-08-12

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch.

## Decision

Authorize one bounded V5 Strategy Card and non-live build for
`QM5_20287_wti-blockmed-mom`. At each genuine broker-month transition, the
candidate reconstructs twelve completed WTI monthly log returns, partitions
them chronologically into four non-overlapping three-month blocks, and trades
the sign of the even median of the four block arithmetic means. It renews one
outright `XTIUSD.DWX` package monthly.

The candidate may proceed through bounded source/card extraction, schema and
G0 lint, deterministic registry and magic allocation, resolver regeneration,
strict compile, one `RISK_FIXED` backtest setfile, Q01 validation, and one paced
Q02 enqueue. This authorization does not pre-approve efficacy,
diversification, decorrelation, certification, execution-contract promotion,
or portfolio admission.

## Source Boundary

The approved trading source of record is the complete governed packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, covering Moskowitz, Ooi,
and Pedersen (2012), "Time Series Momentum," *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. Its
retrieval receipt records an end-to-end read of the 23-page published paper,
the author-hosted route, byte and page counts, and PDF SHA-256. The paper
reports positive own-return continuation across the first twelve monthly lags,
defines monthly own-return-sign positions, and includes NYMEX WTI crude in its
commodity universe.

The chronological block median-of-means below is a transparent QM robust-
aggregation mechanization, not a claim imported from the trading paper. The
paper does not prescribe four blocks, three returns per block, the even-median
convention, the Darwinex continuous-CFD port, broker-month reconstruction,
fixed-dollar sizing, ATR stop, spread ceiling, restart ledger, or lifecycle
controls. No source return, WTI-specific alpha, trade density, CFD equivalence,
correlation result, or portfolio conclusion transfers.

## Locked Rule

On the first processed `XTIUSD.DWX` D1 bar after a genuine broker-month
transition, reconstruct exactly thirteen consecutive completed broker-month
closes `C[0]..C[12]`, oldest to newest, and define:

```text
r[i] = ln(C[i+1] / C[i]), i = 0..11
b[0] = (r[0] + r[1] + r[2]) / 3
b[1] = (r[3] + r[4] + r[5]) / 3
b[2] = (r[6] + r[7] + r[8]) / 3
b[3] = (r[9] + r[10] + r[11]) / 3
s = ascending copy of b
block_median = (s[1] + s[2]) / 2

signal = BUY  when block_median > 0
         SELL when block_median < 0
         FLAT when block_median == 0 or state is invalid
```

The position is opened with one fixed `RISK_FIXED=1000` budget and a frozen
`3.5 * ATR(20,D1)` hard stop, without take-profit. Close the prior package on
the first processed D1 bar of the next broker month before considering a new
entry. A forty-calendar-day stale guard closes a missed rollover. Persist the
current month as consumed before history, signal, spread, quote, news, sizing,
or order checks; no failed or flat attempt retries within the month. Friday
close and both news axes are OFF. At most one position exists for the magic.

## Reputable-Source Criteria

- R1: PASS. Exactly one canonical source lineage, backed by a named peer-
  reviewed trading paper, DOI, author-hosted complete paper, durable retrieval
  hash, complete read, and explicit WTI membership.
- R2: PASS. Endpoint count and order, adjacent return orientation, four fixed
  chronological blocks, divisor three, even-median indexes, direction,
  attempt, risk, hard stop, rollover, and stale exit are exact.
- R3: PASS. Registered `XTIUSD.DWX` D1 history plus native MT5 calendar,
  spread, ATR, quote, position, deal, and framework state supply every input.
- R4: PASS. Deterministic logarithm, addition, division, and sorting only; no
  trained output, prohibited signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramiding.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,352 EA-registry rows and 464
root cards. It found no exact identity and no fuzzy match above threshold.
Manual family review resolved the closest structural neighbors:

- `QM5_20272_wti-qtrvote-tr` takes four non-overlapping three-month endpoint
  returns and requires at least three same-sign blocks. This candidate retains
  block magnitude, sorts four block means, and can trade a two-positive /
  two-negative split according to the average of the two inner block means.
- `QM5_20269_wti-medret-mom` sorts twelve individual one-month returns and
  averages middle indexes 5 and 6; it does not preserve or aggregate the four
  chronological three-month blocks.
- `QM5_20270_wti-trimmean-mom` sorts all twelve one-month returns, removes two
  observations from each tail, and averages eight values; it neither forms
  block means nor selects the middle two blocks.
- Cumulative, sign/run/vote, recency-weighted, cap/Winsor, iterative robust-
  location, regression, rank, path-efficiency, and skip-month systems use
  different functionals or endpoint objects.

The exact four chronological blocks, three adjacent returns per block, equal
within-block magnitude weights, even median from sorted indexes 1 and 2, and
nonzero two-versus-two resolution are jointly load-bearing. Verdict:
`CLEAN_AFTER_MANUAL_BLOCK_NEIGHBOR_REVIEW`.

## Allocation And Kill Boundary

- intended EA ID: `QM5_20287`, subject to deterministic registry allocation;
- slug: `wti-blockmed-mom`;
- strategy ID: `MOP-TSMOM-2012_XTI_BLOCKMED12_S35`;
- intended symbol/slot/magic: `XTIUSD.DWX` / 0 / `202870000`;
- expected cadence: approximately eleven to twelve completed monthly packages
  per full post-warm-up year; Q02 owns observed density and economics;
- retire below five completed packages per full post-warm-up year, on
  nonpositive governed economics, or later portfolio-correlation rejection;
- fail on malformed endpoints, wrong return orientation, nonconsecutive or
  overlapping blocks, wrong block count/width/divisor, sorting individual
  returns instead of block means, wrong even-median indexes, sign-only voting,
  wrong-side entry, repeated attempt, missing hard stop, risk mismatch, hold
  beyond forty days, or nondeterminism; and
- no post-result horizon, block, direction, stop, hold, spread, retry, or
  carrier rescue is authorized.

WTI is a crude-oil carrier absent from the current XAU/SP500/NDX/XNG book.
That carrier difference and robust slow-trend state are diversification
hypotheses, not correlation evidence; unchanged Q09 alone may measure overlap.

## Safety Boundary

This authorization excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; `T_Live`; AutoTrading; deploy or T_Live manifests;
portfolio admission; portfolio-gate edits; and correlation waivers. Q02 uses
exactly one `XTIUSD.DWX` D1 setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. If the paced farm reaches its
binding backtest CPU ceiling before enqueue, record the stop and do not enqueue
or run a manual test.
