# FTMO cost-adjusted evaluation path — implementation and refusal evidence

Date: 2026-08-02
Router task: `225a787d-4dad-4639-9e56-a3eb384d0b15`
Evidence class: `DXZ_EXECUTION_FTMO_COST_ADJUSTED_V1`

## Outcome

The cost-adjusted path is implemented and its focused verification passes.
The production calibration and five-sleeve re-score are **not estimated**.
This is the required fail-closed outcome, not a strategy or pipeline verdict:

1. the approved research roots contain no `XAUUSD` or `GER40.cash` FTMO M1
   HCC history; and
2. all five sealed inventory Q08 files are legacy rows and omit the side,
   entry/exit prices, fee, money-basis label, and entry/exit commission split
   required for exact FTMO commission/swap substitution.

No spread value was guessed, no symbol proxy was used, no terminal was
started, no task was enqueued, and neither T_Live nor AutoTrading was touched.

## Implemented contract

- `tools/strategy_farm/portfolio/ftmo_spread_calibration.py`
  - consumes the official MQL5 `CopyRates(PERIOD_M1)` spread projection;
  - hash-binds the projection and every source `.hcc` file;
  - requires exact identical FTMO/DXZ minute timestamps per symbol pair;
  - reports venue and delta quantiles overall and by UTC session bucket;
  - uses the non-negative 90th-percentile delta by default, stricter than the
    required upper quartile, and never credits a negative delta;
  - refuses missing coverage, missing buckets, cross-symbol substitution, and
    unbound history.
- `tools/strategy_farm/portfolio/ftmo_cost_adjusted_export.py`
  - accepts only `FULL_POSITION_LIFECYCLE_ACTUAL_V1` Q08 rows with exact side,
    price, fee, commission-split, notional, and lifecycle fields;
  - removes Darwinex commission/swap, applies pinned FTMO percent commission
    and point swap, and charges the calibrated delta on entry and exit;
  - emits continuous daily rows with the evidence class, cost/calibration
    digests, and per-day cash decomposition;
  - emits intraday cash candidates that the evaluator recomputes at every
    sensitivity multiplier rather than scaling an already-rounded return.
- `tools/strategy_farm/portfolio/ftmo_timebox_eval.py`
  - keeps undeclared Darwinex inheritance refused by default;
  - accepts the new class only under the exact explicit OWNER declaration;
  - stamps the class into the result, composition, and sensitivity rows;
  - evaluates `1.0x`, `1.5x`, and `2.0x` spread charges;
  - enforces non-increasing bootstrap lower bounds and decides on the lowest
    bound, using the largest multiplier to break a tie.

The HCC container is not parsed directly because MetaQuotes documents it as a
terminal-managed proprietary format. The bound projection uses the supported
MQL5 `MqlRates.spread`/`CopyRates` surface and retains the HCC hashes as source
lineage.

## Production calibration attempt

Command, from `C:/QM/repo`:

```powershell
python tools/strategy_farm/portfolio/ftmo_spread_calibration.py `
  --spec docs/ops/evidence/2026-08-02_ftmo_spread_calibration_spec.json `
  --output docs/ops/evidence/2026-08-02_ftmo_spread_calibration.json
```

Verbatim output and process status:

```text
{"status": "REFUSED", "path": "C:\\QM\\repo\\docs\\ops\\evidence\\2026-08-02_ftmo_spread_calibration.json", "sha256": "b366ed3ffed04371f6a8ed565de6d751d079108c71585fbe6d03d54cd3bac9f6", "error": "pairs[0].ftmo.source_hcc_paths[0]: required file is absent: D:\\QM\\mt5\\FTMO_STREAM1\\Bases\\FTMO-Demo\\History\\XAUUSD\\2026.hcc"}
calibration_exit_code=2
```

The two provision receipts independently remain `HOLD` with
`NATIVE_HISTORY_WINDOWS_UNPROVEN`; their target-symbol cache counts are zero.

| Artifact | SHA-256 |
|---|---|
| FTMO_STREAM1 provision receipt | `0fccc0727a98e5db86945cb3ffce19f6d96013f8f71eb09fc960c3777eb45e72` |
| FTMO_STREAM2 provision receipt | `eb8c1626ef796a4c7aabf91559865757c1ba02ab0a0c055e680fe5b43744ac3a` |
| Calibration spec | `8c29e47a004388a0cd198459ce8bfb704d1d3ab175b9155cf1ff3c2b57af445a` |
| Refusal artifact | `b366ed3ffed04371f6a8ed565de6d751d079108c71585fbe6d03d54cd3bac9f6` |

## Sealed Q08 lifecycle preflight

The strict exporter parser was run read-only against the five exact
inventory-bound files. Verbatim result:

```text
13301:GDAXI  REFUSED  missing=entry_commission,entry_price,exit_commission,exit_price,fee,money_basis,side
10145:XAUUSD REFUSED  missing=entry_commission,entry_price,exit_commission,exit_price,fee,money_basis,side
10183:XAUUSD REFUSED  missing=entry_commission,entry_price,exit_commission,exit_price,fee,money_basis,side
13036:GDAXI  REFUSED  missing=entry_commission,entry_price,exit_commission,exit_price,fee,money_basis,side
10128:XAUUSD REFUSED  missing=entry_commission,entry_price,exit_commission,exit_price,fee,money_basis,side
```

Their sealed digests remain unchanged:

| Sleeve | Q08 SHA-256 |
|---|---|
| `13301:GDAXI` | `0a090ebb6ee67236948489a9486f419ba0ba41eb93d2ffa3e040a6a1b2a5a3a3` |
| `10145:XAUUSD` | `b7828167b02d8440ce1956be570f13e56a95b0e26730b776f28086e10bb79c2d` |
| `10183:XAUUSD` | `ca2e43790553fece068a3a91271ac5f75ad82bfc19e6a57d4437a4bb85a46265` |
| `13036:GDAXI` | `da77e80241635ce4c45d1b802f38d779050948e6a4aabced4bc4ed9d0ad88a0b` |
| `10128:XAUUSD` | `d96677acc4ec35597f80a5ad7d28d730c7b96d5dd5b01aceea1b40d9c8b8146f` |

The parser deliberately does not reconstruct missing side/price fields from
profit or assume an exit notional. Such reconstruction would approximate the
percent commission and make direction-dependent swap unknowable.

## Wave-1 / FUND_SCORE re-score

| Composition | 1.0x lower bound | 1.5x lower bound | 2.0x lower bound | Binding condition |
|---|---:|---:|---:|---|
| FUND_SCORE top 1 | not estimated | not estimated | not estimated | calibration + lifecycle fidelity |
| FUND_SCORE top 2 equal | not estimated | not estimated | not estimated | calibration + lifecycle fidelity |
| FUND_SCORE top 3 equal | not estimated | not estimated | not estimated | calibration + lifecycle fidelity |
| FUND_SCORE top 5 equal | not estimated | not estimated | not estimated | calibration + lifecycle fidelity |
| Challenge-ready singleton 10128 | not estimated | not estimated | not estimated | calibration + lifecycle fidelity |

The best bootstrap lower bound remains `null`. Evidence credit remains `0.00`
and the evidence-credit gap to the OWNER 0.80 design bar remains `0.80`. This
is **not** an estimate that the true pass probability is zero. In the existing
decision taxonomy, the binding dimension remains density: zero admissible
cost-adjusted streams exist.

## Verification

Focused suite, verbatim:

```text
python -m pytest -q tools/strategy_farm/tests/test_ftmo_spread_calibration.py tools/strategy_farm/tests/test_ftmo_cost_adjusted_export.py tools/strategy_farm/tests/test_ftmo_daily_net_export.py tools/strategy_farm/tests/test_ftmo_timebox_eval.py tools/strategy_farm/tests/test_ftmo_stream_reconciliation.py tools/strategy_farm/tests/test_ftmo_report_cost_reconcile.py
...................................................                 [100%]
51 passed, 5 subtests passed in 3.40s
```

```text
python -m py_compile tools/strategy_farm/portfolio/ftmo_spread_calibration.py tools/strategy_farm/portfolio/ftmo_cost_adjusted_export.py tools/strategy_farm/portfolio/ftmo_timebox_eval.py
PASS
```

The new tests cover calibration coverage refusals, HCC/projection binding,
upper-tail and non-negative charges, exact FTMO commission/swap substitution
on a worked lifecycle, legacy-row refusal, calibration digest/symbol refusal,
explicit-class default refusal, class propagation, and sensitivity monotonicity.

## Evidence-class boundary and deterministic next prerequisites

Once real inputs exist, this class can support a historical diagnostic of
Darwinex-executed trades after measured FTMO cost substitution. It cannot
support claims of FTMO venue execution, latency, slippage, queue position,
selection sealing, paid-challenge readiness, deployment, or live use.

The next run must first provide both prerequisites without weakening a gate:

1. target-symbol FTMO M1 HCC files inside the approved research roots plus
   hash-bound `CopyRates(PERIOD_M1)` spread projections with a matching DXZ
   calendar; and
2. newly sealed, full-lifecycle Q08 rows for all five sleeves containing the
   exact required fields.

Only then may the five exports, explicit-class config, and sensitivity re-score
run. No enqueue or terminal action is part of this evidence handback.
