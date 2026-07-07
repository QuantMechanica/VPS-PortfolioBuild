# Novo Legacy One 4-Hour Candle Course - Mechanization Dossier

Task: `3b1fe1ab-fc8c-4362-94d1-466ae3ebb97f`
Source: `https://www.youtube.com/watch?v=fNFTpKmSQB8`
Video title: `the trading industry is broken... so I am leaking my $8.5k course`
Channel: Novo Legacy
Extraction date: 2026-07-07

## Verdict

EXTRACTED_WITH_REVIEW_CAVEATS. The full public-caption transcript was fetched and read. Two distinct strategy candidates are extractable to a mechanical draft standard:

1. Candle Impulse Theory (CIT) / Novo Box continuation.
2. Candle Range Theory (CRT) / 5 a.m. range sweep reversal.

Do not approve directly for build without reviewer decisions on exact `CSD/change in state`, `breaker block`, and Fibonacci anchor codification. The author teaches those visually and through examples, but not with a fully formal bar-index formula. Risk sizing is source-silent, so any Strategy Card must use QM defaults: `RISK_FIXED > 0`, `RISK_PERCENT = 0` for backtest, and total open risk capped at <=1% account equity per symbol.

Raw evidence:

- Transcript JSON: `D:/QM/strategy_farm/artifacts/research/3b1fe1ab_novo_legacy_transcript_2026-07-07.json`
- Proxy attempt evidence: `D:/QM/strategy_farm/artifacts/research/3b1fe1ab_novo_legacy_proxy_attempts_2026-07-07.json`
- Transcript rows: 4561 public-caption entries.

## Shared Source Mechanics

- The system is presented as usable on forex, futures, stocks, and crypto, but examples and live execution focus on NASDAQ/NQ, S&P/ES, and gold. [00:00:20-00:00:32], [01:03:52-01:04:00], [01:33:12-01:33:16]
- On Oanda charts in Eastern time, the six 4-hour candles start at 1:00, 5:00, 9:00, 13:00, 17:00, and 21:00. The author personally trades the 5:00 candle every morning. [00:03:46-00:04:10]
- On CME/futures or some forex chart feeds, the displayed equivalent candles are 2:00, 6:00, 10:00, 14:00, 18:00, and 22:00 Eastern. For crypto he names 3, 7, and 11. For stocks he maps his 5:00 candle to the 13:30 stock-market candle. [00:04:14-00:04:50]
- A 4-hour candle cannot be used until it is closed. For the 5:00 candle, no entry is allowed before 9:00 because the candle closes at 9:00. For the 1:00 candle, no entry is allowed before 5:00. [01:01:50-01:03:10]
- Primary timeframe alignment is 4H context to 5M entry. The author sometimes uses 2M/3M/15-second examples, but his taught default is 4H -> 5M. [00:31:11-00:31:19], [01:10:22-01:10:30], [01:40:41-01:41:08]
- The New York execution window is 9:00-11:00 or 9:00-11:30 Eastern, with 9:30 open repeatedly identified as the key sweep/open time. [00:36:46-00:37:14], [01:21:45-01:22:35], [01:33:16-01:33:20]
- News handling: red-folder news around 8:30 is explicitly a no-entry-before-news condition; wait for the event because it can create the sweep. QM implementation must enforce mandatory news blackout. [01:21:45-01:22:00], [01:26:01-01:26:17]
- Novo/Gann box levels are 0, 25, 50, 75, and 100 percent. The 25-50 region is the normal retracement zone; 75+ is danger/overextension for impulse logic. [00:26:01-00:26:24], [00:27:22-00:30:09]
- For a bullish impulse candle, draw the box from candle high to candle low so 25% is closest to the bullish close; for a bearish impulse candle, draw it from low to high so 25% is closest to the bearish close. [00:26:48-00:27:18], [00:29:32-00:29:44]
- Previous candle close (PCC) is central: longs should be entered below PCC; shorts should be entered above PCC. [00:25:16-00:25:28], [00:35:42-00:35:56], [00:50:34-00:50:55]

## System 1 - Candle Impulse Theory (CIT) / Novo Box Continuation

### Thesis

CIT is the continuation/impulse playbook. It assumes a strong recent 4H direction should continue after a controlled retracement into the next candle's 25-50% Novo Box zone, with the entry taken on lower-timeframe state change back in the impulse direction. [00:05:37-00:06:04], [00:48:46-00:50:08]

### Mechanical Rule Set

- Instrument preference: source examples favor NASDAQ/NQ, S&P/ES, and gold; for QM commission physics, rank index/metals first and FX last unless spread evidence says otherwise. [01:03:52-01:04:00], [01:33:12-01:33:16]
- Context timeframe: closed 4H candle. Entry timeframe: 5M by default. [00:31:11-00:31:19], [01:40:41-01:41:08]
- State filter: look only at the last three to four 4H candles for immediate trend, not distant highs/lows. Long state requires aligned bullish candles with major bodies or increasing momentum; short state is symmetric bearish alignment. [00:48:53-00:50:08], [01:50:53-01:51:23]
- Reject/stand aside if the setup retraces into the 75% danger/overextended zone or reaches full reversal. [00:29:44-00:30:09]
- Draw Novo/Gann box on the impulse 4H candle using 0/25/50/75/100. Preferred retracement is 25-50%; 0-25 can be premature but valid. [00:26:01-00:26:24], [00:27:22-00:28:24], [00:50:20-00:50:37]
- Only use a retracement born in the new/current candle after the anchor candle closes. A retracement that occurred before the new candle open is not part of the CIT entry. [00:53:05-00:54:58]
- Long entry: after the new candle opens, wait for price to retrace into 25-50 and below PCC; then wait for lower-timeframe CSD/change-state candle close in the long direction. Enter at/after that close. [00:50:34-00:51:18], [00:55:17-00:56:10], [01:40:18-01:40:37]
- Short entry: symmetric. Wait for retracement into 25-50 and above PCC; then wait for lower-timeframe CSD/change-state close in the short direction. Enter at/after that close. [00:25:16-00:25:28], [01:51:15-01:53:13]
- Additional liquidity/turtle-soup evidence is a positive filter but not sufficiently formal as a required rule. [00:51:04-00:52:18], [00:55:11-00:55:27]
- Long stop: just below the lower-timeframe entry low and below the 50% level. [00:56:07-00:56:17]
- Short stop: example places the stop above the 25% level after bearish change-state entry. [01:53:09-01:53:27]
- Mechanization decision needed: define the stop as the more conservative of (a) CSD swing extreme plus spread/buffer and (b) relevant box invalidation level. This is inferred from examples, not stated as a single author formula.
- Initial target: range high for longs and range low for shorts / external liquidity in the impulse direction. [00:35:42-00:35:56], [00:50:48-00:51:00], [01:59:41-02:00:00]
- Fibonacci targets named by source: 1.272, 1.7, and 2.145. Slow/late day: use 1.272; stronger volatility can target 1.7 or 2.145. [01:28:40-01:31:10]
- For a bearish extension, draw from recent low to recent high; for bullish, draw from recent high to recent low. [01:31:52-01:32:03]
- Example CIT short uses TP at 1.272 for about 1:2 from the lowest chart point to the 4H candle high. [01:53:25-01:53:56]
- No explicit source time-stop formula. The author tends to stop looking around 10:30 and expects many TPs by 10:30-11:30, but this is live-management commentary rather than a formal exit. [02:00:50-02:01:21], [02:03:20-02:03:28]

### Buildability Notes

Buildable only after reviewer approves deterministic definitions for `CSD/change-state`, `breaker block`, and Fibonacci anchor lookback. Source is silent on sizing; use QM fixed-risk defaults and cap total risk <=1% equity per symbol. Enforce news blackout.

## System 2 - Candle Range Theory (CRT) / 5 a.m. Range Sweep Reversal

### Thesis

CRT is the author's ranging/reversal playbook. It treats one completed 4H candle as an objective range. A quick sweep outside that range during the next session sets directional bias back toward the opposing side of the range. [00:57:41-01:00:22], [01:10:50-01:11:39]

### Mechanical Rule Set

- Instrument preference: source examples again emphasize gold, NASDAQ/NQ, and S&P/ES. [01:03:52-01:04:00], [01:33:12-01:33:16]
- Context timeframe: completed 4H range candle. Entry timeframe: 5M default. [00:59:39-01:00:22], [01:10:22-01:10:30]
- Default anchor: author's Oanda/forex chart uses the 5:00 candle; futures/FXCM equivalent is 6:00. Mark that completed 4H candle high and low. [00:57:45-00:58:17], [01:32:40-01:33:05]
- Range state filter: last 4H candles are indecisive, smaller, more wick than body, and alternating bullish/bearish rather than directional. [01:01:10-01:01:28], [01:55:50-01:56:22]
- Wait for the anchor candle to close. Using the 5:00 candle means no trade before 9:00. [01:01:50-01:03:10]
- Sweep window: for the 5:00 candle, look for a sweep from 9:00 to 11:30 Eastern; 9:30 is the most important open/sweep time. [00:59:39-01:00:22], [01:21:45-01:22:35], [01:33:16-01:33:35]
- Sweep definition: price must move outside the 4H range and return back into it. A sustained breakout outside the range is not the ideal CRT sweep. [01:33:20-01:33:35]
- Bias: sweep of the 4H high gives bearish bias toward the low; sweep of the 4H low gives bullish bias toward the high. [01:33:42-01:34:38], [01:56:40-01:57:07]
- Entry trigger: after sweep, wait for lower-timeframe change in state of delivery/body close, return to breaker block, and directional sentiment before entry. [01:18:12-01:19:55], [01:57:12-01:57:32]
- Formalization required: transcript describes CISD as body closes and breaker block as a pierced order block, but does not provide a precise swing-index algorithm. [01:19:15-01:19:55], [01:34:21-01:34:32]
- Short stop: just above CRT high or the day's high. Long stop: symmetric below CRT low or the day's low. [01:57:32-01:57:43]
- Primary target: opposing side of the 4H range. [00:59:49-01:00:22], [01:57:32-01:57:43]
- Conservative target: 50% of the range. The author says it has high hit frequency but lower reward. [01:57:55-01:58:25]
- Extended target: after opposing liquidity is reached or if volatility remains, use Fibonacci 1.272, 1.7, or 2.145, drawn from recent high/low around the sweep. [01:28:40-01:32:03]
- News: do not enter before 8:30 red-folder news; wait through it because it may create the sweep. [01:26:01-01:26:17]

### Buildability Notes

CRT is the stronger candidate for a first Strategy Card because its anchor range, sweep window, bias, stop, and base target are more objective than CIT. Reviewer still must formalize `CISD/change-state` and `breaker block` before build. For QM, force no trades during mandatory news blackout and reject any setup where fixed-risk sizing cannot keep total risk <=1% equity per symbol.

## Discretionary Discard List

- IRS model: described as impulse-range-sweep and an entry/re-entry model, not a standalone strategy with complete stops/targets/sizing. [00:07:57-00:08:18], [00:31:34-00:31:57], [01:38:42-01:39:28]
- Volume profile: the author says it is not a major make-or-break and uses low-volume nodes, POC, VAH/VAL as confirmation/target context. Node selection remains visual. [01:41:17-01:43:40], [01:43:40-01:48:20]
- SMT/divergence: optional add-on; the author says he might add it if feeling lucky, so it is not core mechanical entry logic. [01:35:16-01:35:35], [02:04:04-02:04:34]
- 15-second execution: mentioned for fast entries, but this violates the Edge Lab no-HFT direction and is not needed for the 4H/5M systems. [01:30:23-01:30:32]
- Live management commentary such as de-risking, not going break-even, late re-entries, and Discord calls is not accepted as a complete EA rule set. [02:00:50-02:01:28], [02:09:43-02:11:38]
- Psychology, course marketing, candle anatomy theory, and volume-shape education are context only, not standalone strategies.

## Stacking, Grid, Martingale

No martingale or grid is taught as a required system. The author discusses second entries/rebalancing and live add-ons, but gives no bounded level count, spacing, or sizing schedule. Any future scale-in variant must be separately specified and must cap total open risk <=1% account equity per symbol. [00:28:28-00:30:23], [02:03:43-02:05:58]

## Unverified Claims

- Over $500/day, 84% win rate, and passed prop accounts. [00:00:00-00:00:20]
- Six years and 87,000 candlesticks studied. [00:00:41-00:00:48]
- Over 1000 trades studied for the single candle. [00:02:08-00:02:18]
- CIT automated backtest: 89% bullish, 85% bearish. [00:24:46-00:25:17], [01:50:30-01:50:42]
- CRT automated backtest: 1400 trades, 84.2% win rate. [01:54:36-01:54:51]
- Live trade profit examples, including about $3000 in under 30 minutes. [03:39:43-03:40:00]

These claims are not accepted as performance evidence for pipeline verdicts.

## Review Decisions Needed Before Strategy Card Draft

1. Choose primary card candidate: recommend CRT first, CIT second.
2. Define `CSD/CISD/change-state` as a deterministic bar rule.
3. Define `breaker block` as a deterministic swing/order-block rule or remove it and use close-back-inside-range only.
4. Map Eastern/Oanda/CME candle times to DarwinexZero broker time and DST handling.
5. Choose default target policy: CRT opposing range side, optional 50% conservative mode, optional Fib extension mode.
6. Confirm mandatory news blackout implementation and fixed-risk sizing.

## Verification

- Full transcript fetched with `youtube-transcript-api` and `GenericProxyConfig` against public captions only.
- Direct no-proxy access returned `RequestBlocked`; proxy rotation saved successful transcript via `http://69.87.216.54:7989`.
- Raw transcript JSON contains 4561 rows and covers 00:00:00 through 04:02:05.
- Every accepted rule above is tied to transcript timestamps. Where the transcript is visual or under-specified, this dossier marks a reviewer codification requirement instead of inventing hidden rules.
