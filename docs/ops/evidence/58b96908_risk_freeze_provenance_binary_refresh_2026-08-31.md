# Risk-Freeze provenance resolution, binary seal, and baseline refresh

Date: 2026-08-31  
Router task: `58b96908-9d54-4906-9142-514e5d961ac1`  
Authority: `OWNER-DEC-RISK-FREEZE-BASELINE-REFRESH` continuation  
Branch: `agents/board-advisor`  
Verdict: **PASS — provenance resolved; binary seal active; baseline refreshed**

## Outcome

The two apparent provenance failures were resolved without touching T_Live.
The recorded `expected_pre_deploy_sha256` values were not erroneous: they bind
the bytes backed up before the repair. After deployment, the correct target is
the prepared source hash recorded by the repair manifest and deploy receipt.

Mutable repository HEAD is not deployment provenance. The new overlay binds:

- repair manifest SHA-256
  `6a1024ca31ec76892f0261a5a34e31df645152eed021968be37f720c4380e837`;
- immutable preparation commit
  `e09749e60b070be2635b322f7aa3971a531aa7ff`;
- deploy receipt SHA-256
  `7e0b0941fda4e8c51e10846f5e6e47c9bc097b088ab365ad93a87043f7a97eb2`;
- each archived source blob, receipt row, deployed preset, preset `build_hash`,
  and deployed companion EX5.

The canonical deployed verifier passes **10/10** using that chain. It reports
the later HEAD evolution of QM5_12989 and QM5_13128 as information, not as a
false deployment failure.

## Per-sleeve archival proof

Every row below passed archived-source = manifest source = deploy-receipt
target = current deployed preset, and companion EX5 = preset `build_hash` =
manifest expected build hash.

| Repair sleeve | Archived/deployed preset SHA-256 | HEAD state |
|---|---|---|
| QM5_10440 | `af2678b4446e10741f68444cb457a16da33059b0150658857f400aa575cea717` | equal |
| QM5_10513 | `722e1344a4fa6bd60a43be79d1d1920730b7a5d62f8236c0b812f8764f596dde` | equal |
| QM5_10706 | `d9d432347648a41b5dfefeb98f1aedf1c26b4d19f0a9db07ea3e1d0bc900f26f` | equal |
| QM5_10911 | `daf0f2143955d3bc052f5bce5b6b8510e7a55354839139f587e11d6ef13f6e1c` | equal |
| QM5_10919 | `af3f2a4a2aa656ec1f9f5f247c55b2331a3c2c842d633afb48f849b98da735fc` | equal |
| QM5_10939 | `298bcd6a7867a967c1b491953fecad83e631b3dc5c001af70462be9e11e4c60e` | equal |
| QM5_11132 | `87fc8288070ab8bf56356ec9ab6a89f0216004df03dd2766e49e3aef3bdd5694` | equal |
| QM5_12567 / XNG | `26537d011b553ba6acb668d99945584be3c0ab0991dc4459fc84de8278cc4e79` | equal |
| QM5_12989 | `9fb2c0f85ad92a1b6de7afeb58988c7fe3fbe56ac9be5f6025af6a5d18d2a5f4` | evolved to `c74ece40...` |
| QM5_13128 | `743326c316de6c2ccdab6080dab6dfff2d010afc9843a75798701f39e981be4e` | evolved to `86ffacae...` |

Commit `1ccbdd4ab0e79177aaafce3ab1c8638e210cf4a8` regenerated the two
HEAD live setfiles on 2026-08-27. It did not change the 2026-08-23 deployed
targets. The overlay is
`docs/ops/evidence/2026-08-31_tlive_preset_repair_provenance_overlay.json`.

## Binary-sealed freeze

`risk_freeze.measure()` now derives each companion EX5 from the deployed
preset's exact EA label and records `binary_path` plus `binary_sha256` on every
sleeve. It also seals a deduplicated binary roster count and inventory hash.
`diff_against_baseline()` fails closed on a missing legacy seal, binary roster
change, inventory hash change, path change, or per-sleeve EX5 hash change.

The refreshed measurement is:

| Field | Value |
|---|---:|
| Presets | 24 |
| Unique companion binaries | 21 |
| Total `RISK_PERCENT` | 9.7499 |
| Non-zero `RISK_FIXED` | 0 |
| Roster SHA-256 | `a98bfdeb08a95d9bd9c8dfe3593e258cc24ec94677a67d821a1338338c8ee159` |
| Binary inventory SHA-256 | `c6bfa77b3d9e8bfbb01ed690e3c273bd95fefbb520fc5a25f926becc07eaa261` |

A fixture test mutates a companion EX5 after arming and proves both the
per-sleeve binary and inventory checks detect drift.

## Authorized refresh and postcondition

After the 10/10 provenance pass, clean 24-sleeve measurement, and focused test
pass, `risk_freeze.py arm --force` refreshed only
`D:/QM/reports/state/live_risk_freeze.json`. The final state is:

- status `ACTIVE`;
- armed at `2026-08-31T05:12:17.7290629Z`;
- `held=true`, drift `[]`;
- state SHA-256
  `79b6a14537a20153f5e203061d0e1b55ab60378adddb4c4c6d8d5825e659b134`.

The prior state SHA-256 was
`82695ac67a7342c5f9443d4625fc849c83a9358937e5a5736f6f20d68ced13e5`.
The SP-A1/A2 lift-condition text was corrected to record that preset
provenance is resolved while the deployment pointer/consumer rollout remains
separately blocked. The freeze was not lifted.

## Verification and no-live-write proof

```text
verify_tlive_preset_repair.py --require-deployed --provenance <overlay>
10/10 PASS; overall PASS

test_risk_freeze_prevention.py + test_verify_tlive_preset_repair.py
26 passed in 2.65s

risk_freeze.py verify
status=ACTIVE held=true drift=[] presets=24 binaries=21 risk=9.7499
```

The T_Live process remained PID 19016, created
`2026-08-23T10:28:59.962873+02:00`, before and after this continuation. No
preset, EX5, chart, terminal process, account setting, T_Live flag, or
AutoTrading setting was changed. Only the authorized Risk-Freeze state file,
repository verifier/tests, provenance overlay, and this evidence receipt were
written.
