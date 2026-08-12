# FTMO research lanes — runner and provision receipts

Date: 2026-08-02  
Router task: `499553be-2a78-4ae7-84b5-afb23a457c31`  
Scope: research infrastructure only; no Q verdict, selection credit, deployment, or live authority

## Outcome

`tools/strategy_farm/ftmo_lane_runner.py` now implements a separate, fail-closed
queue/runner contract for the registered `FTMO_STREAM1` and `FTMO_STREAM2`
portable roots. It does not use the Strategy Farm work-item database, does not
publish into pipeline report roots, and does not expose its artifacts to the
ordinary T1-T10 workers or survivor collection.

Both required `qm.ftmo-lane-provision-receipt/v1` artifacts were published.
Both honestly return `status=HOLD` and `campaign_ready=false`. No FTMO terminal
was launched, no history bootstrap was attempted, no campaign job was prepared
or queued, no active T1-T10 backtest was stopped, and neither T_Live nor an
AutoTrading setting was touched.

The receipts establish:

- each resolved root exactly matches its registered dedicated research root;
- the profile is `FTMO-Demo`, login `1514165262`, and the allowlisted broker
  source is `trader.ftmo.com`;
- `[Experts] Enabled=0`; the runner never changes this value;
- terminal, `common.ini`, `servers.dat`, and opaque `accounts.dat` identities
  are SHA-256-bound without publishing any credential value;
- the runner invocation contract always uses the lane-local executable and
  config with `/portable`;
- the capacity observation admitted at most two FTMO lanes, observed zero FTMO
  terminal processes, claimed zero normal slots, and left eight of ten normal
  slots idle (two T1-T10 terminal processes were observed); and
- actual native history windows remain unproven.

The `company_contains_ftmo` receipt field is based on the allowlisted profile
source domain. A report-level `Company` field remains explicitly unproven until
an admissible tester probe exists.

## Durable receipt identities

| Lane | Receipt | SHA-256 | Status |
|---|---|---|---|
| `FTMO_STREAM1` | `D:/QM/reports/state/FTMO_STREAM1_provision_2026-08-02.json` | `0fccc0727a98e5db86945cb3ffce19f6d96013f8f71eb09fc960c3777eb45e72` | `HOLD` |
| `FTMO_STREAM2` | `D:/QM/reports/state/FTMO_STREAM2_provision_2026-08-02.json` | `eb8c1626ef796a4c7aabf91559865757c1ba02ab0a0c055e680fe5b43744ac3a` | `HOLD` |

Both roots bind the same provisioned bytes:

- `terminal64.exe`: `03e4079b0e9e6697f19ad050049e6ae280cafc49692fa08968409e181209a992`
- `Config/common.ini`: `f524cf4d8aff087839d74676c37d1a15a8235ab7557e575e1df8fc7b7a42059a`
- `Config/servers.dat`: `7b2f083a4b9bae110ed81064927163ea322d8591af6cf7041cdc82edcc9f9eb2`
- `Config/accounts.dat`: `6b10b627a15a5afed0eeb0a17511692e1f146f19315351eebc13188c862d4a31`

`accounts.dat` is treated as an opaque hash-bound input. Its contents are not
copied into the repo, receipt, logs, or this evidence document.

## History finding and evidence-class boundary

The roots contain four incidental `Bases/Default/History` HCC files for FX
symbols, but neither root contains a `.tkc` or `.hcc` cache under an `XAUUSD` or
`GER40.cash` native-symbol path. Therefore the receipts record, separately for
each symbol:

- real ticks: zero relevant cache files, `coverage_proven=false`, null window;
- M1 bars: zero relevant cache files, `coverage_proven=false`, null window.

Cache filenames alone are never promoted into an actual coverage claim. A
future history observation must bind its source artifact by hash and state the
real-tick and M1 windows separately. The corrected OWNER premise remains
binding: model-4 multi-year FTMO evidence is impossible; there is no model
fallback.

The runner requires an explicit execution model on every job:

| CLI value | MT5 model | Evidence class | Daily exporter handoff |
|---|---:|---|---|
| `REAL_TICKS` | 4 | `FTMO_REAL_TICKS` | eligible only after all exporter checks |
| `M1_MODELLED` | 1 | `FTMO_M1_MODELLED` | refused as tick-level FTMO venue execution |

The class is stamped into the manifest, tester INI, and run receipt. The runner
cannot silently substitute one model for the other, and an M1 harvest cannot be
merged into `FTMO_DAILY_NET_V1` by this path.

## Runner controls

The implementation provides three explicit operations:

1. `provision-receipt` performs read-only inspection and writes the receipt.
2. `prepare` derives a run-local native-symbol set, creates a hash-bound tester
   INI/manifest, and writes only to the isolated FTMO queue. It refuses unless
   the reviewed provision receipt is campaign-ready and a hash-bound
   `qm.ftmo-symbol-probe-receipt/v1` proves `SYMBOL_GUARD_INIT`, zero guard
   violations, digits, contract size, tick size, and tick value.
3. `run-next --execute` claims only a matching `FTMO_STREAM1/2` manifest,
   revalidates every binding and current capacity, launches only that lane's
   terminal using `/portable`, and hash-binds the report, full Q08 capture, and
   append-only EA/equity-log delta. The flag is deliberately required after
   reviewer authorization.

The runner does not expose a bootstrap operation from a HOLD receipt. No
bootstrap was authorized or performed in this cycle. A separately reviewed
future bootstrap must serialize first connections because both lanes share the
same demo account; it may not be inferred from these receipts. Active tests are
never preempted; a timed-out test is reported for operator handling rather than
killed by this runner.

Set rebinding preserves every strategy input byte-for-byte at the parsed input
level. It changes only the sealed set's `; symbol:` provenance line; the tester
INI supplies the native host symbol. The sealed `.DWX` source remains immutable,
and both source and derived set files are bound in the manifest and run receipt.

## Reviewed wave-1 identities

The five planning hashes were re-read and match the approved design:

| Sleeve | EX5 SHA-256 | Set SHA-256 |
|---|---|---|
| `10128:XAUUSD` | `0d53e12208e39784c778145f607ed29d84b7a37e155d71caa767aba503064499` | `0c3c9cd5c1071406d216d9a964bdc2f3e74c0d810560f661ed2871f7236004f5` |
| `13036:GDAXI` | `1cfe279753f0d73bc8a9d7ac92abf15643fbb4ba72853cec621d9b89575809ab` | `80dc96e896fa109ef31964af8c617468e6737b1f0823f1616d1117b44c732b70` |
| `10145:XAUUSD` | `ebe9ca4c848cf6b0648417be51990318eb8ef4fa5e755146204e13e6f49192dc` | `0acbbeb78f4093f556b1e061f5fba94b25b3025dbf267f2dc13939ed8e2abb0b` |
| `10183:XAUUSD` | `2c33af263d70e4d5a287cbcff04a393ee707cfd5438c0a4a9e1582789f0c1987` | `ae747dc0b8f7fcb32ab02a4c32c0ac58dcddee8d8119415b88b73c1bc1154976` |
| `13301:GDAXI` | `3f3deac97d4819bf030bcf3e5153bc21f439a6aedb0ca430b3967fcbb236c625` | `3d07e1360e75a92b754fbeb60d8da9fa3901f1bd6efa73449d2081f73c71b511` |

Every set uses `RISK_FIXED=1000` and `RISK_PERCENT=0`; no set weakens
`qm_news_stale_max_hours` above 336. EA 13301 still has two matching EA
directories and is deterministically refused before queue publication.

## Exact isolated enqueue commands for Claude review

These are the five exact `prepare` commands requested by the approved design.
They are intentionally **not executable today**: the current provision
receipts are HOLD and the named symbol-probe receipts do not yet exist. The
first four will refuse before writing a queue row until those gates are closed;
the fifth also refuses the unresolved EA-13301 build ambiguity. They use the
only multi-year class physically possible under the corrected premise,
`FTMO_M1_MODELLED`, and consequently cannot be exported as tick-level venue
evidence.

```powershell
python tools/strategy_farm/ftmo_lane_runner.py prepare --lane FTMO_STREAM1 --sleeve-id '10128:XAUUSD' --ea-id 10128 --evaluator-symbol XAUUSD --source-symbol XAUUSD.DWX --native-symbol XAUUSD --timeframe D1 --from-date 2018-07-02 --to-date 2025-12-31 --execution-model M1_MODELLED --ex5 framework/EAs/QM5_10128_bb-breakout/QM5_10128_bb-breakout.ex5 --expected-ex5-sha256 0d53e12208e39784c778145f607ed29d84b7a37e155d71caa767aba503064499 --setfile framework/EAs/QM5_10128_bb-breakout/sets/QM5_10128_bb-breakout_XAUUSD.DWX_D1_backtest.set --expected-set-sha256 0c3c9cd5c1071406d216d9a964bdc2f3e74c0d810560f661ed2871f7236004f5 --provision-receipt D:/QM/reports/state/FTMO_STREAM1_provision_2026-08-02.json --symbol-probe D:/QM/reports/state/FTMO_STREAM1_XAUUSD_symbol_probe_2026-08-02.json --cost-snapshot artifacts/ftmo_symbol_snapshot_2026-07-11.json --expected-cost-sha256 7309310ad92f794407d25452127c38e7db175b841be0f70b82b201b841b932da --max-concurrent 2 --output-root D:/QM/reports/ftmo_stream/wave1 --queue-root D:/QM/strategy_farm/ftmo_lane_queue

python tools/strategy_farm/ftmo_lane_runner.py prepare --lane FTMO_STREAM2 --sleeve-id '13036:GDAXI' --ea-id 13036 --evaluator-symbol GDAXI --source-symbol GDAXI.DWX --native-symbol GER40.cash --timeframe M15 --from-date 2018-07-02 --to-date 2025-12-31 --execution-model M1_MODELLED --ex5 framework/EAs/QM5_13036_balke-go-long-regime/QM5_13036_balke-go-long-regime.ex5 --expected-ex5-sha256 1cfe279753f0d73bc8a9d7ac92abf15643fbb4ba72853cec621d9b89575809ab --setfile framework/EAs/QM5_13036_balke-go-long-regime/sets/QM5_13036_balke-go-long-regime_GDAXI.DWX_M15_backtest.set --expected-set-sha256 80dc96e896fa109ef31964af8c617468e6737b1f0823f1616d1117b44c732b70 --provision-receipt D:/QM/reports/state/FTMO_STREAM2_provision_2026-08-02.json --symbol-probe D:/QM/reports/state/FTMO_STREAM2_GER40_cash_symbol_probe_2026-08-02.json --cost-snapshot artifacts/ftmo_symbol_snapshot_2026-07-11.json --expected-cost-sha256 7309310ad92f794407d25452127c38e7db175b841be0f70b82b201b841b932da --max-concurrent 2 --output-root D:/QM/reports/ftmo_stream/wave1 --queue-root D:/QM/strategy_farm/ftmo_lane_queue

python tools/strategy_farm/ftmo_lane_runner.py prepare --lane FTMO_STREAM1 --sleeve-id '10145:XAUUSD' --ea-id 10145 --evaluator-symbol XAUUSD --source-symbol XAUUSD.DWX --native-symbol XAUUSD --timeframe D1 --from-date 2018-07-02 --to-date 2025-12-31 --execution-model M1_MODELLED --ex5 framework/EAs/QM5_10145_tsm-meanret/QM5_10145_tsm-meanret.ex5 --expected-ex5-sha256 ebe9ca4c848cf6b0648417be51990318eb8ef4fa5e755146204e13e6f49192dc --setfile framework/EAs/QM5_10145_tsm-meanret/sets/QM5_10145_tsm-meanret_XAUUSD.DWX_D1_backtest.set --expected-set-sha256 0acbbeb78f4093f556b1e061f5fba94b25b3025dbf267f2dc13939ed8e2abb0b --provision-receipt D:/QM/reports/state/FTMO_STREAM1_provision_2026-08-02.json --symbol-probe D:/QM/reports/state/FTMO_STREAM1_XAUUSD_symbol_probe_2026-08-02.json --cost-snapshot artifacts/ftmo_symbol_snapshot_2026-07-11.json --expected-cost-sha256 7309310ad92f794407d25452127c38e7db175b841be0f70b82b201b841b932da --max-concurrent 2 --output-root D:/QM/reports/ftmo_stream/wave1 --queue-root D:/QM/strategy_farm/ftmo_lane_queue

python tools/strategy_farm/ftmo_lane_runner.py prepare --lane FTMO_STREAM1 --sleeve-id '10183:XAUUSD' --ea-id 10183 --evaluator-symbol XAUUSD --source-symbol XAUUSD.DWX --native-symbol XAUUSD --timeframe D1 --from-date 2018-07-02 --to-date 2025-12-31 --execution-model M1_MODELLED --ex5 framework/EAs/QM5_10183_carver-multi-sig/QM5_10183_carver-multi-sig.ex5 --expected-ex5-sha256 2c33af263d70e4d5a287cbcff04a393ee707cfd5438c0a4a9e1582789f0c1987 --setfile framework/EAs/QM5_10183_carver-multi-sig/sets/QM5_10183_carver-multi-sig_XAUUSD.DWX_D1_backtest.set --expected-set-sha256 ae747dc0b8f7fcb32ab02a4c32c0ac58dcddee8d8119415b88b73c1bc1154976 --provision-receipt D:/QM/reports/state/FTMO_STREAM1_provision_2026-08-02.json --symbol-probe D:/QM/reports/state/FTMO_STREAM1_XAUUSD_symbol_probe_2026-08-02.json --cost-snapshot artifacts/ftmo_symbol_snapshot_2026-07-11.json --expected-cost-sha256 7309310ad92f794407d25452127c38e7db175b841be0f70b82b201b841b932da --max-concurrent 2 --output-root D:/QM/reports/ftmo_stream/wave1 --queue-root D:/QM/strategy_farm/ftmo_lane_queue

python tools/strategy_farm/ftmo_lane_runner.py prepare --lane FTMO_STREAM2 --sleeve-id '13301:GDAXI' --ea-id 13301 --evaluator-symbol GDAXI --source-symbol GDAXI.DWX --native-symbol GER40.cash --timeframe M5 --from-date 2018-07-02 --to-date 2025-12-31 --execution-model M1_MODELLED --ex5 framework/EAs/QM5_13301_balke-minute-range-breakout/QM5_13301_balke-minute-range-breakout.ex5 --expected-ex5-sha256 3f3deac97d4819bf030bcf3e5153bc21f439a6aedb0ca430b3967fcbb236c625 --setfile framework/EAs/QM5_13301_balke-minute-range-breakout/sets/QM5_13301_balke-minute-range-breakout_GDAXI.DWX_M5_backtest.set --expected-set-sha256 3d07e1360e75a92b754fbeb60d8da9fa3901f1bd6efa73449d2081f73c71b511 --provision-receipt D:/QM/reports/state/FTMO_STREAM2_provision_2026-08-02.json --symbol-probe D:/QM/reports/state/FTMO_STREAM2_GER40_cash_symbol_probe_2026-08-02.json --cost-snapshot artifacts/ftmo_symbol_snapshot_2026-07-11.json --expected-cost-sha256 7309310ad92f794407d25452127c38e7db175b841be0f70b82b201b841b932da --max-concurrent 2 --output-root D:/QM/reports/ftmo_stream/wave1 --queue-root D:/QM/strategy_farm/ftmo_lane_queue
```

These are FTMO-isolated preparer commands, never substitutes for
`farmctl enqueue-backtest`.

## Focused verification

Command:

```text
python -m py_compile tools/strategy_farm/ftmo_lane_runner.py
python -m pytest -q tools/strategy_farm/tests/test_ftmo_lane_runner.py
```

Verbatim result:

```text
.............                                                            [100%]
13 passed in 0.64s
```

Related exporter/evaluator/reconciliation regression command:

```text
python -m pytest -q tools/strategy_farm/tests/test_ftmo_lane_runner.py tools/strategy_farm/tests/test_ftmo_daily_net_export.py tools/strategy_farm/tests/test_ftmo_timebox_eval.py tools/strategy_farm/tests/test_ftmo_stream_reconciliation.py tools/strategy_farm/tests/test_ftmo_report_cost_reconcile.py
```

Verbatim result:

```text
......................................................              [100%]
54 passed, 5 subtests passed in 2.04s
```

The focused tests cover wrong-server refusal, enabled-Experts/AutoTrading
refusal, AppData/live-root refusal, missing-history refusal, capacity refusal,
symbol-rebinding provenance and guardrails, hash-drift detection,
model/evidence-class mismatch refusal, EA-directory ambiguity, and the explicit
reviewer execution flag.

## Still unproven / blocked

- actual `XAUUSD` and `GER40.cash` real-tick and M1 history windows;
- report-level FTMO company identity;
- native-symbol `SYMBOL_GUARD_INIT`, digits, contract size, tick size, and tick
  value for each lane/symbol;
- material semantic equivalence of `GDAXI.DWX` and `GER40.cash`;
- clean build identity for EA 13301; and
- any campaign outcome, daily stream, evaluator result, or Q-pipeline verdict.

The newer OWNER cost-adjusted-path ruling makes the roots calibration-only; it
does not convert these missing facts into evidence. The receipts and runner are
therefore handed back for review as infrastructure with a deliberate HOLD, not
as authorization to run the historical native campaign.
