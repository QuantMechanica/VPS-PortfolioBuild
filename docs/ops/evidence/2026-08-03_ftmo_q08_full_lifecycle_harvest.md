# FTMO Q08 full-lifecycle harvest — enqueue evidence

Date: 2026-08-03  
Router task: `2270a0a5-55ce-45a0-a714-1edd96c6fd5d`

## Outcome

`HARVEST_ENQUEUED; EXPORT_DEFERRED`.

Five new Q08 rows were created append-only and sealed to current EA, EX5,
setfile, symbol, period, and expert identities.  The prior Q08 rows were not
mutated.  At handoff all five successors remain pending behind the active
factory workload, so no new lifecycle file or Q08 verdict exists yet.

The downstream FTMO-cost export is also inadmissible today: the companion M1
bootstrap task recorded the OWNER challenge terminal with automated trading
enabled and therefore did not launch the shared-account research lanes.  The
reviewed calibration still refuses for absent XAUUSD FTMO history.  No spread,
commission, or swap value was invented, and `ftmo_timebox_eval.py` was not fed
legacy rows under a false evidence class.

## Append-only harvest rows

| Sleeve | New Q08 row | Preserved sealed Q08 row | EX5 SHA-256 | State |
|---|---|---|---|---|
| `10128:XAUUSD` | `80c6800b-8ff6-4642-a739-2abd3e2988c8` | `514651e9-00a7-493e-88f3-72048cb69768` | `19f4981bcef861091e3bfb6b1a4126f0f66c62f6a5ea0b1094656087f0edbef5` | pending |
| `10145:XAUUSD` | `d4895758-2910-4cdf-ba6a-f944088e7633` | `683486f1-7174-470e-9c36-7d1e02276c3e` | `c3f5476eff34ce65b25acf8bd967b5d0b349ce8e05bd492f82316f899a38db86` | pending |
| `10183:XAUUSD` | `34bf3be6-0997-4636-96fe-f7cad652db29` | `4595d303-8afd-47fd-aaeb-b739f54320d9` | `c2fbbb8a9e0b4269bb2635c2f6e75a1295d2d47bcec83a6542744e03d36f7cd7` | pending |
| `13036:GDAXI` | `57ca631d-eced-4376-9203-2bc292e60bf0` | `85aadb10-6860-43df-bfb4-8c164246efc2` | `2cd0f7270572d37bd67ca0d1f724eaad95d756b4af18859d2dd0203d0045b0be` | pending |
| `13301:GDAXI` | `4dcaab4d-06ad-4b23-ace8-ddc557e034b8` | `923b11b9-2e7d-4f70-bd67-37e0bb834123` | `64d71b745fade2134967cd1373b39a359f22cadc94933ba8f71c177ff44edc87` | pending |

Each row carries
`rerun_reason=ftmo_full_position_lifecycle_actual_v1_harvest` and an exact
current MQ5/EX5/setfile binding.  The selected Q07 predecessors are,
respectively, `1e09eceb`, `096bfd3b`, `d364527c`, `37bdfd72`, and `e75520f9`.

## Producer/build verification

The full-position emitter is in `QM_Common.mqh` and writes side, entry and exit
prices, entry and exit commission, fee, total commission, swap, volume,
notional, entry time, exit time, MAE, and
`money_basis=FULL_POSITION_LIFECYCLE_ACTUAL_V1`.

- All five EA directories passed `validate_build_guardrails.py`; the validator
  checked 600 files in total with zero findings and a 336-hour maximum news
  staleness policy.
- Four pre-emitter binaries (`10128`, `10145`, `10183`, `13301`) were rebuilt
  serially through `compile_ea.py`, each with 0 errors and 0 warnings.  The
  canonical pump committed the resulting binaries in `7a426b845`.
- `13036` already carried the full-lifecycle emitter.  Its binary was not
  touched because T7 was executing active Q07 row
  `47db3c85-467e-493d-8779-cf1e4e81979a`.
- Every selected setfile has `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- Focused suite:
  `test_q08_full_lifecycle_money_producer.py`,
  `test_ftmo_cost_adjusted_export.py`, and `test_ftmo_timebox_eval.py` ->
  `32 passed`.

## Cost/evaluator boundary

The routed venue-cost snapshot is the only permitted source of venue costs;
none were applied in this cycle.  The current reviewed spread-calibration call
returned `REFUSED` with artifact
`D:/QM/reports/ftmo_spread_calibration/2026-08-03_bootstrap_deferred_refusal.json`
(SHA-256
`b366ed3ffed04371f6a8ed565de6d751d079108c71585fbe6d03d54cd3bac9f6`)
because `FTMO_STREAM1/Bases/FTMO-Demo/History/XAUUSD/2026.hcc` is absent.

Therefore there are no honest cost-adjusted export paths or timebox result to
report yet.  Producing them would require both (a) these five Q08 rows to finish
and prove full-lifecycle rows and (b) the separately reviewed, hash-bound FTMO
spread calibration to pass.  Pipeline verdicts remain solely the row-bound
pipeline evidence.
