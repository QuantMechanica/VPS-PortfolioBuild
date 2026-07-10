# QM5_11912_cheng-triangle-2touch-second-break-h1 - Strategy Spec

**EA ID:** QM5_11912
**Slug:** cheng-triangle-2touch-second-break-h1
**Source:** Grace Cheng, *7 Winning Strategies for Trading Forex* (Harriman House, 2007), Strategy 5
**Author of this spec:** Codex
**Last revised:** 2026-07-10

## 1. Strategy Logic

The EA detects ascending and descending triangles from closed H1 ZigZag pivots.
A valid setup needs two touches on each boundary over 30-200 bars. Ascending
triangles combine approximately level highs with rising lows; descending
triangles combine approximately level lows with falling highs. The boundary
touch tolerance is the card's eight-pip ZigZag deviation.

The first close outside either boundary is recorded and ignored. Price must
close back inside the projected triangle within ten H1 bars. After re-entry,
an ascending triangle places a buy stop ten pips above resistance and a
descending triangle places a sell stop ten pips below support. The stop order
expires after 50 H1 bars. Each setup is one-shot; no grid, averaging,
pyramiding, martingale, adaptive fit, or ML component is present.

The protective stop is ten pips beyond the opposite projected boundary. The
profit target projects the triangle's maximum height from the entry price. An
open position is closed after 240 H1 bars if neither price exit has fired.
Pending orders are removed when news, Friday-close, or kill-switch gates block
trading.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| strategy_zigzag_depth | 8 | ZigZag depth |
| strategy_zigzag_deviation | 8 | ZigZag deviation and touch tolerance, in pips |
| strategy_zigzag_backstep | 3 | ZigZag backstep |
| strategy_triangle_min_bars | 30 | minimum span between the four boundary touches |
| strategy_triangle_max_bars | 200 | maximum structural lookback and touch span |
| strategy_entry_buffer_pips | 10.0 | stop-entry distance beyond the breakout boundary |
| strategy_stop_buffer_pips | 10.0 | protective-stop distance beyond the opposite boundary |
| strategy_time_stop_bars | 240 | maximum open-position holding time in H1 bars |

The source-fixed re-entry limit is 10 H1 bars and pending-order validity is 50
H1 bars. They are constants rather than optimization inputs.

## 3. Symbol Universe

The approved H1 forex universe and magic slots are:

| Slot | Symbol |
|---:|---|
| 0 | EURUSD.DWX |
| 1 | GBPUSD.DWX |
| 2 | USDJPY.DWX |
| 3 | USDCAD.DWX |
| 4 | USDCHF.DWX |
| 5 | AUDUSD.DWX |
| 6 | NZDUSD.DWX |
| 7 | EURJPY.DWX |
| 8 | GBPJPY.DWX |
| 9 | AUDJPY.DWX |

Each tester attachment trades only its host symbol and resolves magic as
`11912 * 10000 + symbol_slot`.

## 4. Timeframe

- Base timeframe: H1.
- Signal evaluation: once per new bar using closed-bar prices and ZigZag
  pivots.
- Multi-timeframe inputs: none.
- Pending entry validity: 50 H1 bars after structural re-entry.
- Position time stop: 240 H1 bars.

## 5. Expected Behaviour

- Expected frequency from the approved card: approximately 20 trades per year
  per symbol, subject to Q02's hard minimum of five trades per year.
- The setup is a low-frequency structural breakout, not a latency-sensitive or
  high-turnover FX strategy.
- Winners target one measured triangle height; losses are bounded beyond the
  opposite boundary.
- Q02 must judge whether the second-break filter produces enough real-tick
  trades and net profit after forex costs. No performance result is claimed by
  the build.

## 6. Source Citation

Grace Cheng, *7 Winning Strategies for Trading Forex*, Harriman House, 2007,
Strategy 5, "Decreased Volatility Breakout," chapter 9, ISBN
978-1905641192. The approved card records the two-touch validity rule,
ignore-first-break rule, re-entry requirement, buffered second-break entry,
opposite-boundary stop, and measured-move target.

Canonical approved card:
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11912_cheng-triangle-2touch-second-break-h1.md`.

## 7. Risk Model

| Environment | Risk mode | Value |
|---|---|---:|
| Q02-Q10 backtest | RISK_FIXED | USD 1,000 per trade |
| Live | not authorized by this build | no live setfile or manifest |

Every committed backtest set has `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Friday close remains enabled at broker hour 21. The EA
has no live setfile and this build does not authorize deployment.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-07-10 | Replace the non-trading placeholder with the approved structural triangle implementation and repair per-symbol magic setfiles |
