# FTMO alias builds for demo book v3 (D2g6) — 2026-09-18 ~05:1xZ

The sealed factory binaries fail on FTMO venue names with EA_MAGIC_RESOLUTION_FAILED (registered_symbol=<X>.DWX vs expected_symbol=<X>; the sealed builds predate the base-name-tolerant QM_MagicSymbolCanonical resolver). As on 2026-09-06 (untracked alias rebuilds), the six sleeves were rebuilt from the identical canonical sources against the canonical framework/include tree (MetaEditor64, 0 errors/0 warnings each) and installed into Experts\QM_FTMO; the sealed binaries are preserved in bin_sealed_replaced_by_alias/. Demo evidence is DEMO-BURN-IN, no gate verdict is claimed from these binaries.

| EA | source sha256 (mq5) | sealed ex5 (replaced) | alias ex5 (installed) |
|---|---|---|---|
| QM5_13213_balke-gmt3-range-breakout | d140d313c3bbcd87ccefacfb2068bf164f9db9edfbe49ba410a83fcd4d79054f | 8c99dea16fbf758a4b2da9f49a26db26bfe7fed3589f2066be5120314106a8f0 | 85b5d4ed6443d77cc24db2b8046a42473e9e0572407680731d0e60733ad9d2e8 |
| QM5_10706_tv-mon-ls | c932fdd800548a7dae4c39d910c3726491e46b506c5ee60ba1abef523c78bf1e | eaffda6f03c8b422896c0e9ab5ea0f3c7100f8546592353ed661f19d056b78cb | e6701607ef44e02733558bde9cf096aed9ab8e83a57fea4d64c84ad6259574e4 |
| QM5_10700_tv-liq-break | 064d670b736e5125a1def88c10ba00f68fc43253ee904b3d82168d8e2380b850 | 5fbf2ba0048250041296deda0008ff6757f56dce27e39efead69f45838e5e6be | 5dcb1a235f5b78cdff274eaa32e48d4713d19f1415da3a2153c98e48b501d6a1 |
| QM5_11422_williams-18ma-outside-bar-entry-d1 | a68b9f02372edd490f2af9ea32efa6606df7c2d8b40e30f3ddac2e2d56cab84e | 2b98e9e902313148be78d88513fcbda2476150b1a7605eb15a50b2cca6b32d66 | 76e59831ca36c4bd55312686c56c1266f1f11c784b4942250e362b9a9a6c5bb1 |
| QM5_10403_et-turtle20x | b38cfd471fd31811bb23a5447c430cc1bfcc1f370eb816236c99bb88be55d251 | f927f07f46579bbb9a1bdcfdb7caa9b246e9d7555935fbb878f7fc01afbf7ab3 | fbe198f7210b52853741ae3c987416b0b51ebd2a521c70fe18b71061de27ebcc |
| QM5_41219_cum-rsi2-commodity-requal8 | cd2a0ac6e3f4a677cbb30197e23eaeb8338f06f69d66341eeedfc45cb68746b3 | e9670141e89249aff7df44a10a2402e2103aa4cecf8d0a35a8cd6d6babedf108 | e00915b9ac7cbffe177680863f77871262629a42dc64e5385e4580707b1d10ae |

Include tree: canonical framework/include @ d316791011 + T1 stdlib. Authority: OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917.
