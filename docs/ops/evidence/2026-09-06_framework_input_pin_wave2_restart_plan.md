# Framework-input pin wave 2 — append-only restart plan

Date: 2026-09-06  
Router task: `ce03756f-7fad-4bd4-aa57-561551851604`  
Mode: REVIEW list only; no compile enqueue, Q-phase enqueue, or worker reload was performed.

## Restart contract

After each repaired EA receives `COMPILE_OK`, recreate every distinct terminal `(EA, symbol, phase)` identity below without mutating its predecessor. Q02 uses the governed `seed-fresh-q02` / append-only rerun path; Q03 and later phases use their governed append-only rerun paths. Preserve every historical verdict and receipt.

Rows are the read-only terminal Q02+ snapshot from `D:/QM/strategy_farm/state/farm_state.sqlite` at preparation time, grouped by active EA identity. Repeated attempts for the same tuple are collapsed but their terminal work-item IDs and verdicts remain listed.

## Per-EA terminal rows

| EA | Symbol | Phase | Restart path | Terminal predecessor rows |
|---|---|---|---|---|
| `QM5_20202_xauxag-rev18` | `QM5_20202_XAU_XAG_REV18_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `8d9c08b0-3fac-40f5-ac42-0cd7df5fcb17` (done/INFRA_FAIL); `d336ef86-60e2-48fd-a049-78242dcd896e` (done/INFRA_FAIL); `cb096318-c645-42c7-bab2-b94e1b0b2f05` (done/INFRA_FAIL); `f135dea0-3d54-42f0-a047-ac6adb46fa3a` (failed/INFRA_FAIL); `a070ff3f-aec1-4d32-b2c4-3444a42a4d54` (done/PASS) |
| `QM5_20202_xauxag-rev18` | `QM5_20202_XAU_XAG_REV18_D1` | `Q04` | governed append-only rerun | `3e5dffdf-0858-4c47-8372-adec09c5ef9c` (done/FAIL) |
| `QM5_20226_wti-seas-dow` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `f92e06a9-833a-42a7-941c-c3dcfb14c7f3` (done/ZERO_TRADES) |
| `QM5_20233_xauxag-skew-rank` | `QM5_20233_XAU_XAG_SKEW_RANK_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `51eb0d13-b80f-4bb1-a07d-1765c4c228d1` (done/INFRA_FAIL); `681cb88b-3c7e-46b5-9043-e162426d719f` (done/INFRA_FAIL); `d71492e4-c67a-4987-b217-bd264c203bf8` (done/INFRA_FAIL); `4fcabccf-32dd-47c0-b119-d789f66bc45b` (failed/INFRA_FAIL); `19368dc7-7711-422a-a342-ba6837f16c48` (done/INFRA_FAIL); `9a9c4c32-ef7f-49e8-b75d-a0836a126972` (failed/INFRA_FAIL); `9964e9b9-a516-4cd0-94a3-2ef1f1a78964` (done/INFRA_FAIL); `81b1d545-6229-4aa7-80aa-25008eacd9aa` (done/INFRA_FAIL); `1a9563cf-0afc-46af-abff-8d451c8b81dc` (done/INFRA_FAIL); `0736cba3-708e-48e0-a5c4-09c676d7bc2f` (done/INFRA_FAIL); `20b3934e-4dd5-4e64-b44b-771abd228f2a` (done/INFRA_FAIL); `92235bb9-1fc0-4aeb-90c3-f8771ca9e2bd` (done/INFRA_FAIL); `46374352-ee77-4c40-a032-e3cd6e59b00a` (done/PASS) |
| `QM5_20233_xauxag-skew-rank` | `QM5_20233_XAU_XAG_SKEW_RANK_D1` | `Q03` | governed append-only rerun | `f9ccf272-d66e-4a68-b332-76133baab427` (failed/INVALID) |
| `QM5_20233_xauxag-skew-rank` | `QM5_20233_XAU_XAG_SKEW_RANK_D1` | `Q04` | governed append-only rerun | `b4dee137-9a46-472d-a7c7-4695e8f6fdd6` (done/PASS_SOFT) |
| `QM5_20233_xauxag-skew-rank` | `QM5_20233_XAU_XAG_SKEW_RANK_D1` | `Q05` | governed append-only rerun | `26d3aa65-28f7-456d-a94c-32685eace2e3` (done/FAIL); `4e2b0654-cdd1-4ff8-bae4-403baadb7ecf` (done/INFRA_FAIL); `f3a54ce0-6424-4370-b420-02df3f368d70` (done/INFRA_FAIL) |
| `QM5_20234_xauxag-rsj` | `QM5_20234_XAU_XAG_RSJ_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `29a9765e-7fb9-4b06-8740-15e5eab1f32b` (done/INFRA_FAIL); `ed115d61-4339-48b4-9a74-26f7e63aec3d` (done/INFRA_FAIL); `26cfb8db-74c4-451d-91be-4d7fb125b03d` (done/INFRA_FAIL); `881d4691-f092-4510-83f2-017fd0ff65e3` (done/INFRA_FAIL); `4ac6553e-f557-413c-bf19-1587715cfcd2` (done/INFRA_FAIL); `421fdc54-4354-42e6-8461-cc146db9d84b` (failed/INFRA_FAIL); `637ce4d1-46d1-4391-89d4-64dc37f9a9e6` (done/INFRA_FAIL); `9eac7661-d230-4c22-bedd-ba00d95be9bc` (done/INFRA_FAIL); `aa9fe3ae-0dc9-4d4a-849b-9dfcc8953aca` (done/INFRA_FAIL); `908f1e6e-132b-416a-90b8-64f6a5df54c0` (done/INFRA_FAIL); `76d6985b-84f8-4504-b33f-bf150b90549a` (done/PASS) |
| `QM5_20234_xauxag-rsj` | `QM5_20234_XAU_XAG_RSJ_D1` | `Q03` | governed append-only rerun | `8583021d-b8e3-4ed1-b99f-52a0ac9e318e` (failed/INFRA_FAIL) |
| `QM5_20234_xauxag-rsj` | `QM5_20234_XAU_XAG_RSJ_D1` | `Q04` | governed append-only rerun | `1c59aaf8-284a-48d7-84e9-81dd30150403` (done/FAIL) |
| `QM5_20241_wti-seas-anchor` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `cab7979c-a304-45a0-ac0b-39bb46e347d5` (done/FAIL) |
| `QM5_20242_xng-rsm-window` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `5ff045e9-65c5-43ba-87d8-b0bd35125617` (done/FAIL) |
| `QM5_20248_xng-vr-window` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `178a7b59-3bb7-49e7-9c28-36b7841be600` (done/ZERO_TRADES) |
| `QM5_20249_xauxag-vr-spread` | `QM5_20249_XAU_XAG_VRSPREAD_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `c3b593c4-8d79-437a-a9c0-ed73c9ebcd51` (done/ZERO_TRADES) |
| `QM5_20254_xauxag-vr-fade` | `QM5_20254_XAU_XAG_VRFADE_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `3919c4ce-0843-4ad4-9110-b5a0eb278895` (done/ZERO_TRADES) |
| `QM5_20256_wti-vr6-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `8d734be9-bd6e-4626-990a-1a75b3e27fa3` (done/ZERO_TRADES) |
| `QM5_20257_wti-vr12-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `1646d7d1-f248-4d8f-9a42-4db7526eb2cc` (done/ZERO_TRADES) |
| `QM5_20258_wti-mom-vote` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `ff028e35-d4c2-49ad-98c4-e0acc80b55c5` (done/PASS) |
| `QM5_20258_wti-mom-vote` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `c71f6c6d-fcf8-498a-96c7-3ba4ab649b6f` (done/PASS) |
| `QM5_20258_wti-mom-vote` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `661b50c8-253f-4b79-b76d-f2a8e66f5ee0` (done/FAIL) |
| `QM5_20259_xng-mom-vote` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `42c49993-058f-4c6d-95e5-9af556525f92` (done/PASS) |
| `QM5_20259_xng-mom-vote` | `XNGUSD.DWX` | `Q03` | governed append-only rerun | `b316a1ea-3023-4b74-8024-b359e57b42ad` (done/PASS) |
| `QM5_20259_xng-mom-vote` | `XNGUSD.DWX` | `Q04` | governed append-only rerun | `95b18e65-e01e-45db-9cbb-eedd151d7eae` (done/FAIL); `0071e924-5efe-4af1-8d27-cb3b5664192f` (done/FAIL) |
| `QM5_20261_wti-lr-trend` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `1ddcb021-2d49-4829-aca8-ccf2b1b49e3d` (done/FAIL) |
| `QM5_20262_xng-lr-trend` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `ab875180-bc18-48f8-85fe-c32081b2473f` (done/ZERO_TRADES); `b65eb03a-208c-4a90-bd78-3d4a3cc55f4e` (done/FAIL) |
| `QM5_20263_xauxag-mad-rv` | `QM5_20263_XAU_XAG_MADRV_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `d398bebd-b87c-43ed-943d-cb9722585178` (done/PASS) |
| `QM5_20263_xauxag-mad-rv` | `QM5_20263_XAU_XAG_MADRV_D1` | `Q03` | governed append-only rerun | `ebe0edd2-407d-4ad3-917e-b5aa09311006` (done/PASS) |
| `QM5_20264_wti-rank-trend` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `8568f5e8-2860-40cd-be22-48fbf26b1839` (done/PASS) |
| `QM5_20264_wti-rank-trend` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `e5ab8071-1441-470b-9261-b9cbc1ce7318` (done/FAIL) |
| `QM5_20264_wti-rank-trend` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `05a071e6-f950-41b2-b0a9-83e2eabe92c2` (done/PASS_LOWFREQ) |
| `QM5_20264_wti-rank-trend` | `XTIUSD.DWX` | `Q05` | governed append-only rerun | `8a179030-5b28-444b-ae9c-80df5ad8f8ee` (done/PASS) |
| `QM5_20264_wti-rank-trend` | `XTIUSD.DWX` | `Q06` | governed append-only rerun | `d73d488d-8b6c-48b3-a1bc-b098dec373d5` (done/FAIL) |
| `QM5_20265_xauxag-fail-rv` | `QM5_20265_XAU_XAG_FAILRV_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `a0e51f07-b475-432c-9544-317b386c48aa` (done/PASS) |
| `QM5_20267_xng-rank-trend` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `dce7f6b4-782b-4b41-9f1b-21d0a2a6968a` (done/PASS) |
| `QM5_20267_xng-rank-trend` | `XNGUSD.DWX` | `Q03` | governed append-only rerun | `d9446f91-a104-4a7d-8e79-7485c439b8ac` (done/FAIL) |
| `QM5_20267_xng-rank-trend` | `XNGUSD.DWX` | `Q04` | governed append-only rerun | `334459db-b7dd-413e-ba4f-39bfee17a841` (done/FAIL) |
| `QM5_20268_xauxag-qtail-rv` | `QM5_20268_XAU_XAG_QTAILRV_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `2b803c41-5ef5-4cf4-8b20-ce51681287bc` (done/PASS) |
| `QM5_20268_xauxag-qtail-rv` | `QM5_20268_XAU_XAG_QTAILRV_D1` | `Q03` | governed append-only rerun | `5d96f05b-d91b-4d0f-ab34-d0a2d4f66134` (done/PASS) |
| `QM5_20269_wti-medret-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `6e8edd6b-72da-4b37-8a27-15ccdea515b8` (done/PASS) |
| `QM5_20269_wti-medret-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `e665cb28-8592-4934-9180-3c1b7e352d26` (done/FAIL) |
| `QM5_20270_wti-trimmean-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `7922d63b-dbb4-4269-bc4c-6fcaf7a760c1` (done/PASS) |
| `QM5_20270_wti-trimmean-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `b9f6c87a-159b-4787-b01f-7cde74ac6110` (done/FAIL) |
| `QM5_20271_wti-theilsen-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `62f9a076-8d5a-4da4-a246-bd0def468b05` (done/PASS) |
| `QM5_20271_wti-theilsen-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `539034b8-37b3-4d1a-a8e3-bdb8b8abd694` (done/PASS) |
| `QM5_20271_wti-theilsen-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `4ee656e5-d364-4775-8a71-31322d2cf858` (done/PASS_LOWFREQ); `c41d0725-3e9b-453c-b635-c37a659cf3b4` (done/PASS_LOWFREQ) |
| `QM5_20271_wti-theilsen-tr` | `XTIUSD.DWX` | `Q05` | governed append-only rerun | `d2e7bb77-ab42-4d54-9d1a-a6e6d7eef38d` (done/PASS); `ee74623b-334b-412a-87ed-47327ad27380` (done/INFRA_FAIL) |
| `QM5_20271_wti-theilsen-tr` | `XTIUSD.DWX` | `Q06` | governed append-only rerun | `2d4f5f4c-8576-400c-b208-877915d1ffdd` (done/FAIL) |
| `QM5_20272_wti-qtrvote-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `4fe84586-d791-4bbd-84ef-82aa0de5d0f1` (done/PASS) |
| `QM5_20272_wti-qtrvote-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `9c121ac8-727f-4de0-933b-46636e376040` (done/PASS) |
| `QM5_20272_wti-qtrvote-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `01b97f5e-1a62-4490-a89b-887ac34582c8` (done/FAIL); `6f6b1ace-eec0-4aa0-b8ba-ada558ca6665` (done/FAIL) |
| `QM5_20273_wti-signrun-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `6ca3c6e8-97cc-4aed-ac31-551403c10a77` (done/PASS) |
| `QM5_20273_wti-signrun-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `dd897938-1476-4900-9347-baddf3723c0c` (done/PASS) |
| `QM5_20273_wti-signrun-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `c45580ce-bbf0-44f7-baff-4190ce17fed3` (done/FAIL) |
| `QM5_20274_wti-path-eff` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `6586fea1-87ce-4bf4-a570-f49431c50a57` (done/FAIL) |
| `QM5_20275_gsr-runfade` | `QM5_20275_XAU_XAG_RUNFADE_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `2384e96c-5240-4c0c-8829-c2fab47702b3` (done/PASS) |
| `QM5_20275_gsr-runfade` | `QM5_20275_XAU_XAG_RUNFADE_D1` | `Q04` | governed append-only rerun | `b379c778-4eee-4398-868f-ea6e272cbced` (done/FAIL) |
| `QM5_20276_wti-hl-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `dd8c4995-ea1d-4b8b-baa2-1cfbfb063b83` (failed/INFRA_FAIL); `fafd0ea0-a906-4446-b720-09824a55be5f` (done/PASS) |
| `QM5_20276_wti-hl-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `c08a88eb-187a-4764-8a98-7f950019f38c` (done/PASS_LOWFREQ) |
| `QM5_20276_wti-hl-mom` | `XTIUSD.DWX` | `Q05` | governed append-only rerun | `4c45859e-40a2-4609-af65-f4536fb3bd67` (done/FAIL) |
| `QM5_20277_wti-winsor-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `003f3288-7778-4941-b660-3e7e4119da9a` (done/PASS) |
| `QM5_20277_wti-winsor-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `4b575a03-6a82-45df-9bd9-863bce2bc571` (done/FAIL) |
| `QM5_20278_wti-linw-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `50b53e15-f54e-407d-89ee-76dfc758f762` (done/PASS) |
| `QM5_20278_wti-linw-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `badf74ec-c2e6-4ed0-84b1-d7bbbc7465cb` (done/PASS) |
| `QM5_20278_wti-linw-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `9c7b8b74-f2b4-4d45-8229-27e991150bfc` (done/FAIL); `1138d267-be15-4e49-9799-e1580fa8be6c` (done/FAIL) |
| `QM5_20279_wti-expw-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `32cbb0ce-42eb-498a-b8da-2a0115c78494` (done/PASS) |
| `QM5_20279_wti-expw-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `cac6acf4-5865-4785-92f3-e228b5dfb2b4` (done/PASS) |
| `QM5_20279_wti-expw-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `64bcfcdf-8afc-469d-ac70-0003b6b95492` (done/FAIL); `04e0fb68-9aa8-4ddb-a816-e30ab4defd66` (done/FAIL) |
| `QM5_20280_wti-tsmom4m` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `2569300a-1424-44c9-b52d-9ae1f96e0a1b` (done/PASS) |
| `QM5_20280_wti-tsmom4m` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `ab23177b-ccb6-45b8-98fc-f05a2731371d` (done/PASS) |
| `QM5_20280_wti-tsmom4m` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `a985bffb-395a-4065-82c6-27626cd372cd` (done/FAIL); `9e4784e4-7540-4200-a81a-d998bba0a2ff` (done/FAIL) |
| `QM5_20281_wti-tsmom-h2` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `fab14b85-52c0-4fb1-96d9-10b6c8fb9628` (done/PASS) |
| `QM5_20281_wti-tsmom-h2` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `b687ee5f-f5ee-4b3b-af8f-4b31bddb4a2b` (done/PASS) |
| `QM5_20281_wti-tsmom-h2` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `ab38cd15-d04e-4cdf-8371-5aa307779b8b` (done/PASS_LOWFREQ); `da1a6aa8-b3a1-4638-aa77-7e9dc4e6409c` (done/PASS_LOWFREQ) |
| `QM5_20281_wti-tsmom-h2` | `XTIUSD.DWX` | `Q05` | governed append-only rerun | `f0bc3285-8a0e-4267-a303-1a0594e65c80` (done/FAIL) |
| `QM5_20282_wti-madcap-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `0bf7e357-2686-4e5b-98f5-0eb8c65cf31e` (done/PASS) |
| `QM5_20282_wti-madcap-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `272ed303-e51f-4123-b104-68543c95e20c` (done/PASS_LOWFREQ) |
| `QM5_20282_wti-madcap-mom` | `XTIUSD.DWX` | `Q05` | governed append-only rerun | `0fa22100-fd3d-4805-acef-95cd0e4743ee` (done/FAIL) |
| `QM5_20283_wti-trimean-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `2db5b53c-82d0-4856-a2b8-83f99307bce9` (done/PASS) |
| `QM5_20283_wti-trimean-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `7d228aca-e5e1-4141-9ee9-341256ff79e7` (done/FAIL) |
| `QM5_20284_wti-skip1-trend` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `d433c822-a34a-48b5-9678-385f65558ff4` (done/PASS) |
| `QM5_20284_wti-skip1-trend` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `3a95478e-274f-436b-8d89-e945ddab9153` (done/FAIL) |
| `QM5_20285_wti-huber-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `3e3d87c9-3d4e-4188-8ae6-4840a5259a11` (done/PASS) |
| `QM5_20285_wti-huber-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `f61693a9-13f9-4558-9ad7-a1cf97ea7c6c` (done/FAIL) |
| `QM5_20286_wti-bisquare-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `db894631-d726-4ff2-98c3-ef8ab043d0ff` (done/PASS) |
| `QM5_20286_wti-bisquare-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `bb0f3194-df94-4cb8-ae57-afe007d8f7f1` (done/FAIL) |
| `QM5_20287_wti-blockmed-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `1e04556a-44ce-4eca-8c19-d8e9d3f9c7ee` (done/PASS) |
| `QM5_20287_wti-blockmed-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `1ab356e7-9b9d-4fa7-863d-66702618af6d` (done/PASS) |
| `QM5_20287_wti-blockmed-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `ec331edf-507c-428d-a6f7-4bc849527142` (done/PASS_LOWFREQ); `43d081fa-6d25-4aca-93d3-83e07516ce92` (done/PASS_LOWFREQ) |
| `QM5_20287_wti-blockmed-mom` | `XTIUSD.DWX` | `Q05` | governed append-only rerun | `759b2f38-0d40-40a3-a787-571dd2dc578b` (done/PASS) |
| `QM5_20287_wti-blockmed-mom` | `XTIUSD.DWX` | `Q06` | governed append-only rerun | `1e6a707c-233c-4a29-9c73-9e8d7d8b030c` (done/FAIL) |
| `QM5_20288_wti-volnorm-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `9714bc6b-d11d-485e-b359-6e6cfa2c2ec5` (done/PASS) |
| `QM5_20288_wti-volnorm-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `49e3ced6-1c7a-42ad-80e5-0c96bfdcb9f0` (done/PASS) |
| `QM5_20288_wti-volnorm-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `a37e6b3f-a8a4-4d6a-8619-d20531194e84` (done/FAIL); `4a845159-9da6-4539-9d92-38c41ed82fa2` (done/FAIL) |
| `QM5_20289_wti-rsj-rev` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `41d6f237-cc5e-46ec-8048-1722c398a110` (done/PASS); `c1a2de16-6162-45fa-810d-be941a4ce7bd` (done/PASS) |
| `QM5_20289_wti-rsj-rev` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `8d937ada-3b92-48d1-8939-a776d28f6dfd` (done/PASS) |
| `QM5_20289_wti-rsj-rev` | `XTIUSD.DWX` | `Q05` | governed append-only rerun | `3f577c40-7204-4ac8-bba5-ddcd41d3fa25` (done/FAIL) |
| `QM5_20290_wti-skew-prem` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `661b4c77-8fed-41ff-92e2-d4851ebcaad0` (done/PASS); `b59227b5-d1fa-4f60-a794-743d51451be1` (done/PASS) |
| `QM5_20290_wti-skew-prem` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `35048caa-bd9c-40d6-b3bb-f632849d3392` (done/PASS) |
| `QM5_20290_wti-skew-prem` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `9c6c9d1f-b1eb-4a10-9ccb-ff6172a29709` (done/FAIL); `a9a08824-f88d-486f-9148-299f56e89db0` (done/FAIL) |
| `QM5_20291_xauxag-kurt-rk` | `QM5_20291_XAU_XAG_HKURT_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `fbe16151-4f78-446d-a61f-a399f1c6659a` (done/INFRA_FAIL); `2d48d9f7-8348-40f6-9a99-abc83e2dd1a7` (failed/INVALID); `a7c3f1dc-9203-4423-830e-7b23e60af18a` (done/INFRA_FAIL) |
| `QM5_20292_fx-carry-unwind` | `QM5_20292_FX_CARRY_UNWIND_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `774accb9-8957-44df-9da8-156134610f74` (done/DRAFT_DEFECT); `e0afb922-fa1f-4b39-ab6f-ec7c6b757d5d` (done/DRAFT_DEFECT); `257d153d-a880-4431-8661-e4d736676ecb` (done/ZERO_TRADES) |
| `QM5_20293_wti-tsmom9m` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `6dc123c3-7d53-4d1d-8a07-1348cda756cd` (done/PASS) |
| `QM5_20293_wti-tsmom9m` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `45d56ea5-01d3-4f07-a7e3-4a342cb741b1` (done/PASS) |
| `QM5_20293_wti-tsmom9m` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `2073c038-9723-4966-97d3-9a85eadff45f` (done/INFRA_FAIL); `095c51fc-5be3-4b6a-bcf9-0bcc6e70193f` (done/PASS_SOFT) |
| `QM5_20293_wti-tsmom9m` | `XTIUSD.DWX` | `Q05` | governed append-only rerun | `7724061f-d939-4c4b-b056-a191c1fa37ea` (done/PASS) |
| `QM5_20293_wti-tsmom9m` | `XTIUSD.DWX` | `Q06` | governed append-only rerun | `1ce53198-5447-4057-ae2b-833349d1f091` (done/FAIL) |
| `QM5_20294_xauxag-max-rk` | `QM5_20294_XAU_XAG_LOWMAX_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `b9bde578-9476-470f-a051-fda0a11116c6` (done/INFRA_FAIL); `be182dfd-bf33-4577-904c-761bf87c4ccc` (done/INFRA_FAIL); `37bc6871-9078-410e-b949-7d504cf74dd5` (done/PASS) |
| `QM5_20294_xauxag-max-rk` | `QM5_20294_XAU_XAG_LOWMAX_D1` | `Q03` | governed append-only rerun | `9437109a-799b-4f29-a501-89e6b4a3809c` (failed/INVALID) |
| `QM5_20294_xauxag-max-rk` | `QM5_20294_XAU_XAG_LOWMAX_D1` | `Q04` | governed append-only rerun | `a34ee5cd-39b0-4655-9b02-1bf8e389f440` (done/PASS_SOFT) |
| `QM5_20294_xauxag-max-rk` | `QM5_20294_XAU_XAG_LOWMAX_D1` | `Q05` | governed append-only rerun | `c56df942-e7aa-4c7d-b855-402de608352f` (done/PASS) |
| `QM5_20294_xauxag-max-rk` | `QM5_20294_XAU_XAG_LOWMAX_D1` | `Q06` | governed append-only rerun | `14a0dbf8-bd2b-4f64-9906-3e0b9b399bab` (done/INFRA_FAIL) |
| `QM5_20295_wti-kurt-prem` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `0ed36c55-2a83-49ad-a5f0-71b25700ff18` (done/PASS); `8f769b59-4463-4325-ae6e-5f7a6edb7163` (done/PASS) |
| `QM5_20295_wti-kurt-prem` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `7be7dd45-3881-4c5c-9e2e-59786fca60a7` (done/PASS) |
| `QM5_20295_wti-kurt-prem` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `e383ed93-69a0-4ff5-80ce-e0c0c016b6dd` (done/FAIL) |
| `QM5_20296_xng-skew-prem` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `36cc9282-c16c-449f-b5a1-455809f8a9d4` (done/PASS); `1ed45d08-e42c-4c33-a0cf-a16a5c3f2e81` (done/PASS) |
| `QM5_20296_xng-skew-prem` | `XNGUSD.DWX` | `Q03` | governed append-only rerun | `7d0ac80f-9d34-4b94-baa9-dde9a1fd1cee` (done/PASS) |
| `QM5_20296_xng-skew-prem` | `XNGUSD.DWX` | `Q04` | governed append-only rerun | `e388fd1e-f8d6-4b79-90de-cbe7042975fa` (done/FAIL) |
| `QM5_20297_xng-kurt-prem` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `8a3e73ec-caca-4306-89fb-4941d953a05a` (done/PASS); `a24c1399-0002-4824-b044-e0244893dde4` (done/PASS) |
| `QM5_20297_xng-kurt-prem` | `XNGUSD.DWX` | `Q03` | governed append-only rerun | `516dac60-34bc-4224-bbbe-ddc7f7eef448` (done/INFRA_FAIL); `22eb9bae-e796-4bc8-bd2f-42b85bb913bf` (done/PASS) |
| `QM5_20297_xng-kurt-prem` | `XNGUSD.DWX` | `Q04` | governed append-only rerun | `bb0f8ddc-d2e0-4aa5-a9f9-a1117357ce6f` (done/FAIL) |
| `QM5_20298_wti-vov-regime` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `16e088fa-2b19-49d8-b0c2-027e94ddfa50` (done/PASS); `d2a2d3dc-3356-4a9c-b727-dcec2a391894` (done/PASS) |
| `QM5_20298_wti-vov-regime` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `51701426-8cff-40eb-9e43-ecb1da69262f` (done/FAIL) |
| `QM5_20299_xng-vov-regime` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `19cae282-9ed8-4791-b439-868b1c51e867` (done/PASS); `23931290-932c-4b94-beeb-16a4ecfb8458` (done/PASS) |
| `QM5_20299_xng-vov-regime` | `XNGUSD.DWX` | `Q03` | governed append-only rerun | `3b597143-37ab-4eb5-888d-4f8d32f1947f` (done/FAIL) |
| `QM5_20299_xng-vov-regime` | `XNGUSD.DWX` | `Q04` | governed append-only rerun | `347a0da8-39cd-405c-bd3f-0c74b562adb6` (done/FAIL) |
| `QM5_20300_wti-max-regime` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `42f8f5dd-b01e-493f-ba28-c51e9ff2b9d8` (done/PASS); `3ba83b8a-c0fb-4553-8984-b196e3540f9f` (done/PASS) |
| `QM5_20300_wti-max-regime` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `ff941851-8f4d-4d8b-aa96-90622908bdca` (done/FAIL) |
| `QM5_20300_wti-max-regime` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `0a96d70a-caf1-494d-9397-285d0c2677ae` (done/FAIL) |
| `QM5_20301_wti-es-regime` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `391694f4-f6d3-400a-9f3b-9f8f5d700ae0` (done/PASS); `60e065d8-acfb-4ce1-89a3-ec9b0caabe91` (done/PASS) |
| `QM5_20301_wti-es-regime` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `bd6edacd-9b99-47a0-bd1e-543d96888c6d` (done/FAIL) |
| `QM5_20302_wti-aliq-regime` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `9666a9ef-f51a-464f-a883-90a89945d45d` (done/PASS); `7a2d303a-4028-4a26-9f04-ce680879379e` (done/PASS) |
| `QM5_20302_wti-aliq-regime` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `bd7e02fa-7e16-4e47-965b-4822703d304e` (done/FAIL) |
| `QM5_20302_wti-aliq-regime` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `13b6a165-95b5-4dcc-9d18-6b8766cebd0c` (done/FAIL) |
| `QM5_20303_wti-volbeta-reg` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `81939741-407c-40dc-b6ad-91baa91c0e92` (done/FAIL) |
| `QM5_20304_wti-jumpbeta-reg` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `4da3518e-2356-425b-a2e3-0dee10ae05a7` (done/FAIL) |
| `QM5_20305_xng-aliq-regime` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `dabe5f1f-fe1b-4fca-9902-3bb9c87f374e` (done/PASS) |
| `QM5_20305_xng-aliq-regime` | `XNGUSD.DWX` | `Q04` | governed append-only rerun | `82ba5eb3-f8b2-44d9-917d-0402079c270c` (done/FAIL) |
| `QM5_20306_xng-jumpbeta-reg` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `266ead87-d0e5-4103-bfa0-881944c68b20` (done/FAIL) |
| `QM5_21516_wti-decoup-trend` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `35a76a18-9b2c-4ac3-9b96-c4096be2a460` (done/PASS); `d8e8a579-0387-4fb2-ac86-887e16802a2b` (done/PASS) |
| `QM5_21516_wti-decoup-trend` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `042f57b3-a033-4a16-851d-f3258354fc35` (done/PASS) |
| `QM5_21516_wti-decoup-trend` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `c21f405a-16b1-4707-9a78-101c3984e3a3` (done/INFRA_FAIL); `a43b6f99-c718-4291-9cb9-b23f321687a5` (done/PASS_LOWFREQ) |
| `QM5_21516_wti-decoup-trend` | `XTIUSD.DWX` | `Q05` | governed append-only rerun | `26b962c1-0fc4-4906-9863-ec64587a05dc` (done/PASS) |
| `QM5_21516_wti-decoup-trend` | `XTIUSD.DWX` | `Q06` | governed append-only rerun | `6602a040-7d7c-425c-99b2-c6ce8aeaa8eb` (done/FAIL) |
| `QM5_21518_wti-brent-cfm` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `baee9255-3daf-4a85-b300-07a4f57ac0cf` (done/INFRA_FAIL); `d938e1c8-50dd-402b-8f90-cf04c8381eee` (done/INFRA_FAIL); `08883210-eca7-4144-9e07-419509aea846` (done/INFRA_FAIL); `dba41b9c-357b-42e6-83cc-7952155208f2` (done/INFRA_FAIL); `9736b404-bae2-4070-b8a0-98618e3873ec` (done/INFRA_FAIL); `3c0d115a-f8d5-4ad7-b662-d24b95aa543d` (done/INFRA_FAIL); `54b465dc-ea33-4953-8802-c5ede04e25d9` (done/RETIRE) |
| `QM5_21522_wti-lowdb-trend` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `fe4d6ae0-b23e-401a-822d-bc8a83a2bdc2` (done/FAIL) |
| `QM5_21523_wti-xau-div-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `6353edf7-625d-412e-b928-51ebe6715e7e` (done/ZERO_TRADES) |
| `QM5_21527_wti-fallcorr-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `4ec8fc49-9460-47a1-a938-619b9d50251a` (failed/INFRA_FAIL); `f2e7b05f-6194-4a21-a2cc-2f71a5d52e9a` (done/PASS); `0f308401-bd4d-48d4-bdc3-e270f21c03f5` (done/PASS) |
| `QM5_21527_wti-fallcorr-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `3ec1b968-d62c-431c-8cc7-a0ec8e1ed663` (done/PASS) |
| `QM5_21527_wti-fallcorr-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `db16e50b-7244-4c8d-9baa-6889b603ef83` (done/FAIL); `766c54cb-c75a-43f7-a4d9-ec3b59d4ef28` (done/FAIL) |
| `QM5_41016_wti-mclose-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `52032468-6d7e-46ac-a46a-310185ddf5cd` (done/ZERO_TRADES) |
| `QM5_41021_wti-mdual-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `d23c5d11-4bd5-409f-9927-ab9683dbee15` (done/ZERO_TRADES) |
| `QM5_41023_wti-mends-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `255bc16d-bce6-4311-b84e-45ffe6b79038` (done/PASS) |
| `QM5_41023_wti-mends-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `04b0eaeb-a4e6-4cf7-ba5f-ca144dc5ae53` (done/PASS) |
| `QM5_41023_wti-mends-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `ae974a41-fd90-4763-8df9-6d24318cb79c` (done/FAIL) |
| `QM5_41024_wti-1wed-mom1` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `4abd0d0a-4b6f-424b-81e9-c54b7722bf62` (done/PASS) |
| `QM5_41024_wti-1wed-mom1` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `9e8962b2-8c03-4a64-a39f-f1676249716c` (done/PASS) |
| `QM5_41024_wti-1wed-mom1` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `de7af29a-90b4-4d33-bd29-98b71f875b1c` (done/FAIL) |
| `QM5_41025_wti-dom-mom1` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `e96b97cd-e777-401d-aed8-af621853fff7` (done/PASS) |
| `QM5_41025_wti-dom-mom1` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `44287d08-c436-4be2-b2a1-db8a41798e62` (done/FAIL) |
| `QM5_41026_wti-1fri-rev1` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `0ad6c59b-3f81-4501-a996-bd1a7c7e01fb` (done/FAIL) |
| `QM5_41027_wti-mopen-rev1` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `0e4a6000-278b-4395-8dec-876681079abc` (done/PASS) |
| `QM5_41027_wti-mopen-rev1` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `a122ed37-ca1e-4b46-aa90-cb6482f771af` (done/FAIL) |
| `QM5_41028_wti-mgap-fade` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `bbc88313-233b-4861-b0a7-1c35f09ec3d1` (done/PASS) |
| `QM5_41028_wti-mgap-fade` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `28504443-4cd4-4aea-a340-fccf4d148119` (done/PASS) |
| `QM5_41028_wti-mgap-fade` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `045b9bdb-dcba-4040-8c10-07db19ecc369` (done/FAIL) |
| `QM5_41034_wti-mflow-agree` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `35c44125-9c2f-4ffa-8b6d-21c4c0408251` (done/PASS) |
| `QM5_41034_wti-mflow-agree` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `35a7995a-10d2-4276-86dc-7ac28aa194bb` (done/FAIL) |
| `QM5_41034_wti-mflow-agree` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `e35687b7-de71-4946-b65f-e7a70e34acb0` (done/FAIL) |
| `QM5_41035_wti-mflow-div` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `6c8f3dd6-7d8c-4400-8c74-7f6cc754db29` (done/FAIL) |
| `QM5_41036_wti-mflow-dom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `ba6d6d6d-4ce6-4979-ab0a-45ddf1fab1bf` (done/FAIL) |
| `QM5_41037_xng-mflow-div` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `4d5ae07d-706a-47b3-ac2c-d0bac1576684` (done/PASS) |
| `QM5_41037_xng-mflow-div` | `XNGUSD.DWX` | `Q04` | governed append-only rerun | `80378d81-65ee-412d-9b8f-ed8ae2d6d6b2` (done/FAIL) |
| `QM5_41056_energy-rev18` | `QM5_41056_ENERGY_REV18_D1` | `Q02` | `seed-fresh-q02` / append-only rerun | `ec96c0af-85cd-4517-83d6-9b5742d93062` (done/PASS) |
| `QM5_41056_energy-rev18` | `QM5_41056_ENERGY_REV18_D1` | `Q03` | governed append-only rerun | `5464349e-0b50-48b7-8f9b-7001ea370027` (done/PASS) |
| `QM5_41056_energy-rev18` | `QM5_41056_ENERGY_REV18_D1` | `Q04` | governed append-only rerun | `641e4771-566d-4a04-992b-5b7085baeac8` (done/PASS_LOWFREQ) |
| `QM5_41056_energy-rev18` | `QM5_41056_ENERGY_REV18_D1` | `Q05` | governed append-only rerun | `1bbd0d58-ad91-4bd1-a693-3388f14bb6c3` (done/PASS) |
| `QM5_41056_energy-rev18` | `QM5_41056_ENERGY_REV18_D1` | `Q06` | governed append-only rerun | `a3309a00-cef5-4c0e-8eb2-78891388f8f6` (done/FAIL) |
| `QM5_41064_wti-mflip-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `e5d1dfa2-a198-4769-9a41-f9c99e7d191a` (done/ZERO_TRADES) |
| `QM5_41065_wti-wflip-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `56b5f192-3de3-445b-a02a-ccf8f8a18981` (done/PASS) |
| `QM5_41065_wti-wflip-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `d924c8b7-fcf1-4dfd-90f2-d5dabe4457b0` (done/PASS) |
| `QM5_41065_wti-wflip-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `1ac25bcc-4f71-4780-91b2-3ce2d61da399` (done/FAIL) |
| `QM5_41067_xng-wflip-mom` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `64ce426a-0897-41cf-8446-c764df5394fb` (done/PASS) |
| `QM5_41067_xng-wflip-mom` | `XNGUSD.DWX` | `Q04` | governed append-only rerun | `99aec9d1-43f6-4f8c-9977-c138f8e2a615` (done/FAIL) |
| `QM5_41068_wti-waccel-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `747954ed-a571-47a7-a56e-b222c949c483` (done/PASS) |
| `QM5_41068_wti-waccel-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `328649b9-cf50-4000-9b9b-04e433751b63` (done/PASS) |
| `QM5_41068_wti-waccel-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `1194d2aa-f849-47be-9896-2872a155f819` (done/FAIL) |
| `QM5_41069_wti-wpull-trend` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `7de96edd-3cb1-48ae-a5fc-98c0ab0145e7` (done/PASS) |
| `QM5_41069_wti-wpull-trend` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `e2229474-982f-4607-9a0b-8b3541cd0b4f` (done/FAIL) |
| `QM5_41070_wti-wdecel-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `c3419789-5a4f-47b6-8788-a4a53b7e188c` (done/PASS) |
| `QM5_41070_wti-wdecel-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `7520d015-c499-422a-803f-bcb4c0eeb29d` (done/PASS) |
| `QM5_41070_wti-wdecel-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `48832f6c-fa7f-4681-a4dc-87bcd1a77282` (done/FAIL) |
| `QM5_41071_wti-wresume-dom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `1ccf5654-4082-4c63-b2b5-ad9d262b2888` (done/PASS) |
| `QM5_41071_wti-wresume-dom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `10ee40e0-3351-4f6d-8e76-00e0b9cfc22e` (done/FAIL) |
| `QM5_41072_wti-wcounter-dom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `e66025e3-b4bf-4e7d-aeba-19f9871e7d1d` (done/FAIL) |
| `QM5_41073_wti-woutside-settle` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `fd4efd6e-112d-4c2f-ae1c-8e0af970be48` (done/FAIL) |
| `QM5_41074_wti-wstreak3-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `059206dc-dc65-4bee-aa7c-68f5ce7be3e3` (done/PASS) |
| `QM5_41074_wti-wstreak3-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `2271d46a-9510-4c90-b25e-20a62eaf0083` (done/PASS) |
| `QM5_41074_wti-wstreak3-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `a19b78ef-df10-4a27-a05f-27c4278efbe8` (done/FAIL) |
| `QM5_41080_wti-wclose-location-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `69dd6bb9-5bbf-4182-a5f0-e528abaa9d24` (done/PASS) |
| `QM5_41080_wti-wclose-location-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `e99b6fb9-78a4-4617-bc7e-a895631e77e5` (done/PASS) |
| `QM5_41080_wti-wclose-location-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `744da77e-8e17-45ea-8d5f-ccab815eabda` (done/FAIL) |
| `QM5_41081_xng-wclose-location-mom` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `2b000d1c-cda3-4f6b-9b04-ddd80d718f08` (done/PASS) |
| `QM5_41081_xng-wclose-location-mom` | `XNGUSD.DWX` | `Q04` | governed append-only rerun | `69ee9861-c956-467a-84a8-e7097317a169` (done/FAIL) |
| `QM5_41082_wti-wrunbreak-dom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `b5864e8a-30fd-47c8-9873-6a82a4369aec` (done/FAIL) |
| `QM5_41084_wti-wdaybreadth-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `5b3f8e9f-45e0-426f-a2d4-dfcfc1677bd0` (done/PASS) |
| `QM5_41084_wti-wdaybreadth-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `e34c3058-bdbb-47fc-bbd3-57c55368ec8c` (done/PASS) |
| `QM5_41084_wti-wdaybreadth-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `d1dedf69-6c63-4d4b-8aef-a85b470223d7` (done/FAIL) |
| `QM5_41087_wti-wr4-close-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `e928a598-a8f3-4283-820b-4e6461fe0f52` (done/PASS) |
| `QM5_41087_wti-wr4-close-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `66b29234-2722-41a8-866e-3831160e0b64` (done/PASS) |
| `QM5_41087_wti-wr4-close-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `e3f038a4-38ca-4fd2-802a-ac597bdc49ec` (done/FAIL) |
| `QM5_41089_wti-wrange-migrate-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `72eb32ba-a5c5-4415-86fb-b0bb974ed1e0` (done/PASS) |
| `QM5_41089_wti-wrange-migrate-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `e97e55ec-e39f-43d4-b567-d6a701b41112` (done/PASS) |
| `QM5_41089_wti-wrange-migrate-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `7e38cf16-aea9-4d7b-b2f4-1fa963bd5f40` (done/FAIL) |
| `QM5_41090_wti-wmid-overlap-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `62df6178-fd1f-4c38-9eb0-ae8053e50e52` (done/PASS) |
| `QM5_41090_wti-wmid-overlap-mom` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `eb6947e7-b5b6-4558-b0ec-e54d5a9ec9e1` (done/PASS) |
| `QM5_41090_wti-wmid-overlap-mom` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `c3238be3-e8f4-42e5-92f3-ddefd61aaccc` (done/FAIL) |
| `QM5_41091_wti-winside-body-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `1d772581-dfc4-42d1-a04a-710766faed2e` (done/ZERO_TRADES) |
| `QM5_41092_wti-wbody-dominance-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `1c0dcc3a-69cf-46dc-96fb-e8f111c949ac` (done/ZERO_TRADES) |
| `QM5_41093_wti-wclose-breakout-mom` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `be766bd9-7310-45bc-8cbc-c2fdbe90b00b` (done/ZERO_TRADES) |
| `QM5_41094_xng-wbody-dominance-mom` | `XNGUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `898dac1d-db74-474c-a874-8d9c8bf0b11d` (done/ZERO_TRADES) |
| `QM5_41249_wti-mwelch-shift-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `61aa2e78-4f80-49f3-b4a0-437d013e40d7` (done/FAIL) |
| `QM5_41250_wti-mperm-scale-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `fc9d1764-2071-4b1c-9602-ed0302366985` (done/FAIL) |
| `QM5_41251_wti-mbrunner-shift-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `dea73845-8c1a-4395-b940-585581c86aa9` (done/FAIL) |
| `QM5_41253_gbpusd-weekend-tail-fade` | `GBPUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `274bb48e-2444-40c1-aa64-750bb38e2239` (done/FAIL) |
| `QM5_41255_wti-mcvm-shift-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `0408691c-6a64-4d26-a5e1-c8b68a0bc6dd` (done/PASS) |
| `QM5_41255_wti-mcvm-shift-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `f2ab5cb2-ebfd-4859-9a89-9d737f6392ab` (done/FAIL) |
| `QM5_41255_wti-mcvm-shift-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `2c0ee711-93db-4f1a-af9e-7cbe1c8443dc` (done/FAIL) |
| `QM5_41257_wti-mmedscore524-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `3fa2c2f5-4dcb-4421-a668-2c3bbd417bd8` (done/PASS) |
| `QM5_41257_wti-mmedscore524-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `71e69785-9d35-4b25-a187-72ce0dde707d` (done/FAIL) |
| `QM5_41257_wti-mmedscore524-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `9c567c50-fbcb-4435-b9bc-afbbf04a1fca` (done/FAIL) |
| `QM5_41258_wti-menergy-shift-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `968edec1-0842-481b-b223-bb4309c6dc50` (done/PASS) |
| `QM5_41258_wti-menergy-shift-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `5b6a6b3f-e4e6-4bf5-8eea-be9899d10394` (done/FAIL) |
| `QM5_41261_wti-mab-scale-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `bd902ed1-c6ad-4584-9f37-4cca9c4cd805` (done/PASS) |
| `QM5_41261_wti-mab-scale-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `659bbe0b-f28d-4a81-ab2f-5aed9acc76aa` (done/FAIL) |
| `QM5_41261_wti-mab-scale-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `02ff423b-ecc4-4d7e-a7e9-dba1a399133b` (done/FAIL) |
| `QM5_41262_wti-mdaily-meanloc-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `8ddf8854-c563-4d08-a560-a774579dca60` (done/PASS) |
| `QM5_41262_wti-mdaily-meanloc-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `e882772f-9b58-4179-a3ff-d68ffbce9f92` (done/PASS) |
| `QM5_41262_wti-mdaily-meanloc-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `c8b7b932-ae52-40de-8733-183243f5c9a7` (done/FAIL) |
| `QM5_41264_wti-myuen20-shift-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `521db984-5d65-4292-9f6a-15febc46a89a` (done/FAIL) |
| `QM5_41266_wti-mfk-scale-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `2a367105-aaa8-4458-a559-ec0b59eeddd4` (done/FAIL) |
| `QM5_41267_wti-mmood-scale-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `d6ba6cdf-4d4e-4eb4-8c22-5c0474d393df` (done/FAIL) |
| `QM5_41270_wti-mlepage-shift-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `1884c158-1783-497d-bb3b-708fc36a50d7` (done/PASS) |
| `QM5_41270_wti-mlepage-shift-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `23ca1541-80a9-4e0e-9db9-0ab865618f20` (done/FAIL) |
| `QM5_41270_wti-mlepage-shift-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `a6527b37-ca8d-4553-8432-ab408ae079f0` (done/FAIL) |
| `QM5_41271_wti-msiegel-tukey-scale-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `7c2e0cec-5209-4109-9b86-a39b9bdd39fe` (done/FAIL) |
| `QM5_41274_wti-m3block-rank-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `7ecad3f3-c079-4810-967f-46cc101e88a7` (done/PASS) |
| `QM5_41274_wti-m3block-rank-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `4d1ad49b-3c5f-40c7-bc37-50ef617445c8` (done/PASS) |
| `QM5_41274_wti-m3block-rank-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `61100283-2127-40ba-afe2-a08abf1289d2` (done/PASS_LOWFREQ) |
| `QM5_41274_wti-m3block-rank-tr` | `XTIUSD.DWX` | `Q05` | governed append-only rerun | `a9ea19d1-51aa-4484-8861-fe5ecea32f17` (done/PASS) |
| `QM5_41274_wti-m3block-rank-tr` | `XTIUSD.DWX` | `Q06` | governed append-only rerun | `3d494f52-1791-48e1-b5be-c961aebe8474` (done/INFRA_FAIL) |
| `QM5_41275_wti-mqndisp-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `9cc24276-b079-4abc-8813-1ee3a2f8b5d6` (done/PASS) |
| `QM5_41275_wti-mqndisp-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `36aa6aac-b769-49e8-8283-1df51423fae6` (done/PASS) |
| `QM5_41275_wti-mqndisp-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `358c08f2-6722-4306-a1b9-97c83a62d793` (done/FAIL) |
| `QM5_41277_wti-msndisp-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `01fbf53a-4349-4d37-aa1f-a94279c730ca` (done/PASS) |
| `QM5_41277_wti-msndisp-tr` | `XTIUSD.DWX` | `Q03` | governed append-only rerun | `197e9113-e5bc-4f66-92e0-dada91f89e40` (done/PASS) |
| `QM5_41277_wti-msndisp-tr` | `XTIUSD.DWX` | `Q04` | governed append-only rerun | `6d723677-1ab5-4ed5-b5ed-316799ae580e` (done/FAIL) |
| `QM5_41284_wti-mfp-shift-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `efdc8b9c-074f-4118-9056-efee11110655` (done/FAIL) |
| `QM5_41350_wti-adf-ljungbox-agree-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `a09ca266-a672-4c9d-8d15-ead92b464596` (done/FAIL) |
| `QM5_41351_wti-adf-bds-agree-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `8eb2473b-755a-409a-bc3a-2c0fc938e0ee` (done/FAIL) |
| `QM5_41352_wti-adf-vr-agree-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `e001ff07-3e79-4cb2-a2de-e623cbb6f0f4` (done/DRAFT_DEFECT) |
| `QM5_41354_wti-adf-mkendall-agree-tr` | `XTIUSD.DWX` | `Q02` | `seed-fresh-q02` / append-only rerun | `c762c5a5-8d19-4d8b-b54a-4ffc3a47038e` (done/FAIL) |

## Exclusions

Excluded census rows receive neither a source mutation nor a wave-2 compile authority/restart instruction.

| EA | Reason |
|---|---|
| `QM5_20186_xauxag-samecal` | `EA_Q08_MAE_HOOK_MISSING` |
| `QM5_20189_xauxag-calmom1` | `EA_Q08_MAE_HOOK_MISSING` |
| `QM5_20190_oilbench-cal` | `ACTIVE_MAGIC_OR_DWX_MATRIX_INCONSISTENT, EA_Q08_MAE_HOOK_MISSING; bad magic rows: [{"symbol_slot":"1","symbol":"XBRUSD.DWX","magic":"201900001"}]` |
| `QM5_20192_xauxag-ivol` | `EA_Q08_MAE_HOOK_MISSING` |
| `QM5_20194_xauxag-momrev` | `EA_Q08_MAE_HOOK_MISSING` |
| `QM5_20206_xauxag-momivol` | `EA_Q08_MAE_HOOK_MISSING` |
| `QM5_20260_xauxag-mom-vote` | `EA_Q08_MAE_HOOK_MISSING` |
| `QM5_20292_fx-carry-unwind_card` | `APPROVED_CARD_IDENTITY_MISMATCH, DUPLICATE_NUMERIC_IDENTITY_IN_CENSUS, REGISTRY_IDENTITY_MISMATCH` |
| `QM5_21517_xauxag-seas-rv` | `EA_Q08_MAE_HOOK_MISSING` |
| `QM5_41171_wti-mturnpoint-tr` | `ALREADY_REPAIRED_BY_PRECEDENT` |
| `QM5_41319_wti-madf-persist-tr` | `ALREADY_REPAIRED_BY_PRECEDENT` |

## Counts

- Census wave-2 rows: 130.
- Repaired/authority-bound identities: 119.
- Excluded census rows: 11.
- Distinct terminal `(EA, symbol, phase)` restart rows: 261.
- Compile enqueues: 0.
- Q-phase enqueues: 0.
- Worker reloads: 0.
