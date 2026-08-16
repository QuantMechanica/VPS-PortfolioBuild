# QM5_1231 PCA alpha — Q02 history-isolation repair and exact rerun

Date: 2026-08-16
Branch: `agents/board-advisor`
Scope: one diverse, low-frequency Q02 infrastructure recovery; no pipeline result is claimed

## Why this EA

`QM5_1231_carver-pca-alpha` is an approved structural D1 cross-sectional
sleeve with an expected cadence of 12 trades/year/symbol. Its deterministic
PCA/OLS transform is card-approved as non-ML (`r4_ml_forbidden: PASS`). The
implemented universe contains six FX majors and four liquid indices, so
recovering it adds materially more instrument breadth than another
index/metal/energy-only build.

The farm claim for this unit is agent task
`f602773b-014f-4c7b-8642-960eebf1a7aa`, with claim scope
`dependency_manifest_plus_exact_append_only_q02`.

## Source failure and root cause

The preserved Q02 source row is
`5b66c5eb-a571-49ed-b722-0c7a355abd75`:

- EA/symbol/phase: `QM5_1231` / `EURUSD.DWX` / `Q02`
- terminal state: `done`, verdict `INFRA_FAIL`, unclaimed
- evidence: `D:\QM\reports\work_items\5b66c5eb-a571-49ed-b722-0c7a355abd75\QM5_1231\20260801_190407\summary.json`
- evidence SHA-256: `bca3067d6c71722b6b52e6c6cd2e6d91f8857cf7fc40d00a5b1a9dd755a556d8`
- historical EX5 SHA-256: `2f1deb6d6beddc90a5fff4017107698c969859c4f045c1272c6d12b1a17fd1c3`

The summary classified the run as `ONINIT_FAILED`, but the retained T2 terminal
log shows the actual pre-execution signature at 2026-08-01 21:04:17:
repeated `History 'EURUSD.DWX' file opening or reading error [32]`, immediately
followed by a zero-duration tester error. The EA never reached a strategy
decision. The terminal log is
`D:\QM\mt5\T2\logs\20260801.log`, SHA-256
`db267bd7510529594418ebaf408295f4bbb762125857c8326f459385361bdda4`.

The EA source reads a fixed ten-symbol D1 array, but the EA directory had no
multi-symbol dependency manifest. Consequently the isolation/admission path
could bind only the host symbol and could not reserve and privatize all foreign
history archives before launch. This is an infrastructure-contract defect, not
an economic or strategy-mechanics result.

## Repair

Added `basket_manifest.json` as a dependency-only manifest declaring the exact
ten symbols read by the source:

- indices: `GDAXI.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX`
- FX: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `USDJPY.DWX`,
  `USDCHF.DWX`, `USDCAD.DWX`

The manifest intentionally omits `logical_symbol`, `host_symbol`, and
`host_timeframe`. That preserves one real host work item per registered
setfile while allowing the dependency loader, archive admission, terminal
serialization, and copy-on-claim isolation to cover all ten symbols.

The source description was changed only to identify the dependency-bound
artifact; trading logic and approved parameters are unchanged. A forced
canonical compile then produced:

- compile verdict: `COMPILED`
- MetaEditor errors/warnings: `0 / 0`
- symbol-scope verdict: `BASKET_OK`
- compile report: `D:\QM\reports\compile\QM5_1231_carver-pca-alpha\result.json`
- current MQ5 SHA-256: `786f13ebb6529a1a418f088112c88394aa4762dfa35b91a59acc726dc7346646`
- current EX5 SHA-256: `d3de676c33f8fb117ccbe11f1e4ffaf908dfeeccc4d421ea99ed8190172c44ca`
- manifest SHA-256: `a4e9a160692d4373278e91e7d78c3b9c9e4992f476bef580160b057860a8a620`

The exact queue-bound EURUSD `RISK_FIXED` setfile was verified byte-identical
to the tracked artifact after canonical validation. No setfile is part of this
change, and the pre-existing percent-risk live setfiles remain byte-identical to
HEAD.

## Admission and append-only queue receipt

Current custom-history admission passed for all ten dependencies with zero
missing symbols. The successor payload seals:

- archive activation SHA-256:
  `61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`
- archive manifest SHA-256:
  `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`
- selected archive rows: `1040`
- basket symbol count: `10`
- multisymbol timeout: `450` minutes
- risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`

The unchanged-binary enqueue was first rejected fail-closed with
`q02_infra_source_binary_not_repaired`; it created no row. After the fresh
compile, `farmctl enqueue-backtest` created exactly one successor:

- new work item: `ca1eadb1-e1aa-4cc7-9627-9075256550d5`
- symbol/phase: `EURUSD.DWX` / `Q02`
- initial state: `pending`
- append-only predecessor:
  `5b66c5eb-a571-49ed-b722-0c7a355abd75`
- expected current EX5 SHA-256:
  `d3de676c33f8fb117ccbe11f1e4ffaf908dfeeccc4d421ea99ed8190172c44ca`
- setfile:
  `framework/EAs/QM5_1231_carver-pca-alpha/sets/QM5_1231_EURUSD.DWX_D1_backtest.set`
- setfile SHA-256:
  `e46d390074fbd2439ee2a783490e8d3be17be09ce8184ac5ac207cf4ba766050`

The historical failure row remains unchanged. The farm pump owns subsequent
claim and execution.

## Verification and boundaries

- `framework/scripts/build_check.ps1 -EALabel QM5_1231_carver-pca-alpha -SkipCompile`:
  `PASS`, zero failures, zero warnings; report
  `D:\QM\reports\framework\21\build_check_20260816_095047.json`.
- Dependency loader: 10 symbols, `D1`, and no logical-basket promotion.
- Active archive admission: `ok=true`, no missing symbols.
- No smoke test or backtest was launched by this work unit; it only enqueued Q02.
- No T_Live terminal, AutoTrading control, portfolio gate, or T_Live manifest
  was read or changed.
