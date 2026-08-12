# STR-103 independent Codex spec — 3 Little Pigs multi-timeframe SMA swing

## 1. Source rules (verbatim-anchored)

- Harmonicphil's chosen variant uses three timeframes. For a buy: “Price is above the 55 Simple Moving Average (SMA) on the Weekly timeframe,” “Price is above the 21 SMA on the Daily timeframe,” and “Price closes above the 34 SMA on the 4 Hour timeframe” (PDF p. 1, post #1). Sell is vice versa.
- The detailed long trigger is: “On close of the next candle that touches and then closes above the 34 SMA on the 4 Hour timeframe” (PDF p. 1, post #1). The short trigger is the symmetric touch and close below.
- Initial stop intent: calculate 25% of the sum of the displayed High and Low values of ATR(14), then place the stop that many pips beyond H4 SMA(34) (PDF p. 1, post #1).
- Initial target intent: “I use an open target and exit only when my Trailing Stop loss is taken out” (PDF p. 1, post #1).
- Re-entry intent: “If I get stopped out I will re-enter according to my Entry rules” (PDF p. 1, post #1).
- The journal introduces a temporary exit change: “I will now tighten stop to the ma not the (ma - atr) calculated figure” (PDF p. 5, post #27). Later author examples again describe stops “trailing 25 behind the MA” and “12 pips behind the MA” (PDF pp. 22–23, posts #99/#100). The later captured practice therefore appears to revert to the original ATR-offset trail; this drift must remain visible.
- A later risk variation caps a stop: “I’m setting the stop to a max of 100” (PDF p. 7, post #40). The author does not state whether this one-trade variation permanently amends every pair.
- Final late-entry clarification: “if you’re late to the action on a trade I would wait for confirmation of a new signal” (PDF p. 24, post #105). That later statement is more restrictive than the first post's fallback entry when W1/D1 align after an earlier H4 signal.
- The author trades AUDUSD, EURGBP, EURJPY, EURUSD, GBPUSD, USDCAD, USDCHF, and USDJPY, risking 1% per trade (PDF p. 2, post #1).

## 2. Entry

- H4 is the execution clock. Evaluate once after each H4 close; no intrabar entry or historical use of a forming higher-timeframe candle.
- Closed-bar indicator state:
  - W1: previous fully closed weekly close above/below its SMA(55).
  - D1: previous fully closed daily close above/below its SMA(21).
  - H4: the just-closed candle relative to SMA(34).
- Long:
  1. Closed W1 close `[1]` is above W1 SMA(55) `[1]`.
  2. Closed D1 close `[1]` is above D1 SMA(21) `[1]`.
  3. After both higher-timeframe filters are aligned, a fresh H4 signal candle touches SMA(34) and closes above it. Mechanically: the closed H4 candle's low is at or below its closed-bar SMA(34) value and its close is above that value.
  4. Enter long at the first tradable price after that H4 close.
- Short is symmetric: closed W1 and D1 closes below their SMAs, then a fresh H4 candle whose high reaches SMA(34) and whose close finishes below it; enter after the H4 close.
- “Fresh” implements the author's later post #105: do not chase when several candles have passed. Wait for another H4 touch/cross-and-close signal after the W1/D1 filters align.
- The source appears to have used live/current W1 and D1 values in its indicator and journal. This spec deliberately uses fully closed W1/D1 bars to satisfy the no-repaint requirement. That timing difference is a fidelity item for reconciliation, not a hidden assumption.

## 3. Exit

- No fixed take-profit. Exit when the protective trailing stop is hit.
- Initial and ongoing stop are based on H4 SMA(34) plus/minus the source's ATR-derived offset.
- At each H4 close, for a long move the stop upward to `SMA34 - offset`; for a short move it downward to `SMA34 + offset`. Never widen the stop.
- Version drift: post #27 briefly changes the trail to the SMA itself, but later author posts #99/#100 explicitly report the offset-behind-MA trail again. The final captured practice is therefore specified as the offset trail, with direct-at-SMA retained as an alternative requiring reconciliation.
- If the W1 or D1 filter flips while a position remains open, the source does not order an immediate market exit; the stated exit remains the trailing stop.

## 4. SL/TP sizing

- ATR period: 14 on H4.
- Source formula: `offset_pips = 0.25 * (ATR_display_high + ATR_display_low)`.
- Long initial SL: `H4_SMA34 - offset_pips`. Short initial SL: `H4_SMA34 + offset_pips`.
- The “High” and “Low” are the values displayed at the right of the ATR pane. Their calculation/lookback is not specified and can change with chart viewport. A community EA later uses the max and min ATR(14) over 30 H4 periods (PDF pp. 13–14, post #70), but that is not harmonicphil's authored rule and must not be silently adopted.
- Post #40 adds a 100-pip maximum. The demonstrated trade places the stop exactly 100 pips from entry, so the closest mapping is to cap entry-to-stop risk distance at 100 pips. Its global scope remains ambiguous.
- TP: NONE STATED; the author explicitly uses an open target.
- Spread is paid in the entry example but is not incorporated into the stop formula. Pip/digit normalization is unstated.

## 5. Filters/Session

- Mandatory trend filters are W1 SMA(55) and D1 SMA(21), both aligned with the desired direction.
- The captured author variant is limited to the eight named FX pairs.
- Signals are checked at H4 closes. The author describes UK time with charts one hour ahead and attempts checks around 07:00, 11:00, 15:00, 19:00, and sometimes 23:00 UK time (PDF p. 16, post #77); this is monitoring cadence, not a trading-session exclusion.
- Session filter: NONE STATED.
- News filter: NONE STATED. Any eventual QuantMechanica implementation requires the framework's mandatory fail-closed news blackout as an external overlay.
- No spread, volatility, proximity-to-SMA, or higher-timeframe candle-distance filter is stated by the original author.

## 6. Money management

- Risk exactly 1% of account equity/balance per trade according to the author's chosen approach (PDF p. 2, post #1); the balance/equity basis is not specified.
- Eight pairs may signal concurrently. The source gives no aggregate portfolio-risk or correlated-currency cap.
- No martingale, grid, averaging down, or ML sizing is stated.

## 7. Edge cases

- Re-entry: only after a fresh signal meeting all entry conditions; the journal repeatedly re-enters after stops.
- Late/missed signal: wait for a new H4 confirmation; do not enter several bars late (PDF p. 24, post #105).
- Weekend: the author says, “I tend to leave them open over the weekend” (PDF p. 24, post #108).
- Position already open: the journal generally maintains one position per symbol and describes an arrow as a signal “for anyone not yet in,” but no formal stacking prohibition is stated.
- Higher-timeframe filter flips while open: no forced exit stated.
- Gap through stop or weekend gap: no special handling stated; use next available execution and record slippage.
- Missing bars/insufficient history: no trade until closed W1 SMA(55), D1 SMA(21), H4 SMA(34), and ATR(14) inputs are complete.
- Simultaneous signals: each is eligible at 1% in the source; portfolio risk remains unresolved.
- Exactly touching SMA, spread-adjusted touch, and whether SMA may lie anywhere inside the H4 range are not further defined.

## 8. Expected trade frequency

- The first three weeks of the journal show repeated signals and re-entries across eight pairs, including several on EURJPY and USDJPY.
- Estimated frequency for one named FX pair: approximately 12–35 entries/year, with clustering during aligned W1/D1 trends and repeated H4 pullbacks.
- It is episodic but likely to exceed the Q02 floor of 5 trades/year on a liquid pair. This is an estimate, not pipeline evidence.

## 9. Ambiguities

- Whether W1/D1 direction uses the current forming bar or the last closed bar. Closed bars are required here to prevent repaint, but may delay the source's live signal.
- Exact ATR “High” and “Low” lookback. A chart-pane scale is not reproducible without viewport state.
- Whether the 100-pip maximum in post #40 is a permanent global amendment, a EURUSD-only trial, and whether it caps entry-to-stop distance or the SMA offset.
- Final trailing policy conflict: direct SMA in post #27 versus later offset-behind-SMA examples in posts #99/#100.
- Whether a valid H4 touch must approach from the trend side, cross the SMA, or merely have a range containing the SMA.
- The first-post delayed-alignment fallback conflicts with the later “fresh signal” rule; this spec selects the later, more restrictive statement.
- One-position-per-symbol, aggregate open risk, correlation cap, spread ceiling, holiday/week-start handling, and balance versus equity risk basis.
- Whether to exit immediately when W1/D1 direction flips.
- Exact broker/session alignment used for H4 bars.

## 10. MQL5 mapping notes

- All three SMAs are native `iMA` calculations using `MODE_SMA` and close price.
- Use separate W1, D1, and H4 handles. Copy only completed buffers; do not read W1/D1 shift 0 for historical decisions.
- ATR(14) is native, but the author's plot High/Low scale is not a stable indicator output. Reconciliation must define a fixed closed-bar lookback before code can reproduce the stop.
- Detect the H4 touch using the completed candle range against completed SMA(34); place the market order only after the bar closes.
- Convert pip distances through symbol digits/tick size and validate volume, stop level, freeze level, and order price.
- Update the trailing stop once per completed H4 bar and enforce monotonic tightening.
- Multi-timeframe warmup must include at least 55 completed W1 bars plus the dependent D1/H4 history.
