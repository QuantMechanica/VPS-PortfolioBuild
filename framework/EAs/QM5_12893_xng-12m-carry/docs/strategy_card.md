---
ea_id: QM5_12893
slug: xng-12m-carry
type: strategy
strategy_id: KOIJEN_CARRY_2018_XNG_S01
source_id: KOIJEN-CARRY-2018
source_citation: "Koijen, R. S. J., Moskowitz, T. J., Pedersen, L. H. and Vrugt, E. B. (2018). Carry. Journal of Financial Economics, 127(2), 197-225. DOI https://doi.org/10.1016/j.jfineco.2017.11.002; NBER working paper https://www.nber.org/papers/w19325."
target_symbols: [XNGUSD.DWX]
timeframes: [D1]
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
---

# XNG 12M Carry

This build-side card copy follows
`strategy-seeds/cards/xng-12m-carry_card.md`.

The EA trades `XNGUSD.DWX` on D1. Direction is set by the broker swap side:
long when long swap is better than short swap, short when short swap is better
than long swap. A 12-month D1 return guard blocks carry trades that are fighting
an extreme adverse drift. Entries are checked on the configured weekly rebalance
weekday, use an ATR hard stop, and close on max hold or carry-side flip.

Backtests use `RISK_FIXED=1000`. No live manifest, `T_Live` file, portfolio
gate, or AutoTrading setting is touched by this build.
