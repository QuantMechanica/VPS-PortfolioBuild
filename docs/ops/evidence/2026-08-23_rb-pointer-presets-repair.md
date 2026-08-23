# rb-pointer-presets-repair — prepared preset repair evidence

Date: 2026-08-23

Authority: `OWNER-DEC-POINTER-PRESETS`, option (a), recorded in
`decisions/2026-08-23_owner_decisions_evening_batch_2.md:11`

Status: **PREPARED_NOT_DEPLOYED** — no T_Live write and no pointer signature

## Outcome

Ten repo-local live presets were regenerated from read-only snapshots of the
currently deployed presets through the scoped `build_check.ps1 -EALabel`
provenance-repair path. All ten are `REGENERABLE`: every ordered non-comment
`key=value` assignment is raw-byte equal to the deployed file. No numeric
coercion is used, so `1.0e-10` and `0.0000000001` are deliberately unequal.

The governed path is implemented at `framework/scripts/build_check.ps1:1287`
and calls the template-preserving generator mode at
`framework/scripts/gen_setfile.ps1:437`. Direct template-mode generation is
refused unless it carries the matching scoped build-check binding
(`gen_setfile.ps1:448`). Repair-mode validation is restricted to the generated
set file (`build_check.ps1:436`) and does not compile or run unrelated EA
hardening gates (`build_check.ps1:1352-1358`, `build_check.ps1:1388-1406`).

The generated preset header is `environment: live`, `risk_mode: PERCENT`, and
its `build_hash` is the SHA-256 of the exact T_Live companion `.ex5` observed
during preparation. The generator preserves encoding/newline policy and the
complete assignment sequence (`gen_setfile.ps1:467-535`). The 12989 draft and
do-not-copy marker lines are absent from the regenerated source.
The ten `.set` paths are pinned `-text` in `.gitattributes` so checkout cannot
invalidate the manifest's raw-byte source hashes.

## Per-preset proof

`keys` is the number of non-comment assignments compared one-by-one. `news`
is `qm_filter_news_mode`; `—` means the key is absent on both sides. All ten
have no seed key on either side. The only Friday controls are the two 10706
keys, both byte-equal (`FridayExitHourBroker=18`,
`FridayExitMinuteBroker=30`). Full old/new byte values and hex are in
`docs/ops/evidence/2026-08-23_tlive_preset_repair_functional_diff.json`.

| EA / slot | deployed target | source SHA-256 | expected pre-deploy SHA-256 | keys | news | result |
|---|---|---|---|---:|---:|---|
| `QM5_10440`, NDX slot 3 | `15_NDX_H1_QM5_10440_mql5-ohlc-mtf.set` | `af2678b4…ea717` | `cc7c9e3b…53769` | 23 | 3 | REGENERABLE |
| `QM5_10513`, XAUUSD slot 3 | `19_XAUUSD_D1_QM5_10513_mql5-ichimoku.set` | `722e1344…96dde` | `7d15a349…0408` | 19 | 3 | REGENERABLE |
| `QM5_10706`, GBPUSD slot 1 | `11_GBPUSD_H1_QM5_10706_tv-mon-ls.set` | `d9d43234…0f26f` | `e807c370…f6377` | 28 | 3 | REGENERABLE |
| `QM5_10911`, GDAXI slot 3 | `13_GDAXI_H1_QM5_10911_grimes-complex-pb.set` | `daf0f214…f6e1c` | `6a503e2b…e8ec` | 27 | 3 | REGENERABLE |
| `QM5_10919`, XTIUSD slot 1 | `04_XTIUSD_H4_QM5_10919_grimes-overshoot.set` | `af3f2a4a…735fc` | `10cbf478…f9199` | 15 | 3 | REGENERABLE |
| `QM5_10939`, GBPUSD slot 1 | `12_GBPUSD_H4_QM5_10939_grimes-context-pb.set` | `298bcd6a…c60e` | `4869e29a…0e90a` | 36 | 3 | REGENERABLE |
| `QM5_11132`, SP500 slot 0 | `16_SP500_D1_QM5_11132_tm-cum-rsi2.set` | `87fc8288…5694` | `76a984f0…f94d` | 24 | 3 | REGENERABLE |
| `QM5_12567`, XNGUSD slot 2 | `23_XNGUSD_D1_QM5_12567_cum-rsi2-commodity.set` | `26537d01…4e79` | `c7a3d43f…1551` | 24 | 3 | REGENERABLE |
| `QM5_12989`, XAUUSD slot 3 | `21_XAUUSD_H4_QM5_12989_grimes-nested-pb-v2.set` | `9fb2c0f8…2a5f4` | `a04013c5…bdeb8` | 20 | 3 | REGENERABLE |
| `QM5_13128`, NDX slot 0 | `14_NDX_H1_QM5_13128_pre-fomc-drift-ndx.set` | `743326c3…be4e` | `3aa27e4b…49ffb` | 10 | — | REGENERABLE |

All runtime `RISK_FIXED`, `RISK_PERCENT`, `PORTFOLIO_WEIGHT`,
`qm_magic_slot_offset`, news, strategy, seed, and Friday values are byte-equal.
The expected comment-only changes are recorded separately in the diff report:

- 10919: `environment backtest -> live`, `risk_mode FIXED -> PERCENT`, and
  stale build hash -> current companion-binary hash.
- 12989: draft risk-mode comment -> `PERCENT`, `build_hash pending` -> current
  companion-binary hash, and the two forbidden marker comments removed.
- The other eight: environment/risk comments remain `live`/`PERCENT`; pending
  build hashes are replaced by current companion-binary hashes. Provenance
  version/author/date comments are also repaired.

The complete deploy contract, including repo source paths, source hashes,
absolute targets, expected pre-deploy hashes, EA/symbol/slot/magic identities,
risk values, and binary hashes, is
`docs/ops/evidence/2026-08-23_tlive_preset_repair_manifest.json:1`.

## Verification tool

`tools/strategy_farm/verify_tlive_preset_repair.py:195` verifies:

- repo source SHA and current T_Live companion-binary SHA;
- target SHA as either the exact expected pre-deploy bytes or exact source
  bytes, with `--require-deployed` enforcing source-to-target equality;
- active `magic_numbers.csv` row and `ea_id*10000+slot` consistency;
- `environment: live`, `risk_mode: PERCENT`, `RISK_FIXED=0`, exact
  `RISK_PERCENT`, forbidden-marker absence, and a 64-hex build hash;
- canonical news-calendar presence and news-mode presence when news is enabled;
- the 24-sleeve, 9.7499-percent live manifest and per-sleeve roster/risk.

Pre-deploy invocation returned `PASS`, with 10/10 targets in
`EXPECTED_PREDEPLOY` state. That state proves the source has not yet been
copied. Claude's post-deploy invocation must add `--require-deployed`; any
changed live preset or companion binary fails closed.

## Tests and governed generation output

Completed commands:

```text
python -m pytest -q tools/strategy_farm/tests/test_verify_tlive_preset_repair.py
5 passed in 0.65s

python -m pytest -q tools/strategy_farm/tests/test_build_guardrails.py
20 passed in 0.99s

python -m pytest -vv tools/strategy_farm/tests/test_build_gate_hardening.py
27 passed in 150.99s

python tools/strategy_farm/verify_tlive_preset_repair.py --manifest docs/ops/evidence/2026-08-23_tlive_preset_repair_manifest.json
status=PASS; 10/10 target_state=EXPECTED_PREDEPLOY
```

Each of the ten scoped `build_check.ps1` invocations ended
`build_check.result=PASS`, `build_check.failures=0`. Existing advisory-only
`.DWX` zero-spread warnings appeared for 10911 and 10919; they do not alter or
invalidate this assignment-preserving preset repair.

## Rollback

No live rollback is needed because this ticket did not write T_Live or sign
the pointer. Before deployment, rollback is `git revert <this-commit>` (or
remove the prepared sources under review). If Claude deploys later, the file
rollback source is the preserved
`C:\QM\deploy\DXZ_FINAL_2026-07-19\presets` batch; every restored target must
match this manifest's `expected_pre_deploy_sha256` before the pointer is
re-evaluated. AutoTrading is not part of either operation.

## Boundary evidence

- T_Live was read and copied only into an isolated temporary scratch directory.
- The verifier still reports all ten targets at their original pre-deploy SHA.
- No factory toggle, enqueue, backtest deletion, verdict write, threshold,
  manifest risk, AutoTrading state, deploy-pointer signature, or T_Live file
  was changed.
