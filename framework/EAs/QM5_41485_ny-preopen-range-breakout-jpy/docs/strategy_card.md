# QM5_41485 frozen-spec mirror — DRAFT, NOT A STRATEGY CARD

This local document mirrors the builder inputs so the source package is
self-describing. It is not in `cards_review` or `cards_approved`, has no G0
status, grants no pipeline transition, and must not be used to allocate magic.

| field | frozen value |
|---|---|
| source | `QM-RESEARCH-2026-0012` revision 2 |
| assignment-bound source SHA-256 | `84362c84bffcc748953b32254bd13902226b2671a011c7363ba03d6714881984` |
| current canonical source SHA-256 | `2120bd972a80cc0abf4024f9e6bdf96717c71599e46f7a5396e1439c5bd8bcb8` (manifest receipt hash only; mechanics unchanged) |
| build authority | Codex critique `afb38e9a`, `APPROVE_BUILD` for C2/C3/EUR C3 |
| parent | `QM5_13213_balke-gmt3-range-breakout` |
| runtime | M30; explicit closed-bar gate |
| venue | DXZ only; fixed server clock |
| anchor / flat | 15:30 / 23:00 server |
| range grid | 60 minutes, aligned `:30`, exact two-M30 pairing |
| arms | slot 0 USDJPY C2; slot 1 USDJPY C3; slot 2 EURUSD C3 |
| ATR filter | SMA TR(14), accept 0.4-2.5 ATR |
| entry | paired stop orders at RH/RL, opposite edge SL, no TP |
| OCO | transaction-time removal plus next-tick reconciliation |
| news | PRE30_POST30 / DXZ; placement retries in `[15:30,16:30)` |
| trail | after 1R based on current SL; prior two completed grid bars |
| backtest risk | fixed 1000; percent 0 |
| prohibited | FTMO set, live use, optimization, ML, grid/martingale |

The authoritative mechanical and falsification text remains the bound research
source and its approved cross-vendor critique. See `../SPEC.md` for the complete
build mirror.
