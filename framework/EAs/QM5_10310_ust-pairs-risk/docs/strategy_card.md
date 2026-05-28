---
ea_id: QM5_10310
slug: ust-pairs-risk
type: strategy
source_id: fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
sources:
  - "[[sources/ssrn-microstructure-hft]]"
concepts:
  - "[[concepts/pairs-trading]]"
  - "[[concepts/spread-trading]]"
  - "[[concepts/risk-control]]"
indicators:
  - "[[indicators/spread-zscore]]"
  - "[[indicators/rolling-volatility]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
expected_trades_per_year_per_symbol: 90
g0_approval_reasoning: "R1 PASS SSRN paper URL/citation; R2 PASS deterministic spread entry/exit/extreme-risk stops with ~90 trades/year/symbol; R3 PASS ports to DWX FX/index/gold pairs; R4 PASS fixed non-ML bounded 1-package rules."
---

# Treasury-Style Pairs With Extreme Risk Control

## Quelle
- Source: [[sources/ssrn-microstructure-hft]]
- Paper URL: https://ssrn.com/abstract=565441
- Paper: "High Frequency Pairs Trading with U.S. Treasury Securities: Risks and Rewards for Hedge Funds", Purnendu Nath, London Business School, 2003.
- Page / Timestamp: SSRN abstract and citation page. The abstract describes a simple pairs trading strategy with automatic extreme risk control on highly liquid U.S. government debt securities.

## Mechanik

### Entry
On M15 bars for a rates-sensitive or highly correlated DWX pair:
- Formation window: 60 trading days.
- Require rolling correlation of M15 returns `>= 0.75`.
- Build spread `S = log(A) - beta * log(B)`, beta from OLS over the formation window.
- Compute spread z-score over the last 20 trading days.
- If `z >= +1.75`, short A and long B.
- If `z <= -1.75`, long A and short B.
- One package per magic number.

### Exit
- Exit when `abs(z) <= 0.20`.
- Exit at a maximum holding period of 3 trading days.
- Exit immediately if the pair correlation falls below `0.50` over the last 10 trading days.

### Stop Loss
Automatic extreme risk control:
- Hard stop when `abs(z) >= 3.0`.
- Hard stop when package loss reaches `1.5 * rolling_daily_spread_sigma` expressed in account currency, capped at $1,000 in P2.
- No averaging down, no re-entry in the same direction for 24 hours after a hard stop.

### Position Sizing
Fixed $1,000 P2 risk equivalent across the spread package. Leg weights are volatility-normalized, not martingale-adjusted.

### Zusätzliche Filter
- Skip during scheduled central-bank decisions and high-impact inflation prints if the tested symbol set is rates-sensitive.
- Skip if spread cost exceeds 10% of entry-to-mean distance.
- Use only symbols with reliable M15 history and stable quote availability.

## Concepts (was ist das für eine Strategie)
- [[concepts/pairs-trading]] - primary
- [[concepts/spread-trading]] - secondary
- [[concepts/risk-control]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named SSRN paper by Purnendu Nath with SSRN URL and London Business School attribution. |
| R2 Mechanical | PASS | Simple pairs spread entry plus automatic extreme risk exits are deterministic. |
| R3 Data Available | PASS | U.S. Treasury instruments are not DWX-native, but the spread/risk-control concept ports to DWX rates-sensitive FX/index/gold pairs. |
| R4 ML Forbidden | PASS | Fixed thresholds and bounded package risk; no ML, grid, martingale, or adaptive equity feedback. |

## R3
Primary DWX ports: `USDJPY.DWX`/`USDCAD.DWX`, `EURUSD.DWX`/`GBPUSD.DWX`, `XAUUSD.DWX`/`USDJPY.DWX`, and index pairs where available. The Treasury-security source instrument is not required under relaxed R3 because the method is a generic liquid spread-trading framework.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING, drafted from SSRN microstructure/HFT batch 1.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10308_hft-pairs-z]] - intraday equity-pairs variant.
- [[strategies/QM5_10309_cointeg-hft-pairs]] - cointegration residual variant.

## Lessons Learned (während Pipeline-Lauf)
- TBD

