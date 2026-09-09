# Video evidence — René Balke USDJPY Range Breakout: clock, outside-range, buffer, numbers (2026-09-09)

Executed by: Claude (Orchestrator, interactive session) under OWNER instruction 2026-09-09 ~21:00Z
("Die Videorecherche können du, Astra, Sonnet, Opus und agy durchführen"). Router task `4a3a4a02`
(OWNER-VID-BALKE-CLOCK). Method: captions on file (proxy transcripts,
`D:\QM\reports\research\balke_symbol_transcripts\transcript_*_timestamped.txt`). The Chrome
connector was not connected (2026-09-09T21:1xZ), so **no frame was viewed**; every on-screen-only
value is marked `NICHT GEZEIGT` and stays a GAP. Timestamps are `[hh:mm:ss]` of the cited video.

Sources:
- `Pay-JP34YSI` — "My Settings for the Range Breakout EA in USDJPY and GBPUSD" (Apr 2024)
- `mOa4dqxAh4g` — "Explaining all the Settings of my Range Breakout EA (New/Latest Version)" (Feb 2025)
- `docs/research/balke_symbols_survey_2026-07-15.md` (prior survey, same transcripts)

## Headline finding

**The 03:00–06:00 window is not Balke's USDJPY setting.** It entered our lineage as the OWNER's
own specification on 2026-06-27 (`docs/research/BALKE_RANGE_BREAKOUT_QM5_12700_2026-06-27.md`
line 3: "OWNER ask: take the René Balke range-breakout EA, range 03:00–06:00, close …"), was
carried into QM5_13213 ("gmt3 normalization") and QM5_41097/41398. Balke's published live/FTMO
USDJPY configuration in `Pay-JP34YSI` is **range 00:00–07:30 (450 min), delete orders and close
positions 18:00**, with no range filter, no trailing stop, no break-even, max 1 buy + 1 sell per
day, SL = opposite side of the range, no take-profit, 0.5 % risk. (The 03:05–06:05 window is his
**gold** configuration per the 2026-07-15 survey, which may be the origin of the confusion.)

## Answers to Q1–Q6

| Q | Answer | Evidence |
|---|---|---|
| Q1 Clock | Times are the **EA inputs in his MT4/MT5 tester**, i.e. **broker server time of his backtest/live broker**. He never states a GMT offset or "German time" on-air. Which broker/offset the tester used is on-screen only. | `Pay-JP34YSI` [00:02:44]–[00:02:56] "trade the range from 4:00 in the morning until 12 … delete orders and close positions at 18:00"; [00:08:44]–[00:09:13] USDJPY "we trade from 0 to 730 … 450 minutes … delete at 18:00, close at 18:00". Offset: **NICHT GEZEIGT** (survey GAP "never stated on-air; inferred GMT+2/+3"). |
| Q2 Price already outside the range at range end | Not described verbally. His EA places stop orders at range end and removes the opposite order after the fill / max-trades rule; the case "price already beyond the range" is never spoken about. | `mOa4dqxAh4g` [00:20:27]–[00:21:13] (first sell executed, buy stop still visible, removed after second trade / max-2 rule). Behaviour for already-outside price: **NICHT GEZEIGT / not stated** → GAP; establish from our own tester journal (Astra S2). |
| Q3 Buffer | His EA has an **"order buffer points"** input: stops are placed X points above/below the range, "a little puffer for fake breakouts"; in the settings demo he used **20 points**. Whether his **live USDJPY** setting uses a buffer > 0 is on-screen only. | `mOa4dqxAh4g` [00:06:40]–[00:06:57], [00:20:03]–[00:20:24]. Live USDJPY buffer value: **NICHT GEZEIGT** (inputs shown on screen at [00:08:52]–[00:09:17] of `Pay-JP34YSI`). |
| Q4 Stop / target | **SL factor 1 = opposite side of the range; no take-profit.** SL/TP are always computed from range high/low, not from the fill price. No trailing, no break-even on the FTMO account (break-even used on two other accounts). | `Pay-JP34YSI` [00:02:33]–[00:02:42], [00:03:01]–[00:03:15]; `mOa4dqxAh4g` [00:21:15]–[00:22:01]. |
| Q5 Filters | **No range filter, no moving-average filter** in the GBPUSD/USDJPY tests ("everything's the same, just the time changes" for USDJPY). His EA does offer min/max range filters (points and/or percent) that skip the day; he does not use them here. Max **2 trades/day** (1 buy + 1 sell). | `Pay-JP34YSI` [00:05:09]–[00:05:19], [00:08:37]–[00:08:49], [00:03:17]–[00:03:24]; `mOa4dqxAh4g` [00:14:43]–[00:15:38]. → Our ATR(14) 0.4–2.5 range band is **not** a Balke rule for USDJPY. |
| Q6 Numbers | Backtest 2013-01-01 → mid-April 2024, Tick Data Suite data, 100K account, 0.5 % risk; "even way better than the test in GBPUSD"; critics' "5 % per year" is quoted, not his figure. **PF / net / drawdown / trade count: NICHT GEZEIGT** in captions (key-figures screen at [00:10:09]–[00:10:13]). | `Pay-JP34YSI` [00:09:25]–[00:09:33], [00:10:02]–[00:10:13], [00:10:39]–[00:10:45]. |

## Consequences for QM5_41398 / the Astra audit (`d444a7a8`)

1. Our instrument implements a **different strategy variant** (03:00–06:00 fixed UTC+3, ATR range
   band, trailing +1R, exit-on-recross) than Balke's published USDJPY configuration. Comparing our
   PF 1.16 with Balke's numbers is not like-for-like even before the clock question.
2. Primary hypothesis for the matrix is now **H-WINDOW**: Balke's actual configuration
   (range 00:00–07:30 broker time, close 18:00, no range filter, no trailing, max 2/day, SL opposite
   side, buffer 0 and 20 points) reproduces materially better economics on Darwinex .DWX data than the
   03:00–06:00 variant. Refutation: costed PF and net over 2018–2025 not better than cell 0 in both
   halves. Note the 07:30 range end needs **minute granularity** (M5/M15 range bars), which the
   H1-bar range builder of 41398 cannot express — the sibling needs a bar-period input for the range
   scan.
3. Clock modes remain to be tested (GMT3_FIXED vs BROKER_DST vs CET) because the offset was never
   stated on-air; BROKER_DST is the most plausible reading of "EA inputs in the tester".
4. Remaining on-screen GAPs (3 frames, ~2 minutes of OWNER time, or a connected Chrome session):
   `Pay-JP34YSI` [00:08:52] (USDJPY input sheet: buffer, filters, max trades), [00:10:11] (key figures:
   PF, DD, net, trades), [00:05:26] (visual tester chart: server-time axis → offset).

## Not claimed

No economic result, no verdict change, no statement about Balke's live account beyond his words.
