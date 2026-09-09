# FX cointegration fallback — QM5_12507 Q02 hard CPU stop

Date: 2026-09-09

Captured: `2026-09-09T14:15:58.4503266Z`

Branch: `agents/board-advisor`

Observation head: `43811b585f8c3d81dde369ffd071b2aaaecfe892`

## Outcome

The frozen, sign-aware 66-pair FX cointegration frontier remains fully
mechanized, so creating another scan-derived Strategy Card or basket EA would
duplicate governed coverage. The two requested anchors are beyond Q02 rather
than blocked by current `ONINIT` or `NO_HISTORY` failures:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 `PASS`, Q04 `PASS`, then Q05
  `FAIL`.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 `PASS`, then Q04 `FAIL`.

The preserved existing-card continuation is the low-frequency EURUSD/GBPUSD
H1 relationship in `QM5_12507_pair-coint-z`. Its canonical logical-basket Q02
work item, `547c4fd3-f3fd-4c59-b9dc-654e96521251`, remains pending, unclaimed,
and at attempt zero. No duplicate Q02 row was inserted.

The existing basket has a compiled `.ex5`, `basket_manifest.json`, and a
logical backtest setfile sealing `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Its reputable structural-method lineage is Ernest P.
Chan, *Quantitative Trading* (Wiley, 2009), preserved in
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`.

## Binding CPU stop

The canonical farm query returned only three active work items (`Q07=1`,
`OPT_CENSUS=2`), below the configured active-row limit of seven. The independent
whole-host CPU gate nevertheless bound: five one-second samples were
`84.791764%`, `77.358300%`, `81.454023%`, `92.383167%`, and `99.609884%`.
The average was `87.119428%`, and the maximum exceeded the binding `97%`
ceiling.

The path-aware slot snapshot observed one running factory terminal (`T9`) and
ten terminal workers. `T_Live` and the unrelated FTMO terminal were observed
only so they could be excluded; neither was controlled.

Per the explicit resource rule, processing stopped. No compile or backtest
work was enqueued, no queue row or priority marker was mutated, no dispatch
tick or tester was launched, and no terminal was controlled.

## Reproduction

```powershell
python tools/strategy_farm/farmctl.py mt5-slots
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --status active
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm work-items --ea QM5_12507
1..5 | ForEach-Object { (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue; Start-Sleep -Seconds 1 }
```

## PACER guard and safety

- No `.mq5` was generated or modified, so the mandatory post-write
  `audit_framework_input_pins.py --check-source` compile boundary was not
  entered.
- No Strategy Card, EA source, binary, setfile, basket manifest, registry, or
  magic-number row changed.
- No portfolio-admission, portfolio KPI, Q08-contribution, portfolio-gate,
  deploy-manifest, `T_Live`, or AutoTrading surface was touched.
- Existing unrelated dirty-worktree changes were left untouched.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12507_q02_cpu_ceiling_stop_20260909T141558Z_board_advisor.json`.
