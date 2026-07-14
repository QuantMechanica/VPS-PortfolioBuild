# FTMO density sleeve requalification - 2026-07-10

## Verdict

The proposed `10118 + 10916 + 10546` density addition is `NO GO`. All three
were checked from native MT5 deals against the official FTMO symbol snapshot
from 2026-07-10. None clears the strict FTMO cascade.

| sleeve | current native evidence | current FTMO cost result | terminal gate | verdict |
|---|---:|---:|---|---|
| `10118 / US100.cash` | 716 trades, PF 1.088 | PF 1.016; 5 bp PF 0.996 | Q02 | FAIL |
| `10546 / XAUUSD` | 1,762 trades, PF 1.133 | PF 0.993, USD -8,067 | Q02 | FAIL |
| `10916 / GER40.cash` | 466 fresh trades, PF 1.234 | PF 1.240; 5 bp PF 1.210 | Q05 DD 15.1025% > 15.0% | FAIL |

## Cost normalization

The reconciler maps Darwinex source exposure to FTMO exposure by contract
size. `NDX.DWX` and `GDAXI.DWX` use 10 source contracts per lot while current
FTMO cash indices use one. For GER40 the historical EUR-to-USD conversion is
recovered trade by trade from native realized P/L. Long and short swaps are
applied separately, with Wednesday triple rollover. Native bid/ask spread is
retained; the additional 5 bp result is an explicit execution-cost stress.

Current official inputs used:

| symbol | contract | commission per side | long swap | short swap |
|---|---:|---:|---:|---:|
| `US100.cash` | 1 | 0% | -626.88 points | +19.57 points |
| `GER40.cash` | 1 | 0% | -424.13 points | -27.07 points |
| `XAU/USD` | 100 | 0.0014% | -75.93 points | -23.55 points |

Source: `https://ftmo.com/wp-json/ftmo/symbols`, snapshot 2026-07-10.

## 10916 fresh sequence

The EA was recompiled strict before the yearly runs. Each year used two
identical native model-4 runs on T1. 2024 and 2025 were held closed until the
2020-2023 official-cost pool passed PF 1.20.

| year | trades | native PF | net USD | equity DD USD |
|---:|---:|---:|---:|---:|
| 2020 | 89 | 1.64 | +24,045.07 | 6,753.72 |
| 2021 | 67 | 0.93 | -2,581.84 | 9,598.11 |
| 2022 | 71 | 1.16 | +5,764.74 | 6,388.56 |
| 2023 validation | 78 | 1.13 | +5,315.79 | 6,624.06 |
| 2024 holdout | 76 | 1.32 | +11,078.44 | 8,759.31 |
| 2025 holdout | 85 | 1.23 | +9,739.90 | 15,102.46 |

Q04 passed all folds (`1.13 / 1.32 / 1.23`). Q05 used the complete available
history from 2018-07-02 through 2025-12-31 and failed only the fixed drawdown
ceiling: `15.1025% > 15.0%`. No post-holdout parameter or signal rescue was
attempted.

## Execution boundary

Only T1-T4 were addressed. Parallel same-symbol starts on T2-T4 produced
history file-lock errors and no valid reports; those infrastructure attempts
were discarded and all valid years were rerun serially on T1. T5 remained
idle. T6-T10, T_Live, the FTMO terminal, AutoTrading, and live accounts were
not touched.
