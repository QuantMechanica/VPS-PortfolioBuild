# QM5_9936 USDJPY drawdown diagnosis — 2026-07-27

## Recommendation

Build one isolated variant first: **Tuesday-off**. It is the only available
split with a directly observed, repeated negative contribution. Do not modify
QM5_9936 in place and do not queue the variant until tester capacity is
allocated.

## Evidence and diagnosis

Source: the 1,252 closed trades in
`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl`,
2017-10-09 through 2025-12-30. Amounts below are divided by the native $1,000
fixed risk, so 1.0 is approximately one account-percent at the specified 1x
sizing. No commission, swap, DST, or volatility value was invented.

The deepest consecutive losing runs are not one isolated episode: 12 runs lost
at least 5.1R; the worst lost 8.16R across 8 trades (2023-05-23 to 2023-06-06),
followed by 7.15R (7 trades, 2023-01-23 to 2023-02-03) and 6.26R (7 trades,
2020-07-23 to 2020-08-06). This recurrence across years is the mechanism behind
the 8.18% p90 window drawdown: ordinary near-1R stop losses cluster.

The strongest ex-ante discriminator available in the stream is weekday:

| Close weekday | Trades | Net R | Mean R/trade | Loss rate |
|---|---:|---:|---:|---:|
| Monday | 230 | +22.47 | +0.098 | 47.8% |
| **Tuesday** | **214** | **-11.00** | **-0.051** | **55.6%** |
| Wednesday | 267 | +47.95 | +0.180 | 47.6% |
| Thursday | 279 | +46.32 | +0.166 | 47.7% |
| Friday | 262 | +58.72 | +0.224 | 45.0% |

Tuesday is uniquely negative and has the highest loss rate. The effect is not a
story inferred from the worst streak; it uses all 214 Tuesday observations.
Year is not a stable switch: 2019 and 2023 are negative, while 2018, 2020,
2022, 2024 and 2025 are positive.

Close hour is descriptive, not a permissible entry filter: trades closing
05:00–12:59 UTC total -154.2R while 19:00–20:59 total +373.2R, but early closes
are predominantly stops and late closes predominantly survivors. Filtering on
the future close hour would be look-ahead and is rejected.

## Ranked variants

1. **`QM5_<new>_ff-range-breakout-gmt3-h1-tuesday-off`** — add a mechanical
   weekday entry guard, with no other change. Expected: reduce `wDD_p90` and
   improve worst day modestly; historical med60 should not fall because the
   removed subset is -11.0R in aggregate. **SPECULATIVE magnitude:** the stream
   does not establish that p90 DD will halve. Overfit test: choose Tuesday-off
   using 2017–2021 only, freeze it, then require improvement in 2022–2025 and
   across GBPUSD/NDX without selecting their weekday separately.
2. **`...-range-filter-tight`** — one small predeclared grid around existing
   `strategy_min_range_atr_mult=0.4` and `strategy_max_range_atr_mult=2.5`
   (for example one inward step per boundary, tested one-at-a-time).
   **SPECULATIVE:** clustered stop-outs may be non-productive volatility
   regimes; the Q08 stream does not carry range/ATR-at-entry, so no causal
   claim is established. Expected: lower drawdown but likely lower med60 through
   fewer trades. Overfit test: parameters selected only on early folds must
   improve p90 DD on untouched late folds and both neighboring values must show
   the same direction.
3. **`...-cancel-earlier`** — test a single earlier
   `strategy_order_cancel_hour_gmt3` against 13. **SPECULATIVE:** later breakouts
   may have poorer continuation, but entry-hour-conditioned expectancy was not
   available in the stream. Expected: lower trade count and possibly shallower
   streaks, with material med60 risk. Overfit test: require monotone behavior
   over two adjacent cancel hours and unchanged sign out of sample; reject if
   benefit comes from a handful of removed losses.

Changing the trailing trigger or session close from this evidence is not
recommended: close time is outcome-contaminated and cannot establish an
entry-time regime.

## Gate contract

Every proposal is a new EA/sleeve identity with new registry and magic rows. It
inherits no evidence from QM5_9936 and must run the normal Q02–Q10 sequence,
including mandatory news blackout and fixed-risk backtest settings
(`RISK_FIXED>0`, `RISK_PERCENT=0`). FUND_SCORE remains screening only and cannot
override any gate. No backtest was queued and no terminal or live setting was
touched.
