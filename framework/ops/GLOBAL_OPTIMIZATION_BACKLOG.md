# Global Optimization Backlog - Time-Range & Parameter Hunting

This document outlines the systematic optimization plan for all EAs with time-sensitive logic or session-based entry rules.

## Priority 1: Morning & Session Breakouts (The "Balke" Class)

| EA ID | Name | Optimization Strategy | Target Symbols |
| :--- | :--- | :--- | :--- |
| **QM5_1142** | USDJPY Time-Range BO | Scan 0-23h start, 60-480m duration, Long-Only vs Both | USDJPY, EURJPY, Gold |
| **QM5_5003** | Balke Session | UTC 7-10h range start, Volume multiplier 1.0-3.0 | GDAXI, NDX, EURUSD |
| **QM5_10003** | Xaron Morning BO | CET 7-11h range start, Time-stop 12-24h | EURUSD, GBPUSD, GDAXI |
| **QM5_10001** | Static Fib Open | Tokyo Open hour (22-02h), Fib Levels 38.2-78.6 | USDJPY, AUDJPY |

## Priority 2: Intraday Seasonality & Overnights

| EA ID | Name | Optimization Strategy | Target Symbols |
| :--- | :--- | :--- | :--- |
| **QM5_10012** | Intraday Seasonality | All 48 M30 slots (0-47), Filter by Skew/Vol | All Major Forex, Gold |
| **QM5_10020** | SPX Overnight | Entry hour 21-02h, Exit hour 14-18h | SP500, NDX, GDAXI |
| **QM5_10007** | PrevDay BO Edge | Boundary UTC hour (20-02h) | EURUSD, GBPUSD |
| **QM5_10010** | AR10 Reversal | NY Close hour (21-01h), Reversal sensitivity | All Majors |

## Priority 3: Time-Stop & Holding Periods

| EA ID | Name | Optimization Strategy | Target Symbols |
| :--- | :--- | :--- | :--- |
| **QM5_10009** | Cointeg BB | Time-stop multiplier 1.0-5.0, D1 Cap | EURUSD, AUDUSD |
| **QM5_10024** | Comm Basket | Time-stop days 5-40 | USDCAD, AUDUSD |
| **QM5_1017** | Pairs Stat Arb | OU Half-life multiplier 0.5-2.5 | AUDUSD/NZDUSD, EURUSD/GBPUSD |

## Execution Protocol (for Agents & MT5 Farm)

1.  **Template Generation:** Create `sets/*_P3_Optimization.set` for each EA listed above.
2.  **Queue Enqueue:** Add `kind: optimization`, `phase: P3` work items to `farm_state.sqlite`.
3.  **Result Aggregation:** Pipeline-Op collects `optimization_report.csv`.
4.  **Walk-Forward Trigger:** Top 5 settings for each symbol automatically move to `phase: P4`.
5.  **Review:** OWNER signs off any sleeve-deployment decision after the required evidence gates.
