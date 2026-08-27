# QM5_35005 pre/post pattern-include equivalence evidence

## Decision

**ABWEICHEND (DEVIATION).** The retained pre-integration EX5 and the governed
post-integration EX5 do not produce field-identical native Deals lists under the
same authenticated MT5 setup. Keep the compile-wave release hold in place and
escalate to Orchestrator/OWNER review. This document records evidence only; it
does not issue a pipeline or gate verdict.

- Router task: `b98560ce-ebd0-45e6-93bc-78d498211d93`
- Governed work item: `9f6481b9-da13-5f2e-9bac-64609ae4b20e`
- Queue result: `done / ARTIFACT_READY` (`ARTIFACT_READY` is a utility-row
  completion token, not a pipeline verdict)
- Execution: `2026-08-27T15:42:50+02:00` to
  `2026-08-27T15:57:55+02:00`, claimed by resident worker `T4`
- Runner implementation commit: `6ae6f618cb7fb78e75273e6e19832925e94334a3`
- Integration commit under review: `b0bdc4d72f23876398b707db72450a560718ef4a`

## Binary and compile identities

| Identity | Pre integration | Post integration |
|---|---|---|
| Git/source anchor | `82755f48a664abf1b0cc1fe5fa8833a8f3721aec` | current source at governed compile |
| EX5 SHA-256 | `28ef9a97341ab09666f4b8ac6a817bbdabe806c968fbc96279a0e1be0b2fbd59` | `59d116784db396fd081175503e6e43b154593925d781e01bb18bc8a9f2f95750` |
| EX5 size | 393,332 bytes | 432,606 bytes |
| Source MQ5 SHA-256 | n/a (retained Git binary) | `8c5457fc7cc7b10af168f89089b7320a5118d43078f87ed73232de18bbe0d4fc` |

The post binary is bound to governed `COMPILE_EA` work item
`0ca4936f-d280-42bd-adc5-fa3f44f0d117`. Its receipt has SHA-256
`62fb6d1477e723a25d763ed0f0426d182caf7acff70322f581a5f85d40f0ffaf`
and records `PASS`, zero compiler errors, and zero warnings. The runner retained
private copies of both exact binaries and verified that the source, setfile,
original binaries, runtime binary, and terminal binaries did not change during
the comparison.

## Controlled setup

| Field | Pre | Post | Check |
|---|---|---|---|
| Terminal | T4 | T4 | identical resident governed worker |
| Runtime Expert path | `QM\EQV35005\QM5_35005_sma-crossover-pullback-system.ex5` | same | identical |
| Symbol / period | `EURUSD.DWX` / H1 | same | identical |
| Window | `2022.07.01` through `2022.12.31` | same | identical |
| Tester model | `4` | `4` | identical |
| Framework RNG seed | `42` | `42` | identical |
| Setfile SHA-256 | `bbc838facbd272824da0134aadc81cee5704989d63c8bbf42c2465ca0e16f4b4` | same | identical |
| Risk inputs | `RISK_FIXED=1000`, `RISK_PERCENT=0` | same | compliant |
| Tester execution-fields SHA-256 | `fe27bea10460615dded1ebdac604f3205813f0b7e3cbca15bf4f61fb397c454b` | same | identical |
| Terminal64 SHA-256 | `86c563c8c113e4af8802dc91241ecd51fc06caf92cc86fc40026dd8046e526ed` | same | identical |
| History snapshot SHA-256 | `7651cdde3a26623ed844a846ee1f61170aa9101127fa242a8d24a26139fcf63d` | same | identical before/after |

Both authenticated reports completed successfully, contain one valid run, and
contain a non-empty native Deals table. No active factory terminal was
interrupted; the runtime Expert was restored after the sequential runs.

## Exact result

| Measure | Pre | Post | Result |
|---|---:|---:|---|
| Total trades | 34 | 34 | same count |
| Native Deals rows | 69 | 69 | same count |
| Canonical Deals SHA-256 | `2ab38e879cf4dd22833e69af3b1ae1889a9ff631000846a1954db3b4cb5dadf5` | `316279044df62b842724593414ecd9f42aeba76c742ca8e388ee8a4b7446f6ad` | **different** |
| Differing native rows | 43 | 43 | **different** |

The 43 differing rows contain 41 `Balance`, 6 `Time`, 3 `Price`, 2 `Profit`,
and 1 `Comment` field differences. The first time-only difference occurs at
row index 1. The first price/entry divergence occurs at row index 27 and causes
a realized stop-loss difference at row index 28:

| Row | Field | Pre | Post |
|---:|---|---|---|
| 1 | sell-entry time | `2022.07.01 00:05:00` | `2022.07.01 00:04:01` |
| 27 | buy-entry time / price | `2022.09.13 03:00:00` / `1.01293` | `2022.09.13 03:06:01` / `1.01339` |
| 28 | stop time / price / profit | `2022.09.13 21:52:11` / `0.99793` / `-990.00` | `2022.09.13 20:44:22` / `0.99837` / `-991.32` |
| 28 | resulting balance | `101041.91` | `101040.59` |
| 65 | buy-entry time / price | `2022.12.19 02:00:00` / `1.05847` | `2022.12.19 02:06:00` / `1.05881` |
| 66 | close profit / balance | `161.70` / `101429.53` | `139.26` / `101405.77` |

The September loss produces the persistent EUR 1.32 balance offset through the
intervening rows. The later December entry-price change explains the additional
EUR 22.44 realized-profit difference at row 66. These observations establish
non-equivalence; they do not, by themselves, assign root cause.

## Required post-input echo

The native post report echoed every compatibility input at zero:

- `opt_pp_buy1=0`
- `opt_pp_buy2=0`
- `opt_pp_buy3=0`
- `opt_pp_sell1=0`
- `opt_pp_sell2=0`
- `opt_pp_sell3=0`

This check passed and therefore does not explain or waive the trade-list
deviation.

## Durable machine evidence

- Evidence JSON:
  `D:\QM\strategy_farm\artifacts\equivalence\b98560ce-ebd0-45e6-93bc-78d498211d93\9f6481b9-da13-5f2e-9bac-64609ae4b20e\equivalence_evidence.json`
  (SHA-256 `69a5ccd5c246264c41b85e71d1de841fd7eb057a8267d0e94428049611a21f22`)
- Exact native diff:
  `D:\QM\strategy_farm\artifacts\equivalence\b98560ce-ebd0-45e6-93bc-78d498211d93\9f6481b9-da13-5f2e-9bac-64609ae4b20e\native_deals_diff.json`
  (SHA-256 `844c24626d0e6d4e828189da4dc53a39c10e094ef7cd0dd27c8583985668234f`)
- Comparison table:
  `D:\QM\strategy_farm\artifacts\equivalence\b98560ce-ebd0-45e6-93bc-78d498211d93\9f6481b9-da13-5f2e-9bac-64609ae4b20e\comparison.csv`
  (SHA-256 `1604f808d5fc93ca4b2cf5c045b7146a520103f1004f416af0d8e768176e886e`)
- Pre report:
  `D:\QM\reports\work_items\9f6481b9-da13-5f2e-9bac-64609ae4b20e\equivalence\pre\QM5_35005\20260827_134553\raw\run_01\report.htm`
  (SHA-256 `bfaeec3f182944a7c434cdff4a499617e43a177cf6ed4a105d42274948faabc7`)
- Post report:
  `D:\QM\reports\work_items\9f6481b9-da13-5f2e-9bac-64609ae4b20e\equivalence\post\QM5_35005\20260827_135039\raw\run_01\report.htm`
  (SHA-256 `ed0f0d73f333d34942e68c815656bb7ed21ffd3501ae87f2424c1c67ed8c8fad`)

## Required disposition

Leave the task in `REVIEW`, retain the compile-release hold, and have
Orchestrator/OWNER decide the source-level root-cause investigation or rollback.
No pipeline admission, release, or self-approval follows from this proof.
