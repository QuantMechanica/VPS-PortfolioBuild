# QM5_11470 USDCAD Q05 Append-Only Retry

Date: 2026-08-10 (Europe/Berlin)

Branch: `agents/board-advisor`

Scope: advance one existing low-frequency structural FX sleeve after proving
that the frozen 66-pair cointegration scan has no unbuilt relationship. No
tester dispatch, live action, or portfolio-gate action was performed.

## Outcome

`QM5_11470_nekritin-peters-kangaroo-tail-d1` now has exactly one pending
append-only Q05 retry for `USDCAD.DWX`:

- current Q04 `PASS_LOWFREQ` predecessor:
  `88a13e89-6f77-4938-bdc9-86f38885cb26`;
- preserved Q05 T5-scope infrastructure row:
  `4b7af90f-5c1e-48d7-8473-6e10183a88aa`;
- new Q05 retry: `1b7474a6-5790-4923-9a7c-26fa611d16bd`; and
- immediate verification state: `pending`, unclaimed, attempt count 0.

The guarded enqueue created one row, requeued zero rows, and skipped zero
rows. Normal paced workers own any later claim and execution.

## Selection and Duplicate Guard

The current repository reconciliation in
`docs/research/FX_COINTEGRATION_FRONTIER_Q02_CPU_CEILING_STOP_2026-08-07.md`
shows that every relationship in the frozen 66-pair scan is already
mechanized. The final two rows are also covered by existing builds, so a new
Card, EA ID, magic row, setfile, or basket manifest would duplicate governed
work.

Fresh canonical-farm reads confirmed that neither preferred anchor is blocked
at Q02:

- `QM5_12532`: one Q02 PASS and one Q04 PASS, followed by Q05 FAIL; and
- `QM5_12533`: one Q02 PASS, followed by Q04 FAIL.

The available deferred breadth candidates were not used: `QM5_11447` is M5,
and `QM5_11497` had already produced `ZERO_TRADES` on all three tested hosts.
The umbrella `QM5_12512` pair basket was also rejected because its H1 pair
slots duplicate dedicated low-frequency builds.

`QM5_11470 / USDCAD.DWX` was selected because it is an approved D1
indicator-free FX card with a current-binary Q04 `PASS_LOWFREQ`. Its only Q05
row was an infrastructure failure caused by the historical T5 phase-runner
scope defect. The deterministic victim census in
`docs/ops/evidence/2026-08-03_mnt046_t5_phase_runner_scope.md` explicitly
classifies this exact row `READY_APPEND_ONLY`, with the exact Q04 predecessor
used here. No strategy verdict or open work identity was retried.

## Source, Structure, and Risk Preflight

The approved Card has `g0_status: APPROVED`, `indicators: []`, and R1-R4 PASS.
It cites Alex Nekritin and Walter Peters PhD, *Naked Forex: High-Probability
Techniques for Trading without Indicators*, Chapter 8 (Wiley Trading, 2012).
The strategy uses completed-D1 OHLC structure: tail/body geometry,
room-to-the-left, bounded support/resistance, and one-bar stop-entry expiry.
The optional ATR filter is disabled (`strategy_atr_multiplier=0.0`), and no
ML, adaptive model, grid, martingale, or mechanics change was introduced.

The exact USDCAD backtest setfile remains:

- `RISK_FIXED=1000`;
- `RISK_PERCENT=0`;
- `PORTFOLIO_WEIGHT=1`; and
- `USDCAD.DWX`, D1, backtest environment.

| Artifact | SHA-256 |
|---|---|
| MQ5 | `cb106725391cbef0219f87389eed0870115462b7cc73594cf602881a96f52ec8` |
| EX5 | `56f7c134649df3174a93e90d718152f56c380372f275e9a6b4660f25a7bbbd5f` |
| USDCAD backtest setfile | `578c34fecaa323e68b85d44015dac3dedfb352fc79969e7e07bb536e13cbc86a` |

The new payload seals those three hashes plus expert
`QM\QM5_11470_nekritin-peters-kangaroo-tail-d1`, symbol `USDCAD.DWX`, and
period D1.

## Preserved Funnel Evidence

The USDCAD Q02 smoke predecessor is work item
`955a893e-0973-4da4-9a23-224e1a43361a`, with evidence at:

`D:/QM/reports/work_items/955a893e-0973-4da4-9a23-224e1a43361a/QM5_11470/20260731_215450/summary.json`

It records a Model-4 Q02 PASS over 2018-07-02 through 2022-12-31 with 27
trades and stable artifact bindings. Its SHA-256 is
`be8fbcc91c41466a4fe74f4304d13fe8933ba488b312213b39f175c5e6f3257c`.
The Q02 performance was weak (PF 0.38); Q02 is a smoke gate, not a portfolio
claim.

The exact Q04 predecessor evidence is:

`D:/QM/reports/pipeline/QM5_11470/Q04/USDCAD.DWX__88a13e89-6f77-4938-bdc9-86f38885cb26/aggregate.json`

All three folds completed. They produced 5, 9, and 6 trades with net PF
approximately 1.712, 0.328, and 3.104. The pooled low-frequency rule returned
`PASS_LOWFREQ` with PF 1.048, 20 trades, and activity in all three years. The
aggregate SHA-256 is
`899b1a9b6c152806ae9d3b7cd367c89f0135628b50c60b76c95428a3df9da85a`.
This marginal pass is why the Q05 stress gate remains necessary; no certified
performance or portfolio value is claimed here.

The historical Q05 row remains unchanged at `failed / INFRA_FAIL`, with no
evidence path. The append-only retry cites it through
`append_only_rerun_of_work_item` and cites the Q04 predecessor through
`promoted_from_work_item`.

## Capacity, Enqueue, and Verification

The immediate pre-enqueue `farmctl mt5-slots` sample at
`2026-08-10T14:45:37+02:00` found five running factory terminals:

```text
T1, T5, T8, T9, T10
```

Five was below the binding seven-terminal paced-fleet ceiling. `T_Live` and
the external FTMO terminal were observed separately and excluded.

The supported append-only command was:

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm `
  enqueue-backtest --ea QM5_11470 --phase Q05 `
  --from-work-item-id 88a13e89-6f77-4938-bdc9-86f38885cb26 `
  --append-only-rerun-of 4b7af90f-5c1e-48d7-8473-6e10183a88aa `
  --rerun-reason "OWNER 2026-08-10 forex-book fallback: preserve the exact T5-scope Q05 INFRA_FAIL and append one current-binary USDCAD D1 low-frequency structural retry from Q04 PASS_LOWFREQ; no mechanics changed." `
  --expected-current-ex5-sha256 56f7c134649df3174a93e90d718152f56c380372f275e9a6b4660f25a7bbbd5f
```

Immediate readback found exactly one open Q05 identity for this EA and symbol.
The old Q05 row and Q04 predecessor were preserved, and SQLite
`PRAGMA quick_check` returned `ok`.

## Safety

- No pump, dispatch tick, manual smoke test, or pipeline runner was invoked.
- No terminal process was launched, stopped, reserved, reaped, or controlled.
- No Card, EA source, binary, setfile, registry, risk amount, or gate threshold
  changed.
- `T_Live`, AutoTrading, deploy manifests, live setfiles, portfolio admission,
  portfolio KPI, and Q08-contribution paths were not touched.

Machine-readable receipt:
`artifacts/qm5_11470_usdcad_q05_append_only_retry_20260810.json`.
