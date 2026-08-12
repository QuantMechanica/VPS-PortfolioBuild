# Diversity Funnel CPU-Ceiling Stop — 2026-07-24

## Outcome

No EA was claimed, built, repaired, compiled, smoked, or enqueued. The live farm
coordination state had no eligible unclaimed diversity-first build and the MT5
fleet was already at the backtest CPU ceiling. Stopping preserves distinct-agent
ownership and avoids increasing contention at Q02-Q03.

## Build-backlog decision

Live database: `D:/QM/strategy_farm/state/farm_state.sqlite`.

The open `build_ea` rows were:

| EA | Instrument class | State | Decision |
|---|---|---|---|
| QM5_20062 `kats-eu-macisar` | Forex (EURUSD.DWX) | `active`, claimed by `claude-farm-pump` | Do not collide |
| QM5_1457 `as-predict-bonds` | Rates | `pending`, prior Codex block recorded | Card requires unavailable Treasury/bond inputs; deterministic build preflight fails |
| QM5_1459 `as-lumber-gold` | Lumber/gold | `pending` | No approved DWX lumber feed; deterministic build preflight fails |
| QM5_20061 `kats-dax-maci` | Index (GDAXI.DWX) | `pending` | Lower diversity than the requested forex/rates/crypto/pairs priority |

This leaves no executable forex, crypto, rates, energy-beyond-XNG, or
market-neutral-pairs card that can be claimed without duplication or violating
the approved-card data contract.

## CPU-ceiling evidence

`python tools/strategy_farm/farmctl.py mt5-slots` at approximately 2026-07-24
13:29 UTC reported eight pipeline tester processes:

- T1: QM5_11422 Q06, USDCAD.DWX
- T3: QM5_1230 Q07, XAUUSD.DWX
- T4: QM5_10470 Q03, GDAXI.DWX
- T6: QM5_9940 Q02, SP500.DWX
- T7: QM5_11422 Q03, GBPUSD.DWX
- T8: QM5_13213 pipeline run
- T9: QM5_10961 Q03, EURUSD.DWX
- T10: QM5_20099 Q02, XTIUSD.DWX

The separate `T_Live` process was observed read-only and was not touched.

## Safe next action

On the next paced wake, re-read the live farm DB. Prefer a newly approved,
unclaimed forex, crypto, rates, energy-beyond-XNG, or market-neutral pair card.
If none exists, select a diverse Q02-Q03 infrastructure failure only after the
fleet falls below the CPU ceiling and an atomic collision guard confirms that
the EA has no competing active task or pending/active replacement row.
