---
source_id: MOP-XNG-MOMVOTE-2026
title: Moskowitz-Ooi-Pedersen XNG one-three-twelve-month momentum vote extraction
publisher: Journal of Financial Economics / author-hosted published paper
source_type: peer_reviewed_paper_with_complete_read_record
status: approved
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-07
primary_url: https://doi.org/10.1016/j.jfineco.2011.11.003
parent_packet: strategy-seeds/sources/MOP-TSMOM-2012/source.md
strategy_ids:
  - MOP-TSMOM-2012_XNG_MAJ1312_S13
---

# Moskowitz-Ooi-Pedersen XNG Multi-Horizon Momentum Vote Source Packet

## Source Identity And Complete-Read Record

Moskowitz, Tobias J., Yao Hua Ooi, and Lasse Heje Pedersen (2012),
"Time Series Momentum," *Journal of Financial Economics* 104(2), 228-250,
DOI `10.1016/j.jfineco.2011.11.003`.

The governed parent packet
`strategy-seeds/sources/MOP-TSMOM-2012/source.md` records an end-to-end review
of the complete 23-page published paper, its author-hosted retrieval receipt,
and PDF SHA-256. The paper's monthly trading family takes the sign of an
instrument's own past `k`-month excess return, goes long after a positive
return and short after a negative return, and includes natural gas in the
commodity-futures universe. The paper studies monthly lags one through sixty;
the repository already carries separate governed XNG one-, three-, and
twelve-month return-sign implementations.

This extraction combines those three pre-existing source-family states by a
fixed majority vote. The aggregation is a transparent QM hypothesis and is not
attributed to the authors. No horizon, vote, threshold, direction, stop, or
holding rule was chosen from Darwinex results.

## Locked Multi-Horizon Rule

At the first tradable D1 bar of each broker month, reconstruct thirteen
consecutive completed XNG broker-month-end closes in chronological order
`C[0]..C[12]`, where `C[12]` is the immediately preceding month end. Define:

```text
R1  = ln(C[12] / C[11])
R3  = ln(C[12] / C[9])
R12 = ln(C[12] / C[0])

vote = sign(R1) + sign(R3) + sign(R12)
```

Each component must be finite and strictly nonzero. Because three valid signs
are used, `vote` is one of `{-3,-1,1,3}`:

- `vote > 0`: long XNG for the new broker month;
- `vote < 0`: short XNG for the new broker month;
- zero component, invalid/nonconsecutive history, or invalid arithmetic: flat
  for the consumed month.

The one-month component represents the newest short state, the three-month
component the intermediate state, and the twelve-month component the slow
state. Two aligned faster states can therefore override a stale slow state,
while agreement across all three produces the same direction. Vote magnitude
does not change Q02 risk; every valid package uses the same governed fixed-risk
budget.

## Bounded QM Mechanization

The V5 carrier derives completed month ends from bounded `XNGUSD.DWX` D1
history because native MN1 history is not guaranteed in the tester. It closes
the prior package at the next month boundary, persists one consumed attempt per
broker month before signal and execution gates, and renews at most one package
for that month. A frozen `3.5 * ATR(20,D1)` hard stop, forty-calendar-day stale
guard, 3,000-point spread ceiling, fixed-risk sizing, and restart-safe month
ledger are explicit QM risk/execution controls rather than source claims.

The source uses rolling liquid futures excess returns and ex ante volatility
scaling, whereas `XNGUSD.DWX` is a continuous Darwinex CFD proxy. Roll
construction, excess-return equivalence, financing, gaps, costs, and
single-instrument concentration are unproven. Q02 must falsify density and
economics. Q09 alone may measure realized overlap with the certified
XAU/SP500/NDX/XNG book; different logic on the same underlying is not assumed
to be decorrelated.

Runtime reads only native MT5 D1 time/close, ATR, quotes, spread, broker
calendar, positions, deal history, symbol metadata, and V5 framework state. It
does not read a futures curve, inventory, volume, open interest, external file
or API, analyst input, optimizer output, or trained output.

## Reputable-Source Criteria

- R1: PASS. The parent packet records a complete read of a peer-reviewed
  *Journal of Financial Economics* article with DOI and author-hosted published
  text; natural gas and monthly own-return sign rules are explicit.
- R2: PASS. Thirteen endpoints, three nested returns, strict signs, majority
  mapping, monthly renewal, attempt persistence, hard stop, spread cap, and
  stale exit are deterministic.
- R3: PASS. `XNGUSD.DWX` D1 is registered and has an established T1-T5 tester
  route; runtime requires no external data.
- R4: PASS. Native logarithm, calendar, ATR, position, and history arithmetic
  only; no adaptive fit, banned signal indicator, grid, martingale,
  pyramiding, or multiple positions per magic.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,316 registry rows and 433
cards, found no exact collision, and surfaced three expected source-family fuzzy
neighbors. Manual review fixes the boundary:

- `QM5_20258` is the WTI carrier of this vote. The exact XNG carrier is
  load-bearing and receives no transferred WTI evidence.
- `QM5_20204`, `QM5_20063`, and `QM5_12804` follow one XNG horizon alone; the
  twelve-month sibling also requires a volatility corridor.
- `QM5_13116` compares the breadth of twelve separate monthly return signs
  with 0.40, not three nested cumulative horizons.
- `QM5_12358` votes on rolling 20/60/120 D1-bar returns, evaluates daily,
  exits on daily vote reversal, and does not register XNG.
- `QM5_12567` uses a long-only two-day cumulative RSI(2) pullback and a
  five-D1-bar maximum hold, not a symmetric monthly trend vote.
- XNG calendar, storage, weather, memory, reversal, ratio, carry, breakout,
  and event systems use different states.

The XNG carrier, completed calendar-month endpoints, three exact horizons,
strict nonzero components, majority mapping, monthly attempt clock, and package
renewal are jointly load-bearing. This packet does not authorize adjacent
horizon votes or post-result parameter rescue.

## Safety Boundary

This packet authorizes one `RISK_FIXED` research/backtest carrier only. It does
not authorize a live/demo/shadow setfile, manual backtest, AutoTrading,
`T_Live`, deploy or T_Live manifest, portfolio admission, portfolio-gate edit,
or correlation waiver.
