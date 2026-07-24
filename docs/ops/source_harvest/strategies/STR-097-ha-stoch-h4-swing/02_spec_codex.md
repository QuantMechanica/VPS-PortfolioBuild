# STR-097 independent Codex spec — Heiken-Ashi + Stochastic trend-pullback swing

## 1. Source rules (verbatim-anchored)

- Scope: Hugh Briss's H4 trend-pullback method in the captured first three forum pages. The author says, “I like to use 4 hour charts” and lists “Heiken Ashi candles / 100 sma close / Stochs 8,3,3, low/high” (PDF p. 1, post #1).
- Trend direction: “if the price is above the ma the trend is up and we only want to buy and below is down and we only want to sell” (PDF p. 1, post #1).
- Long trigger: after a smooth pullback in an uptrend, “When the HA candle turns back to green and the stochastics make a nice smooth cross towards the bottom of the stochs window then wait for the 4 hour candle to close and open your long trade” (PDF p. 2, post #1). The sell is the stated opposite.
- The source requires a visibly established trend: the moving average should be “moving smoothly in one direction for a period of time” and price should make a “classic zig zag movement” (PDF p. 2, post #1).
- The first post offers three alternative exit packages: a 50-pip initial stop with HA/trailing exit; a 50-pip stop and 50-pip target with stop moved to +1 at +25; or half off at +25 with the remainder moved to break-even and trailed (PDF p. 2, post #1).
- The author subsequently selects the first package for his own forward test: “I will use a 50 pip stop loss and trail the stop behind the second to last heiken ashi” (PDF p. 6, post #16). He separately describes the exit as “exit on a HA change against the trade” (PDF p. 3, post #8).
- Closed-bar behavior is reinforced by the author's alert description: it “only signals once the candle has closed” (PDF p. 15, post #44).
- Version drift: post #20 adds a discretionary comparison of relative currency strength when choosing between simultaneous pair signals (PDF p. 7). Post #22 explains HA dojis as especially useful reversal shapes, but does not replace the first-post color-turn rule (PDF p. 8). The daily countertrend gold trade in posts #24/#32 is a discretionary exception, not the final H4 core ruleset.

## 2. Entry

- Execution timeframe: H4. Evaluate once, immediately after an H4 bar has fully closed. Never use the forming H4 bar.
- Indicators:
  - 100-period simple moving average of ordinary close on H4.
  - Standard Heiken-Ashi candles on H4.
  - Stochastic oscillator `(8,3,3)` using Low/High price input on H4.
- Long sequence on closed bars:
  1. Ordinary price is above SMA(100).
  2. The SMA and price action constitute an established, smooth uptrend.
  3. A smooth HA pullback has printed one or more red candles.
  4. The just-closed HA candle turns green.
  5. On that same close, the stochastic main line crosses upward through its signal line “towards the bottom” of the oscillator.
  6. Enter at the first tradable price of the next H4 bar.
- Short sequence is exactly symmetric: price below SMA(100), established smooth downtrend, green HA pullback, just-closed HA candle turns red, and a downward stochastic cross “towards the top”; enter at the next H4 bar's first tradable price.
- A mechanical cross can be represented as `K[2] <= D[2] && K[1] > D[1]` for long and the inverse for short, where index 1 is the just-closed H4 bar. This does not resolve the source's unstated stochastic “bottom/top” boundary.
- The source does not quantify “smooth,” “for a period of time,” SMA slope, pullback length, or the stochastic bottom/top zones. A faithful implementation must obtain those definitions during reconciliation; this spec does not silently replace them with a one-bar SMA slope or conventional 20/80 thresholds.

## 3. Exit

- Final author-selected package in the captured material: no fixed take-profit; start with a 50-pip protective stop and trail behind the second-to-last fully closed HA candle as the trade advances.
- For a long, the natural mechanical interpretation of “behind” is below the low of HA bar `[2]`; for a short, above the high of HA bar `[2]`. The source gives no extra buffer. Never widen the protective stop.
- Close any remainder after a fully closed HA candle changes color against the trade. Do not exit from an intrabar HA color flicker.
- The first post's fixed 50/50 and half-at-25 alternatives are test variants, not the package Hugh Briss chose in post #16.

## 4. SL/TP sizing

- Initial SL: exactly 50 pips from entry in the adverse direction for the author's selected H4 package.
- TP: NONE STATED for the selected package. Its profit exit is the HA color change/trailing stop.
- Trail: second-to-last closed HA candle, with no stated pip buffer. Whether “second to last” means HA index `[2]` at every H4 close or the second most recent completed swing candle is not defined; the literal bar-index reading is the closest mapping.
- “Pip” normalization for JPY and non-FX instruments is not stated. The core examples are FX; the daily gold example uses a different discretionary stop and is not part of this H4 package.

## 5. Filters/Session

- Direction filter: trade only with price's side of the H4 SMA(100) and a visibly smooth trend.
- Avoid sideways/slowing or reversing conditions. The author warns that trend traders should be careful when the trend is slowing or reversing (PDF p. 12, post #36) and rejects examples because H4 is sideways or the trend is slowing (PDF pp. 16–17, posts #49/#51).
- Optional discretionary pair selection: compare related currency crosses and favor the relatively stronger currency against the weaker one (PDF p. 7, post #20). No formula or mandatory threshold is supplied, so it is not mechanizable as written.
- Session filter: NONE STATED.
- News blackout: NONE STATED in the source. Any eventual QuantMechanica build still requires the framework's mandatory fail-closed news blackout as an external risk overlay, not as a claimed source rule.

## 6. Money management

- The source-selected trade package fixes stop distance but does not state a lot-sizing formula or exact percentage risk. Post #31 only advocates risking “a %” of the account (PDF p. 11).
- Do not infer confidence-weighted sizing from mrluckystar's posts; that is another participant's discretionary practice.
- No martingale, grid, loss-recovery sizing, or position adding is part of the core rules.

## 7. Edge cases

- Gaps through entry or stop: NONE STATED. Use ordinary next-available-price and broker stop execution semantics; record slippage.
- Weekend holding/closure: NONE STATED.
- Missing H4 bars or insufficient 100-SMA/HA/Stochastic history: do not signal until every indicator has complete closed-bar history.
- Simultaneous signals across pairs: the author optionally ranks them by discretionary relative strength, but supplies no deterministic rule. Portfolio exposure and correlated-signal caps are unstated.
- Re-entry after a stop: NONE STATED. Require a fresh, fully closed color-turn plus stochastic-cross signal; do not reuse the stopped signal.
- Position already open: pyramiding and duplicate same-symbol entries are unstated. A later implementation must choose a cap explicitly; do not infer adding from the separate discretionary gold example.
- HA doji with no color change: post #22 calls it useful, but the core entry requires the stated color turn. Treat doji-only entry as a separate unresolved variant.

## 8. Expected trade frequency

- The author says that across his watched markets it is “usual to see 5 or more trades per week,” while also warning that trend-following periods can produce no trades (PDF p. 1, post #1).
- Estimated frequency for one liquid FX symbol on H4: roughly 12–35 entries/year, assuming an 8–15-pair watchlist behind the aggregate statement. This is a source-derived allocation estimate, not measured evidence.
- The one-symbol stream is episodic and must be checked empirically. It is likely, but not guaranteed, to clear the Q02 floor of 5 trades/year.

## 9. Ambiguities

- Numeric definition and lookback for a “smooth” SMA trend and “classic zig zag.”
- Numeric stochastic bottom/top zones; which plotted stochastic line leads; MA method and price field beyond the stated `(8,3,3, low/high)`.
- Whether ordinary close, HA close, or another “price” is compared with SMA(100).
- Minimum red/green pullback length, whether a same-color HA doji qualifies, and whether the stochastic cross must occur on exactly the color-turn bar.
- Exact standard HA formula intended. The author's prose description of HA open is imprecise and should not override the platform-standard formula without reconciliation.
- Exact stop anchor implied by “behind the second to last heiken ashi,” buffer, update cadence, and precedence between the trail and closed-color exit.
- Same-symbol position cap, re-entry delay, correlated-pair risk cap, spread ceiling, and weekend handling.
- Whether the discretionary relative-strength scan is mandatory or merely a ranking aid.

## 10. MQL5 mapping notes

- SMA(100) is native via `iMA` with `MODE_SMA` and `PRICE_CLOSE`.
- Stochastic is native via `iStochastic`; use K=8, D=3, slowing=3 and Low/High price mode. The source does not name the stochastic MA method, so using the platform default must be recorded as a reconciliation choice.
- Heiken-Ashi is trivially computed or available as the platform example indicator. Persist only completed HA values; the forming HA candle can change color intrabar.
- All indicator buffer reads must use closed shifts. Warm up enough H4 history for SMA(100), stochastic smoothing, and recursively calculated HA values.
- Normalize one pip by symbol digits/tick size rather than assuming one point. Validate stop distance against the symbol's trade-stops level.
- The qualitative trend and oscillator-zone predicates are the main non-code blockers; fail validation rather than embedding untraceable visual discretion.
