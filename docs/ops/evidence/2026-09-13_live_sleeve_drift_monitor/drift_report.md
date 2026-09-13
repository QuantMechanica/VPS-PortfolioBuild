# Live Sleeve Drift Monitor (qm.live-sleeve-drift/v1)

Generated: 2026-09-13T20:43:38Z | terminal_state=RUNNING | overall verdict: **ALARM**

Sleeves: 24 | OK 19 / WARN 2 / ALARM 3

| Sleeve | Days live | lambda_bt | Expected | Fills | Placements | P(X<=obs) | Activity | Perf n/p | Last heartbeat | Verdict | Alarms |
|---|--:|--:|--:|--:|--:|--:|---|---|---|---|---|
| 12778|AUDUSD | 45 | 0.112005 | 5.0402 | 0 | 0 | 0.006472 | ALARM | 0/- | 2026-09-11 (0td) | **ALARM** | ALARM_DARK, ALARM_WARMUP_EMPTY |
| 12969|USDJPY | 45 | 0.15424 | 6.9408 | 0 | 0 | 0.000967 | ALARM | 0/- | 2026-09-11 (0td) | **ALARM** | ALARM_DARK |
| 13117|EURGBP | 44 | 0.104208 | 4.5852 | 0 | 0 | 0.010202 | WARN | 0/- | 2026-09-11 (0td) | **ALARM** | WARN_LOW_ACTIVITY, ALARM_WARMUP_EMPTY |
| 10440|NDX | 55 | 0.317575 | 17.4666 | 10 | 10 | 0.039372 | WARN | 0/- | 2026-09-11 (0td) | **WARN** | WARN_LOW_ACTIVITY |
| 1556|XAUUSD | 45 | 0.029742 | 1.3384 | 6 | 6 | 0.999521 | WARN | 6/- | 2026-09-11 (0td) | **WARN** | WARN_HIGH_ACTIVITY |
| 10403|XAUUSD | 45 | 0.10157 | 4.5707 | 4 | 56 | 0.518747 | OK | 4/- | 2026-09-11 (0td) | **OK** | - |
| 10513|XAUUSD | 55 | 0.033531 | 1.8442 | 2 | 2 | 0.718763 | OK | 0/- | 2026-09-11 (0td) | **OK** | - |
| 10706|GBPUSD | 45 | 0.167754 | 7.5489 | 8 | 8 | 0.655237 | OK | 0/- | 2026-09-11 (0td) | **OK** | - |
| 10911|GDAXI | 55 | 0.170092 | 9.3551 | 17 | 17 | 0.992276 | OK | 9/- | 2026-09-11 (0td) | **OK** | - |
| 10919|XTIUSD | 50 | 0.015504 | 0.7752 | 0 | 0 | 0.460615 | OK | 0/- | 2026-09-11 (0td) | **OK** | - |
| 10939|GBPUSD | 55 | 0.044167 | 2.4292 | 2 | 2 | 0.562102 | OK | 1/- | 2026-09-11 (0td) | **OK** | - |
| 11132|SP500 | 55 | 0.042319 | 2.3275 | 5 | 5 | 0.96852 | OK | 4/- | 2026-09-11 (0td) | **OK** | - |
| 11165|AUDCAD | 41 | 0.097504 | 3.9976 | 6 | 6 | 0.889571 | OK | 6/- | 2026-09-11 (0td) | **OK** | - |
| 11165|EURUSD | 41 | 0.121837 | 4.9953 | 3 | 3 | 0.265684 | OK | 3/- | 2026-09-11 (0td) | **OK** | - |
| 11421|AUDUSD | 55 | 0.047535 | 2.6144 | 3 | 18 | 0.732857 | OK | 1/- | 2026-09-11 (0td) | **OK** | - |
| 11421|EURUSD | 55 | 0.04596 | 2.5278 | 5 | 24 | 0.956098 | OK | 3/- | 2026-09-11 (0td) | **OK** | - |
| 11708|EURUSD | 45 | 0.088446 | 3.9801 | 3 | 8 | 0.437375 | OK | 2/- | 2026-09-11 (0td) | **OK** | - |
| 12567|XAUUSD | 55 | 0.040988 | 2.2544 | 0 | 0 | 0.104942 | OK | 0/- | 2026-09-11 (0td) | **OK** | - |
| 12567|XNGUSD | 55 | 0.030446 | 1.6745 | 0 | 0 | 0.187394 | OK | 0/- | 2026-09-11 (0td) | **OK** | - |
| 12989|XAUUSD | 50 | 0.025797 | 1.2898 | 0 | 0 | 0.275317 | OK | 0/- | 2026-09-11 (0td) | **OK** | - |
| 13128|NDX | 45 | 0.029771 | 1.3397 | 0 | 0 | 0.261921 | OK | 0/- | 2026-09-11 (0td) | **OK** | - |
| 13213|USDJPY | 44 | 0.743363 | 32.708 | 30 | 60 | 0.35907 | OK | 12/0.952252 | 2026-09-11 (0td) | **OK** | - |
| 13301|GDAXI | 42 | 0.441404 | 18.539 | 15 | 30 | 0.246237 | OK | 11/0.781447 | 2026-09-11 (0td) | **OK** | - |
| 1567|EURUSD | 43 | 0.044722 | 1.923 | 1 | 1 | 0.427238 | OK | 0/- | 2026-09-11 (0td) | **OK** | - |

## Alarms

- **ALARM ALARM_DARK** `12778|AUDUSD` - fills=0 (placements=0, no_entries) expected=5.0402 P(X<=obs)=0.006472 days_live=45
- **ALARM ALARM_WARMUP_EMPTY** `12778|AUDUSD` - BASKET_WARMUP loaded=0 x34
- **WARN WARN_LOW_ACTIVITY** `10440|NDX` - fills=10 (placements=10, journal_fill_join) expected=17.4666 P(X<=obs)=0.039372 days_live=55
- **ALARM ALARM_DARK** `12969|USDJPY` - fills=0 (placements=0, no_entries) expected=6.9408 P(X<=obs)=0.000967 days_live=45
- **WARN WARN_HIGH_ACTIVITY** `1556|XAUUSD` - fills=6 (placements=6, journal_fill_join) expected=1.3384 P(X>=obs)=0.002572
- **WARN WARN_LOW_ACTIVITY** `13117|EURGBP` - fills=0 (placements=0, no_entries) expected=4.5852 P(X<=obs)=0.010202 days_live=44
- **ALARM ALARM_WARMUP_EMPTY** `13117|EURGBP` - BASKET_WARMUP loaded=0 x33
