# STR-104 — Codex independent mechanical specification

## Source boundary

- Source: Eliteforexpartner, “A Scalping/Day Trading strategy 5minute timeframe,” BabyPips thread 1266726 (2024).
- Evidence read for this blind specification: `00_source.md` and the `STR-104` row in `SOURCE_LEDGER.csv` only.
- Exit Method 3 is excluded because wedge recognition, a “third touch,” and overshoot judgment are not mechanically defined.
- Status: independent Codex draft for G0 comparison; not an approval, profitability verdict, or live-use authorization.

## Strategy hypothesis

A MACD(6,17,1) zero-line cross starts a directional campaign. After momentum extends outside a tight shifted Bollinger envelope and then pulls back into it, require a closed-bar breakout of the pre-pullback extreme, place a stop order one pip beyond the breakout candle, and manage the fill with one of the two source-defined fixed-R exits.

## Instrument and timeframe scope

- Baseline cohort: validated `.DWX` FX majors, tested separately.
- Decision and execution timeframe: M5.
- The source says the idea can also trade indices and precious metals, but those are separately labelled generalizations, not part of the baseline cohort.
- The logic is bar-driven scalping/day trading, not tick-scalping or HFT.

## Closed-bar indicator definitions

At the first tick of each new M5 bar:

- `macd1 = EMA(Close,6)[1] - EMA(Close,17)[1]`; with signal period 1, the source MACD zero-line event is mechanically the EMA6/EMA17 cross noted in the thread.
- Bollinger Bands use period 10, deviation 0.66, applied Close, and positive plot shift 1.
- To avoid look-ahead, a band “at” a closed price bar means the value visibly aligned to that bar after the +1 plot shift. Equivalently, the band calculation source bar is one completed bar older. An implementation may use native buffers only if a test proves this same causal alignment.
- One pip comes from validated symbol metadata; it is not assumed to equal one point.

## Mechanical rules — campaign state machine

1. Evaluate campaign state once per newly closed M5 bar.
2. Start a new long campaign only when `macd2 <= 0` and `macd1 > 0`. Start a new short campaign only when `macd2 >= 0` and `macd1 < 0`.
3. A new campaign cancels any unfilled order from the prior campaign and resets its extension, pullback, extreme, breakout, and consumed flags.
4. Long extension state requires at least one post-cross closed bar above the upper band. Track the maximum high from the campaign-cross bar through the last bar before the first subsequent band re-entry.
5. A long pullback occurs when a later bar reaches back into the envelope, mechanically `Low[1] <= alignedUpperBand[1]`; the close may be inside or below either band.
6. For a short campaign, mirror rules 4–5: require at least one post-cross closed bar below the lower band, track the minimum low, then recognize re-entry when `High[1] >= alignedLowerBand[1]`.
7. After a long pullback, the tracked pre-pullback high is resistance. Require a later M5 close strictly above it.
8. If a bar trades above resistance but closes at or below it, treat that as the source’s wick-only case: replace resistance with that bar’s higher high and continue waiting.
9. After a short pullback, require a later close strictly below the tracked support. A wick below without such a close replaces support with the lower low.
10. A qualifying long breakout creates one buy-stop price one pip above the breakout signal candle’s high. A short breakout creates one sell-stop price one pip below that candle’s low.
11. If the stop-entry price is already behind executable market or violates stop/freeze geometry at placement, do not convert it to an undeclared market order and do not widen it. Record the invalid setup and wait for a new campaign.
12. Maintain at most one pending order or one open position per symbol/magic. A campaign is consumed after one fill; no second trade is opened before the next opposite zero-line campaign.
13. An unfilled buy stop remains active until MACD crosses below zero; an unfilled sell stop remains until MACD crosses above zero. There is no source-backed bar-count expiry.
14. Mandatory news handling must cancel a triggerable pending entry before a restricted window. After blackout, require a fresh closed-bar breakout rather than resurrecting a stale order.
15. **Exit Method 1 baseline:** for a long, initial SL is one pip below the breakout signal candle’s low; for a short, one pip above its high. TP is exactly one executable fill-to-SL risk unit.
16. **Exit Method 2 source variant:** for a long, initial SL is one pip below the causally aligned lower band at the breakout signal bar; for a short, one pip above the aligned upper band. TP is exactly two executable fill-to-SL risk units.
17. Calculate R from actual fill to normalized protective stop. If R is non-positive or broker-invalid, reject the setup rather than substitute a distance.
18. Once filled, do not use a later MACD zero cross as an exit; the source only assigns that cross to unfilled-order cancellation. Close by the selected fixed-R stop/target or mandatory framework safety handling.

## Required inputs and baseline defaults

| Input | Baseline | Allowed research variation | Evidence status |
|---|---:|---:|---|
| `SignalTF` | M5 | fixed | sourced |
| `MACDFastEMA` | 6 | fixed | sourced |
| `MACDSlowEMA` | 17 | fixed | sourced |
| `MACDSignalPeriod` | 1 | fixed | sourced |
| `BBPeriod` | 10 | fixed | sourced |
| `BBShift` | 1 | fixed | sourced |
| `BBDeviation` | 0.66 | fixed | sourced |
| `BBAppliedPrice` | Close | fixed | interpretation I-01 |
| `EntryBufferPips` | 1 | fixed | sourced |
| `ExitMethod` | `METHOD_1_SIGNAL_CANDLE_1R` | `METHOD_2_OUTER_BAND_2R` as a separately labelled run | both sourced |
| `OneTradePerCampaign` | true | fixed baseline | interpretation I-06 |
| `PendingExpiryBars` | disabled | none | no source-backed expiry |
| `SessionMode` | ALL | fixed baseline | no source-backed session |
| `StrategySpreadVeto` | disabled | none | source notes spread sensitivity but supplies no threshold |
| `RISK_FIXED` | positive test lot from canonical set generation | positive only | house backtest constraint |
| `RISK_PERCENT` | 0 in backtests | live configuration at or below 1.0 only with separate authorization | house constraint |

## Interpretation register

- **I-01 — Bollinger applied price:** the source gives period, shift, and deviation but not applied price. Baseline uses Close, the ordinary chart default, and exposes it in the spec.
- **I-02 — shifted-band alignment:** a positive indicator plot shift is visual displacement, not permission to read future bars. Baseline compares price with the value causally displayed at that bar and requires an alignment test.
- **I-03 — what makes a pullback:** “pull back into the Bollinger bands” implies a prior extension outside the envelope. Baseline requires one closed outside bar followed by wick contact with the near band; the source does not state this exact finite-state test.
- **I-04 — stop-entry anchor after confirmation:** a close above the old resistance means an order one pip above that old level may already be behind market. Baseline interprets “the high” as the confirming breakout candle’s high, which gives a valid continuation stop order and aligns with Method 1’s “breakout signal candle.” This is a material reconciliation point.
- **I-05 — extreme window:** “highest point where price hits before the pullback” is taken as the campaign high from the zero-cross bar through the bar preceding first band re-entry; shorts mirror it.
- **I-06 — campaign consumption:** the author says the campaign structure prevents over-trading but does not explicitly state how many fills one campaign may produce. Baseline permits one, consistent with one-position-per-magic and no stacking.
- **I-07 — strict zero cross:** equality is assigned to the prior side in rules 2 and 13 so a genuine sign change starts or cancels a campaign once, without repeated events at exact zero.
- **I-08 — Method 2 band snapshot:** the source does not say which lower/upper band observation fixes the stop. Baseline freezes the causally aligned band on the breakout signal bar; it does not trail the band.

## V5 five-hook sketch

1. **Initialization hook:** validate M5 history, create MACD/EMA and shifted Bollinger data, prove causal buffer alignment, resolve pip/tick/volume metadata, and fail closed on stale or missing mandatory news data.
2. **New-bar campaign hook:** detect zero crosses and advance `NEW_CAMPAIGN -> EXTENSION -> PULLBACK -> BREAKOUT_CONFIRMED`, updating wick-only extremes from closed bars.
3. **Order/risk hook:** create one buffered stop intent with the selected source exit package, size from its real stop distance, and enforce one order/position per magic.
4. **Pending/position-management hook:** cancel unfilled orders on the opposite zero cross or before news blackout, never revive stale orders, and otherwise preserve fixed protection/target without Method 3 discretion.
5. **Exit/audit hook:** record campaign ID/state transitions, MACD values, causally aligned bands, extrema, breakout candle, pip conversion, order geometry, exit method, fill/R/exit, and Q-only phase labels.

## House and Edge Lab controls

- Mandatory high-impact-news blackout applies and stale/missing calendar data fails closed. `qm_news_stale_max_hours` is never raised above 336.
- No martingale, grid, averaging, stacking, recovery sizing, discretionary wedge exit, or ML.
- FTMO + DXZ evaluation only; daily drawdown must remain at or below 5% and total drawdown at or below 10%.
- Backtest setfiles require `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- M5 closed-bar campaign logic is allowed scalping; no sub-minute signal, latency logic, or tick-scalping is permitted.
- No T_Live, AutoTrading, terminal launch, pipeline verdict, or deployment action is authorized.

## Evidence caveat and fidelity exclusions

The source contains no reproducible backtest. One tester reports terrible live-market results on major FX pairs and the discussion identifies MACD(6,17,1) as an EMA6/17 cross. These are reasons for strict falsification, not a profitability verdict. The faithful baseline must not add an unquantified spread filter, trend filter, session filter, time exit, discretionary wedge/third-touch exit, market-order chase, multiple concurrent orders, or repeat entries within one campaign.
