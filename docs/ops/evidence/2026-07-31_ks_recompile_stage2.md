# KS vintage recompile — stage 2 evidence (no deploy)

**Date:** 2026-07-31

**Router task:** `45da1fa0-585a-4f8c-a202-5224811b0af6`

**Required reviewer:** Claude

**Decision authority:** `decisions/2026-07-31_t_live_ks_vintage_recompile_plan_approval.md`

**Verdict:** **BUILD PASS; CANARY BLOCKED; NO DEPLOY AUTHORITY**

The seven EAs were repaired, source-locked, and compiled serially into immutable non-live staging with zero errors and zero warnings. The approved canary gate did **not** pass: `KS_BASELINE_LOADED` is deliberately disabled by the shared kill-switch code in Strategy Tester mode, and there is no registered non-live demo/chart lane that can exercise the live-only path. The honest canary result is therefore **0/9**, not 9/9. Nothing was written to T_Live, no terminal/chart was re-initialized, AutoTrading was not changed, and no adjudication overlay was appended.

## Authority boundary

The OWNER decision authorizes plan steps 1–5 only: guardrail repair, registry analysis, clean source pin, serial Factory build to immutable staging, non-live canary, and preparation of the MNT-043/MNT-044 bill. It explicitly withholds steps 6–9, including a final deploy manifest/signature, T_Live promotion, and re-init. The companion manifest is intentionally unsigned and records `deploy=NOT_AUTHORIZED_NOT_RUN`:

- `docs/ops/evidence/2026-07-31_ks_vintage_recompile_manifest_STAGE2_UNSIGNED.json`
- `docs/ops/evidence/2026-07-31_ks_vintage_recompile_mnt_bill_PROPOSED.json`

## Guardrail repair and source lock

Source commit: `386151841013afbaf01fe10b23e6cf7538480b71` (`fix: restore KS vintage build guardrails`). The build used a clean detached materialization at `C:/QM/worktrees/ks-recompile-stage2-386151841`.

The repair adds the EA-default time exits to exactly seven backtest sets:

- QM5_10919: `strategy_time_exit_bars=12` in NDX, SP500, and XAUUSD H4 sets.
- QM5_10939: `strategy_time_exit_h4_bars=18` in EURUSD, GDAXI, USDJPY, and XAUUSD H4 sets.

`validate_build_guardrails.py` then passed for all seven EAs with no findings. The maximum observed `qm_news_stale_max_hours` remained 336; no fail-closed news rule was weakened. The bounded canary used `RISK_FIXED=1000` and `RISK_PERCENT=0`.

All recursive source closures were re-hashed from the actual build-worktree bytes. Each closure has 29 members (the EA MQ5 plus 28 shared repo-local includes), zero unresolved repo includes, and the platform include `Trade/Trade.mqh` is separately bound at SHA-256 `96e6781624534377fe7971cba52cca3d62d1b030bc10d5e4ebf3ed8c541399ed`. The unsigned manifest contains all 28 shared member hashes.

## Registry caveat

The pinned registry validator remains globally failed: 4,246 EA rows, 15,395 magic rows, 1,363 issues, and 1,231 warnings. The target-specific issue is exact:

`ea_id_registry:duplicate_ea_id:12567:lines=3511,3515`

Both physical rows carry the same identity (`12567,cum-rsi2-commodity,ee172909-2f40-5169-9fa3-c1dc0657dee0,active`). The four magic rows are unique and contiguous (slots 0–3, magics 125670000–125670003), and the generated resolver has the same four unique ordered mappings.

Proposed separate reviewed maintenance: retain the earliest row 3511 and delete only the later redundant row 3515. Do not change `magic_numbers.csv` or the resolver. This task did not edit any registry. Before any signature, require that cleanup or an exact OWNER-signed exception for the global baseline and the duplicate.

## Serial Factory build receipts

Compiler: `D:/QM/mt5/T1/metaeditor64.exe`, file/product version `5.0.0.6061`, SHA-256 `bc62cabf758c7debf30073bb8e20c2b5a673bef4104eb856952aae77271cee23`.

Immutable stage: `D:/QM/strategy_farm/artifacts/ks_vintage_recompile_stage2_20260731_386151841`.

| EA | MQ5 SHA-256 (prefix) | closure SHA-256 (prefix) | staged EX5 SHA-256 | bytes | compile |
|---|---|---|---|---:|---|
| 10911 | `b874d6a025f9` | `f00283000624` | `a815c73da991736d25a02c027bbcfb23f68615adb66b7325cc2efcdc52344158` | 365,564 | 0 errors / 0 warnings |
| 10919 | `17f60ed4f7b0` | `2de520e07feb` | `57e0db8401616a5fb10c68557c24e8b7a7e98254cb8ddf57245fc178aa3a4691` | 369,984 | 0 errors / 0 warnings |
| 10939 | `8d153796f055` | `9aee4b166f03` | `308604a3546c44fc8bfb40ecff36801e5479bf33887847b8b6e5650943312aac` | 373,152 | 0 errors / 0 warnings |
| 11132 | `dc66c331268e` | `99c5b34126bf` | `25b68c44d9724d9915298ad6b632e9c4db77133526e8c441fa82adc2a0474152` | 359,180 | 0 errors / 0 warnings |
| 11421 | `5bab448a8bbe` | `0bc38d0ff875` | `0f7c8ff9ad91c43f275aacbfb366f06f17aeda0f1d567c83936af7d8dca69ca7` | 360,466 | 0 errors / 0 warnings |
| 12567 | `fec2b16bdf81` | `49720184507b` | `5d5be334288e76a582349dac8351a95700222b91bbd28e1921e9d4aa6e3b10f9` | 359,998 | 0 errors / 0 warnings |
| 12989 | `98f7397011b5` | `610ef66856b0` | `7f2c298f4a8b4395480e47f20f9cefb8d5c53083bd63f7ea9ef1db067f52c4d2` | 373,406 | 0 errors / 0 warnings |

Each staged EX5 is byte-identical to its build-worktree output. Compile logs and JSON receipts are sealed below the stage root and hash-bound in the manifest. Compilation was serial. Active T1–T10 tests were observed but not interrupted; no `terminal64.exe` was started manually.

## Non-live canary — required table

Registered DEV1/DEV2 tester lanes support only `NDX.DWX`, `GDAXI.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and `XAUUSD.DWX`. Four target symbols are therefore additionally unsupported (`XTIUSD.DWX`, `SP500.DWX`, `AUDUSD.DWX`, `XNGUSD.DWX`). More importantly, the shared source makes the baseline-loaded gate impossible in **every** Strategy Tester run:

```mql5
if(MQLInfoInteger(MQL_TESTER) != 0)
  {
   g_qm_ks_baseline_loaded = false;
   return;
  }
```

This is `framework/include/QM/QM_KillSwitchKS.mqh:217-220` at the source pin, file SHA-256 `5df2827296dfcc03f7fbbf703ac235a149d28048c90e5a171497e938ef7a1239`. Its comments state that loading the Q10 distribution in backtests would arm the divergence kill under deliberately perturbed stress evidence, so the live/burn-in protection is intentionally dormant in the tester.

| EA | identity | registered lane | observed `KS_BASELINE_LOADED` | result |
|---|---|---|---:|---|
| 10911 | GDAXI / H1 / 109110003 | DEV1 tester, one bounded run | 0 | **FAIL gate** (smoke otherwise passed) |
| 10919 | XTIUSD / H4 / 109190001 | symbol unsupported; tester path also suppresses KS | 0 | NOT RUN / known unsatisfiable |
| 10939 | GBPUSD / H4 / 109390001 | tester path suppresses KS | 0 | NOT RUN / known unsatisfiable |
| 11132 | SP500 / D1 / 111320000 | symbol unsupported; tester path also suppresses KS | 0 | NOT RUN / known unsatisfiable |
| 11421 | EURUSD / D1 / 114210000 | tester path suppresses KS | 0 | NOT RUN / known unsatisfiable |
| 11421 | AUDUSD / D1 / 114210003 | symbol unsupported; tester path also suppresses KS | 0 | NOT RUN / known unsatisfiable |
| 12567 | XAUUSD / D1 / 125670003 | tester path suppresses KS | 0 | NOT RUN / known unsatisfiable |
| 12567 | XNGUSD / D1 / 125670002 | symbol unsupported; tester path also suppresses KS | 0 | NOT RUN / known unsatisfiable |
| 12989 | XAUUSD / H4 / 129890003 | tester path suppresses KS | 0 | NOT RUN / known unsatisfiable |

The one bounded DEV1 run used 10911/GDAXI.DWX/H1 for 2025-01-02 through 2025-01-10. It ran through the registered scheduled-task lane, proved exclusive listener ownership, restored the isolated account disabled, and left the cleanup lease disarmed. The staged EX5 hash remained `a815c73d…4158`; news calendar status was OK at age 31h; `NEWS_TESTER_CALENDAR_SELFTEST`, `NEWS_CALENDAR_LOADED`, `KILL_SWITCH_INIT`, `EXECUTION_CONTRACT`, `INIT_OK`, entry, order, and close events were present; two trades occurred. The logger had 22 events and zero `KS_BASELINE_LOADED` events.

Evidence root: `D:/QM/reports/dev1/runs/20260731T171738Z_daa476aacc354bfeb8d8c96e00135cf4`.

- atomic result SHA-256: `e372719ee46c28d662a5daa890bee0fde89d53e69025d70b4bacb3775fa7e1e9`
- smoke summary SHA-256: `cc5649476c8969e8f84765bf60ee5d619e31e75eda6cd1a01da0167e8d4cc5fd`
- logger sample SHA-256: `9f45d9910b447572ba97cb84a791b3daeeb93ae28da93f70688af174fcbf2e21`

No registered non-live demo/chart lane exists in the current inventory. T_Live is prohibited. Repeating tester runs cannot change the result, so they were stopped. The required signal/order/trade-stream delta comparison is **not admissible** because its baseline-loaded prerequisite cannot be exercised; no delta equivalence is claimed.

## MNT-043/MNT-044 bill

The retained read-only scan has file SHA-256 `72e42276e3a8455a3b016dffbe9c20208986668d3c22408a14a2ccf12029b3cf` and internal fingerprint `6ae7ed1da2d27b9aa28ede6cd7846b82fb69b1ce75112a593b1af37b61ffb64c`. It found 26 historical Q06/Q07 PASS rows for the seven target EAs: 22 admission-priority rows and four history-priority rows.

Those rows already resolve predominantly to `PROVENANCE_UNVERIFIED` because evidence files or identity bindings are missing. That does not permit inheritance to the newly staged EX5s. The proposed bill binds every raw row hash to the actual new EX5 hash and proposes `EVIDENCE_VINTAGE_STALE` / `BINARY_VINTAGE_MISMATCH` when the staged binary is adopted. It also lists the fresh admission-relevant Q06/Q07 rerun identities. Duplicate historical rows for 11132/SP500 are one rerun identity each, not permission to run duplicate work.

The bill is **proposal only**: no overlay bytes were appended, no work-item row was changed, and no pipeline verdict was created.

## Review disposition

Claude should review:

1. the source/closure/compiler/EX5 chain and the seven guardrail backfills;
2. the exact 12567 duplicate-row disposition and global registry exception posture;
3. the source-proven tester/live semantic mismatch that makes the approved canary gate impossible;
4. whether to authorize a new registered non-live demo/chart canary mechanism or revise the gate through a new OWNER decision;
5. the proposed append-only vintage bill and admission rerun identities.

Until a new authority resolves the canary mechanism and all signature caveats, the staged binaries remain non-deployable. The unsigned manifest is not a deploy manifest and creates no live or pipeline verdict.
