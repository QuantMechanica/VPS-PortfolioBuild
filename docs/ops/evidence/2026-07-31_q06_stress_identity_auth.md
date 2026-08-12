# Q06 stress execution-identity authentication

Date: 2026-07-31  
Router task: `229e96c8-1394-46f5-9765-654480c0e68f`  
Reviewer: Claude  
Disposition: **13/13 STRESS_WIRING_DEFECT; 0 legitimate-insensitivity; 0 RETIRE decisions.** Existing Q06 PASS evidence in this cohort is not a valid rejection-stress result.

## Executive result

The detector's 13 candidates reduce to two concrete mechanisms:

1. **Eight effective-input failures.** The generated Q06 set and tester INI request `qm_stress_reject_probability=0.1000`, but the native MT5 report does not list that input. MT5 therefore ran the compiled EA's default interface without the requested stress dimension. This affects QM5_10571, QM5_1116, QM5_1551, and five QM5_1567 symbols.
2. **Five basket-path failures.** The native report authenticates effective values `0.0000` at Q05 and `0.1000` at Q06, but the compiled basket binaries predate commit `89204d606` (2026-07-25), which first added the rejection draw to `QM_BasketOpenPosition`. The input reached the EA and then terminated at the basket execution path. This affects QM5_13140, QM5_13144, QM5_13146, QM5_13147, and QM5_13151.

No case is plausibly explained by low frequency: each has 66-679 completed trades, and every case has a directly observed wiring defect. No strategy is retired from invalid stress evidence.

## Candidate decisions

| Candidate | Q05 / Q06 work items | Native effective input (Q05 -> Q06) | Pair authentication | Decision and sink |
|---|---|---:|---|---|
| QM5_10571 / XAUUSD.DWX | `700dd8e0-07fa-411e-9fb5-1a8081ee4aa4` / `42cb13b0-11d3-475f-bc5e-a96cfcd2c8f7` | absent -> absent | **AUTHENTICATED**: both native summaries bind the same MQ5 and EX5; distinct set, INI, and report hashes; stable before/after | **STRESS_WIRING_DEFECT** at `QM5_10571_mql5-pchan-stop.mq5:58`: no stress input and no stress argument to framework init. |
| QM5_1116 / EURJPY.DWX | `ae2066ab-d7b1-4760-88a0-1a7ff33b0cfb` / `70f8df8a-4251-4082-8c8a-374c1947250a` | absent -> absent | Partial legacy identity; report/INI/set hashes bound below, old summary lacks MQ5/EX5 block | **STRESS_WIRING_DEFECT** at `QM5_1116_hopwood-asctrend-h1-tf.mq5:301`: same missing input/init argument. |
| QM5_13140 / XTI-XNG ALIQ | `fecdd2a8-4d65-4c3a-b59c-8285545ebbcf` / `c2f718c6-7427-427a-84da-9da08e2918e3` | 0.0000 -> 0.1000 | Partial legacy identity; effective input is native-report authenticated | **STRESS_WIRING_DEFECT**: compiled EX5 predates basket hook `89204d606`; sink was `QM_BasketOpenPosition`, fixed in source at `QM_BasketOrder.mqh:186-260`, binary still needs rebuild. |
| QM5_13144 / XTI-XNG MICRO11 | `0dd5d466-aea8-462f-901e-7fda4211fe30` / `1fcbda55-8565-4718-bb2a-b7dfd7753c3d` | 0.0000 -> 0.1000 | Partial legacy identity | **STRESS_WIRING_DEFECT**, same pre-WP-9 basket binary. |
| QM5_13146 / XTI-XNG VOV | `aecfcae3-21ae-47c3-8688-27a455c3ce73` / `603a318d-cad2-47d5-888b-b767f8536849` | 0.0000 -> 0.1000 | Q06 is fully hash-bound and stable; Q05 is legacy-partial | **STRESS_WIRING_DEFECT**, same pre-WP-9 basket binary. Q06 binds EX5 `6663cc...963fc`, whose build predates the hook. |
| QM5_13147 / XTI-XNG JBETA | `e9fb1153-8d22-441e-8c1b-960cab61a1f7` / `5766463f-f929-46a5-ba8d-3133f7ddd0e8` | 0.0000 -> 0.1000 | Partial legacy identity | **STRESS_WIRING_DEFECT**, same pre-WP-9 basket binary. |
| QM5_13151 / XTI-XNG VBETA | `8991af81-6836-45b3-aa42-4e824c3800a4` / `a61f2775-1ef0-489e-8d63-26d9f7614cfe` | 0.0000 -> 0.1000 | Partial legacy identity | **STRESS_WIRING_DEFECT**, same pre-WP-9 basket binary. |
| QM5_1551 / USDJPY.DWX | `745ea5f3-b45d-4836-933c-eae91266cc94` / `9f4eaf7c-5af1-4075-ac78-48e97e5c4c13` | absent -> absent | Partial legacy identity | **STRESS_WIRING_DEFECT** at `QM5_1551_demark-td-range-projection-h4.mq5:362`: missing input/init argument. |
| QM5_1567 / EURGBP.DWX | `09d9d520-2413-41a3-b46e-701fc2ab06f7` / `04fd4814-f1d9-4db5-a529-1faf300e0896` | absent -> absent | Partial legacy identity | **STRESS_WIRING_DEFECT** in historical binary. Commit `9c5b934cb` added the input and init wiring on 2026-07-25, after this run. Fresh rebuild/rerun required. |
| QM5_1567 / EURUSD.DWX | `e0b94eb4-6ceb-4e41-b52f-4cc0972200e5` / `5299eb44-8e1d-46c8-938c-06d8c1ac5d52` | absent -> absent | Partial legacy identity | **STRESS_WIRING_DEFECT**, same historical binary. |
| QM5_1567 / GBPJPY.DWX | `470b5cb7-32f9-4ff2-98b1-86fc2e73bb1c` / `747b2cb2-debc-4da9-8f19-4d937c732532` | absent -> absent | Partial legacy identity | **STRESS_WIRING_DEFECT**, same historical binary. |
| QM5_1567 / GBPNZD.DWX | `5bf1dfe0-e9f8-4933-996d-d8fa38db0d68` / `c9f74c71-6eed-413c-9bae-116137f7cef0` | absent -> absent | Partial legacy identity | **STRESS_WIRING_DEFECT**, same historical binary. |
| QM5_1567 / USDJPY.DWX | `5b5cc1f0-813c-4123-ba4b-313a8abd585e` / `eeb2da0e-9243-46ff-8c46-8a5ab3bbe5fa` | absent -> absent | Partial legacy identity | **STRESS_WIRING_DEFECT**, same historical binary. |

`AUTHENTICATED` is deliberately strict. Only QM5_10571 has a fully bound Q05/Q06 pair under the then-current `run_smoke/v2` schema. QM5_13146 Q06 is individually bound, but its older Q05 partner is not. The other historical summaries predate `execution_identity`; this audit does not launder current files into historical run identity. Their report, tester INI, and retained generated-set bytes are nevertheless independently hashed below, and the native report directly authenticates whether MT5 recognized the requested input.

## Wiring trace

The common runner chain is:

```text
baseline set
  -> gen_stress_setfile.py appends/sets qm_stress_reject_probability
  -> q06_stress_harsh.py passes generated set to run_smoke.ps1
  -> tester.ini names that exact generated set
  -> native report lists only inputs recognized by the compiled EX5
  -> QM_FrameworkInit(..., qm_rng_seed, qm_stress_reject_probability)
  -> QM_EntryConfigure
  -> standard QM_Entry or basket QM_BasketOpenPosition rejection draw
```

Observed sinks:

- The generator intentionally appends the key even when an old baseline lacks it. For QM5_10571, QM5_1116, QM5_1551, and the historical QM5_1567 binary, that created syntactically correct set bytes but the compiled EX5 had no such input. The native reports omit it, proving the set-to-EA boundary swallowed the value.
- The five energy EAs do expose and pass the input. Their reports show `0.1000`, so set generation and tester uptake worked. Their actual entries use `QM_BasketOpenPosition`; before `89204d606`, that function bypassed the standard `QM_Entry` rejection hook. Their current EX5 timestamps/hashes are still from before that commit, so source-only remediation has not repaired their executable identity.

## Code correction

Commit `6ed4776b2` (`fix: authenticate Q06 stress execution`) makes future evidence fail closed:

- Q06 reads the native report's effective input and returns `INVALID stress_input_not_effective` if `qm_stress_reject_probability=0.1000` is absent or different. A generated set alone can no longer claim successful injection.
- Q05/Q06 aggregates copy the run-smoke MQ5, EX5, set, and native-report SHA-256 values into durable aggregate evidence. Legacy evidence stays explicitly partial rather than inferred.
- The health authenticator now requires the same EA source and binary across paired runs while requiring each generated-set hash to be present. It no longer incorrectly requires Q05 and Q06 generated sets to be byte-identical; their stress values must differ.

Verification:

```text
python -m py_compile framework/scripts/q05_stress_medium.py framework/scripts/q06_stress_harsh.py tools/strategy_farm/health.py
PASS

python -m pytest framework/scripts/tests/test_q05_q07_verdicts.py -q
45 passed

python -m pytest tools/strategy_farm/tests/test_health_vacuousness.py -q
36 passed

git diff --check -- <five changed paths>
PASS
```

No old aggregate, setfile, report, work item, or verdict was edited.

## Hash appendix: retained per-run artifacts

Every hash below was recomputed read-only from the retained path on 2026-07-31. `R` is the canonical native report, `I` the generated tester INI, and `S` the named generated set in the canonical EA directory. For legacy summaries, `S` authenticates the retained bytes but is not promoted to historical deployment identity.

| Candidate / phase | Work item | R (SHA-256) | I (SHA-256) | S (SHA-256) |
|---|---|---|---|---|
| 10571 XAU / Q05 | `700dd8e0-07fa-411e-9fb5-1a8081ee4aa4` | `53062fe55d35cad7dc4b2880aa64c335587fa1613374b6a57944a8b902a681f4` | `e010affc64004a6bc341b11a56d179bf09197afd2868728c3f1b745caf571518` | `94611f6e1fd38ced8984ede2406f2d6b55cbf388d077f6718d6abca7803cfcc3` |
| 10571 XAU / Q06 | `42cb13b0-11d3-475f-bc5e-a96cfcd2c8f7` | `09e470c244ae0af13c024232278c7ab4a0980480bf432017aa5c8705dc631927` | `6acdc16cf78f4fb8289ffcabab5ef404b06fd85db2c9d538e2128063f8dc3188` | `bf3283d859121d5e025dad5e0c6c352ce528d0460aaf9eed571c84d869f1913a` |
| 1116 EURJPY / Q05 | `ae2066ab-d7b1-4760-88a0-1a7ff33b0cfb` | `f3144ad3315cae27833bddf9a205fabc936919696d3b40bd4e352751f90ef62d` | `0e4202f54c47e3f2a801b40a829c4bae5cc2319ca53bfec43998c35f76931f34` | `038f08ba8340153e69c53baf842baeec4dc95900c59531200b047909f8d145e3` |
| 1116 EURJPY / Q06 | `70f8df8a-4251-4082-8c8a-374c1947250a` | `cc180ca0e8692fdfdc1aecd7750813299c5ad221a1a397d9da2927cf630600cc` | `a138584fca311235541ad7c426ca00726c1bb1f1fa6805021dd296e09f8ae993` | `d58fcc94568554557ad4ae90fce6a928c43cf787ff83520a3c23095e5d422a27` |
| 13140 ALIQ / Q05 | `fecdd2a8-4d65-4c3a-b59c-8285545ebbcf` | `da1467b139af07d02c67993ea2000b748a961148b064cc1a8a950a6effb3f242` | `e5a746d831f5eb9464fc1c7799007d67fbb935b7d75e9bf10511e202bff6b50f` | `a18897abcfa31934933f3273ae67518a51410b19b42abfe1d025967a3fc185bd` |
| 13140 ALIQ / Q06 | `c2f718c6-7427-427a-84da-9da08e2918e3` | `7b09c5f642ba0ff77677def41695063d516729efb3c9bd9b2eb2ceeda1c4bc49` | `f0d3d048453ce1946208aeb737097946382d88d8ccecf5d2341963e90e168f84` | `9a57ddd2155d39a9f7f28091df1ba4bf438c1274ab6309030f431706de1c926a` |
| 13144 MICRO11 / Q05 | `0dd5d466-aea8-462f-901e-7fda4211fe30` | `970b36ba2c8321f75c128fbf75a4988a80c4d0ea3c4ffcefec5a9b70d414de7b` | `18e8c334e3ba3e486a988b9b12738e12cc52b885573f95e3004eb0c4ddb68da6` | `52ed8c50052b547524a7ee87b3ce404a4a560b05becbb3bed11fa713ce258a48` |
| 13144 MICRO11 / Q06 | `1fcbda55-8565-4718-bb2a-b7dfd7753c3d` | `a955cc95d9d2bfcc630f765c637b50e79806794faa7aaaeed5e750741088fc12` | `fd35c188b0ba1bf1ca830cdd3a5f8c3e4b26d294fff68f8d6669d9422c8e1499` | `cfe90fffc4bc955b6a438bf56097899561f8682e12fabc352f6b4986464fd5da` |
| 13146 VOV / Q05 | `aecfcae3-21ae-47c3-8688-27a455c3ce73` | `7ccac4eb2dae7c905a2bdda6992dbba9f4c1957355f44626bbb3ffdffe745b75` | `b04662e4a4905dacdeb766b89af6904a16b56d19a3e431522f86bf1420fc86cb` | `d805afdc579ccb5b6806aa13506f877abbbfddfcbcbc709326f4f3e3aa207fbe` |
| 13146 VOV / Q06 | `603a318d-cad2-47d5-888b-b767f8536849` | `2b8466bfc4236310e1f05b5331fa8f042949e18f7d93a88a45fc1cab4ee0cdbc` | `73f6a828a786b12f5d51a23809510ba75e35fa97f8f0e164f4612e08d076bec7` | `aeaaa7623501044ba18fbc99baf16b2e54f364fd9706052cdaf1ed97feb67596` |
| 13147 JBETA / Q05 | `e9fb1153-8d22-441e-8c1b-960cab61a1f7` | `4eae5be04847dc1bf4d799d5763c9fe795b91edcd9b08c4d81b93759fac11c57` | `174c2774cdfe74ccc3e39fb27384791333f3c744e14aa51d90da5f22a8edc0a6` | `f966b79fe471f17dd3096e15e4f6891c6cfd10cc542e8642115248526cd9f040` |
| 13147 JBETA / Q06 | `5766463f-f929-46a5-ba8d-3133f7ddd0e8` | `cc5e545519efe1e60cfbd6e7c4918af6bc33cf981d4af762f2f0ec0bd1c9b9e1` | `ee33de34716e22c560cc2f9156c3200c325a2b4c6d41fab2a31e47543f84fd8f` | `fa990f37703d2726701f305e21d2a04fe6a77e85646ed95ccc564686eaa8ca27` |
| 13151 VBETA / Q05 | `8991af81-6836-45b3-aa42-4e824c3800a4` | `2ebdc7cf55c28be7e0ad74e4d3dbaf01e9b69e01059c676d49677b94db1583d5` | `d13472e0fef38199c23b1238baa9765e84007d0a9f5b4fb529d1571bee5fcea9` | `9c19a7872c90fbea4f63a0690ac5227d074fc1125eb4239b5cc679a476bbf50f` |
| 13151 VBETA / Q06 | `a61f2775-1ef0-489e-8d63-26d9f7614cfe` | `d92c06e9a3cbcbd4f43d1f29ee602cc8fa00afeae10b03d8f5630796c902db21` | `22821c1519166b2ec2cdabcea0707eb7198d75057930c69959eb8c61788ef7d3` | `4b9dd06ba19f123acd93b901f7b43431576bd10f06a3be21defa77926322f0bb` |
| 1551 USDJPY / Q05 | `745ea5f3-b45d-4836-933c-eae91266cc94` | `6a019fa92f1ee720e101967f220116581e2066014c78b39e3822b6fef45d0063` | `80986de53f0dca44f10d8c8eb72996cc8e1027313f84aaefdb5d5eb5869637c0` | `739d59226f8e333e4cc3cdc09c0faa7a9609c3f4664eb95d2321289949d8cd45` |
| 1551 USDJPY / Q06 | `9f4eaf7c-5af1-4075-ac78-48e97e5c4c13` | `0c8904ad506ff277348c52c4cfd9bf499d9dd55ec89a7fd7c19c295d6c8968a4` | `c228bdf84fd7343fe00861465df0ef171d2a4af867172a48440093fe472ada04` | `f4482d4cd4f274a74b2f922f3635661a1f38907a38aae708ad294a9684af7bef` |
| 1567 EURGBP / Q05 | `09d9d520-2413-41a3-b46e-701fc2ab06f7` | `9ae0ba19cf7fb6cbe36b6d84beb175615d7e9a317ee781d6a0d8aa593affa7b4` | `07d5bfeb3fea7d94f30d183ab9e39adfc6f723379521cf7279c536a402acacfd` | `6abb0233ab082d36dce9cfc5326811c56e1e361daec40559969c4fdf3a798951` |
| 1567 EURGBP / Q06 | `04fd4814-f1d9-4db5-a529-1faf300e0896` | `3b78f9889c2fd96df6480464d0bddf277f777dd9bce21b99eb3a6947fb610538` | `b47b48a33bcc0d84ffea13e63d0877802a987d41869ab0a4053b74011a4ce6f5` | `299d6c11b028d5a37645915d843c92aba15a4183e01d0c40f5b16f226596e62a` |
| 1567 EURUSD / Q05 | `e0b94eb4-6ceb-4e41-b52f-4cc0972200e5` | `d7ce45bc9dbee15291df6ef6d1f9ed9b0c752d1694ae4eb9d3e73729ea4c120c` | `d9e8ad3880f3c82bfaeef94f27c132124b72c46acc9e8165393dcffb1c78b745` | `2beab208322c5dfd5019b6f737c8183232338c404b12d8e12dbb6ff75245c371` |
| 1567 EURUSD / Q06 | `5299eb44-8e1d-46c8-938c-06d8c1ac5d52` | `357042254d414d7c95e7af1a97176f5fc20d55b51c4205870e62fb12cef5a5fc` | `ae92fb72b2e6726250043570d8f616d839360338daf540a7f727abe541b9750c` | `dc2db29a2de1d247e24afab34e4bd321ef9a2da32068b9646fffa3d44562c52f` |
| 1567 GBPJPY / Q05 | `470b5cb7-32f9-4ff2-98b1-86fc2e73bb1c` | `ced5010f871972e52a4504e18124b9d97924a110483d4216572f242527057f41` | `c6c3978c5ec88f895c45d26220750bd2d46edadf4aa3d0206071d1500432d465` | `073494d56813954c053a0ff5cad16742005b67369eaea965d93ab2c3f9ca3c4e` |
| 1567 GBPJPY / Q06 | `747b2cb2-debc-4da9-8f19-4d937c732532` | `adae5dd50e343cd327f04843430a54c013c80e0addd6f633e5c6edc348b0f56c` | `8da561bc1d62c5d3ccb418f3aa3ab9e40dda49b0576382241430c885621d96d4` | `365fd8c5250dbc00eae4be8c6c2b115e4bcea1914038df80ca6eb5b739e41681` |
| 1567 GBPNZD / Q05 | `5bf1dfe0-e9f8-4933-996d-d8fa38db0d68` | `6299b339054fab9b9d96b3286401dc8cfceb115538dedc2082992a4c04e9c549` | `04825d9fc9dc53ce8e8d05893cb05af4f2ec19c3735069d56fcb0273ded74993` | `ee9f8aae973106352774c74be0981358fd8c1b3049dfb4c5190b9dde25264659` |
| 1567 GBPNZD / Q06 | `c9f74c71-6eed-413c-9bae-116137f7cef0` | `cafb4beafb2e2ae438bd70e6d1079b5278965243b24c60938f86fc8f14fe0867` | `7b0f032ea7b982854a6755f3f6f80d09e8822b681084721e3e1dbb6c43fe955e` | `3c5cea0fd12e5c7087764a4d193e601d1113e9f21437238f2f951e79f0d2a2f6` |
| 1567 USDJPY / Q05 | `5b5cc1f0-813c-4123-ba4b-313a8abd585e` | `0843628abb16c1e4b691eff8737d87f7c27c71efac2c88efdb8653a692486f78` | `0f54ad98c767f0f4c160936233f28590059a59e6abd71bf131fb0798a321705c` | `858539ea36edfb4b1dafa388bc76517a56a803ad56ea7193368f73533559323d` |
| 1567 USDJPY / Q06 | `eeb2da0e-9243-46ff-8c46-8a5ab3bbe5fa` | `43a3c4f998e49a8e726d577e0ba73b7d7a8c063f4f40966dde66d08282d1c1fc` | `a6af9a71f3f6c1afa91f6ead048d5a15c53e57ece74fc89cf90cde67e55f49ea` | `f546ede2a1ad555b75ec7e6f7b7d4d4d55f4ad3db5b0f10ab5753b0a8a4ab053` |

## Bound/current source-binary hashes

| EA | MQ5 SHA-256 | EX5 SHA-256 | Interpretation |
|---|---|---|---|
| QM5_10571 | `d701f60c19188476c683a7779a75af83b68bf902f134f77083e10fbc12c9c815` | `98652850ed2b4316e81acd1a8b3166335f2786108840bd8f0a9553044f75d642` | Native-bound in both runs; current bytes still match; stress input absent. |
| QM5_1116 | `1eddb281e9093ab25ce5eb587b35867fdc29f5803dd6408b7e2c91ab9f9666a6` | `808f49c041d331ac798bcdf6e12790bfa4f9f3e57c136892248d6f38c02bbcdb` | Current/versioned only, not promoted into legacy run identity; source still lacks input. |
| QM5_13140 | `aae0e65eff3eaf72eacf1cd2d3be41cec38426ad725e95eadb653b13fff60de3` | `304278efee71b059272899365b70a63c1b2c22f1d7a748a19f69fe17197d09aa` | Current EX5 predates basket hook. |
| QM5_13144 | `37daa9c3945d480938888bbb4dbd4064798bf2d4edf45262b01f5e9186feb6b6` | `58d478b81c369220cce5504cbd7fc9f94eb21347a82f3572c7518b5285d207dc` | Current EX5 predates basket hook. |
| QM5_13146 | `24c51ac8e34ae1e5e287ec5dec0e273f2b6b4631e4824f39986c2decb4163556` | `6663cc326e2c53f06a3c3daac96133e6a62e914514c104dec44eefaabac963fc` | Native-bound/stable in Q06; EX5 predates basket hook. |
| QM5_13147 | `9be47992127c375e63a60cbce842a967aa0b14404067e83a64c9fa42308b4192` | `80b8aca54026535d6537352a3e804d4c211f8b7844bb8249b1964ec7a54ddedb` | Current EX5 predates basket hook. |
| QM5_13151 | `036b90f22016941f3c3e87c85ca261ce93ecaba4f6fed4ca249dac3463acfc16` | `5cda2a9b904e34e0503bc5335e9c7d76ab1c31bad998ddcdada99a38d38f33d5` | Current EX5 predates basket hook. |
| QM5_1551 | `036709249e2e978c3f23bc4ee2bac0af9d82c4045ec6dd5dc24648b12b89a349` | `42686ea7ade200e5c13c53cea3943cf639798d37a2b2bec642321a897e3a510a` | Current/versioned only; source still lacks input. |
| QM5_1567 | `685af902fd614945f15df604810f52b561d6dd3c0d155166b09dde9126da0f27` | `874862269c04efbcc639c98a54fb069a8a5194c85c03bf37f72dddf2e3884e94` | Current post-fix identity, **not** the July 18-19 run identity. Existing Q06 evidence remains invalid pending fresh run. |

## Required follow-up (not executed here)

1. Add the standard `qm_rng_seed` / `qm_stress_reject_probability` input and framework-init wiring to QM5_10571, QM5_1116, and QM5_1551; compile through the framework path and re-run Q05/Q06 under separately routed work.
2. Recompile the five energy basket EAs against the post-`89204d606` framework, then re-run Q05/Q06. Merely regenerating setfiles cannot repair their EX5 identity.
3. Re-run the already source-fixed QM5_1567 cohort on its post-`9c5b934cb` binary.
4. Reviewer may then invalidate/supersede the old Q06 PASS rows through a separately authorized mutation. This audit made no database or evidence mutation.

No terminal was launched, no queue item was created, and no T_Live or AutoTrading state was touched.
