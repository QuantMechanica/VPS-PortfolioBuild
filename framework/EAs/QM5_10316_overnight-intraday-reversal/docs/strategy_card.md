---
ea_id: QM5_10316
slug: overnight-intraday-reversal
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
sources:
  - "[[sources/ssrn-microstructure-hft-journal]]"
concepts:
  - "[[concepts/intraday-reversal]]"
  - "[[concepts/overnight-return]]"
indicators:
  - "[[indicators/overnight-return-rank]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 200
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS SSRN URL/named paper; R2 PASS mechanical overnight-return rank entries and same-session close with ~200 basket trades/year; R3 PASS portable to DWX index/commodity basket with SP500.DWX T6 caveat; R4 PASS fixed deterministic no ML/martingale"
---

# Overnight Intraday Reversal

## Quelle
- Source: [[sources/ssrn-microstructure-hft-journal]]
- Primary URL: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2730304
- Source paper: Chun Liu, Yang Liu, Tianyu Wang, Guofu Zhou, Yingzi Zhu, "Overnight-Intraday Reversal Everywhere", SSRN abstract 2730304, AsianFA 2016 Conference.
- Page / Timestamp: SSRN abstract states the rule buys assets with the lowest past overnight returns and sells those with the highest; accessed 2026-05-21.

## Mechanik

### Entry
Daily, after all target instruments have completed the opening window:
- Compute each instrument's overnight return: `session_open / prior_session_close - 1`.
- Rank instruments by overnight return within the configured basket.
- Go long the bottom quantile or bottom 2 instruments with the lowest overnight returns.
- Go short the top quantile or top 2 instruments with the highest overnight returns.
- If basket size is small, use top/bottom one instrument and stay flat when rank spread is below 0.25x rolling 60-day median absolute overnight dispersion.

### Exit
- Close all positions at the same session's close.
- No overnight holding.

### Stop Loss
- Source emphasizes intraday reversal, not stop placement.
- Build default: per-leg stop at 1.0x rolling 20-day median intraday absolute return for that instrument.

### Position Sizing
- Dollar-risk equal per selected leg in P2 baseline.
- One position per symbol/magic; no scaling or pyramiding.

### Zusaetzliche Filter
- Cross-sectional dispersion filter is source-consistent because the paper reports dispersion predicts expected return/Sharpe.
- DWX port basket candidates: SP500.DWX, NDX.DWX, WS30.DWX, DAX40.DWX, UK100.DWX, XAUUSD.DWX, WTI.DWX if data coverage allows.
- Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

### Period
- Signal cadence: D1 session-open to same-session-close cycle.
- Implementation may run on M15 or H1 bars to detect the configured session open/close timestamps, but entries and exits are evaluated once per daily session.

## Concepts (was ist das fuer eine Strategie)
- [[concepts/intraday-reversal]] - primary
- [[concepts/overnight-return]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|-------------|
| R1 Track Record | PASS | SSRN page gives stable URL, named authors, affiliations, AsianFA conference context, and DOI. |
| R2 Mechanical | PASS | Overnight-return rank determines long/short legs; exit is same-session close. |
| R3 Data Available | PASS | Cross-asset concept is portable to index/commodity/FX CFDs with session definitions set during build; SP500.DWX carries the standard T6 live caveat. |
| R4 ML Forbidden | PASS | Fixed rank rule, fixed dispersion filter, no ML, online learning, martingale, or unbounded grid. |

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING, drafted from SSRN Microstructure & High-Frequency Trading journal mining.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10313_market-intraday-momentum]] - opposite intraday sign logic from open information to close window.

## Lessons Learned (waehrend Pipeline-Lauf)
- TBD
