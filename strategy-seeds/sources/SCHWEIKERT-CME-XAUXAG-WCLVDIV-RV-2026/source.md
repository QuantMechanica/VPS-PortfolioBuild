---
source_id: SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026
title: XAU/XAG completed-week opposite close-location reversion
status: approved_source_complete
source_type: governed_composite_mechanization
approval_basis: decisions/2026-08-21_xauxag_weekly_close_location_divergence_reversion_source_approval.md
primary_instruments:
  - XAUUSD.DWX
  - XAGUSD.DWX
decision_timeframe: D1
strategy_ids:
  - SCHWEIKERT-CME-XAUXAG-WCLVDIV-RV-2026_S01
parent_sources:
  - source_id: SCHWEIKERT-XAUXAG-RATIO-2026
    sha256: 4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B
  - source_id: CME-GSR-SPREAD-2025
    sha256: 2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93
---

# XAU/XAG Completed-Week Opposite Close-Location Reversion

## Source Claim

Schweikert documents a potentially state-dependent long-run relation between
gold and silver rather than one guaranteed immutable equilibrium. CME defines
the gold/silver ratio and presents gold and silver as a tradable intermarket
relative-value carrier with overlapping but different economic drivers.

The exact rule below is not claimed by either source. It is a QM composite
hypothesis: when two related metals end the exact same completed broker week
at opposite extremes of their own weekly auction ranges, fade that relative
location disagreement for one broker week with a paired package.

## Deterministic Translation

Evaluate once on the first tradable D1 bar of each new Monday-anchored broker
week, within 180 elapsed minutes of the raw host-bar open.

1. Aggregate every synchronized XAUUSD.DWX and XAGUSD.DWX D1 bar in the
   immediately preceding completed broker week.
2. Require identical timestamps on both legs and exactly three to five unique
   sessions. Exclude all bars from the current decision week.
3. For each leg retain the completed-week high, low, and chronologically final
   close. Require finite positive closes and strict positive high-low ranges.
4. Compute each leg's close-location value independently:
   `clv=(close-low)/(high-low)`.
5. Qualify only one of two strict states:
   - gold `clv>2/3` and silver `clv<1/3`; or
   - gold `clv<1/3` and silver `clv>2/3`.
6. Equality at either boundary, any interior location, missing or extra
   sessions, duplicate timestamps, synchronization failure, or invalid
   arithmetic is no signal.
7. Sell the upper-location leg and buy the lower-location leg. Close-location
   distance does not alter direction or scale risk.

Persist the current Monday anchor before spread, quote, ATR, sizing, margin,
news, or order-send gates. A failed or rejected package may not retry in that
week.

## Frozen Basket And Risk Contract

- host: exact `XAUUSD.DWX`, D1, slot 0;
- companion: exact `XAGUSD.DWX`, D1, slot 1;
- target absolute entry-notional ratio: 1:1;
- maximum post-lot-step notional mismatch: 20 percent;
- aggregate backtest stop-risk budget: `RISK_FIXED=1000`;
- `RISK_PERCENT=0.0`; `PORTFOLIO_WEIGHT=1.0`;
- per-leg frozen hard stop: `3.5*ATR(20,D1)`;
- take profit: none;
- maximum spread: 1,500 XAU points and 500 XAG points;
- news temporal mode and compliance profile: OFF/NONE;
- Friday close: OFF;
- normal exit: first tick carrying a later Monday-anchored broker-week label;
- fail-safe exit: ten elapsed calendar days after package entry;
- no retry, partial close, trail, break-even move, reversal, scale-in, grid,
  martingale, or pyramid.

## Expected Cadence And Falsification

Opposite outer-tercile weekly close locations are expected to produce roughly
six to twelve completed packages per full post-warm-up year before empirical
validation. A canonical Q02 result below five completed packages in any full
scored year retires the candidate. Nonpositive governed economics or any
state, synchronization, side, sizing, lifecycle, or determinism defect also
retires it; the tercile boundaries and direction may not be changed after the
result.

## Provenance And Limitations

The complete parent records, hashes, source boundaries, dedup evidence, and
R1-R4 findings are fixed in
`decisions/2026-08-21_xauxag_weekly_close_location_divergence_reversion_source_approval.md`.

The cited research concerns futures and broader historical relations, while
the build will use DarwinexZero continuous CFDs. Financing, roll treatment,
session labels, spreads, and fills may differ. No source tests the exact
weekly per-leg CLV conjunction or proves market neutrality, profitability,
portfolio decorrelation, or live fitness.

## Prohibited Interpretations

Do not substitute return sign, ratio level, a fitted center or hedge ratio,
current-week partial data, an oscillator, moving average, trend filter,
volatility filter, calendar overlay, external runtime feed, adaptive
threshold, or trained output. Do not add entries, searches, pyramiding, grid,
or martingale logic. A changed rule is a new governed candidate.
