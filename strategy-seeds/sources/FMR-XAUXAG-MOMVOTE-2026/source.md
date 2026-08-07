---
source_id: FMR-XAUXAG-MOMVOTE-2026
title: Fuertes-Miffre-Rallis XAU/XAG one-three-twelve-month cross-sectional momentum vote extraction
publisher: Journal of Banking & Finance / institutional accepted manuscript
source_type: peer_reviewed_paper_with_complete_read_record
status: approved
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-07
primary_url: https://doi.org/10.1016/j.jbankfin.2010.04.009
parent_packet: strategy-seeds/sources/FMR-MOMTS-2010/source.md
strategy_ids:
  - FMR-MOMTS-2010_XAU_XAG_MAJ1312_S05
---

# Fuertes-Miffre-Rallis XAU/XAG Multi-Horizon Momentum Vote Source Packet

## Source Identity And Complete-Read Record

Fuertes, Ana-Maria, Joelle Miffre, and Georgios Rallis (2010), "Tactical
Allocation in Commodity Futures Markets: Combining Momentum and Term
Structure Signals," *Journal of Banking & Finance* 34(10), 2530-2548, DOI
`10.1016/j.jbankfin.2010.04.009`.

The governed parent packet
`strategy-seeds/sources/FMR-MOMTS-2010/source.md` records an end-to-end review
of the complete 47-page accepted manuscript in the City Research Online
institutional repository. Pages 6-7 define average-past-return commodity
momentum ranks, and pages 17-18 report one-, three-, and twelve-month formation
horizons with a one-month hold. The paper uses a broad commodity-futures
cross-section. The repository already carries separate governed XAU/XAG
one-, three-, and twelve-month translations of those source-family ranks.

This extraction combines those three pre-existing source-defined horizon
states by a fixed majority vote. The aggregation and two-metal CFD carrier are
transparent QM hypotheses and are not attributed to the authors. No horizon,
vote, tie threshold, stop, holding rule, or carrier was selected from Darwinex
results.

## Locked Multi-Horizon Rule

At the first tradable XAU D1 bar of each broker month, reconstruct thirteen
consecutive synchronized completed broker-month-end closes for both XAU and
XAG. Store them newest-to-oldest as `C_i[0]..C_i[12]` for metal `i`. For each
formation horizon `h` in `{1,3,12}`, define:

```text
A_i(h) = (1/h) * sum(C_i[k] / C_i[k+1] - 1, k=0..h-1)
D(h)   = A_XAU(h) - A_XAG(h)
vote   = sign(D(1)) + sign(D(3)) + sign(D(12))
```

Every endpoint must have a matching timestamp and month key across the two
metals. Month keys must be consecutive, the newest endpoint must belong to the
immediately preceding broker month, prices must be positive, and every
calculation must be finite. Require `abs(D(h)) > 1e-10` at all three horizons:

- `vote > 0`: buy XAU and sell XAG for the new broker month;
- `vote < 0`: sell XAU and buy XAG for the new broker month;
- a tied component, invalid/nonconsecutive history, timestamp mismatch, or
  invalid arithmetic: consume the month flat.

Because all three comparisons must be valid, the vote is one of
`{-3,-1,1,3}`. Vote magnitude does not change risk. Both a 2-1 majority and a
3-0 majority use one shared governed package budget.

## Bounded QM Mechanization

The V5 carrier derives completed month ends from bounded native
`XAUUSD.DWX` and `XAGUSD.DWX` D1 history because synchronized MN1 history is
not assumed in the tester. The two opposite legs split one fixed cash-risk
budget equally after independent ATR normalization. Each leg receives a
frozen `3.5 * ATR(20,D1)` hard stop. A partially opened, duplicate,
same-direction, wrong-symbol, wrong-magic, or missing-stop package is flattened
immediately.

The prior package closes at the next broker-month transition before the new
vote is considered. The EA persists one consumed attempt per broker month
before history, signal, news, spread, quote, sizing, stop, or order gates. A
forty-calendar-day stale guard, 1,500-point XAU spread ceiling, 3,000-point XAG
spread ceiling, restart-safe attempt ledger, and atomic leg repair are QM
risk/execution controls rather than source claims.

The source uses diversified collateralized futures portfolios. This carrier
uses only two continuous Darwinex CFDs and does not reproduce futures-chain
rolls, collateral returns, source portfolio breadth, or source weighting.
Opposite precious-metal directions express market-neutral construction intent,
not proof of dollar, beta, volatility, industrial-demand, or portfolio
neutrality. Q02 must falsify density and economics; Q09 alone may measure
realized overlap with the certified XAU/SP500/NDX/XNG book.

Runtime reads only native MT5 D1 time/close, ATR, quotes, spread, broker
calendar, positions, deal history, symbol metadata, and V5 framework state. It
does not read a futures curve, external file or API, volume, open interest,
inventory, analyst input, optimizer result, trained output, or portfolio
state.

## Reputable-Source Criteria

- R1: PASS. The parent packet records a complete read of a peer-reviewed
  *Journal of Banking & Finance* paper with DOI and a complete accepted
  manuscript in an institutional repository. The one-, three-, and twelve-
  month momentum ranks and one-month hold are explicit.
- R2: PASS. Thirteen synchronized endpoints, three arithmetic-average return
  ranks, strict no-tie comparisons, majority mapping, shared risk, atomic
  execution, monthly renewal, attempt persistence, hard stops, spread caps,
  stale exit, and repair are deterministic.
- R3: PASS. `XAUUSD.DWX` and `XAGUSD.DWX` D1 are registered and have an
  established logical-basket tester route; runtime needs no external data.
- R4: PASS. Native simple-return, calendar, ATR, position, and history
  arithmetic only; no adaptive fit, banned signal indicator, grid, martingale,
  pyramiding, or multiple positions per magic.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,317 registry rows and 434
cards, found no exact collision, and surfaced seven expected fuzzy neighbors.
Manual review fixes the boundary:

- `QM5_20057`, `QM5_20184`, and `QM5_20050` rank only the one-, three-, or
  twelve-month XAU/XAG formation horizon, respectively. This extraction
  requires all three non-tied ranks and trades their majority.
- `QM5_13126` combines one-month XTI/XNG momentum with a broker-swap proxy;
  `QM5_20051` ranks XTI/XNG on one month. Neither uses the precious-metals
  carrier or a three-horizon vote.
- `QM5_20258` and `QM5_20259` vote on one instrument's own cumulative return
  signs for WTI or XNG. This extraction votes on cross-sectional XAU-minus-XAG
  arithmetic-average-return ranks and executes two opposite legs.
- Ratio, residual, return-spread, volatility-rank, reversal, calendar,
  conditional-quantile, and other XAU/XAG baskets use different states.

A content-level scan found no existing XAU/XAG intake card that requires a
majority or vote. The carrier, endpoint synchronization, exact three horizons,
strict no-tie rule, cross-sectional rank vote, shared risk, consumed attempt,
and monthly renewal are jointly load-bearing. This packet does not authorize
adjacent horizon votes or post-result parameter rescue.

## Claim Boundary

The paper supports broad cross-sectional commodity momentum ranks at the three
formation horizons. It does not claim that this majority vote or two-name CFD
subset is profitable, neutral, frequent enough, cost-feasible, or diversifying.
No source return, alpha, Sharpe ratio, drawdown, trade count, cost, XAU/XAG
constituent result, or correlation statistic transfers.

## Safety Boundary

This packet authorizes one logical-basket `RISK_FIXED` research/backtest
carrier only. It does not authorize a live, demo, shadow, stress, or
optimization setfile; manual backtest; AutoTrading; `T_Live`; deploy or T_Live
manifest; portfolio admission; portfolio-gate edit; or correlation waiver.
