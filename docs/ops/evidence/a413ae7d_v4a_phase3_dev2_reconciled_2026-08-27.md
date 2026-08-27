# V4a Phase 3 — governed sequential tester validation

**Verdict:** `BACKEND_EXECUTION_STOP`
**Execution:** `0/20` cells launched, `0/20` compared, `0` exact.
**Feature flag:** `QM_ENABLE_WARM_CELL_RUNNER` was process-scoped for this validation; production wiring remains absent and Default-OFF.

The backend uses the governed DEV2 Scheduled-Task controller and restarts the tester sequentially in one isolated lane. It does not claim unsupported resident MT5 IPC. Every completed cell is authenticated through the unchanged `run_smoke/v2` receipt and includes native report bytes, logger-sample bytes, canonical trade rows, and entry-trading-day evidence.

## Acceptance result

| Criterion | Result |
|---|---|
| Backend + tests | BLOCKED — governed DEV2 restart backend, Default-OFF authorization, byte guards, and containment closeout |
| 20-cell parity | DEVIATION/STOP — 0/20 exact; full hashes are in the table, CSV, and JSON packet |
| Speedup | cold=6741.611 s; attempted like-for-like=None; complete batch=None; target >=2.5x=NOT MET |
| Cold path / DL-089 | PASS — governed cold-path files byte-identical to Phase-3 start |
| Frozen history | PASS_COMMON_BYTE_INVENTORY — 20 claim receipts, 108 byte-identical files |

## Stop detail

`ActivationRefused: DEV2_CONTROLLER_FAILED_CELL_01_EXIT_1`

## Timing

| Path | Cells | Total s | Mean s | Median s | Min s | Max s | Speedup |
|---|---:|---:|---:|---:|---:|---:|---:|
| Cold authenticated receipts | 20 | 6741.611 | 337.081 | 291.088 | 238.565 | 596.262 | baseline |
| Governed DEV2 cell walls | 0 | None | None | None | None | None | None |

## Parity table

| # | Arm | Set SHA-256 | Cold/Warm metrics | Cold/Warm trades | Cold/Warm report | Cold/Warm logger | Days | Exact |
|---:|---|---|---|---|---|---|---|---|
| 1 | baseline | `efb30cbb4d99938c44a4d62012e7ae136712fffbea3dcda7abf5890d9c2350e9` | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` / `NOT_RUN` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` / `NOT_RUN` | `2a6cc66d37c41d398cdecf726632aeabf8f7fe547d148c47956de9db5c9899bf` / `NOT_RUN` | `20011036f5c2ed0732845939f9188b52f759642bc16375a2c2767010334da16b` / `NOT_RUN` | 193/NOT_RUN | None |
| 2 | buy_003 | `245138245344231b1159baa069646fef7a14d3911f80df666c046b700f7ce1ad` | `c939eac37d0c409bcc2d05396c58f4ba7a54541db5786a0c6014f5f58b6ad9d8` / `NOT_RUN` | `69befe7a507a3943d2a75924248a4530cec5076f3e2a4253e9ca93637af17080` / `NOT_RUN` | `144e32b94d8210f0fea91d05a83897843e10204f34396526d353705720a81ff1` / `NOT_RUN` | `e8452640fad88286d15267bca3f8ec4a6e80e6b16f0b1a0c8f0d90781bf09de9` / `NOT_RUN` | 183/NOT_RUN | None |
| 3 | buy_004 | `0793b52f66f941cdfd65512f2ee723f503d3c535ee4b9278cb2e204fd13a4783` | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` / `NOT_RUN` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` / `NOT_RUN` | `266dfbf06404db1a6da2fec2aefae10752283e986d064427986ee7127066b5ff` / `NOT_RUN` | `2c7ca47b6ba9fb5cfcaad41e88c4ee42497226f0b1419a0404f16986dd1dcfa6` / `NOT_RUN` | 193/NOT_RUN | None |
| 4 | buy_005 | `3c87e821bf80b69622d42c93f0eb88b0c6a674f428e961c0cefd87f77e4cf39d` | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` / `NOT_RUN` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` / `NOT_RUN` | `484d131f9969700a65c6346f33e243f3b5e6468122594209bc9ed4dbca8c418b` / `NOT_RUN` | `44f022a7abff1a22223274e7afaab75c31ec3b7ed1655ce1f26820861a07ed2d` / `NOT_RUN` | 193/NOT_RUN | None |
| 5 | buy_006 | `5950dbb9e0dd87c3c731b61013a56111f4cebf7d88d8caf155473a34f5645561` | `c5d05a555f5affede5905015bda167a8e2faf7cf7adc09143e0b4aa9e903103d` / `NOT_RUN` | `db78ccde49fb8caac3ebd6d1188c1984809c2d8e26febbedff1d04c2d7dcc8b8` / `NOT_RUN` | `d4614715a2e497203703b173b4f18bf82a657f32724d4fe2092a3e719aae9983` / `NOT_RUN` | `a746e0879cde1fe6af62ac8dae10508aa0a635d7f157505d5d720c2033fd809b` / `NOT_RUN` | 190/NOT_RUN | None |
| 6 | buy_008 | `5dc40032c44482b37b35ae49ca531e71f177b350be5a2309f85320687e48987e` | `950d222ef2fa8a90a44b689fff73730e25519fae78679e0b3d30b68043d195b9` / `NOT_RUN` | `435c5436f6c3d24046c3ac1e6830f9f7e9e942e28f6eda11001613235d2588e6` / `NOT_RUN` | `23bf334275eb5a1d1ad187bb2b7bc7cb1bc987683a86db8833e0f7dc0cb3f15d` / `NOT_RUN` | `709a966e9070b0c1cd4912ef63e874f18281dd4294a0ce8a6b68dcbd062300ea` / `NOT_RUN` | 192/NOT_RUN | None |
| 7 | buy_009 | `9012025e2b8db81c6ddac702925c2d6d055fb4dbb4e2b9414829c67b402b72f5` | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` / `NOT_RUN` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` / `NOT_RUN` | `3c0b64a6487e30a46281074c893775ce311b5b70cd8bc1785e7d3c1996508e8f` / `NOT_RUN` | `397ba9317730855db06d467187df7eabffecb77c1bf6669643cfad2622999f79` / `NOT_RUN` | 193/NOT_RUN | None |
| 8 | buy_011 | `952840be62875652a73128e3661cdc580f9cef44fb099d43be8aa2009bc18206` | `a38adb929b3335128837a2b99ecb0cee80abeac236556b2bc6f0082f5b3da7a2` / `NOT_RUN` | `151800be34e02c3d55c2039f3a283ce2b62db9c66cb8806c25c30142334d36d8` / `NOT_RUN` | `0325de65f4ce10a29434b71a255bd541720eb16d48dd8614f027be1fdfc2a8c2` / `NOT_RUN` | `2bd25e1ef44299bc7fcbbe305c2deced35fc0fc7773a1f0c45f3c148de2f45ad` / `NOT_RUN` | 192/NOT_RUN | None |
| 9 | buy_012 | `4055e3ea3299523f64eedab31c049a70b5d88ec0004b972dcf2ab619e923f324` | `44720c613e29b790de66cad5b9940c66a310a4fd6259f8f22d49e97b7a1638be` / `NOT_RUN` | `df8d8086ab7b35b0c089ab9d7b59e58d60ec75de07f4d7334e4afe3602a0f554` / `NOT_RUN` | `75fa9f33fcf7b8a47e0cbbc826d0407650d2a50c938d0b6ce5f441cc89bb0fbf` / `NOT_RUN` | `8cee697a3363d61a82b9c6e94f47c3e21d3eb759f9b8881d5c1efba77cd47ece` / `NOT_RUN` | 181/NOT_RUN | None |
| 10 | buy_013 | `041953ae417a55262984dbda23b08e73517b8a70cdae504e365cc3ee8670c411` | `c2c0b4c63fb664659ae226b6b6ea60bc18e69a35bb5b84f51158547989286063` / `NOT_RUN` | `166708674db87ac87efca8085cee4dade876257c3f41f91bd6e5251c68bb08f4` / `NOT_RUN` | `e824cd2f256569e63ad337b2b98b5076cbad40e981f4aaa0759916dba33ab58f` / `NOT_RUN` | `dcbfee5551714fb8a51ab673582510153e66346186e30f4f3b3c2c639eb4e237` / `NOT_RUN` | 185/NOT_RUN | None |
| 11 | buy_015 | `b47ee59cb248c62bd418d09f6ce26f8646494bada4bdd38d3d68de29d3e8a01e` | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` / `NOT_RUN` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` / `NOT_RUN` | `4e6ee4bb7b332af0edda835aeaf0016f756e633bfde1747a466650850734009a` / `NOT_RUN` | `fe314e645f88d324098181ceb88467931e36d9370f6c3597569837d08fc4fcfa` / `NOT_RUN` | 193/NOT_RUN | None |
| 12 | buy_017 | `780456ae8381643561cd073816554b107f3951ed50a6d95812758ab030c530c6` | `e7436c51311ba53b064069db0f87395e94785ed12100cded4b02337606903a36` / `NOT_RUN` | `5a3d3bfef8a9c2c04af9609934ba3daabb8b79498e49def6a1c3e60f05d8eb5d` / `NOT_RUN` | `7ff492b271cbfef3d535a3832d4d4e143b08996e694142a54cf9c9892879ea62` / `NOT_RUN` | `cf6434e5a71ebfacf0e7ffd3d2efc7519e1ad6da4771ce8cffbdc815dfdfba20` / `NOT_RUN` | 193/NOT_RUN | None |
| 13 | buy_018 | `bbec7c638e57b735a8fdc054e3ca29d412122c18cbfc17b3f09c56cb34f06deb` | `2e308f588d24f1b54bc96a9aefc7b43f4cd9fb788018254a226252666e0cce47` / `NOT_RUN` | `bb3cba89327b6883f32a4f972fbc06b4e17e561d9d16d8311efb1b8393fb0e26` / `NOT_RUN` | `466dfa4e83a1fadeb7254c5867f099af5cedc50f9f0621765b31de497c038038` / `NOT_RUN` | `a349ff9e22c32ab7456127a32e41678ae0806d6ee0b13623115758f76a76f26c` / `NOT_RUN` | 188/NOT_RUN | None |
| 14 | buy_019 | `da9ffc8cb4ecfd17429d37b6a0d45cfa4aeab72f8cb773385431c47a763830ec` | `174682be19ada36eb090bbd14b81fa6afa61b1409afaf295e0446a19fc27be16` / `NOT_RUN` | `c7032dce9c15eb8c780cea805373a4e1c557d45048bbf57a05f37dd492a0e47d` / `NOT_RUN` | `5e7b8ec8245026a90229813279e23335307e95b82b5338be90e085027dfbfa39` / `NOT_RUN` | `8ef44c1cc31999c7a4587c08bf9ec3eb86aaa70c02be0f7acc69e63c4d5c8a61` / `NOT_RUN` | 190/NOT_RUN | None |
| 15 | buy_020 | `a7006d74428646da4ef757274d2622ab3b55f9cf38a9c44c8d9798fe66542018` | `58c401cfaf6521a36198eef74d6344a8dd65794bde7a3e44ec16f697f87340e5` / `NOT_RUN` | `7dd7b691e34dbfb2ee5dd9ff2238113102ccce1468a6a632ddcf3220142e41dd` / `NOT_RUN` | `91d919c0c8c015a9dfe66ef0411274513a714f56b83dc9e32beeaf89a4fb1d29` / `NOT_RUN` | `a17c522d4016c0fcfd7a3ea27b78e268ffe67b0986bcfbb19a4e485c37344c45` / `NOT_RUN` | 192/NOT_RUN | None |
| 16 | buy_021 | `899a4ffa6388332498b873105d36c1766b5c1c9828d610113c1ed18e72276b5e` | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` / `NOT_RUN` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` / `NOT_RUN` | `3eb3791a392988bd847983f88e7ff7201267d6071e6fe62b53b3f0b8a986bac2` / `NOT_RUN` | `6e09ae80cb8337ef02d71d1a15a7cedbc458cd1d97ea38acf41f2f86b1c7ed37` / `NOT_RUN` | 193/NOT_RUN | None |
| 17 | buy_022 | `c0555e8ebb0d8012048ffea4c875d1940deed649fe2585b3f69a931066c0672e` | `ed0b452d372620c5d767fc186b66c61eb8810093dd9da56140e57512e948994a` / `NOT_RUN` | `7d2eaa00eb29aefe3802d9d579d66e35f1c49ddd4dce0d09efa5412cfef19099` / `NOT_RUN` | `0213860b320c3b95f2f21db3d767f7f72cdd807e5f5d247b97ad06d3ac96cd72` / `NOT_RUN` | `54247f3ca482c26ac02d544be6defd2b0e21ec7721de315e567578d64a60783d` / `NOT_RUN` | 189/NOT_RUN | None |
| 18 | buy_024 | `f2062619182f111a83fe54cca52b8bf23ea4389afc56061abfc921b0ac7da2f5` | `ed0d8a78c41b92974e877ea4b98f0623edfbf0ddaa9e1d3b6d20324670c1bd48` / `NOT_RUN` | `b1ef198b0b16a1abccf45e9071c0089b5f1211597197b653294d2395f9634ea4` / `NOT_RUN` | `470e44c71f6f1ee22e1f5267b842bd72b391dd89f75832e01487957af031fea9` / `NOT_RUN` | `89ea9329c56b191e22a747edaab0944f3e9128fb8dae0f9725dbb199aa2bd661` / `NOT_RUN` | 193/NOT_RUN | None |
| 19 | buy_025 | `8a9acfd7b601486b120c535e1a7f23fc24d3cae211693b09ec1fe9481c4020fb` | `3a51e5eb3e3f18f8f357c95f5fa74211a1db462d6279880c178892951805a93e` / `NOT_RUN` | `eff5246ac0c5ecf3a9f79288da30634a2149060f4e46dc3f4d1844ac1724a5c8` / `NOT_RUN` | `65fff5ba236b2df500cdb86898f615a9c4fbc1a75f6053736a560522ad7de588` / `NOT_RUN` | `6146e908511643ae072042106c8d41228a4368de81e4ecaf1022d10a6ae4defd` / `NOT_RUN` | 193/NOT_RUN | None |
| 20 | buy_027 | `137cd526cd50803364dc05830602d1ca6ed01b199786e030b065b21759f5fe76` | `1f9fa1ff16a23f689252f828728a2431fef70ea4e96b9a111f1c84b29cc3420c` / `NOT_RUN` | `37c7f2ec39de93327308d1c1204520cfa4e49fe81b9200155f41cf7790730237` / `NOT_RUN` | `243cd04e7902198cc22906f87c741c3268aa8ec528fbfdefe53c7b8ef0a47494` / `NOT_RUN` | `4d03ca12e498e448f176aadaaba92b8b5427037352b97c28eacdfd6402025f45` / `NOT_RUN` | 189/NOT_RUN | None |

## Activation checklist

| Gate | Status |
|---|---|
| validation-only governed backend implemented and tested | **BLOCKED** |
| 20 oldest authenticated references selected | **PASS** |
| 20/20 field and artifact-byte parity | **BLOCKED** |
| measured >=2.5x complete-batch speedup | **BLOCKED** |
| repeat complete batch deterministically | **BLOCKED** |
| OWNER activation seal binds reviewed backend and parity packet | **BLOCKED** |
| production remains Default-OFF; cold path and DL-089 unchanged | **PASS** |

## Safety record

- T1–T10, T_Live, AutoTrading, production claims, queue rows, pipeline verdicts, and the farm database were not changed.
- DEV2 was entered idle with its isolated account disabled; the governed controller restored it disabled after every cell and the logical-session closeout rechecked zero lane processes.
- `terminal_worker.py`, `run_smoke.ps1`, `opt_census.py`, and `dl089_matrix_service.py` retain their exact Phase-3-start bytes.
- This validation packet is not pipeline evidence and does not authorize activation.
