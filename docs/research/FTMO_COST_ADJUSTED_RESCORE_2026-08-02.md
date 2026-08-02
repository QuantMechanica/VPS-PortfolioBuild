# FTMO cost-adjusted re-score — 2026-08-02

Evidence class: `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1`
Router task: `225a787d-4dad-4639-9e56-a3eb384d0b15`

## Decision statement

The calibrated cost-adjusted implementation is ready for review, but the
production five-sleeve re-score is **not estimated**. The approved FTMO
research roots contain no `XAUUSD` or `GER40.cash` M1 HCC history, so the
calibration correctly emitted a `REFUSED` artifact instead of inventing a
spread delta. Independently, each of the five exact sealed Q08 files lacks the
full-lifecycle side, entry/exit price, fee, money-basis, and commission-split
fields required to substitute FTMO commission and swap exactly.

Accordingly, the best bootstrap lower bound remains `null`, evidence credit is
`0.00`, and the evidence-credit gap to the OWNER 0.80 bar is `0.80`. That gap
is not an estimate that the true FTMO Phase-1 pass probability is zero. The
binding dimension is density: there are zero admissible cost-adjusted streams.
No book-readiness claim is made.

## Delivered implementation

- `ftmo_spread_calibration.py` binds official M1 spread projections and source
  HCC hashes, requires identical minute coverage, calculates venue/delta
  quantiles by UTC session bucket, and defaults to a non-negative p90 charge.
- `ftmo_cost_adjusted_export.py` accepts only exact
  `FULL_POSITION_LIFECYCLE_ACTUAL_V1` rows, removes source commission/swap,
  inserts pinned FTMO terms, charges the calibrated delta per side, and emits
  class-labelled daily cash decomposition.
- `ftmo_timebox_eval.py` accepts the class only under the explicit OWNER
  declaration, evaluates 1.0x/1.5x/2.0x spread sensitivity, stamps the class
  throughout the result, enforces monotonicity, and decides on the pessimistic
  lower bound.

## Calibration evidence

| Artifact | SHA-256 |
|---|---|
| Calibration spec | `8c29e47a004388a0cd198459ce8bfb704d1d3ab175b9155cf1ff3c2b57af445a` |
| Calibration refusal | `b366ed3ffed04371f6a8ed565de6d751d079108c71585fbe6d03d54cd3bac9f6` |
| FTMO_STREAM1 provision receipt | `0fccc0727a98e5db86945cb3ffce19f6d96013f8f71eb09fc960c3777eb45e72` |
| FTMO_STREAM2 provision receipt | `eb8c1626ef796a4c7aabf91559865757c1ba02ab0a0c055e680fe5b43744ac3a` |

Verbatim calibration result:

```text
{"status": "REFUSED", "path": "C:\\QM\\repo\\docs\\ops\\evidence\\2026-08-02_ftmo_spread_calibration.json", "sha256": "b366ed3ffed04371f6a8ed565de6d751d079108c71585fbe6d03d54cd3bac9f6", "error": "pairs[0].ftmo.source_hcc_paths[0]: required file is absent: D:\\QM\\mt5\\FTMO_STREAM1\\Bases\\FTMO-Demo\\History\\XAUUSD\\2026.hcc"}
calibration_exit_code=2
```

No calibration digest exists with `status=PASS`; therefore no exporter was
allowed to emit a production class-labelled stream.

## Five-sleeve input audit and re-score table

All exact Q08 inputs refused on row 1 with the same missing fields:
`entry_commission, entry_price, exit_commission, exit_price, fee, money_basis,
side`.

| Sleeve | Sealed Q08 SHA-256 | Input status |
|---|---|---|
| `13301:GDAXI` | `0a090ebb6ee67236948489a9486f419ba0ba41eb93d2ffa3e040a6a1b2a5a3a3` | REFUSED exact lifecycle fields |
| `10145:XAUUSD` | `b7828167b02d8440ce1956be570f13e56a95b0e26730b776f28086e10bb79c2d` | REFUSED exact lifecycle fields |
| `10183:XAUUSD` | `ca2e43790553fece068a3a91271ac5f75ad82bfc19e6a57d4437a4bb85a46265` | REFUSED exact lifecycle fields |
| `13036:GDAXI` | `da77e80241635ce4c45d1b802f38d779050948e6a4aabced4bc4ed9d0ad88a0b` | REFUSED exact lifecycle fields |
| `10128:XAUUSD` | `d96677acc4ec35597f80a5ad7d28d730c7b96d5dd5b01aceea1b40d9c8b8146f` | REFUSED exact lifecycle fields |

| Composition | 1.0x FTMO Phase-1 LB | 1.5x LB | 2.0x LB | Binding condition |
|---|---:|---:|---:|---|
| FUND_SCORE top 1 | not estimated | not estimated | not estimated | calibration + lifecycle fidelity |
| FUND_SCORE top 2 equal | not estimated | not estimated | not estimated | calibration + lifecycle fidelity |
| FUND_SCORE top 3 equal | not estimated | not estimated | not estimated | calibration + lifecycle fidelity |
| FUND_SCORE top 5 equal | not estimated | not estimated | not estimated | calibration + lifecycle fidelity |
| Challenge-ready singleton 10128 | not estimated | not estimated | not estimated | calibration + lifecycle fidelity |

## Verification

```text
python -m pytest -q tools/strategy_farm/tests/test_ftmo_spread_calibration.py tools/strategy_farm/tests/test_ftmo_cost_adjusted_export.py tools/strategy_farm/tests/test_ftmo_daily_net_export.py tools/strategy_farm/tests/test_ftmo_timebox_eval.py tools/strategy_farm/tests/test_ftmo_stream_reconciliation.py tools/strategy_farm/tests/test_ftmo_report_cost_reconcile.py
...................................................                 [100%]
51 passed, 5 subtests passed in 3.40s
```

```text
python -m py_compile tools/strategy_farm/portfolio/ftmo_spread_calibration.py tools/strategy_farm/portfolio/ftmo_cost_adjusted_export.py tools/strategy_farm/portfolio/ftmo_timebox_eval.py
PASS
```

Full command/output and refusal evidence is committed at
`docs/ops/evidence/2026-08-02_ftmo_cost_adjusted_path.md`.

## What this class can and cannot support

With a real PASS calibration and full-lifecycle inputs, the class can support
a historical diagnostic of **Darwinex-executed** streams with measured FTMO
cost adjustments. It cannot be described as FTMO venue execution and cannot
prove FTMO slippage, latency, fill probability, queue position, deployment
readiness, paid-challenge readiness, selection sealing, or live performance.

The deterministic prerequisites are target-symbol M1 history/projections in
the approved research roots and newly sealed exact full-lifecycle Q08 rows for
all five sleeves. No terminal launch, enqueue, Q-pipeline verdict, T_Live
change, or AutoTrading change is authorized by this report.
