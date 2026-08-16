# Evidence: Repair and Complete Cryptographic Verification of 8 Blocked EAs (2026-08-16 / 2026-08-17)

- **Task ID**: `c162c123-6264-4028-9f19-84cbd81cff48`
- **Agent**: Gemini (`agents/board-advisor`)
- **Repair Commit**: `c99b67c8b954e23f70da5d78d45a4483a8710d18`
- **Review Cycle**: Recycle 1 (reworked following Codex review `7ef88ada-0b69-41a8-985e-36857b21aa68` / `docs/ops/evidence/2026-08-17_codex_review_gemini_8_ea_battery.md`)
- **Timestamp**: 2026-08-16T23:26:00Z
- **Verdict**: `REVIEW` (Ready for Codex review)

---

## 1. Summary of Changes & Resolutions to Codex Review Findings

### Finding 1: QM5_1630 Cooldown Timestamp Placement (Fixed & Tested)
- **Defect**: Cooldown timestamps `g_last_buy_entry_time` and `g_last_sell_entry_time` were updated in `Strategy_EntrySignal` before order placement was attempted in `OnTick`, causing rejected/failed opens to prematurely consume the full 18-bar cooldown.
- **Resolution**: Removed timestamp writes from `Strategy_EntrySignal`. Timestamp updates are now executed strictly inside the `if(QM_TM_OpenPosition(req, out_ticket))` success branch in `OnTick`. In addition, `g_last_buy_entry_time` and `g_last_sell_entry_time` are explicitly reset in `OnInit()`.
- **Regression Coverage**: Added `framework/scripts/tests/test_qm5_1630_and_11897_repair_regression.py::test_qm5_1630_cooldown_only_on_successful_open_regression`, proving statically and via state-machine simulation that failed opens do not block subsequent signals while successful opens enforce the 18-bar cooldown.

### Finding 2: QM5_11897 Timeframe Wiring (Fixed & Tested)
- **Defect**: While `strategy_timeframe` was parsed and wired for indicator calculations, pending-order expiry (`lines 193, 273`) and the 120-bar time stop (`line 426`) remained hard-coded to `* 3600` (H1 seconds).
- **Resolution**: Replaced hardcoded constants with `PeriodSeconds(tf)` in `GetBuyStopSignal` and `GetShortStopSignal`, and with `PeriodSeconds(GetStrategyTimeframe())` in `Strategy_ManageOpenPosition`.
- **Regression Coverage**: Added `framework/scripts/tests/test_qm5_1630_and_11897_repair_regression.py::test_qm5_11897_timeframe_wiring_and_duration_regression`, verifying that all durations scale dynamically with the selected timeframe and no hard-coded 3600-second multipliers remain.

### Finding 3: Cryptographic Evidence Binding & Durability (Addressed)
- All 8 EAs were re-compiled under `compile_ea.py --force` to bind each source closure (`.mq5`) and artifact (`.ex5`) directly to the repair commit with full SHA256 checksums, byte sizes, compiler logs, and build check report paths recorded below.

---

## 2. Complete Artifact & Cryptographic Evidence Table

| EA Label | Source Path & Size | Source SHA256 | Binary Path & Size | Binary SHA256 | Compiler Log Path | Build Check Report | Guardrails |
|---|---|---|---|---|---|---|---|
| `QM5_10648_tv-velox-mtf` | `framework/EAs/QM5_10648_tv-velox-mtf/QM5_10648_tv-velox-mtf.mq5` (12,513 B) | `aeccd90e989cd611509c3c79c9e67b551ed77f30dc67e465203353237767e4dc` | `framework/EAs/QM5_10648_tv-velox-mtf/QM5_10648_tv-velox-mtf.ex5` (379,830 B) | `32e357fd8d967f3c0b4f435fc6216cd97457f2f328643eb791edc44688ccb842` | `C:\QM\repo\framework\build\compile\20260816_231958\QM5_10648_tv-velox-mtf.compile.log` | `D:\QM\reports\framework\21\build_check_20260816_232420.json` | PASS (0 findings) |
| `QM5_10649_tv-stoch-sltp` | `framework/EAs/QM5_10649_tv-stoch-sltp/QM5_10649_tv-stoch-sltp.mq5` (8,496 B) | `c9a66aeaa938889188c80040491bd859c8bc926c1e90346ad7f841e56c9f038d` | `framework/EAs/QM5_10649_tv-stoch-sltp/QM5_10649_tv-stoch-sltp.ex5` (374,820 B) | `3bb85b8d7726ae975826cf5f578fbbaaa0ea3a8c6f62fdc69f3d1dae822844b0` | `C:\QM\repo\framework\build\compile\20260816_232029\QM5_10649_tv-stoch-sltp.compile.log` | `D:\QM\reports\framework\21\build_check_20260816_232431.json` | PASS (0 findings) |
| `QM5_10973_ftmo-adl-div` | `framework/EAs/QM5_10973_ftmo-adl-div/QM5_10973_ftmo-adl-div.mq5` (17,106 B) | `b3c2e0153ca3b6979794163614942ea1c2544dcffde264b75384266e678c1c20` | `framework/EAs/QM5_10973_ftmo-adl-div/QM5_10973_ftmo-adl-div.ex5` (382,830 B) | `2a9d570f314170d2bd46f0e2e02cd6a562acbe3c1b9dc13ff3b3c2c6f33707cd` | `C:\QM\repo\framework\build\compile\20260816_232059\QM5_10973_ftmo-adl-div.compile.log` | `D:\QM\reports\framework\21\build_check_20260816_232440.json` | PASS (0 findings) |
| `QM5_11897_vegas-wave-ema144-169-fractal-h1-alt` | `framework/EAs/QM5_11897_vegas-wave-ema144-169-fractal-h1-alt/QM5_11897_vegas-wave-ema144-169-fractal-h1-alt.mq5` (17,581 B) | `63a150bb5efb0105e5ad0bcfacf67509ea3d95ca5c426d36677f3d898482dc50` | `framework/EAs/QM5_11897_vegas-wave-ema144-169-fractal-h1-alt/QM5_11897_vegas-wave-ema144-169-fractal-h1-alt.ex5` (383,296 B) | `0f5a8ba6ec55f5537f0b95071f310a2701374356fde6bc6cb6dd6a0015004291` | `C:\QM\repo\framework\build\compile\20260816_232339\QM5_11897_vegas-wave-ema144-169-fractal-h1-alt.compile.log` | `D:\QM\reports\framework\21\build_check_20260816_232450.json` | PASS (0 findings) |
| `QM5_1355_williams-vix-fix-fx-h4` | `framework/EAs/QM5_1355_williams-vix-fix-fx-h4/QM5_1355_williams-vix-fix-fx-h4.mq5` (11,365 B) | `b2afc41e7bcee9abff91bc32e1073c466bfb13e9c21561c212727a6c29ae3b15` | `framework/EAs/QM5_1355_williams-vix-fix-fx-h4/QM5_1355_williams-vix-fix-fx-h4.ex5` (378,516 B) | `a5104d02317519b7a8a0395cfb9bfc9f979d83517da5017e95150ffb1a5b4dbc` | `C:\QM\repo\framework\build\compile\20260816_232131\QM5_1355_williams-vix-fix-fx-h4.compile.log` | `D:\QM\reports\framework\21\build_check_20260816_232500.json` | PASS (0 findings) |
| `QM5_1630_demark-td-sequential-combo-overlay-h4` | `framework/EAs/QM5_1630_demark-td-sequential-combo-overlay-h4/QM5_1630_demark-td-sequential-combo-overlay-h4.mq5` (25,908 B) | `4a6ecac199fb538db0bb64924ecd5f61714aa520afe36d5d4a6b8fbe12ab1a1d` | `framework/EAs/QM5_1630_demark-td-sequential-combo-overlay-h4/QM5_1630_demark-td-sequential-combo-overlay-h4.ex5` (384,420 B) | `966462c5f393fe28d25fbc5949999929b27c448b4c423463ec4d34b5ab96a2fc` | `C:\QM\repo\framework\build\compile\20260816_232201\QM5_1630_demark-td-sequential-combo-overlay-h4.compile.log` | `D:\QM\reports\framework\21\build_check_20260816_232512.json` | PASS (0 findings) |
| `QM5_2076_chaikin-oscillator-h4` | `framework/EAs/QM5_2076_chaikin-oscillator-h4/QM5_2076_chaikin-oscillator-h4.mq5` (13,790 B) | `24e7ea01cb598aac3c67cca013384605845a54a1355c0c7981be66ee067490a4` | `framework/EAs/QM5_2076_chaikin-oscillator-h4/QM5_2076_chaikin-oscillator-h4.ex5` (386,194 B) | `4827d5d4476d770b6a43c66a1c9fa1a40217644212be60d7f1be57f4100b7431` | `C:\QM\repo\framework\build\compile\20260816_232236\QM5_2076_chaikin-oscillator-h4.compile.log` | `D:\QM\reports\framework\21\build_check_20260816_232523.json` | PASS (0 findings) |
| `QM5_9501_pring-kst-w1` | `framework/EAs/QM5_9501_pring-kst-w1/QM5_9501_pring-kst-w1.mq5` (20,537 B) | `cbd359a5078ad293da46533b9d6ed406eb31e01952e568f6f929600580220339` | `framework/EAs/QM5_9501_pring-kst-w1/QM5_9501_pring-kst-w1.ex5` (382,988 B) | `062fb24c5177df1549ca1b507302615c3e89e5ee38cb2768030b26f635a8aa31` | `C:\QM\repo\framework\build\compile\20260816_232311\QM5_9501_pring-kst-w1.compile.log` | `D:\QM\reports\framework\21\build_check_20260816_232532.json` | PASS (0 findings) |

---

## 3. Independent Verification Results

- **`validate_build_guardrails.py`**: PASS for 8/8 EA directories with `qm_news_stale_max_hours` ceiling 336 and `RISK_FIXED > 0`, `RISK_PERCENT = 0`.
- **`build_check.ps1`**: PASS (0 failures, 0 warnings) for 8/8 EAs.
- **`compile_ea.py`**: PASS (`COMPILED`, 0 errors, 0 warnings) across all 8 EAs.
- **Regression Suite**: `pytest framework/scripts/tests/test_qm5_1630_and_11897_repair_regression.py` passed (2 passed).

---

## 4. Next Steps
Task `c162c123-6264-4028-9f19-84cbd81cff48` is updated to `REVIEW` with durable evidence for Codex review.
