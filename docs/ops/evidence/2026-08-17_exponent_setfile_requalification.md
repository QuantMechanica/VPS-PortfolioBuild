# Q02 exponent-setfile requalification evidence — 2026-08-17

Router task: `dc02ec96-7cd8-49c2-ae26-7c4fbcb738dc` (priority 97)

## Verdict

PASS for remediation and Q02 admission. All 32 exponent-form values identified by
`artifacts/exponent_setfile_sweep_20260817b.json` were expanded exactly in all 25
affected setfiles. The 22 owning EAs compiled with zero errors and zero warnings.
The 15 EAs named by the task were re-enqueued as exact, append-only Q02 reruns;
their historical rows and verdicts remain unchanged. New pipeline verdicts remain
pending and must come only from the new Q02 evidence.

The opt-in build command is:

```powershell
pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel <label> -NormalizeExponentFloats
```

The switch refuses an unscoped invocation, imports the generator's existing exact
float serializer, rejects missing input-type or lossy conversions, and preserves
the existing UTF-8 BOM policy. It does not regenerate whole setfiles and therefore
does not drop unrelated locked inputs.

## Normalized setfiles

The SHA-256 values below are post-normalization file identities. Build-check also
refreshed each setfile's existing `build_hash` header through its normal validation
path.

| Setfile | Exact normalization(s) | Current SHA-256 |
|---|---|---|
| `framework/EAs/QM5_13203_energy-downbeta/sets/QM5_13203_energy-downbeta_QM5_13203_XTI_XNG_DOWNBETA_D1_D1_backtest.set` | `strategy_beta_tie_epsilon`: `1e-8` -> `0.00000001` | `bc8ffefd0ffefcf31da1ba2229eee725d336ddb829cb708d225967f4cfa783cd` |
| `framework/EAs/QM5_13205_xau-xag-qc/sets/QM5_13205_xau-xag-qc_QM5_13205_XAU_XAG_QC_D1_D1_backtest.set` | `strategy_slope_unique_epsilon`: `1e-10` -> `0.0000000001` | `e22942fad77218c8c85de2c6e0b191f7ef47e5b1462c994a1c12924eedb28be8` |
| `framework/EAs/QM5_20262_xng-lr-trend/sets/QM5_20262_xng-lr-trend_XNGUSD.DWX_D1_backtest.set` | `strategy_slope_epsilon`: `1.0e-10` -> `0.0000000001` | `446385b13af9efa78f1bc4a7706536f6db954caa486b1ddded600b5c4759d0cb` |
| `framework/EAs/QM5_20289_wti-rsj-rev/sets/QM5_20289_wti-rsj-rev_XTIUSD.DWX_D1_backtest.set` | `strategy_rsj_tolerance`: `1.0e-12` -> `0.000000000001` | `a6e204d4e663d3e51b17ad0f7aabf767036f29c1a867ef6b0abffeb1edb7db23` |
| `framework/EAs/QM5_20289_wti-rsj-rev/sets/QM5_20289_wti-rsj-rev_XTIUSD.DWX_D1_q05_stress_medium.set` | `strategy_rsj_tolerance`: `1.0e-12` -> `0.000000000001` | `71a899b2bb50ebd2cdb84e59cad1ee2479ad9f196b49ac40c974f9eeb4202841` |
| `framework/EAs/QM5_20290_wti-skew-prem/sets/QM5_20290_wti-skew-prem_XTIUSD.DWX_D1_backtest.set` | `strategy_variance_floor`, `strategy_skew_tolerance`: `1.0e-12` -> `0.000000000001` | `fba30ada18175b1abdea216efa4e160ca6691c22ace3fbbcd9e59958de95bfd3` |
| `framework/EAs/QM5_20295_wti-kurt-prem/sets/QM5_20295_wti-kurt-prem_XTIUSD.DWX_D1_backtest.set` | `strategy_variance_floor`, `strategy_kurtosis_tolerance`: `1.0e-12` -> `0.000000000001` | `7a488de9dd38bfb3265e715d7b2381d110df40cd6c0e8eefd38a3158ee361514` |
| `framework/EAs/QM5_20296_xng-skew-prem/sets/QM5_20296_xng-skew-prem_XNGUSD.DWX_D1_backtest.set` | `strategy_variance_floor`, `strategy_skew_tolerance`: `1.0e-12` -> `0.000000000001` | `a787a13c2f8dd61c45b2928c374d8393aba4c2b5d153fbc11c22c628f582b4e9` |
| `framework/EAs/QM5_20297_xng-kurt-prem/sets/QM5_20297_xng-kurt-prem_XNGUSD.DWX_D1_backtest.set` | `strategy_variance_floor`, `strategy_kurtosis_tolerance`: `1.0e-12` -> `0.000000000001` | `adcd14a92f3a49eb8eb53b1882e821f07c1d06274eacaddb38131fc3d6581902` |
| `framework/EAs/QM5_20298_wti-vov-regime/sets/QM5_20298_wti-vov-regime_XTIUSD.DWX_D1_backtest.set` | `strategy_vov_tolerance`: `1.0e-12` -> `0.000000000001` | `867e25d61dc8e850bb831e76b2072ee69de6c83a8260a2f889c600a822d81a10` |
| `framework/EAs/QM5_20299_xng-vov-regime/sets/QM5_20299_xng-vov-regime_XNGUSD.DWX_D1_backtest.set` | `strategy_vov_tolerance`: `1.0e-12` -> `0.000000000001` | `7d9c84357904ea8d90464dbfc6f54c9da95c42075ef736c5c5766eb716dae622` |
| `framework/EAs/QM5_20300_wti-max-regime/sets/QM5_20300_wti-max-regime_XTIUSD.DWX_D1_backtest.set` | `strategy_max_tolerance`: `1.0e-12` -> `0.000000000001` | `d1dee702f949e13352bde80a14efe9f78aacf6522cfdb90d0498d4deddffe869` |
| `framework/EAs/QM5_20301_wti-es-regime/sets/QM5_20301_wti-es-regime_XTIUSD.DWX_D1_backtest.set` | `strategy_es_tolerance`: `1.0e-12` -> `0.000000000001` | `24f508f7e6603395eca6c8caa0d0f06e69ecceb2cb21ed8e8270bee83f196c78` |
| `framework/EAs/QM5_20302_wti-aliq-regime/sets/QM5_20302_wti-aliq-regime_XTIUSD.DWX_D1_backtest.set` | `strategy_aliq_tolerance`: `1.0e-12` -> `0.000000000001` | `2720a792fad5a071f845edb92263438f6fb11ed69f9b439fa3cf086df6a8745c` |
| `framework/EAs/QM5_20303_wti-volbeta-reg/sets/QM5_20303_wti-volbeta-reg_XTIUSD.DWX_D1_backtest.set` | `strategy_beta_tolerance`: `1.0e-12` -> `0.000000000001` | `09761f57eec28fc12ac9894a636bd34c8f4ca4633cf96f22daf00162b939d2ba` |
| `framework/EAs/QM5_20304_wti-jumpbeta-reg/sets/QM5_20304_wti-jumpbeta-reg_XTIUSD.DWX_D1_backtest.set` | `strategy_beta_tolerance`: `1.0e-12` -> `0.000000000001` | `6ee79ee1046d7dadac1f119b55b86ac39a39c921c4d04d5b858f602d614b7109` |
| `framework/EAs/QM5_20305_xng-aliq-regime/sets/QM5_20305_xng-aliq-regime_XNGUSD.DWX_D1_backtest.set` | `strategy_state_tolerance`: `1.0e-12` -> `0.000000000001` | `e72f3d220895a76847837c8d17a710f5e8788150831dd1b07bf9d1adc94c36c4` |
| `framework/EAs/QM5_20306_xng-jumpbeta-reg/sets/QM5_20306_xng-jumpbeta-reg_XNGUSD.DWX_D1_backtest.set` | `strategy_beta_tolerance`: `1.0e-12` -> `0.000000000001` | `8ed12047256fcefd27811147ff9c0687136ee2538ca332ddb98f1b2c16f56753` |
| `framework/EAs/QM5_21516_wti-decoup-trend/sets/QM5_21516_wti-decoup-trend_XTIUSD.DWX_D1_backtest.set` | `strategy_corr_tolerance`: `1.0e-12` -> `0.000000000001` | `745394395753331394b9337cd2433d97ef009c715278c804f2b4bdb9ea162fa2` |
| `framework/EAs/QM5_21516_wti-decoup-trend/sets/QM5_21516_wti-decoup-trend_XTIUSD.DWX_D1_q05_stress_medium.set` | `strategy_corr_tolerance`: `1.0e-12` -> `0.000000000001` | `211042238e79798cf337503c6031267aa26cf1592f93eaa51e13b7827567c29a` |
| `framework/EAs/QM5_21516_wti-decoup-trend/sets/QM5_21516_wti-decoup-trend_XTIUSD.DWX_D1_q06_stress_harsh.set` | `strategy_corr_tolerance`: `1.0e-12` -> `0.000000000001` | `9693846b999780bc40e8236189c02eced40e6474bf08f451076a0530115e962c` |
| `framework/EAs/QM5_21518_wti-brent-cfm/sets/QM5_21518_wti-brent-cfm_XTIUSD.DWX_D1_backtest.set` | `strategy_return_tolerance`: `1.0e-10` -> `0.0000000001` | `582c47f363d9f2fc9549469aa0d349ecf38062d3f40e4b0ea66d1273a67fcbec` |
| `framework/EAs/QM5_21522_wti-lowdb-trend/sets/QM5_21522_wti-lowdb-trend_XTIUSD.DWX_D1_backtest.set` | `strategy_beta_tolerance`: `1.0e-12` -> `0.000000000001`; `strategy_variance_epsilon`: `1.0e-16` -> `0.0000000000000001` | `73ba2df582a619e85b2b74fc7bc46726224a2cdb3f06bd5d8d3c9e275ee223f7` |
| `framework/EAs/QM5_21523_wti-xau-div-tr/sets/QM5_21523_wti-xau-div-tr_XTIUSD.DWX_D1_backtest.set` | `strategy_sign_deadband`: `1.0e-12` -> `0.000000000001`; `strategy_return_tolerance`: `1.0e-10` -> `0.0000000001` | `855ac7306e06dc8b985615270e54ea5f6bdafc638a3e2252a0098cd32805f088` |
| `framework/EAs/QM5_21527_wti-fallcorr-tr/sets/QM5_21527_wti-fallcorr-tr_XTIUSD.DWX_D1_backtest.set` | `strategy_corr_tolerance`: `1.0e-12` -> `0.000000000001`; `strategy_variance_epsilon`: `1.0e-16` -> `0.0000000000000001` | `bcc09d4c531940a918a96facd6cb4cb5b4796b6cfa68401dd7fada2900d6d041` |

## Q02 append-only requalification

`farmctl enqueue-backtest` was extended narrowly so an old terminal economic
verdict (`PASS`, `FAIL`, or `ZERO_TRADES`) may be requalified only when at least
one current execution identity differs (`MQ5`, `EX5`, or setfile SHA-256). The
existing exact symbol, period, expert, evidence, current-EX5 confirmation, risk,
open-row, and current-terminal guards remain in force. The query which detects an
already-current terminal row now compares all three artifact identities.

| EA | Preserved old row | Old verdict | New Q02 row | State at audit | New verdict | Worker |
|---|---|---:|---|---|---|---|
| `QM5_13203` | `495424b7-6438-4279-8096-6ea8607ee392` | `PASS` | `5faefc2b-76c5-4166-9de9-68327b6f49e0` | `pending` | `PENDING` | `-` |
| `QM5_13205` | `d7f3de72-d870-441a-88b1-d18562c0863f` | `FAIL` | `964d164d-b3ec-47ce-ba62-4b407fdc3009` | `pending` | `PENDING` | `-` |
| `QM5_20262` | `ab875180-bc18-48f8-85fe-c32081b2473f` | `ZERO_TRADES` | `b65eb03a-208c-4a90-bd78-3d4a3cc55f4e` | `pending` | `PENDING` | `-` |
| `QM5_20289` | `41d6f237-cc5e-46ec-8048-1722c398a110` | `PASS` | `c1a2de16-6162-45fa-810d-be941a4ce7bd` | `active` | `PENDING` | `T7` |
| `QM5_20290` | `661b4c77-8fed-41ff-92e2-d4851ebcaad0` | `PASS` | `b59227b5-d1fa-4f60-a794-743d51451be1` | `pending` | `PENDING` | `-` |
| `QM5_20295` | `0ed36c55-2a83-49ad-a5f0-71b25700ff18` | `PASS` | `8f769b59-4463-4325-ae6e-5f7a6edb7163` | `pending` | `PENDING` | `-` |
| `QM5_20296` | `36cc9282-c16c-449f-b5a1-455809f8a9d4` | `PASS` | `1ed45d08-e42c-4c33-a0cf-a16a5c3f2e81` | `pending` | `PENDING` | `-` |
| `QM5_20297` | `8a3e73ec-caca-4306-89fb-4941d953a05a` | `PASS` | `a24c1399-0002-4824-b044-e0244893dde4` | `pending` | `PENDING` | `-` |
| `QM5_20298` | `16e088fa-2b19-49d8-b0c2-027e94ddfa50` | `PASS` | `d2a2d3dc-3356-4a9c-b727-dcec2a391894` | `pending` | `PENDING` | `-` |
| `QM5_20299` | `19cae282-9ed8-4791-b439-868b1c51e867` | `PASS` | `23931290-932c-4b94-beeb-16a4ecfb8458` | `pending` | `PENDING` | `-` |
| `QM5_20300` | `42f8f5dd-b01e-493f-ba28-c51e9ff2b9d8` | `PASS` | `3ba83b8a-c0fb-4553-8984-b196e3540f9f` | `pending` | `PENDING` | `-` |
| `QM5_20301` | `391694f4-f6d3-400a-9f3b-9f8f5d700ae0` | `PASS` | `60e065d8-acfb-4ce1-89a3-ec9b0caabe91` | `pending` | `PENDING` | `-` |
| `QM5_20302` | `9666a9ef-f51a-464f-a883-90a89945d45d` | `PASS` | `7a2d303a-4028-4a26-9f04-ce680879379e` | `pending` | `PENDING` | `-` |
| `QM5_21516` | `35a76a18-9b2c-4ac3-9b96-c4096be2a460` | `PASS` | `d8e8a579-0387-4fb2-ac86-887e16802a2b` | `pending` | `PENDING` | `-` |
| `QM5_21527` | `f2e7b05f-6194-4a21-a2cc-2f71a5d52e9a` | `PASS` | `0f308401-bd4d-48d4-bdc3-e270f21c03f5` | `pending` | `PENDING` | `-` |

At the binding audit, every new row matched the current MQ5, EX5, and setfile
SHA-256; all setfiles had `RISK_FIXED > 0` and `RISK_PERCENT = 0`; all were free
of exponent-form values. Fourteen pending rows appeared in the production claim
selector with no active hold or poison-pill quarantine and passed the real Q02
history predicate on T1-T10. The fifteenth, QM5_20289, had already been claimed
by T7. News-calendar preflight was `OK` at 11.05 hours old with the unchanged
336-hour ceiling, and `FACTORY_OFF.flag` was absent.

Eight source setfiles originally carried UTF-8 BOMs. After restoring that byte
policy, five still-pending work-item payloads required an exact setfile binding
refresh. Those five updates were atomic, guarded on `pending`/unclaimed/null
verdict, and recorded as `execution_binding_refreshed` events. No historical row
was edited. Pre-mutation database backup:
`D:/QM/strategy_farm/state/backups/farm_state_before_exponent_requalification_20260817T154128Z.sqlite`
(`c41bfbc8eabc42f38335b8dea208778bea99f29f5d40e52f491bd19c0c903fad`).

## Verification

- 22 scoped `build_check.ps1 -EALabel ... -NormalizeExponentFloats` runs: PASS,
  zero compile errors and zero warnings.
- Post-pass detector: 0 exponent-form values across the 25 target setfiles.
- Numeric equivalence: 32/32 expanded values equal the original numeric value;
  no lossy conversion.
- `framework/scripts/tests/test_setfile_float_serialization.ps1`: PASS, including
  positive, regression, other-type, malformed, underflow, and overflow controls.
- `python -m pytest tools/strategy_farm/tests/test_candidate_repair_enqueue.py -q`:
  39 passed.
- `validate_build_guardrails.py` over all 22 owning MQ5 files: PASS; news stale
  maximum remained 336 hours.
- Focused `git diff --check`: PASS.

## Proposed long-term EA-input guard (not applied)

Do not bulk-edit these 22 EAs in this remediation. In each EA's next normal
maintenance change, add the framework's existing finite/range validation at INIT
for only the affected input names listed in the normalization table. The guard
should reject non-finite values and require the documented positive domain, while
allowing the exact small decimal defaults above. Pair that source change with a
per-EA INIT test that loads the committed setfile and asserts the parsed value
equals the card default. Separately, make the generator/build validation reject
any exponent-form value for an MQL `double` before a setfile becomes queue-bindable.

This proposal is deliberately not applied here: the task repairs serialization
and requalification without changing trading mechanics or input semantics.
