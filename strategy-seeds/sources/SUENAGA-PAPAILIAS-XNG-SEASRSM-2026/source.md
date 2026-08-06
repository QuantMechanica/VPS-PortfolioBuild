---
source_id: SUENAGA-PAPAILIAS-XNG-SEASRSM-2026
title: XNG seasonal volatility-window return-sign momentum
publisher: Journal of Futures Markets; Journal of Banking & Finance
source_type: composite_peer_reviewed_source_packet
status: approved_source_complete
approval_basis: OWNER commodity/energy sleeve mission delivered 2026-08-06
created: 2026-08-06
created_by: Research+Development
parent_sources:
  - SUENAGA-XNG-SEASVOL-2008
  - PAPAILIAS-RSM-2021
cards_extracted:
  - xng-rsm-window
---

# Suenaga-Papailias XNG Seasonal RSM Source Packet

## Approval And Complete-Read Record

The OWNER mission delivered on 2026-08-06 authorizes one new structural,
low-frequency commodity/energy card and non-live build. This bounded packet
combines two already governed, completely read peer-reviewed sources:

- Suenaga, Hiroaki; Smith, Aaron; and Williams, Jeffrey C. (2008),
  "Volatility Dynamics of NYMEX Natural Gas Futures Prices," *Journal of
  Futures Markets* 28(5), 438-463, DOI `10.1002/fut.20317`. The complete
  26-page paper, including the POTS model, data, estimates, hedging
  application, conclusion, and references, is recorded at
  `strategy-seeds/sources/SUENAGA-XNG-SEASVOL-2008/source.md`.
- Papailias, Fotis; Liu, Jiadong; and Thomakos, Dimitrios D. (2021),
  "Return Signal Momentum," *Journal of Banking & Finance* 124, Article
  106063, DOI `10.1016/j.jbankfin.2021.106063`. The complete accepted
  manuscript, including Appendices A-I and individual-instrument Tables
  G.1-G.3, is recorded at
  `strategy-seeds/sources/PAPAILIAS-RSM-2021/source.md`.

Both parent packets were read completely again for this extraction. Their
source identities, page-level method locations, applicability, adverse
evidence, and proxy limits remain authoritative.

## Findings Used

Suenaga, Smith, and Williams establish that natural-gas futures volatility is
materially seasonal and identify two broad physical-market information
windows: early May through late September and early November through
mid-January. Storage capacity, seasonal demand, and the limited ability of
inventories to buffer shocks provide the structural explanation. The paper
does not establish a return direction or a profitable trading rule.

Papailias, Liu, and Thomakos explicitly include natural gas in their futures
panel. Their fixed RSM0.4 rule converts the prior twelve completed monthly
returns to binary signs, calculates the equal-weight non-negative-return share,
holds long when that share is at least `0.40`, otherwise short, and renews
monthly. The paper's adaptive threshold is excluded.

## Bounded Mechanization

At the first processed `XNGUSD.DWX` D1 bar of each broker month:

1. close any prior package before considering replacement exposure;
2. consume the month before all fallible gates;
3. permit entry only in May-September or November-January;
4. reconstruct thirteen consecutive completed broker-month closes;
5. set each of the twelve intervening monthly observations to `1` for a
   non-negative return and `0` for a negative return;
6. compute `P = positive_count / 12`;
7. buy XNG when `P >= 0.40`, otherwise sell XNG; and
8. attach a frozen `3.5 * ATR(20,D1)` hard stop, with next-month and forty-day
   exits.

The seasonal window is an entry/exit gate, not a directional forecast. The
RSM state alone determines side. An ineligible month is consumed flat. This
intersection is a transparent QM hypothesis; neither paper tests it.

## Translation Boundary

The source studies maturity-specific or rolled exchange futures. The Q02
carrier is a continuous Darwinex CFD. Runtime uses only native D1 OHLC,
broker-calendar time, ATR, spread, executable quotes, positions, deals, and V5
framework state. It does not fit POTS/GARCH, read weather, storage, volume,
open interest, a futures curve, an external calendar, a file, or an API.

No source return, Sharpe ratio, drawdown, volatility estimate, trade count,
cost, neutrality, or portfolio-correlation statistic is imported. Fixed cash
risk, the ATR stop, spread cap, persistent attempt ledger, and exact month
translation are V5 safety and portability choices.

## Non-Duplicate Boundary

The deterministic checker scanned 4,299 EA-registry rows and 416 canonical
cards and returned `CLEAN`, with no exact or fuzzy hit for `xng-rsm-window`.
Manual semantic review resolves the nearest parents:

- `QM5_13116_xng-signmom` applies the twelve-month RSM0.4 state in every
  month; it has no physical-season window.
- `QM5_20052_xng-seas-trend` uses the same source volatility windows but
  derives side from one 126-D1 magnitude return with a two-percent deadband;
  it never counts completed monthly return signs.
- `QM5_20162` and `QM5_20164` use fixed winter or summer windows with daily
  21/84-SMA stacks and slope tests, not monthly sign probability.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day oscillator pullback
  below a trend filter.

The two source windows, twelve consecutive binary monthly signs, fixed 0.40
threshold, monthly close-before-renew, and flat off-window state are jointly
load-bearing. Removing either source state recreates a parent mechanic.

## R1-R4 Verdict

- R1 reputable source: PASS. Two named-author peer-reviewed papers with DOIs,
  durable complete-read records, and natural-gas applicability.
- R2 mechanical: PASS. Fixed months, exact completed-month sign estimator,
  fixed threshold, monthly attempt and renewal, hard stop, and stale exit.
- R3 data available: PASS. Registered `XNGUSD.DWX` D1 OHLC and native V5
  execution state are sufficient; Q02 owns history and economics.
- R4 ML ban: PASS. Deterministic calendar, comparison, counting, division, and
  ATR arithmetic only; no trained model, banned indicator, external runtime
  feed, grid, martingale, scale-in, or pyramiding.

