# FTMO native cost receipts — four-symbol follow-up

Task: `17758960-375c-4ce5-80db-a14c261838dd`  
Date: 2026-09-12  
RESULT: REVIEW — four hash-bound native receipts captured read-only; two symbols expose realised commission, but none exposes a complete request-time executable-quote slippage stream, so the rerun selects zero incumbents.

## Capture boundary

`collect_ftmo_native_cost_receipts.py` first proved exactly one FTMO terminal process was already running, then used the same read-only Python IPC pattern as `ftmo_trial_pulse.py`. It required account `1514536732`, server `FTMO-Demo`, and the exact data directory before reading symbol specifications, ticks, margin calculations, deal history, and order history. It called no trading function, did not launch/control the terminal, did not toggle AutoTrading, and did not place/cancel/modify any order.

Window: `2026-09-06T19:38:00+00:00` through `2026-09-12T08:50:00Z`.

| Symbol | Receipt SHA-256 | Native fills | Commission + fee | USD / entry lot RT | Slippage status |
|---|---|---:|---:|---:|---|
| GBPUSD | `9ec3ae430405d05988d4c2879072d7430917e30be0a4ca09b837f81472ef6db9` | 2 deals / 1 lifecycle | -5.86 | 5.00854701 | INCOMPLETE_NO_EXECUTABLE_QUOTE |
| EURUSD | `60d031733e9ad523ba076fc82960b2ae6a2a60e4a45eee78216c7ee22459a587` | 2 deals / 1 lifecycle | -1.96 | 5.02564103 | INCOMPLETE_NO_EXECUTABLE_QUOTE |
| USDCAD | `055df14a6fc6969072563fa36729b62057b155ac9ecf8dff7e099c668844a5c1` | 0 (one cancelled pending order) | missing | missing | MISSING_NO_FILL |
| USOIL.cash | `b5d42013221747871d11a6fe44cdb97afb7490172d565d661b669667f2a48c09` | 0 | missing | missing | MISSING_NO_FILL |

Each receipt also contains native lot min/step/max, point, tick size and profit/loss tick values, contract size, swap mode/rates/triple weekday, current quote and tick time, and `OrderCalcMargin` results for one lot in account currency.

The GBPUSD stop exit records requested `1.35472` and fill `1.35471`; the EURUSD sell-stop entry records requested `1.15984` and fill `1.15975`. Those are request-price versus fill observations, not full slippage estimators: market-order request prices are zero under this execution mode and the collector did not capture an executable quote at request time. Consequently `value_for_cost_model` remains null. USDCAD never filled and USOIL.cash has no order/fill in the window. No cost is inferred from balance changes or filled with zero.

## Comparator rerun

`docs/ops/evidence/2026-09-09_ftmo_shortlist/compare.py` now hash-verifies the receipt manifest and all four receipts, attaches the relevant evidence to matching symbols, and keeps `cost_eligible=false` unless both native commission and complete slippage evidence exist.

- `comparison.json` SHA-256: `55ccdd1003567a479d14de0a63ae2278952723645c5f679a3a583d9d5db8c188`
- `comparison.csv` SHA-256: `706e67f2a131bd00bf4d29351f796c35e65f3b21a3a0cbd5192190a512f5524d`
- Repeat run: both hashes identical.
- Pairs: 16; historically exposed streams: 7; selected incumbents: **0**.

No incumbent qualifies. GBPUSD and EURUSD now have realised commission evidence but incomplete slippage evidence; USDCAD and USOIL.cash lack a native commission fill and slippage fill. This does not change any verdict or threshold and does not authorize a demo/live action.

