# V4a Q-validation — governed sequential tester validation

**Verdict:** `DEVIATION_STOP`
**Execution:** `1/20` cells launched, `1/20` compared, `0` exact.
**Feature flag:** `QM_ENABLE_WARM_CELL_RUNNER` was process-scoped for this validation; production wiring remains absent and Default-OFF.

The backend uses the governed DEV2 Scheduled-Task controller and restarts the tester sequentially in one isolated lane. It does not claim unsupported resident MT5 IPC. Every completed cell is authenticated through the unchanged `run_smoke/v2` receipt and includes native report bytes, logger-sample bytes, canonical trade rows, and entry-trading-day evidence.

## Acceptance result

| Criterion | Result |
|---|---|
| Backend + tests | PASS — governed DEV2 restart backend, Default-OFF authorization, byte guards, and containment closeout |
| 20-cell parity | DEVIATION/STOP — 0/20 exact; full hashes are in the table, CSV, and JSON packet |
| Speedup | cold=4885.034 s; attempted like-for-like=0.7579; complete batch=None; target >=2.5x=NOT MET |
| Cold path / DL-089 | PASS — governed cold-path files byte-identical to task start |
| Frozen history | PASS_COMMON_MANIFEST_MULTI_INVENTORY — 20 claim receipts, 108 byte-identical files |

## Stop detail

`warm parity deviation at DL089_QM5_41097_USDJPY_DWX_2019_2025:2019:sell_093: `

The fixed identity and 191-trade count matched, but the economic result did not:
cold net profit / profit factor / drawdown were `-7487.43 / 0.91 / 17160.94`,
while DEV2 produced `-1279.59 / 0.98 / 15725.59`. Trade-row bytes therefore
diverged even though both runs covered the same dates and entry-day count. This
is an honest negative result; it is not evidence for activation or speedup.

## Timing

| Path | Cells | Total s | Mean s | Median s | Min s | Max s | Speedup |
|---|---:|---:|---:|---:|---:|---:|---:|
| Cold authenticated receipts | 20 | 4885.034 | 244.252 | 226.234 | 193.961 | 356.696 | baseline |
| Governed DEV2 cell walls | 1 | 351.703 | 351.703 | 351.703 | 351.703 | 351.703 | 0.7579 |

## Parity table

| # | Arm | Set SHA-256 | Cold/Warm metrics | Cold/Warm trades | Cold/Warm report | Cold/Warm logger | Days | Exact |
|---:|---|---|---|---|---|---|---|---|
| 1 | sell_093 | `a7bcf1080d40372b149bee6c8a7a09374ad6e677b4299c9b8fb6bbf8ed4be800` | `58c8fb1d2b9a863d92715a972ac3bf086e4da89aa326b64544119f586ec47444` / `04fa50ea24f736dc3fda45351c312540d5c3e41b522ec91c535afdde3c953327` | `6a03d541e6a6391951d296643f364bff995e86cebb17f857f5ba7da65a52d671` / `d69adbd9e34bc276471691f0036c9ed228c24d8d38d33c814667b42556b0f2a3` | `96bf870b4008f16944011f38aca3538752dadb3093edda6797e3fa3eb2c11a0f` / `56798d3c8c618d3b2089f2e69723b01911b7d33148c2e8f679792b36cf77d10c` | `63150d4a55f4fc9a57bc8b304b01e706b6f5338e59a5903ba2a80d170b482698` / `9415d5ba98db1eb272a515fd2e4fafa0caa24d497cf8a99a09a074d0bb2bc425` | 191/191 | False |
| 2 | sell_092 | `44bde093e742c58b9a6d083806eeae652c1f3590b998ba56e3716be1e55b5fa3` | `fd9fe3c91a44971ab670bc59abbff88e9092ef9ea8522b1557ab22a8af63e75f` / `NOT_RUN` | `18f1c86186942a213c74f6ddecd63a13189d7de7160cca381643e679a09209bb` / `NOT_RUN` | `a2909802b205ea08f52baeb7626b8a17b642785517333168310a7cffa11002f3` / `NOT_RUN` | `087172eda1268e3fc5e841e0cf3a0169999d74a0624bbacec36df133274c4bd4` / `NOT_RUN` | 191/NOT_RUN | None |
| 3 | sell_091 | `bfc895fe52f164997025367ef740906a257868cc10e0631883eda0809addffef` | `51bb6e301de3284c9e94c0e1eec8d7b7d2efd51feb34bf06406040a83463f6a4` / `NOT_RUN` | `44a97f963e55b3093ef00bcfd57212ec16911a38057c51f7fd89f8e4cea72203` / `NOT_RUN` | `e22e148d3f2a96bfbe7bb2215ab5309457e1d3f6422f531609e2ec5c1d1cd1a8` / `NOT_RUN` | `1bc26bc74e3ac51a72a5ca0d38c7f57fb984fa49a85a3f7ae6f8ce8d1e114eae` / `NOT_RUN` | 187/NOT_RUN | None |
| 4 | sell_090 | `e2099bc0b003a8de40ce2e683b21a62a2edbb5cf35d3b651f845a7d602eaa4e6` | `0e26786c6555db42bb36a28f4182727b87b7318020e1387c4d74464e2556f577` / `NOT_RUN` | `62eb916c0ea661a2623c2990bb6e7992c9581d92d3fe90b8289b085f513691e2` / `NOT_RUN` | `a534e6a5d015ac5812950f4cf01af538ceff78fc26bc10f9b502d3026e679b9b` / `NOT_RUN` | `0f39596b91a8c16983b41ebb8de62290d8ea06c9fc54d0b13f76c771a5f1679c` / `NOT_RUN` | 187/NOT_RUN | None |
| 5 | sell_088 | `c13cb810832ea408e5cff223ba64cfb61a228905afe9ba1f8e6bbe09032b50bf` | `20517b8bbfd1d6fc77bc1b1c9323d1211bab9841c3eff9006f6bd10733a0515d` / `NOT_RUN` | `94b0f36b5671a9e6036712862135abb14e17ca8c76ed2521112e715d7ae96264` / `NOT_RUN` | `56e788846a53715c3ba9302069b5817347fd7105472fa2d2ef31523e3c1a2938` / `NOT_RUN` | `e98a223e35b9c422cac94bbd2c42872f9b0d7f466cc665f688581a322a349044` / `NOT_RUN` | 192/NOT_RUN | None |
| 6 | buy_079 | `f91954aa0274cf9f410516b230315a125787c910db1095c9cc80d77d2dd01e99` | `2eb77a89ac65f3ca0a75098cda9513313f0f8729eb269048c8f8389d4e7c9abb` / `NOT_RUN` | `83397b1a387316d0e376748d7f204a658ffe2d1aa3cedf9870043c9d72686cc2` / `NOT_RUN` | `80d330e7de4b7a0b3d69b44b78035134921d5e8c1a4eeedc4ad771429abcc544` / `NOT_RUN` | `7dc9bdb29c4841e4f1ed19637116c1fa0b55161eaf57c35030fd713b50f2ca5c` / `NOT_RUN` | 29/NOT_RUN | None |
| 7 | sell_087 | `fa730a86fe1cde4effb8a16a557157ad64ee45207f4589444db8d86007ff4d9e` | `ef7706782dd1cd484e735cfd9024cb3dcc9fe5bb9386ca2d5e06f372ea694000` / `NOT_RUN` | `5dac4e1ef2838f4098258ed0c822e34373949dae42d45ba134bcbd97e67a6e11` / `NOT_RUN` | `952a9a7dc8acbdd8e407806a450c68560693054eeb718b8ffe1066871fe89888` / `NOT_RUN` | `c18bf581acf4dc7ce1c27e0bb5d98b24595ed97c54c18dd710e987aa1189e193` / `NOT_RUN` | 182/NOT_RUN | None |
| 8 | buy_078 | `4382e31cdd896d26b093a784c2fff41d9b5382736cb609720fcfbf28a48af7cc` | `cb18ad3e6fd9efd64de92d660cb81eea43c4365fe923e94f1832649aadd3e9cc` / `NOT_RUN` | `c6a042f1df8139887b66340bd386e4b965ac787c944e7d6cf094f469e0488ab4` / `NOT_RUN` | `e9849d0ed37ac879de6789a506be4c6c635202891d6cf6e0bfa614b894825a18` / `NOT_RUN` | `e08c2b7f05b8746e148d7ffa7640f5afae27bda622e83028e103623544d8cb4a` / `NOT_RUN` | 29/NOT_RUN | None |
| 9 | sell_084 | `84798a4835b6db28144f421f8a221419e0755fc57ae02064b5207c91bde7a446` | `df07addf533b5bd119dce29986d5a0bd73c5d53b79a8c83a03588b4af4f84b3e` / `NOT_RUN` | `c2de9c721ce5e6e61bddeaf3435d5490129f91c86abf3448927e8df176cc7cc6` / `NOT_RUN` | `d3d6a6cc88cdab2258c4179848ea497743f6a3fb4e10431c2a01372b7ba2716f` / `NOT_RUN` | `e48ce073af8a522f8ad5ff537f21a4d02b595defcb97f5aad5e7be16c02fb5a1` / `NOT_RUN` | 189/NOT_RUN | None |
| 10 | buy_077 | `62c2b4a78370bdcfa893c43952ccd43178172f2e65a39888bb90a82e7109280d` | `d64ba952c7934338ce18c2b48112776ae07c1226435906a15049cb2d7bcdb461` / `NOT_RUN` | `38901d1194bb9061598a843e3813f1371d03fcde357aed2773386d1977d18dac` / `NOT_RUN` | `9caaa26b8b510a4cb1e076e9511e50b10ae8637f0682c81a1f6d8a65844d0d1b` / `NOT_RUN` | `86bd03c8468b9c59153355bf4ef5e4c6ccc4b28fab906961759dd01cbd061178` / `NOT_RUN` | 34/NOT_RUN | None |
| 11 | buy_060 | `b36c12ffbde9e46043b8c189b25e5869f36fcc1577eb2a07462d76db0aee92bc` | `2259da5261ad5c2b27ec98f53062c58d3840056821c3b055b4ba1bccb02f47df` / `NOT_RUN` | `264feb06c7808958f9776d7aad7d455a0b9ac2811d9cd2300614a31e6cd85e90` / `NOT_RUN` | `d3049cba835ce7c663f7ca84d91789fd68ebb4e583f78e26e3e908f6467e8129` / `NOT_RUN` | `03473b4fdfdb594f4e4984eb0abf9e96c0bfa32f7fb117152334ad64464a5e59` / `NOT_RUN` | 36/NOT_RUN | None |
| 12 | sell_083 | `01602b5ecdb124b71273d529297f0b760fd553da7fea77a2bab5f0b7f1ace200` | `8ffefb616e1cbe4471b5547eb11a2057ccf1d4df2e4f005dda8c9f141286bbac` / `NOT_RUN` | `5141390d824d9b4c9979ddfbadfb728ac5f8af6458947367fb266c368544a766` / `NOT_RUN` | `b16d3739301cb7fb8662482f8ddc9d15e56b0f3b5e48550ac1458506a9236ff0` / `NOT_RUN` | `ef32185d871878e97910880d14d1ab16835e1e5e381f5b55efdac856123c7e32` / `NOT_RUN` | 188/NOT_RUN | None |
| 13 | buy_059 | `5272056f8d3b4da0a6a193c7b8d0c7e253679b965274d28a68d39d51ed5be219` | `7abdd33a05b49de2525f27c9df24ae11b45b8c2d866c08b7452606f8836178d7` / `NOT_RUN` | `2af3a8864a113f8d7981d5dbcd56f94b295520b887a787e47493d262d9b2a90a` / `NOT_RUN` | `f3e2f67496f938ae1693058ad624c03bedabde9aaaffd066b617225a44310c02` / `NOT_RUN` | `4d8734264768a41a0c4eb780c7390c31dd268de8ceb9f36aeb613d7b948df011` / `NOT_RUN` | 34/NOT_RUN | None |
| 14 | buy_058 | `ad581d53ab546bbdf976271c8ca4ae584bf2202562e13c09a802d4da89b19fd1` | `2259da5261ad5c2b27ec98f53062c58d3840056821c3b055b4ba1bccb02f47df` / `NOT_RUN` | `264feb06c7808958f9776d7aad7d455a0b9ac2811d9cd2300614a31e6cd85e90` / `NOT_RUN` | `967f76f57877f00bd849bd4bacdcc662d6d244a6bd0367c7ebda989fb848686e` / `NOT_RUN` | `85c05d30be64ad8580d7f0b9fe82a737971bc913689ba8326d9cf3c2f0af4fca` / `NOT_RUN` | 36/NOT_RUN | None |
| 15 | buy_057 | `3aa1aa2ac699d15beba87e7b98b1b4cb957fd192ccf832f1e46875eb9a5d56a1` | `19a3909a5ebaf38c92780e5e4b4e06a3ba64276b48a53bde0c9fdff2f585446d` / `NOT_RUN` | `b53a2fcf26c51cefc09853c9879393165844be642661259dd9b82781318d951f` / `NOT_RUN` | `3f2363818b3c17638b06604517941470cceb8968ed070a5891c1e51c6e8171ff` / `NOT_RUN` | `37deb734800a7d6e75cf1c9b02bac4fb159d4d2a9ea906551517955b34e5cf57` / `NOT_RUN` | 33/NOT_RUN | None |
| 16 | buy_055 | `b90c2f68d4b717bb8c0e3ee7b6b34ed745d90453717b60afca7546b29ebc983c` | `29f572db0c600e840e45221b28a3e6b8aa7f8c2485edf3e8ce9d7102a0256c07` / `NOT_RUN` | `4a8b599a534cae0354cc1550852d6b444948a9bcababe783304256dcf8341664` / `NOT_RUN` | `9ac1cba57d4a4fdd33dc0dd0adf325305971024d86447c27d231a509c8523625` / `NOT_RUN` | `c0c27cb35dcbb5ed77f64183fc7471972969e78648f00e6e708aa54a4d1e23d0` / `NOT_RUN` | 37/NOT_RUN | None |
| 17 | buy_054 | `dea17b754fd9a80b96e77ddd14bb6117f94b73549ae189868cff7ce1c5fac617` | `bc3eeb06896ad6422dc8f6e8feea122da3b525acb984e20f169e11c785524978` / `NOT_RUN` | `2e8d3238c58117795e7ab59e42e300855608b0557900580859ca734786def566` / `NOT_RUN` | `9d435bb356154cc17f323e8aefcd5c8fe17afbfc8c80cee2ff6fcec49a0033a2` / `NOT_RUN` | `22f79f9fdda4197dd9519f55ef7e02f9dee105ef273193872c4c996cb51b07ee` / `NOT_RUN` | 33/NOT_RUN | None |
| 18 | buy_053 | `645ca23f5c4e9dd27d0150de5318742df8e57ce482ddff7b2b693540de0f221f` | `c70b455581acb78ba80cd64f40886381d295c5cceae5292298122a39b1d33a9b` / `NOT_RUN` | `153d5825a2c764415d5fe3a6658418fcd5e5d29fc08f1a9a5adda9c036eba425` / `NOT_RUN` | `4eb443e0a6b929af8a3d8796e216f32f68b2bbda61271a3eb465262f6d60cd3c` / `NOT_RUN` | `6bc482613d8787307f275bb4317cb4612455720e1d3086abb7df9de1e2f4e829` / `NOT_RUN` | 37/NOT_RUN | None |
| 19 | buy_051 | `4716cc45505c30e3dfd1bd51419e12b277f9810ccaa22cd5fc06461852f3faa4` | `3df55d4ada21d17425b1b94466086f45fa3f5b7e575a5449a834e1bfd891f610` / `NOT_RUN` | `28bb997625fb0f80eadd8a8057946c7a7f5a7dba94187ef9c1809aca1c645ff1` / `NOT_RUN` | `0f9d87b275d36862d903c74f8c657f14615ffa00dc24733f9af5ea38a1b382d0` / `NOT_RUN` | `0934acda7362613b72325e37f70b6c4e5f615c0f645a8402464f513c8f6cce78` / `NOT_RUN` | 34/NOT_RUN | None |
| 20 | buy_050 | `5ca4177b59543d4283fc25a7e41ab3b3068173730260d4a2025c7fbcd1f71bcc` | `20f454a1a66a84b402844256397aaddb8b29cf402c8811d2a1731240aad18bdc` / `NOT_RUN` | `1dc2f4b1536fd8dac8d45c9f1640cf6dd5aeb4cdc1e283c82b5db3edc301f9f7` / `NOT_RUN` | `9f6b9ad58dd0b3010907b8fd3a2de931480df54869b50f95a7f9909eb340ddbd` / `NOT_RUN` | `0f370f9e1b3627b3d24b5b0792e41bbc8b4d821bac2936e6b8d3c847371b8f3f` / `NOT_RUN` | 37/NOT_RUN | None |

## Activation checklist

| Gate | Status |
|---|---|
| validation-only governed backend implemented and tested | **PASS** |
| 20 oldest authenticated references selected | **PASS** |
| 20/20 field and artifact-byte parity | **BLOCKED** |
| measured >=2.5x complete-batch speedup | **BLOCKED** |
| repeat complete batch deterministically | **BLOCKED** |
| OWNER activation seal binds reviewed backend and parity packet | **BLOCKED** |
| production remains Default-OFF; cold path and DL-089 unchanged | **PASS** |

## Safety record

- T1–T10, T_Live, AutoTrading, production claims, queue rows, pipeline verdicts, and the farm database were not changed.
- DEV2 was entered idle with its isolated account disabled; the governed controller restored it disabled after every cell and the logical-session closeout rechecked zero lane processes.
- `terminal_worker.py`, `run_smoke.ps1`, `opt_census.py`, and `dl089_matrix_service.py` retain their exact task-start bytes.
- This validation packet is not pipeline evidence and does not authorize activation.
