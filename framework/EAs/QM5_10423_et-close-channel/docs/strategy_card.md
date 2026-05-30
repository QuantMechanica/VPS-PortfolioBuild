---
ea_id: QM5_10423
slug: et-close-channel
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "mdjgd4 / mushinseeker, Amibroker AFL Coding Help, Elite Trader, 2014-03-07/08, https://www.elitetrader.com/et/threads/amibroker-afl-coding-help.282591/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/channel-breakout]]"
  - "[[concepts/close-breakout]]"
  - "[[concepts/donchian-variant]]"
indicators: [HHV, LLV, ATR]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, SP500.DWX, NDX.DWX]
period: H1
expected_trade_frequency: "Close-only channel breakout on H1/D1; conservative estimate 55 trades/year/symbol."
expected_trades_per_year_per_symbol: 55
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS Elite Trader URL/handles; R2 PASS deterministic close-channel entry/exit/ATR stop with plausible 55 trades/year/symbol; R3 PASS OHLC/ATR portable to DWX FX/metals/indices with SP500 caveat; R4 PASS fixed non-ML one-position logic."
---

# Elite Trader Close Channel Breakout

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/amibroker-afl-coding-help.282591/
- Author / handle: `mdjgd4`; code reply by `mushinseeker`.
- Date: 2014-03-07/08.
- Location: thread defines buy/cover as close above the highest close N bars ago and sell/short as close below the lowest close N bars ago; reply provides AFL using `HHV(Close, Length)` and `LLV(Close, Length)`.

## Mechanik

### Entry
- Baseline H1.
- `Upper = highest Close over prior N completed bars`.
- `Lower = lowest Close over prior N completed bars`.
- Long: completed bar closes above `Upper`.
- Short: completed bar closes below `Lower`.
- Enter at next bar open.

### Exit
- Exit long when completed bar closes below `Lower`.
- Exit short when completed bar closes above `Upper`.
- V5 conversion: flatten first, then wait one bar before any opposite-side entry.

### Stop Loss
- Initial stop: `2.0 * ATR(20)`.
- Optional channel stop:
  - Long stop cannot be above `Lower`.
  - Short stop cannot be below `Upper`.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.

### Zusaetzliche Filter
- One position per symbol/magic.
- Compute channels from prior completed bars only; no current-bar lookahead.
- Optional P3 filter: require ATR(20) above its 100-bar median.

## Concepts
- [[concepts/channel-breakout]] - directional trade after price escapes a rolling channel.
- [[concepts/close-breakout]] - source uses closing prices rather than intrabar highs/lows.
- [[concepts/donchian-variant]] - related to Donchian/Turtle but close-based and configurable.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader URL plus visible handles. |
| R2 Mechanical | PASS | Close-channel entry/exit logic is explicit; V5 adds stop and completed-bar constraints. |
| R3 DWX-testbar | PASS | Uses OHLC close/ATR only and ports to DWX FX, metals, and indices. |
| R4 No ML | PASS | Fixed lookback, one-position conversion, no ML/adaptive/grid/martingale. |

## R3
Primary P2 basket: `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX`, `SP500.DWX`, `NDX.DWX`.

Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source compares the idea to Turtle-style highest-close/lowest-close breakout but does not claim profitability.

## Parameters To Test
- Period: H1, H4, D1.
- Lookback N: 10, 20, 40, 80.
- Exit lookback: same as entry, half entry lookback.
- Stop: 1.5, 2.0, 2.5 ATR(20).
- Volatility filter on/off.

## Initial Risk Profile
This overlaps with prior Donchian/channel cards. Its distinct feature is close-only confirmation, which may reduce false intrabar breaks but adds lag.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.

