# FTMO NDX session-open ATR long Q02 - 2026-07-10

## Verdict

`QM5_13127_et-open-atr-long` is `Q02 FAIL` and retired. The 2024 and 2025
holdouts were not opened, and no parameter rescue was attempted.

This was a distinct source-faithful repair of `QM5_10375`: long-only NDX M5,
fixed 16:30 session anchor, 0.30 D1 ATR(20) buy-stop band/opposite-band stop,
0.60 ATR target, unchanged spread/news gates, and session time exit. It compiled
strict with zero errors and zero warnings.

## Pre-holdout results

| year | trades | PF | net | close DD | overnight |
|---:|---:|---:|---:|---:|---:|
| 2021 | 123 | 1.382 | 11,189.57 | 2,759.94 | 4 |
| 2022 | 135 | 0.883 | -4,294.48 | 6,530.56 | 1 |
| 2023 validation | 144 | 1.214 | 7,992.17 | 7,402.85 | 2 |
| pooled | 402 | 1.144 | 14,887.26 | 7,402.85 | 7 |

Each valid year had two identical native model-4 runs. Native NDX bid/ask
spread and both commission sides were present. Pooled PF 1.144 is below the
locked 1.20 gate, and 2022 is independently loss-making.

## Additional falsification

Seven positions closed after the entry broker date because the custom symbol
had no usable tick immediately after the 23:00 session boundary. The `.DWX`
reports charged zero swap. Therefore the "intraday-flat" assumption is not
execution-safe on the tested schedule and would require a separately proposed
earlier time exit, not an after-the-fact parameter change.

The 2020 T1 attempts produced incomplete reports and no summary. They are
classified as infrastructure invalid, not a strategy loss. No retry was needed
after the 2022 and pooled hard gates had already failed. The cohort also wrote
about 3.23 GB of tester logs, the existing systemic framework logging issue.

## Evidence

- `artifacts/ftmo_13127_q02_preholdout_2026-07-10.json`
- `artifacts/ftmo_10375_orb_v2_holdout_screen_2026-07-10.json`
- `framework/build/compile/20260710_212857/QM5_13127_et-open-atr-long.compile.log`
- `D:\QM\reports\smoke\QM5_13127_Q02_PREHOLDOUT_20260710`

Only T1-T4 were used. T5 was idle. T6-T10, T_Live, the FTMO terminal,
AutoTrading, and live accounts were not touched.
