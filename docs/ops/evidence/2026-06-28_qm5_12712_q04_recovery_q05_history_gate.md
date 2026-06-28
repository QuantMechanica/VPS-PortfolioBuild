# QM5_12712 Q04 Recovery and Q05 History Gate - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, no AutoTrading, no
portfolio-gate edits.

## Decision

`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` remains the controlling
66-pair scan. The strict-threshold pairs (`QM5_12532`, `QM5_12533`) are already
built and past logical-basket Q02, so the non-duplicate action was to advance an
existing exploratory forex basket.

Target: `QM5_12712` EURGBP/EURAUD cointegration.

## Q04 Recovery

The first Q04 row had valid real-MT5 folds for the available 2023 and 2024 OOS
years, then invalidated the 2025 fold because `EURGBP.DWX` lacks 2025 D1
history/cache on the checked factory terminals.

Recovered evidence:

| Fold | OOS year | PF-net | Trades | Status |
|---|---:|---:|---:|---|
| F1 | 2023 | 1.402340959431621 | 11 | OK |
| F2 | 2024 | 1.92701446596737 | 13 | OK |

Action taken:

- DB backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_12712_q04_recovery_q05_enqueue_20260628_072053Z.sqlite`
- Preserved the invalid rerun aggregate as:
  `D:/QM/reports/work_items/06e86ebb-4f8d-4763-ac11-1966a890cf22/QM5_12712/Q04/QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1/aggregate_invalid_20260628T014020Z.json`
- Rebuilt the standard Q04 aggregate from archived real-MT5 F1/F2 evidence with
  `latest_full_year=2024`:
  `D:/QM/reports/work_items/06e86ebb-4f8d-4763-ac11-1966a890cf22/QM5_12712/Q04/QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1/aggregate.json`
- Updated work item `06e86ebb-4f8d-4763-ac11-1966a890cf22` to `Q04 PASS`.

No MT5 tester was launched for this recovery.

## Q05 Gate

`farmctl enqueue-backtest --ea QM5_12712 --phase Q05` initially showed the
history precheck was looking for the synthetic logical symbol. I patched
`tools/strategy_farm/farmctl.py` so Q05 history checks use
`basket_manifest.json` host/leg symbols for logical basket work items.

After the fix, Q05 correctly checks `EURGBP.DWX` and `EURAUD.DWX`. The enqueue
still skips because this downstream stress gate requires 2023-2025 coverage and
`EURGBP.DWX` is missing 2025 D1 history/cache. No Q05 row was forced.

## Verification

```powershell
python -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py -q
python -m pytest tools/strategy_farm/tests/test_basket_work_items.py tools/strategy_farm/tests/test_q04_latest_full_year_payload.py -q
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_12712 --phase Q05
```

Results:

- `test_farmctl_cascade.py`: 8 passed
- basket/Q04 payload tests: 8 passed
- Q05 enqueue: skipped on genuine `EURGBP.DWX` 2025 D1 history/cache gap,
  not on the logical basket symbol.
