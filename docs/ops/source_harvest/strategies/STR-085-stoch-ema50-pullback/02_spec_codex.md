# STR-085 — Codex independent mechanical specification

## Source boundary

- Source: GazFx, “Trend Continuation Strategy,” ForexFactory thread 837301.
- Evidence read for this blind specification: `00_source.md` and the `STR-085` row in `SOURCE_LEDGER.csv` only.
- This specification intentionally does not use any prior EA implementation as authority.
- Status: independent Codex draft for G0 comparison; not an approval, profitability verdict, or live-use authorization.

## Strategy hypothesis

Trade an H4 pullback continuation when Stochastic(5,3,3, Close/Close) crosses in an extreme zone and the EMA50 points in the same direction. Place the initial stop beyond the most recently closed bar with the source’s 10-pip H4 buffer, set a 3R target, and trail by the original stop distance.

## Instrument and timeframe scope

- Primary cohort: validated DXZ `.DWX` FX symbols with H4 history. Each symbol is tested independently.
- Source-supported secondary cohort: XAUUSD and XAGUSD, evaluated separately from FX.
- The source says “any symbol / any timeframe,” but says H4 with the default settings works best. H4 is therefore the canonical baseline; H1 and other timeframes are variants, not part of this baseline.
- No session filter is sourced.

## Closed-bar definitions

At the first tick of a new H4 bar:

- `b1` is the just-closed H4 signal bar; `b2` is the H4 bar immediately before it.
- `K[n]` and `D[n]` are the main and signal values of Stochastic(5,3,3), Close/Close, on bar `bn`.
- `EMA[n]` is the standard 50-period exponential moving average applied to close on bar `bn`.
- A pip is derived from symbol digits (`10 * _Point` for 3/5-digit FX quotes, otherwise `_Point` unless the validated symbol registry supplies an explicit pip size). The non-FX pip mapping must come from the registry; it must not be guessed.

## Mechanical rules

1. Evaluate entries once per newly opened H4 bar, using only closed H4 data.
2. A bullish stochastic cross exists when `K[2] <= D[2]` and `K[1] > D[1]`.
3. A bearish stochastic cross exists when `K[2] >= D[2]` and `K[1] < D[1]`.
4. A bullish cross is in the buy zone only when `K[1] <= 20` and `D[1] <= 20`.
5. A bearish cross is in the sell zone only when `K[1] >= 80` and `D[1] >= 80`.
6. EMA50 is sloping up when `EMA[1] > EMA[2]`, sloping down when `EMA[1] < EMA[2]`, and flat when the values are equal at symbol tick precision.
7. Open a long at the next tradable market price only when rules 2, 4, and the upward condition in rule 6 all hold.
8. Open a short at the next tradable market price only when rules 3, 5, and the downward condition in rule 6 all hold.
9. Ignore the signal when the EMA is flat, when the stochastic direction and EMA direction disagree, or when a position/pending entry already exists for this magic and symbol.
10. For a long, set the initial stop at `Low[1] - 10 pips`. For a short, set it at `High[1] + 10 pips`.
11. Reject the order if the stop is not strictly on the loss side of the executable entry price or violates the broker’s validated minimum stop distance.
12. Let `R` be the absolute executable-entry-to-initial-stop distance. Set take profit at entry `+ 3R` for a long and entry `- 3R` for a short.
13. Use a fixed-distance trailing stop whose distance equals `R`. On every tick, calculate `Bid - R` for a long or `Ask + R` for a short and modify the stop only when that candidate tightens the current stop, remains on the valid side of market, and respects the broker stop/freeze levels. Never loosen the stop.
14. Close only by the protective stop, the 3R take profit, or a framework safety exit. There is no source-backed time exit or opposite-cross exit.
15. Permit at most one open position and one entry intent per magic/symbol. Do not stack signals.

## Required inputs and baseline defaults

| Input | Baseline | Allowed research variation | Evidence status |
|---|---:|---:|---|
| `SignalTF` | H4 | H1 only as a separately labelled variant | H4 preferred by source |
| `StochK` | 5 | fixed | sourced |
| `StochD` | 3 | fixed | sourced |
| `StochSlowing` | 3 | fixed | sourced |
| `StochPriceField` | Close/Close | fixed | sourced |
| `StochMAMethod` | SMA | separately swept only | source says scanner later allowed MA-type input but gives no canonical alternative |
| `OversoldLevel` | 20 | fixed | sourced |
| `OverboughtLevel` | 80 | fixed | sourced |
| `EMAPeriod` | 50 | fixed | sourced |
| `EMAAppliedPrice` | Close | fixed | sourced |
| `EMASlopeLookbackBars` | 1 | no silent change | interpretation I-02 |
| `StructureBufferPips` | 10 | fixed for H4 | sourced |
| `RewardMultiple` | 3.0 | fixed | sourced minimum/canonical value |
| `TrailingDistanceR` | 1.0 | fixed | sourced |
| `MaxSpreadPips` | disabled | none | no source-backed spread veto |
| `TimeExitBars` | disabled | none | no source-backed time exit |
| `OppositeCrossExit` | false | none | no source-backed opposite-cross exit |
| `RISK_FIXED` | positive test lot from the canonical set generator | positive only | house backtest constraint |
| `RISK_PERCENT` | 0 in backtests | live configuration at or below 1.0 only with separate authorization | house constraint |

## Interpretation register

- **I-01 — zone timing:** “Crossovers that occur at or below 20 / at or above 80” does not state whether one or both stochastic lines must remain in-zone at the close. Baseline requires both `K` and `D` in-zone on `b1`; this is the strict, reproducible reading.
- **I-02 — EMA slope:** the source gives no slope lookback or minimum angle. Baseline uses the sign of `EMA[1] - EMA[2]`; no ATR-normalized slope or minimum threshold is permitted without a new, labelled variant.
- **I-03 — execution timing:** the source describes alerts, not an exact order type. Baseline enters at the first tradable tick after the signal bar closes, preventing look-ahead.
- **I-04 — “previous low/high”:** at next-bar execution, baseline treats the just-closed signal bar as the previous bar. A multi-bar structure stop is not sourced.
- **I-05 — trailing cadence:** the source specifies a trailing distance equal to the entry-stop distance but not its activation or cadence. Baseline trails from entry on every tick and only ratchets.
- **I-06 — 3R wording:** the source says take profit is “at least” three times the stop and gives 3R as the concrete rule. Baseline fixes 3R; larger targets require a separately identified variant.

## V5 five-hook sketch

1. **Initialization hook:** validate H4 availability, create EMA50 and Stochastic handles, resolve pip size through symbol metadata/registry, and fail closed if required news-calendar or symbol data is stale/missing.
2. **New-bar signal hook:** copy closed `b1/b2` indicator values, evaluate rules 2–9 once, and emit at most one directional intent.
3. **Risk/order hook:** derive the buffered stop, calculate `R`, size through the V5 risk module, attach the 3R target, and reject invalid geometry.
4. **Open-position management hook:** ratchet the fixed-`R` trailing stop on ticks; never widen risk and never create an add-on entry.
5. **Exit/audit hook:** record signal values, EMA slope sign, entry/stop/target, stop modifications, and the terminal exit reason using Q-only operator phase naming.

## House and Edge Lab controls

- Mandatory framework news blackout applies to new entries; stale/missing calendar data fails closed. This is a house safety control, not a sourced edge rule.
- No martingale, grid, stacking, ML, averaging, or recovery sizing.
- FTMO + DXZ evaluation only; daily drawdown must stay at or below 5% and total drawdown at or below 10%.
- No HFT behavior: signal evaluation is H4 closed-bar; per-tick work is limited to protective-stop management.
- Backtest setfiles must have `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- No T_Live, AutoTrading, or deployment action is authorized by this specification.

## Explicit fidelity exclusions

The following are not supported by the admitted source and must not appear in the faithful baseline: a five-bar structure stop, ATR-normalized or thresholded EMA slope, maximum-stop rejection other than broker/geometry validity, a time exit, an opposite-stochastic-cross exit, a spread veto, or an additional regime filter.
