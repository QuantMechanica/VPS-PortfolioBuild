# STR-021 independent Codex spec — Weekly-open liquidity sweep and M15 order-block retrace

## 1. Source rules (verbatim-anchored)

- The thread begins with MOP/WOP/DOP as trend and support/resistance context. It defines WOP as “The first trading day’s opening price of the week” and states that price above/below the opening levels indicates bullish/bearish sentiment (PDF p. 1, Sol72).
- The later explicit algorithm makes the weekly open primary. For a buy, “The price must break the level downwards,” then find below it a bearish extreme-volume candle, “Wait for the price to close above the high of the bearish candle,” place a buy limit at that candle's high, and put the stop below its low (PDF p. 14, Sol72). Sell is the symmetric break upward, bullish candle, close below its low, sell limit at its low, and stop above its high (PDF pp. 14–15).
- M15 is the signal timeframe in the worked entries: “The price broke through and closed above the M15 signal candle” (PDF p. 12, Sol72), and the later rationale names a “bearish 15-minute candle with the highest volume” (PDF p. 27, Sol72).
- The decisive final evolution is: “one should only enter after liquidity has been taken out and an order block has formed afterward. Volumes serve only as confirmation” (PDF p. 25, Sol72). This adds sequence: liquidity sweep first, order block second.
- Stated exits are alternatives: next weekly/daily level, next order block, midpoint of an imbalance/FVG, or 1:2 reward:risk (PDF p. 15, Sol72).
- The author says, “My clock is set to UTC” (PDF p. 5, Sol72), but does not answer the follow-up asking the exact daily-open timestamp.
- Version drift: the opening post suggests generic bounces plus candlestick/RSI confirmation. The later author algorithm replaces that broad idea with weekly-level break, post-sweep OB, closed-candle break confirmation, and limit retrace. Page 25 is the final captured rule hierarchy; volume confirms rather than defines the setup.

## 2. Entry

- Target market for this strategy card: metals, evaluated on M15. The source demonstrations are principally ETH/USDT and only discuss oil/gold data availability; transfer to metals is unproven and must remain explicit.
- Establish the current weekly open from the first tradable quote of the UTC trading week. Daily and monthly opens/highs/lows are context and possible targets, not mandatory final-entry filters unless the setup explicitly uses them.
- Long sequence, all decisions from fully closed M15 bars:
  1. Identify a sell-side liquidity reference below/around the weekly open.
  2. Price breaks below the weekly open and takes that sell-side liquidity.
  3. Only after that sweep, identify a bearish M15 signal/OB candle below the level. Volume may confirm it but cannot substitute for the sweep.
  4. A later M15 candle closes above the signal candle's high.
  5. After that confirming close, place a buy-limit order at the signal candle's high.
  6. Enter only if price retraces and fills that limit.
- Short sequence is symmetric:
  1. Identify buy-side liquidity above/around the weekly open.
  2. Price breaks above the weekly open and takes that liquidity.
  3. Only afterward, identify a bullish M15 signal/OB candle above the level.
  4. A later M15 candle closes below the signal candle's low.
  5. Place a sell limit at the signal candle's low and enter only on retrace.
- No intrabar “break confirmation” is valid. A wick may perform the liquidity sweep, but the signal-candle break must be confirmed by a completed M15 close.
- The source does not define liquidity-pool selection, swing lookback, an algorithmic order block, or “extreme” volume. Those are required reconciliation inputs; this spec does not silently equate every prior-bar high/low with liquidity.

## 3. Exit

- Protective stop remains active from entry.
- The source offers four non-ranked profit exits:
  - next weekly or daily level;
  - next order block;
  - midpoint of the next imbalance/fair-value gap;
  - fixed 2R from actual entry relative to stop.
- There is no unique final exit selector or precedence rule. A build must select exactly one `exit_mode` during reconciliation and record it. Fixed 2R is the only fully numeric self-contained option stated by the source, but the source does not declare it the default.
- Trailing stop, break-even move, time exit, and forced week-end exit: NONE STATED.

## 4. SL/TP sizing

- Long SL: below the low of the bearish M15 signal/OB candle.
- Short SL: above the high of the bullish M15 signal/OB candle.
- No tick/pip/ATR buffer beyond the candle is stated.
- TP choices are the four alternatives in section 3. For the 2R variant: `R = abs(entry - SL)` and TP is `entry + 2R` for long or `entry - 2R` for short.
- Limit-order entry means actual fill may differ from the intended signal-candle boundary. Calculate R from actual fill; slippage and gap rules are unstated.

## 5. Filters/Session

- Weekly opening level is primary. Daily and monthly opening levels and daily/weekly highs/lows provide context, liquidity references, and target candidates.
- Mandatory final sequence filter: the liquidity sweep must occur before the order block forms (PDF p. 25).
- Volume is confirmation only in the final rule. Earlier wording calls for “extreme,” “highest,” or “increased” volume, with no lookback/threshold.
- The author rejects FX tick volume as different from actual volume and asks where to obtain oil/gold volume (PDF p. 11). Therefore a metals implementation has no source-approved volume feed or deterministic volume threshold.
- Clock context is UTC; exact metals week/day boundary is not fully stated.
- Session filter: NONE STATED.
- News filter: NONE STATED. Any eventual QuantMechanica EA must add the mandatory framework news blackout as an external fail-closed overlay.
- MOP/WOP/DOP triple alignment and RSI are from the exploratory opening post and are not mandatory in the later final entry algorithm.

## 6. Money management

- Opening-post intent: risk no more than 1–2% of the account per trade and aim for at least 1:2 reward:risk (PDF p. 2, Sol72).
- The later reports of gaining 15% are outcomes, not a sizing rule.
- Multiple pending/filled orders appear in examples, but no total open-risk cap or allocation between entries is stated.
- No martingale, grid, averaging down, HFT, or ML rule is part of the source.

## 7. Edge cases

- Pending-order expiry/cancel: NONE STATED. The author sometimes cancels a buy order when the destination becomes unclear (PDF p. 25), but supplies no mechanical timeout or invalidation level.
- Multiple eligible order blocks after one sweep: no ranking rule. The source discusses competing upper/lower blocks and sometimes places more than one buy order.
- Position already open: additional limits are observed, but maximum entries and shared-risk treatment are unstated.
- Simultaneous long and short candidates: no precedence or netting rule.
- Gap across weekly open, OB boundary, limit, or stop: no handling stated. Record actual fill/slippage and never fabricate a fill.
- Weekend/week rollover: crypto trades continuously and the author notes its week changes Sunday (PDF p. 17); metals do not. Pending-order and position treatment at rollover is unstated.
- Missing bars, missing real volume, or no validated weekly-open quote: fail closed and do not signal.
- If price confirms the OB break but never retraces to the limit: no market chase.
- If a new liquidity extreme is taken before fill, or the signal candle is invalidated before fill: cancellation behavior is unstated.

## 8. Expected trade frequency

- The setup requires a weekly-level excursion, liquidity sweep, a later M15 OB, a closed break-confirmation, and a retrace fill. It is therefore episodic despite the M15 execution chart.
- Estimated frequency for one liquid metal: approximately 8–25 filled trades/year, assuming several qualifying weekly/daily liquidity events but allowing unfilled limits.
- It may clear the Q02 floor of 5 trades/year, but the metals transfer, volume issue, and strict event sequence make that uncertain. Verification is required; this estimate is not pipeline evidence.

## 9. Ambiguities

- Exact UTC definition of WOP/DOP/MOP for a broker-traded metal, including Sunday/Monday open, holidays, and DST.
- Formal sell-side/buy-side liquidity reference: previous daily/weekly extreme, equal highs/lows, local swing, or another pool; lookback and equality tolerance.
- Exact order-block definition, whether it is one candle or a zone, and whether it must be the first opposing candle after the sweep.
- Volume feed for metals, “extreme/highest/increased” threshold and lookback, and whether volume confirmation is mandatory or merely supportive.
- Whether the weekly-open break must close beyond the level or a wick is sufficient.
- Maximum bars allowed between sweep, OB, confirmation, and limit fill.
- Which of the four TP modes is final and how to rank multiple levels/OBs/FVGs.
- Stop buffer, pending-order expiry, invalidation/cancellation, one-position cap, scaling, aggregate risk, and week-roll behavior.
- Whether daily/monthly opening alignment remains a directional filter or only context after the final p. 25 refinement.
- Source-to-target transfer: the worked system is crypto-centric; metals volume and session behavior are not validated by the source.

## 10. MQL5 mapping notes

- Compute UTC-aligned week/day/month opens from validated bar/session data; do not assume broker midnight equals UTC midnight.
- M15 OHLC and closed-bar break checks are native. Persist a state machine: `waiting_for_sweep -> waiting_for_post_sweep_ob -> waiting_for_close_confirmation -> pending_limit -> filled/invalidated`.
- Order blocks, liquidity pools, and FVG midpoints are custom structures and cannot be inferred from a native indicator without definitions from reconciliation.
- Prefer exchange/real volume only if the target symbol supplies validated `real_volume`. CFD tick volume is specifically questioned by the author; missing real volume must not be relabeled as source-compliant confirmation.
- Place limit orders only after the confirmation bar closes. Normalize prices to tick size and validate stop/freeze levels.
- Calculate fixed-2R TP from actual fill and protective stop if that exit mode is selected.
- Preserve event timestamps and source bars in evidence so sweep-before-OB ordering and closed-bar confirmation can be audited.
