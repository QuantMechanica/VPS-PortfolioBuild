# QM5_13124 Build-Time Strategy Card Reference

Canonical approved card:
`strategy-seeds/cards/fx-early-asia-drift_card.md`.

Build binding:

| slot | symbol | UTC entry | UTC exit |
|---:|---|---:|---:|
| 0 | EURGBP.DWX | 00:00 | 01:00 |
| 1 | GBPUSD.DWX | 00:00 | 01:00 |
| 2 | EURAUD.DWX | 00:00 | 01:00 |
| 3 | AUDJPY.DWX | 01:00 | 02:00 |
| 4 | NZDUSD.DWX | 00:00 | 01:00 |

All sleeves are long-only, H1, one entry per UTC date, with ATR(20) stop at
1.25 times ATR, no take profit, 60-minute time exit, 5%-of-ATR entry-spread
ceiling, and 120-second maximum entry delay. These values are locked for Q02.
