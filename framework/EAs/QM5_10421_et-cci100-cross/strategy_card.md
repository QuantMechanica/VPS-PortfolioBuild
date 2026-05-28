---
ea_id: QM5_10421
slug: et-cci100-cross
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "Mi6secret, Amibroker: Coding question, question on which markets does its analysis for..., Elite Trader, 2020-05-11, https://www.elitetrader.com/et/threads/amibroker-coding-question-question-on-which-markets-does-its-analysis-for.344617/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/cci-momentum]]"
  - "[[concepts/threshold-cross]]"
  - "[[concepts/oscillator-reversal]]"
indicators: [CCI, ATR]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, SP500.DWX, NDX.DWX]
period: H1
expected_trade_frequency: "CCI +/-100 threshold crossing on H1; conservative estimate 70 trades/year/symbol."
expected_trades_per_year_per_symbol: 70
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 linked Elite Trader source; R2 mechanical CCI threshold entry/exit with 70 trades/year/symbol estimate; R3 portable to DWX FX/metals/indices incl SP500 caveat; R4 fixed params one-position no ML/grid/martingale."
---

# Elite Trader CCI 100 Cross

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/amibroker-coding-question-question-on-which-markets-does-its-analysis-for.344617/
- Author / handle: `Mi6secret`.
- Date: 2020-05-11.
- Location: post #1 gives AFL signal rules using CCI crossing +100 and -100 for buy/sell/short/cover.

## Mechanik

### Entry
- Baseline H1.
- Compute `CCI(20)`.
- Long: CCI crosses upward through +100 on the completed bar.
- Short: CCI crosses downward through -100 on the completed bar.
- Enter at next bar open.

### Exit
- Exit long when CCI crosses downward through +100 or a short entry signal appears.
- Exit short when CCI crosses upward through -100 or a long entry signal appears.
- Time exit after 30 bars.

### Stop Loss
- Initial stop: `2.0 * ATR(20)`.
- Move stop to breakeven after +1R.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.

### Zusaetzliche Filter
- One position per symbol/magic.
- Optional P3 filter: long only above SMA(200), short only below SMA(200).

## Concepts
- [[concepts/cci-momentum]] - uses CCI threshold breaks as directional momentum.
- [[concepts/threshold-cross]] - entry/exit are deterministic level crossings.
- [[concepts/oscillator-reversal]] - opposite threshold behavior closes the trade.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader URL plus visible handle `Mi6secret`. |
| R2 Mechanical | PASS | AFL rules define buy/sell/short/cover crosses; V5 adds bounded stop/time exit. |
| R3 DWX-testbar | PASS | CCI/ATR uses OHLC and ports to DWX FX, metals, and indices. |
| R4 No ML | PASS | Fixed indicator, one-position behavior, no ML/adaptive/grid/martingale. |

## R3
Primary P2 basket: `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX`, `SP500.DWX`, `NDX.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source is a coding-help post and makes no profitability claim.

## Parameters To Test
- CCI period: 14, 20, 30.
- Threshold: 75, 100, 150.
- Period: M30, H1, H4.
- Exit: threshold recross, zero-line cross, time exit.
- Stop: 1.5, 2.0, 2.5 ATR(20).

## Initial Risk Profile
This is a generic oscillator threshold system. It is valid for intake but should be expected to fail unless a market/timeframe regime supports it.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.

