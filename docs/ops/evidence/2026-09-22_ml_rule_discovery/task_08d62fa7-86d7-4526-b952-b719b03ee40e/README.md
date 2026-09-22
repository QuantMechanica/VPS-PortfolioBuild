# Track B offline mechanical-rule discovery

Task: `08d62fa7-86d7-4526-b952-b719b03ee40e`

OWNER decision: `OWNER-DEC-FTMO-FULL-THROTTLE-20260921`
Disposition: REVIEW — research candidates only; no Strategy Card, EA, pipeline verdict, or live authorization.

## Outcome

The full declared 39-symbol `.DWX` universe was scanned using only 2018-07-02 through 2022-12-31. Thirty-seven symbols had usable history; `JPN225.DWX` and `XBRUSD.DWX` had none in the bound archive. The tool engineered 71 closed-data features in 219 symbol/session groups and evaluated 161,420 direction-specific rules under one global Benjamini-Hochberg family at FDR 10%.

| Accounting item | Count |
|---|---:|
| Declared symbols / symbols with history | 39 / 37 |
| HCC source-file identities (path, size, SHA-256) | 185 |
| Closed-data features | 71 |
| Threshold/feature atoms generated / support-eligible | 81,030 / 74,412 |
| Mechanical rule structures / direction-specific tests | 80,710 / 161,420 |
| BH-FDR discoveries | 527 |
| 2022 same-sign, at-least-half-effect candidates | 6 |
| Neighbor robustness | 0 ROBUST / 4 FRAGILE / 2 NOT_APPLICABLE |
| Final states | 121,800 CLEAR_REJECT / 39,614 UNKNOWN / 6 WORTH_MT5_TEST |

`WORTH_MT5_TEST` is a research-layer label only. None of the six candidates is preregistered, pipeline-validated, or ready for a Strategy Card. The search-size penalty is `sqrt(2*ln(161420)) = 4.89729822`; four of six candidates have a negative search-deflated t statistic, and no ordered-threshold candidate is neighbor-robust. Those facts prevent a stronger conclusion.

## Candidate list

Discovery is 2018-07-02..2021-12-31. Validation is the rule-selection stop, calendar 2022. Means are net target-window ATR units after the declared F2-format round-trip price prior.

| Candidate | Mechanical condition and path | Discovery n / mean | 2022 n / mean | BH q | Deflated t | Neighbor |
|---|---|---:|---:|---:|---:|---|
| `MLDISC-2B5EA12F4567CBBB165B` | UK100 long, NY_CASH→ASIA, GBPUSD MA regime = -1 and Wednesday | 45 / +0.20263 | 45 / +0.15783 | 0.04054 | -1.2253 | N/A (categorical) |
| `MLDISC-52C76C0421E2FE50596F` | XNGUSD long, NY_CASH→ASIA, EURUSD vol ratio <= 1.0 | 391 / +0.18880 | 68 / +0.11786 | 4.16e-11 | +2.6663 | FRAGILE |
| `MLDISC-2DE6E7CD9420F417D20C` | XNGUSD long, NY_CASH→ASIA, GDAXI range >= 1.0 ATR | 266 / +0.15260 | 83 / +0.11230 | 0.00105 | -0.3079 | FRAGILE |
| `MLDISC-81AB88C0139128BCFE0B` | XNGUSD long, NY_CASH→ASIA, NDX range >= 1.0 ATR | 289 / +0.13702 | 90 / +0.09415 | 0.00534 | -0.6938 | FRAGILE |
| `MLDISC-4833F78D4C1169004E50` | XNGUSD long, NY_CASH→ASIA, XAGUSD return >= 0 ATR | 391 / +0.13457 | 117 / +0.07285 | 0.00019 | +0.0672 | FRAGILE |
| `MLDISC-59725479D7B74111B658` | XNGUSD short, NY_PREOPEN→CASH_OPEN, Thursday | 171 / +0.16622 | 48 / +0.15023 | 0.01375 | -0.9340 | N/A (categorical) |

Every candidate in `full_universe.json` carries the complete OWNER section-28 fields plus a model-free `qm.f2-mechanical-session-rule/v1` object. The object is a boolean conjunction over named closed-bar features; missing inputs fail closed to NO_TRADE. It binds next-bar-open entry, mandatory PRE30/POST30 high-impact news blackout, `RISK_FIXED=1000`, `RISK_PERCENT=0`, a stop floor of at least 0.3 prior-14 NY-cash ATR plus target-window/spread floors, no profit target, target-session flat, and Friday close cap. It names the shared F2 `simulate`, `period_stats`, and bootstrap adapters. No model file or runtime inference is emitted.

## Methods and leakage controls

- Feature windows: Asia, London, NY pre-open, cash open, NY cash, and London/NY overlap, mapped with the existing `zoneinfo`/F1 server-time helpers.
- Features: own/reference return and range, overnight gap, prior-day range position, weekday, lagged D1 MA50/MA200 regime, ATR-ratio volatility, NR-style compression, Asia FVG, and time of day. The FVG definition in code is bullish when M15 bar 3 low is above bar 1 high, bearish when bar 3 high is below bar 1 low.
- Leakage assertion: the timestamp of the last consumed HCC source bar must be strictly less than the target-window entry timestamp. Equality fails closed. The NY-pre-open row cannot use the same-open overnight gap.
- Search: shallow CART leaves (depth <=3), sparse one-atom rules, pair association rules (support >=2%, minimum 30), and ten boosted-stump rounds for importance only.
- Multiple testing: every direction/rule combination enters one 161,420-test BH family. The compact JSON materializes all 527 BH discoveries; a canonical-JSONL digest binds the complete in-memory trial ledger.
- Neighbor test: each ordered atom is moved one step each way on its predeclared grid, one atom at a time. Robustness requires minimum support, positive means, and at least half the selected effect in both discovery and 2022.
- Target label: target-session open-to-close return, normalized by lagged target-window ATR and charged one declared F2-format `spread_rt + slip_rt` price prior. Venue-specific commission, stop-path behavior, doubled costs, and news-event simulation belong to the preregistered F2 prescreen and are not claimed here.

The tool opens only years `2018,2019,2020,2021,2022`; `heldout_2023_2025_opened=false` is recorded in the machine output. The untouched 2023–2025 sample is reserved for a separately preregistered prescreen. No terminal, farm database, T_Live, AutoTrading, factory row, or gate was changed.

## Artifacts and provenance

- `full_universe.json` — compact machine result, all FDR discoveries, six mechanical candidates, source-file hashes, group importance, exact search counts, and task/OWNER provenance. SHA-256 `e8d27c3569d63c0270eadd11a3697d910a2526963bd44b6e06af077f195cf107`.
- `full_universe.md` — generated human-readable candidate report. SHA-256 `927041dd03ff4c731548598fe36e61d2b7b0baf38255549a9aa75c13996f03ba`.
- Complete trial-ledger binding: 161,420 canonical rows, SHA-256 `5ca1f59e981c42ca4ad0dd2fc0ee4c242ccc212de2a049a77ba63fdffd677760`.
- `session_features.py` SHA-256 `610549f9a5cdac6f91883533fcfa092229d6cc0c7c09dd715f0f9fa60668be99`.
- `ml_rule_discovery.py` SHA-256 `50d01665bb1dd37282566c5c65cc92e88a85f5a81750ab26033bc47dde53c132`.
- `test_ml_rule_discovery.py` SHA-256 `ba4f2737473601c0f1641301c8973c5bd5c69283f58009eb4edf47513bd92566`.

The cold feature-extraction/full-universe pass took 142.464 seconds. The final calculation from the content-addressed task cache took 66.170 seconds. A separate 74.641-second replay was byte-identical for both JSON and Markdown.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_ml_rule_discovery.py -q
.....                                                                    [100%]
5 passed

python -m py_compile tools/strategy_farm/research/session_features.py tools/strategy_farm/research/ml_rule_discovery.py
PASS

git diff --check -- <three task source/test paths>
PASS

machine contract audit
candidate_contract_failures=0; bad_source_hashes=0; source_years=2018,2019,2020,2021,2022

deterministic replay
json_match=true; markdown_match=true
```

The planted-effect fixture recovers a mechanical rule, the null fixture yields zero post-FDR candidates, equal/future cutoffs trip the look-ahead assertion, NaN cannot satisfy a negated atom, and repeated seeded rule generation is deterministic.

## Review disposition

Review the six research candidates as a family. The evidence does not authorize mining 2023–2025, adjusting conditions after seeing that holdout, drafting a card, building an EA, or entering the factory. A candidate selected for continuation must first receive independent critique and a durable QM-RESEARCH mechanization/preregistration record; only then may the unchanged rule run through the held-out F2 prescreen.
