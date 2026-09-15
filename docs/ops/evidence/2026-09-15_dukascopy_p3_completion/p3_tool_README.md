# Dukascopy/DWX overlap reconciliation

Symbols: 37; PASS: 0; FAIL: 37.

A PASS here is a source-compatibility result only. It does not enqueue or authorize an import.

| Symbol | Result | Close p95 (points) | Limit | Coverage | DST offset |
|---|---:|---:|---:|---:|---:|
| AUDCAD.DWX | FAIL | 9 | 30.375 | 84.480% | -60 |
| AUDCHF.DWX | FAIL | 8 | 21 | 86.288% | -60,0 |
| AUDJPY.DWX | FAIL | 6 | 9.54167 | 84.735% | -60,0 |
| AUDNZD.DWX | FAIL | 9 | 30.4038 | 84.270% | -60 |
| AUDUSD.DWX | FAIL | 4 | 13.4856 | 83.842% | -60,0 |
| CADCHF.DWX | FAIL | 11 | 22.8 | 84.757% | -120,-60 |
| CADJPY.DWX | FAIL | 6 | 15.8407 | 85.458% | -60,0 |
| CHFJPY.DWX | FAIL | 11 | 29.2571 | 84.769% | 0 |
| EURAUD.DWX | FAIL | 28 | 32.4839 | 0.046% | 0 |
| EURCAD.DWX | FAIL | 10 | 27.569 | 85.575% | 0 |
| EURCHF.DWX | FAIL | 8.9 | 13.7027 | 0.034% | 0 |
| EURGBP.DWX | FAIL | 3 | 10.5818 | 84.833% | 0 |
| EURJPY.DWX | FAIL | 28 | 13.3871 | 0.047% | 0 |
| EURNZD.DWX | FAIL | 18 | 60.2727 | 86.227% | -60 |
| EURUSD.DWX | FAIL | 18 | 4.78125 | 0.035% | 0,None |
| GBPAUD.DWX | FAIL | 31.25 | 44.25 | 0.065% | 0 |
| GBPCAD.DWX | FAIL | 13 | 39.9808 | 86.374% | -60 |
| GBPCHF.DWX | FAIL | 8 | 24.988 | 86.296% | -60 |
| GBPJPY.DWX | FAIL | 33 | 24.1187 | 0.059% | 0 |
| GBPNZD.DWX | FAIL | 28 | 74.25 | 86.312% | -60 |
| GBPUSD.DWX | FAIL | 4 | 9.94737 | 84.722% | 0 |
| GDAXI.DWX | FAIL | 2.49999e+07 | 3908.08 | 84.418% | 0 |
| NDX.DWX | FAIL | 2.55284e+07 | 1681.16 | 0.070% | 0 |
| NZDCAD.DWX | FAIL | 13 | 34.575 | 84.148% | 0 |
| NZDCHF.DWX | FAIL | 7 | 24.0476 | 84.495% | 0 |
| NZDJPY.DWX | FAIL | 7 | 12.8438 | 84.542% | -60,0 |
| NZDUSD.DWX | FAIL | 5 | 14.6078 | 84.594% | 0 |
| SP500.DWX | FAIL | 6.89346e+06 | 1047.58 | 96.679% | 0 |
| UK100.DWX | FAIL | 222.01 | 32.9529 | 96.413% | 0 |
| USDCAD.DWX | FAIL | 6 | 18.3158 | 86.001% | 0 |
| USDCHF.DWX | FAIL | 4 | 11.8085 | 83.974% | -60,0 |
| USDJPY.DWX | FAIL | 21 | 6.13333 | 0.046% | 0 |
| WS30.DWX | FAIL | 4.95358e+07 | 3077.11 | 96.874% | 0,900 |
| XAGUSD.DWX | FAIL | 162 | 75.2727 | 97.679% | -180,0 |
| XAUUSD.DWX | FAIL | 379 | 104.96 | 0.073% | 0 |
| XNGUSD.DWX | FAIL | 26575.3 | 150 | 2.275% | None |
| XTIUSD.DWX | FAIL | 150 | 7.5 | 97.718% | 0 |

Fixed acceptance: overlap spans at least 2025-11-01 through 2026-04-01 and both intervening US-DST transition types; close p95 <= 1.5 x typical DWX spread; DWX session coverage >= 99%; every observed US-DST transition window has a best timestamp offset of 0 seconds; compute time < 2 hours.
