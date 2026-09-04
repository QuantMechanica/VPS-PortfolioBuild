# FUND_SCORE current-population re-score — 2026-09-04

Status: REVIEW. Screening evidence only; no roster, manifest, threshold, gate, or book change.

Task: `a32a064e-f650-45e7-9009-4da4dafd4a10`  
Implementation: `caf825c6e89929ddcd932268613c725c6d5bddc9` on `agents/codex`

## Result

The stale-input defect is reproduced and repaired. The prior facade enumerated the live stream directory while `sleeve_improvement_targets.py` imported `challenge_book_60d.py`, whose calculations were hard-pinned to the July bundle. The implementation now passes one explicit stream directory through that engine. Every output row carries the resolved input path and SHA-256; every scored row also carries the complete formula inputs and denominator.

The current population was assembled read-only from `D:/QM/strategy_farm/state/farm_state.sqlite` into:

`D:/QM/strategy_farm/artifacts/portfolio/fund_score_current_population_20260904_bc7e`

Its `bundle_manifest.json` reports schema `qm.sealed_stream_bundle/v1`, DB mode `ro`, **8 requested / 8 bound / 0 refused**, and loader verification `true`. No active FUND_SCORE cache was rewritten.

Formula, unchanged:

`FUND_SCORE = med60_1x / max(2.0, 2.0 * abs(worst_day_1x), wdd_p90_1x)`

| Sleeve | SHA-256 of exact current sealed stream | med60 | abs worst day | wDD p90 | denominator | FUND_SCORE |
|---|---|---:|---:|---:|---:|---:|
| 10706:GBPUSD | `71fb35b8f8539356f511609a4d1dfb06571f85b19b60de6647e907ec891e34f7` | 0.652650 | 2.441940 | 6.105180 | 6.105180 | 0.106901 |
| 11421:EURUSD | `e9d0a9ef831f156f0f67e5bf1140d7e57702c3923a4ff47b5548847957d7c0c1` | 0.035120 | 1.127290 | 1.589430 | 2.254580 | 0.015577 |
| 11422:USDCAD | `7ce6cc3ec2f1279c18e8601119e3319375d5d3fa1ce4cf95cf33e05eefc33198` | 0.451500 | 1.226280 | 3.043910 | 3.043910 | 0.148329 |
| 11910:NZDUSD | `555bbee205432c62f06da96a0a291d14028dc5c88e3fa8b2792ad62bc5d885b0` | 0.194250 | 1.025660 | 1.025660 | 2.051320 | 0.094695 |
| 13054:XTIUSD | `67d4fe2cef067e041f01d10e5e6c98312a32b43683eee2da3d0bfa9af296955b` | 0.048530 | 0.968020 | 0.812500 | 2.000000 | 0.024265 |
| 1537:XAGUSD | `1885c21e4c895827c79ff3d55849308ab4ee5c0db96a7d576cd652dc3eff8658` | 0.262475 | 0.909650 | 1.243510 | 2.000000 | 0.131237 |
| 20048:XTIUSD | `a792e2635250bcd6df5aa4a290359b54e6d5ffe8fbe10e34d143b74dfe0e8d55` | 0.065970 | 0.789620 | 0.321100 | 2.000000 | 0.032985 |
| 21505:XAGUSD | `243804faaf0050f5482b9a4aac8f9eb0dcd552de1c2c139a486f0bcfa46b94c1` | 0.247000 | 0.995400 | 1.779900 | 2.000000 | 0.123500 |

All eight current streams are scorable. Therefore current-population exclusions are **0**; there are no missing rows to conceal or reconcile. All eight scores remain below the unchanged floor of 1.0. The independent builder census remains 8/25, so this result does not authorize a book.

## Explicit legacy comparison

The frozen July bundle was re-scored separately with population label `legacy_frozen_20260719`: 24/24 rows scored. Only two current identities overlap that legacy population by sleeve key, and both stream hashes differ.

| Sleeve | Legacy SHA-256 | Legacy score | Current score | Current minus legacy |
|---|---|---:|---:|---:|
| 10706:GBPUSD | `3649e35f89030017e5e5fc07517bed476244dd22ca2534766cb8e8c25364d9a7` | 0.131643 | 0.106901 | -0.024742 |
| 11421:EURUSD | `7ad106530db79e93ac24a136a451c856a3660823f5d99c0c7130a20df90d3902` | 0.027251 | 0.015577 | -0.011674 |

The other six current sleeves are absent from the July population. The comparison is descriptive only and is not merged into the current score set.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_fund_score_current_population.py tools/strategy_farm/tests/test_assemble_stream_bundle.py tools/strategy_farm/tests/test_dual_book_builders.py -q` — **36 passed, 1 skipped**.
- `python -m py_compile` over the three modified scoring modules — PASS.
- Synthetic test covers one scorable and one excluded stream, exact path/hash provenance, formula reconstruction, explicit population label, and one-output-row-per-input reconciliation.
- Current bundle assembly — **8 bound, 0 refused, loader verified**.

## Review verdict

PASS for implementation review: input selection is explicit and score provenance is reconstructible. Economic verdict remains unchanged: all current scores are below 1.0, the census is 8/25, and NO-BUY remains in force.
