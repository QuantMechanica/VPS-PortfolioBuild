# QM5_12616 WTI 9M TSMOM Build And Q02 Enqueue

Date: 2026-06-27
Branch: agents/board-advisor

## Scope

- Added a new structural commodity/energy sleeve: `QM5_12616_tsmom-9m-commodity-xtiusd`.
- Instrument/timeframe: `XTIUSD.DWX` / `D1`.
- Edge: monthly WTI 9-month time-series momentum with 3-month same-sign confirmation, ATR hard stop, monthly rebalance exit.
- Source: `MOP-TSMOM-2012` (`Moskowitz, Ooi, Pedersen, Journal of Financial Economics, 2012`).
- Non-duplicate rationale: differs from `QM5_12603_wti-tsmom12m` by using a 9-month primary horizon plus 3-month confirmation before entry; no calendar/news/crack-spread logic and no XNG logic.

## Build Evidence

- `python framework/scripts/update_magic_resolver.py`: PASS, regenerated `framework/include/QM/QM_MagicResolver.mqh`.
- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12616_tsmom-9m-commodity-xtiusd`: PASS.
- `pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_12616_tsmom-9m-commodity-xtiusd`: PASS.
- `pwsh -NoProfile -File framework/scripts/compile_one.ps1 -EALabel QM5_12616_tsmom-9m-commodity-xtiusd -Strict`: PASS, 0 errors, 0 warnings.

Generated artifacts:

- `framework/EAs/QM5_12616_tsmom-9m-commodity-xtiusd/QM5_12616_tsmom-9m-commodity-xtiusd.ex5`
- `framework/EAs/QM5_12616_tsmom-9m-commodity-xtiusd/sets/QM5_12616_tsmom-9m-commodity-xtiusd_XTIUSD.DWX_D1_backtest.set`
- `artifacts/qm5_12616_build_result.json`

## Q02 Evidence

Build task:

- `1c97c9e4-dceb-428f-9fe8-695ecd9a54bb`

Record-build result:

- `recorded: true`
- `new_status: done`
- `smoke_result: deferred_p2_smoke`
- `auto_q02_enqueued`: `QM5_12616`, `XTIUSD.DWX`, `D1`

Work item:

- `5e9177d0-4539-4d19-ae8a-975a4e025ee8`
- `phase: Q02`
- `status: pending`
- `symbol: XTIUSD.DWX`

No `T_Live`, AutoTrading, portfolio gate, or live manifest files were touched.
