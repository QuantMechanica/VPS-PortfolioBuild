# D2-c exposure, cost, and live pulse audit - 2026-07-03

Task: `d9b278fd-cbd1-42dc-b9d0-7185885073f7`
Status: evidence + code patch. No T_Live writes, no terminal start, no AutoTrading action.

## Code Change

Patched `C:\QM\worktrees\codex-orchestration-1\tools\strategy_farm\live_book_pulse.py` to read live `MQL5/Presets/slot*.set`, normalize MT5 chart timeframe labels such as `Daily -> D1`, compare loaded chart TFs from terminal journals to preset TFs, and emit `live_book` alarms on `chart_tf_mismatch`. Added focused tests in `C:\QM\worktrees\codex-orchestration-1\tools\strategy_farm\tests\test_live_book_pulse.py`.

Note: `C:/QM/repo/tools/strategy_farm/live_book_pulse.py` is not present in this checkout; the scheduled-task worktree contains the script and was patched.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_live_book_pulse.py`: 3 passed.
- `python -m py_compile tools/strategy_farm/live_book_pulse.py`: PASS.
- Read-only pulse output: `D:\QM\strategy_farm\artifacts\ops\live_book_pulse_tfcheck_2026-07-03.json`.
- Pulse verdict: `OK`.
- Preset consistency: 13 OK / 13 checked, mismatches=0.
- XNGUSD slot12: loaded `Daily` normalized `D1` vs preset `D1` normalized `D1`; status `OK`.

## Same-Symbol Exposure Stacking

Historical Q08 limitation: live-sleeve Q08 `TRADE_CLOSED` streams do not contain `entry_time`, direction, open intervals, MAE, or MFE. Therefore historical same-symbol concurrent exposure and worst combined adverse excursion cannot be reconstructed without reruns/intraday state capture.

Live log sample since 2026-06-29:

| symbol cluster | entry events | same-direction EA counts | max same-dir EAs | max nominal risk | material >2% |
|---|---:|---|---:|---:|---|
| NDX | 1 | SHORT:1 | 1 | 0.75% | FALSE |
| XAUUSD | 1 | SHORT:1 | 1 | 0.75% | FALSE |

Conclusion: the readable live sample shows no 2+ same-symbol same-direction stack in XAUUSD or NDX. This is not enough to clear historical risk; it only says the post-live log sample has not shown material same-symbol stacking.

## Cost Reconciliation

Readable live logs expose order/deal prices but do not expose paid commission, swap, or account-history cost fields. The binary `deals_*.dat` files were not parsed, and `terminal64.exe` was not started. Therefore live paid commission+swap cannot be reconciled exactly in this headless pass.

Q08 modeled cost rank using the existing worst-case DXZ/FTMO commission model:

| slot | EA | symbol | Q08 trades | modeled cost total | cost/trade | cost % abs net | flag |
|---:|---|---|---:|---:|---:|---:|---|
| 8 | QM5_11165 | AUDCAD.DWX | 41 | 312.45 | 7.62 | 3.72% | FX |
| 0 | QM5_10440 | NDX.DWX | 342 | 8562.37 | 25.04 | 1.73% |  |
| 3 | QM5_10715 | USDJPY.DWX | 468 | 1510.26 | 3.23 | 1.18% | FX |
| 5 | QM5_10939 | GBPUSD.DWX | 24 | 307.74 | 12.82 | 1.16% | FX |
| 4 | QM5_10911 | GDAXI.DWX | 268 | 2301.41 | 8.59 | 0.98% |  |
| 10 | QM5_11421 | EURUSD.DWX | 23 | 155.90 | 6.78 | 0.92% | FX |
| 9 | QM5_11421 | AUDUSD.DWX | 53 | 331.30 | 6.25 | 0.87% | FX |
| 7 | QM5_11132 | SP500.DWX | 23 | 85.85 | 3.73 | 0.77% |  |
| 2 | QM5_10692 | NDX.DWX | 195 | 1240.55 | 6.36 | 0.71% |  |
| 6 | QM5_10940 | XAUUSD.DWX | 35 | 233.78 | 6.68 | 0.66% |  |
| 11 | QM5_12567 | XAUUSD.DWX | 28 | 108.92 | 3.89 | 0.41% |  |
| 1 | QM5_10513 | XAUUSD.DWX | 31 | 88.14 | 2.84 | 0.23% |  |
| 12 | QM5_12567 | XNGUSD.DWX | 19 | 21.32 | 1.12 | 0.13% |  |

Terminal deal sample with 9 readable deal lines is included in the JSON artifact. It is useful for slippage spot checks, but not a commission/swap reconciliation. The FX sleeves are flagged in the table; `QM5_10715 USDJPY M15` had no readable live filled deal in the sampled period, so live-cost fragility remains unproven from live data.

## Artifacts

- Evidence JSON: `D:\QM\strategy_farm\artifacts\ops\d2c_exposure_cost_pulse_audit_2026-07-03.json`
- Pulse JSON: `D:\QM\strategy_farm\artifacts\ops\live_book_pulse_tfcheck_2026-07-03.json`
- Pulse append log: `D:/QM/strategy_farm/artifacts/ops/live_book_pulse_tfcheck_2026-07-03.jsonl`

## Verdict

PASS_WITH_DATA_GAPS: pulse TF check implemented and verified; XNGUSD now checks D1/Daily OK. Live log sample shows no material XAU/NDX same-symbol stack, but historical concurrency/MAE and exact live commission/swap reconciliation require additional captured fields or exported account history.
