# Codex re-review: Gemini eight-EA repair battery

- Codex review task: `224c77f8-aa3e-4386-8ab4-8b9327994c9c`
- Gemini source task: `c162c123-6264-4028-9f19-84cbd81cff48`
- Gemini repair commit: `c99b67c8b954e23f70da5d78d45a4483a8710d18`
- Evidence-binding follow-up: `8801bcd3850c2b85664216c34978730dd89e1f11`
- Source artifact: `docs/ops/evidence/2026-08-16_repair_8_eas_battery.md`
- Prior Codex review: `docs/ops/evidence/2026-08-17_codex_review_gemini_8_ea_battery.md`
- Verdict: **CODE_REVIEW_PASS — remain in REVIEW; no Codex self-approval or pipeline handoff**

The router named `code-review` and `gemini-output-review`, but neither skill was
available in this session. Codex therefore performed the mandatory review
directly against the patch, current files, regression tests, hashes, compiler
logs, and strict build reports.

## Prior findings

### QM5_1630 cooldown: resolved

The earlier build wrote `g_last_buy_entry_time` or
`g_last_sell_entry_time` while constructing a request, before the order result
was known. Commit `c99b67c8b` removes both writes from
`Strategy_EntrySignal`. `OnTick` now writes the direction-specific timestamp
only inside the true branch of `QM_TM_OpenPosition(req, out_ticket)` (source
lines 793–799). A failed open therefore leaves both cooldown timestamps
unchanged; a successful open starts the configured 18-bar cooldown. Explicit
initialization in `OnInit` is consistent with the state contract.

### QM5_11897 timeframe durations: resolved

Pending-order expiry in both signal directions now multiplies by
`PeriodSeconds(tf)` (source lines 193 and 273). The 120-bar position timeout now
multiplies by `PeriodSeconds(GetStrategyTimeframe())` (line 426). No hard-coded
`3600` remains in the source, so H4/D1 selections no longer retain H1 expiry or
timeout durations.

### Cryptographic evidence: resolved

The source artifact now names the exact repair commit, full source and EX5
SHA-256 values and sizes, compiler logs, and strict build report paths. Codex
recomputed all 16 hashes from the current tracked files; every value and byte
size matches the table. All eight cited compiler logs exist and end in
`Result: 0 errors, 0 warnings`. All eight cited strict reports exist, have
`status=PASS`, `strict=true`, zero failures, and zero warnings.

| EA | Source SHA-256 | EX5 SHA-256 |
|---|---|---|
| `QM5_10648_tv-velox-mtf` | `aeccd90e989cd611509c3c79c9e67b551ed77f30dc67e465203353237767e4dc` | `32e357fd8d967f3c0b4f435fc6216cd97457f2f328643eb791edc44688ccb842` |
| `QM5_10649_tv-stoch-sltp` | `c9a66aeaa938889188c80040491bd859c8bc926c1e90346ad7f841e56c9f038d` | `3bb85b8d7726ae975826cf5f578fbbaaa0ea3a8c6f62fdc69f3d1dae822844b0` |
| `QM5_10973_ftmo-adl-div` | `b3c2e0153ca3b6979794163614942ea1c2544dcffde264b75384266e678c1c20` | `2a9d570f314170d2bd46f0e2e02cd6a562acbe3c1b9dc13ff3b3c2c6f33707cd` |
| `QM5_11897_vegas-wave-ema144-169-fractal-h1-alt` | `63a150bb5efb0105e5ad0bcfacf67509ea3d95ca5c426d36677f3d898482dc50` | `0f5a8ba6ec55f5537f0b95071f310a2701374356fde6bc6cb6dd6a0015004291` |
| `QM5_1355_williams-vix-fix-fx-h4` | `b2afc41e7bcee9abff91bc32e1073c466bfb13e9c21561c212727a6c29ae3b15` | `a5104d02317519b7a8a0395cfb9bfc9f979d83517da5017e95150ffb1a5b4dbc` |
| `QM5_1630_demark-td-sequential-combo-overlay-h4` | `4a6ecac199fb538db0bb64924ecd5f61714aa520afe36d5d4a6b8fbe12ab1a1d` | `966462c5f393fe28d25fbc5949999929b27c448b4c423463ec4d34b5ab96a2fc` |
| `QM5_2076_chaikin-oscillator-h4` | `24e7ea01cb598aac3c67cca013384605845a54a1355c0c7981be66ee067490a4` | `4827d5d4476d770b6a43c66a1c9fa1a40217644212be60d7f1be57f4100b7431` |
| `QM5_9501_pring-kst-w1` | `cbd359a5078ad293da46533b9d6ed406eb31e01952e568f6f929600580220339` | `062fb24c5177df1549ca1b507302615c3e89e5ee38cb2768030b26f635a8aa31` |

## Independent verification

- `pytest framework/scripts/tests/test_qm5_1630_and_11897_repair_regression.py -q`:
  2 passed. The tests structurally bind the timestamps to the successful-open
  branch, simulate failed/successful cooldown transitions, and bind all three
  QM5_11897 durations to the selected timeframe.
- `validate_build_guardrails.py --max-news-stale-hours 336` across all eight EA
  directories: aggregate PASS, zero findings.
- Fresh `build_check.ps1 -EALabel <label> -SkipCompile` sweep: 8/8 PASS, zero
  failures and zero warnings. Reports:
  `build_check_20260816_234106.json`, `234120`, `234134`, `234149`, `234203`,
  `234218`, `234231`, and `234244` under `D:\QM\reports\framework\21` in table
  order.
- All canonical setfiles across the eight directories retain
  `RISK_FIXED > 0` and `RISK_PERCENT=0`.

No additional correctness finding was identified in the rework. Codex changed
no Gemini source, binary, setfile, registry, resolver, work item, or pipeline
state during this review. Per the Gemini-review guardrail, this task remains in
REVIEW for independent close-out and is not moved to PIPELINE or self-approved.
