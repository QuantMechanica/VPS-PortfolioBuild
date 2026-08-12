# QM5_10253 preregistered two-arm offline DEV report

## Decision

`NO_FAMILYWISE_MERIT`. Both untuned preregistered arms are `NO_MERIT`; neither is selected. No rule, parameter, spread, gate, EA, or production path was changed after outcomes.

The full canonical result is `tv_ifvg_sweep_two_arm_full_dev_result.json`, SHA256 `1f92af36de46b5361cdbc140726b03438039b5e8e8d66ec818e5a1911a5510b8`. Two separate Python processes produced byte-identical output. Integrity is `PASS`; `future_ohlc_parsed=false` globally and for both symbols.

## Frozen basis

- Contract commit: `ab3b31c0126deee5882a8c3eba38a3bd96011912`; SHA256 `687daaf95e085f3eaf086a4eab7b67627671a66dcc9f3090b93a7df28e40c87d`.
- Auditor commit: `5217784987a73c7415ca6409aeb7e843a5c2b0c9`; tool SHA256 `60f7b449c129f6efa6f64547a732b16801879a9d34e3f6894155c3d0f445acd7`.
- Pine-v1 source snapshot: canonical LF SHA256 `49fb3755f0f5fffa074e92a5bf8282a6cdae7bad89f3ea95fc75ebe01bbe9cf8`; upstream UTF-8/CRLF SHA256 `6f2d7e364d64037382b7cf18f04f8fb971f3534d4b838f73c118eab48e551ce8`.
- Synthetic causal/fence/execution suite: 12/12 PASS.
- Arm A is the approved-card adjacent sweep/displacement/gap interpretation. Arm B uses Pine-v1 pivot-5 sweeps and mandatory ordinary-FVG-to-IFVG inversion under the same frozen trade overlay.

## Data integrity

| Symbol | Rows | First selected | Last selected | Selected SHA256 |
|---|---:|---|---|---|
| NDX.DWX | 82,511 | 2018-07-02 01:00 | 2022-12-30 23:45 | `fb5ac3c2600eadbdf2921092f8a45121e254a796c94f6b352b905db46d6e28c4` |
| XAUUSD.DWX | 118,159 | 2018-01-02 01:00 | 2022-12-30 23:45 | `e5256d9d5635c2c318d87d1dde72c16d1e467c03037ba89fd21786d61f175c23` |

The first excluded timestamp is 2023-01-03 01:00 for each file. The unbuffered binary loader stopped after that timestamp prefix without reading its OHLC tail.

## Pooled results

| Arm/scenario | Trades | Adjusted net | PF | Expectancy | Closed DD | Commission | Cost burden | Positive 2019-22 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| A center | 32 | +3.502R | 1.179 | +0.109R | 6.259R | $1,011.96 | 4.30% | 3/4 |
| A adverse | 28 | -7.282R | 0.647 | -0.260R | 11.212R | $848.12 | 6.25% | 1/4 |
| B center | 141 | -32.737R | 0.563 | -0.232R | 34.746R | $10,440.55 | 24.44% | 0/4 |
| B adverse | 130 | -40.223R | 0.466 | -0.309R | 41.211R | $10,113.27 | 28.48% | 0/4 |

## Center symbol and side results

| Arm | Segment | Trades | Adjusted net | PF | Closed DD |
|---|---|---:|---:|---:|---:|
| A | NDX.DWX | 15 | +1.411R | 1.153 | 3.088R |
| A | XAUUSD.DWX | 17 | +2.091R | 1.201 | 5.206R |
| A | Long | 16 | +4.965R | 1.599 | 4.288R |
| A | Short | 16 | -1.463R | 0.871 | 5.074R |
| B | NDX.DWX | 57 | -0.830R | 0.965 | 8.104R |
| B | XAUUSD.DWX | 84 | -31.907R | 0.377 | 31.907R |
| B | Long | 75 | -22.530R | 0.489 | 23.812R |
| B | Short | 66 | -10.207R | 0.669 | 11.517R |

## Center year and symbol-year results

Arm A pooled: 2018 `-5.328R` (8), 2019 `+3.780R` (5), 2020 `0R` (0), 2021 `+2.308R` (7), 2022 `+2.742R` (12).

- NDX: 2018 `-1.053R`, 2019 `-0.109R`, 2021 `+3.673R`, 2022 `-1.100R`.
- XAU: 2018 `-4.275R`, 2019 `+3.889R`, 2021 `-1.365R`, 2022 `+3.842R`.

Arm B pooled: 2018 `-7.250R` (21), 2019 `-6.898R` (22), 2020 `-1.878R` (11), 2021 `-11.290R` (41), 2022 `-5.421R` (46).

- NDX: 2018 `-1.746R`, 2019 `-1.895R`, 2021 `-3.337R`, 2022 `+6.149R`.
- XAU: 2018 `-5.504R`, 2019 `-5.003R`, 2020 `-1.878R`, 2021 `-7.953R`, 2022 `-11.569R`.

## Concentration and strict gates

Arm A center top-two winner share is 17.20%; leave-best-trade remains `+1.514R`, but leave-best-year is `-0.278R`. It passes 16/31 gates. It fails all fill minima (32 pooled versus 120; 15/17 per symbol versus 40; 16/16 per side versus 30), the familywise PF gate (1.179 versus 2.166), NDX PF, Short net/PF, NDX positive-year count, leave-best-year, and every adverse-spread merit gate.

Arm B center top-two winner share is 9.44%; leave-best-trade is `-34.728R` and leave-best-year is `-30.859R`. It passes 9/31 gates. Although it clears all fill minima, it fails pooled/symbol/side net and PF gates, expectancy, year stability, pooled/XAU drawdown, both leave-best-out gates, and every adverse-spread merit gate.

The adverse scenario alone is decisive for Arm A; Arm B is decisively negative before robustness stress. Under the preregistered post-fail rule, these DEV outcomes authorize reporting only, not tuning or production migration.
