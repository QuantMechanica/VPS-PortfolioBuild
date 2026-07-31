# KS ABSENT vintage — source proof and OWNER-gated recompile/deploy proposal

**Status:** evidence complete; **no compile, deploy, T_Live write, terminal/chart action, or AutoTrading action performed**. This document is a proposal for Claude review and an eventual OWNER-signed action. It creates no pipeline verdict.

**Router task:** `5690506f-88ed-4796-bb9c-1f5642755a6a`

**Draft manifest:** [`2026-07-31_ks_vintage_recompile_manifest_DRAFT.json`](2026-07-31_ks_vintage_recompile_manifest_DRAFT.json)

**Source pin used for this read-only analysis:** `629582b6aa9a06ab12ea00812226bfac883041ea` on `agents/board-advisor`

The seven EA/include/registry scope was clean when that pin was captured at 15:17:53Z. A concurrent task later changed the shared working-tree registries and generated resolver. Those unrelated in-flight changes are preserved and are not incorporated into this draft. The draft hashes bind the raw canonical-checkout bytes observed at capture; unchanged members remain verifiable in place, and the recorded pre-drift resolver hash is verified from the immutable pin. A final build must use its own clean approved materialization and regenerate every hash.

## Result

The defect is proven. Commit `d8b741d02febfc6fea4d33d3bcb7729611cc8eba`, authored 2026-07-06 12:18 +02:00, changed the KS baseline path from the illegal MQL5 drive-letter path

```text
D:\QM\data\baselines\QM5_<ea_id>_<symbol>.json
```

to the sandbox-relative path

```text
QM\baselines\QM5_<ea_id>_<symbol>.json
```

The loader already had a terminal-local `FileOpen` followed by a `FILE_COMMON` retry. The defect was therefore **not a missing fallback** and not a symbol-name mismatch: both opens received the same drive-letter string, which cannot resolve inside either MQL5 file sandbox. The seven old T_Live binaries still expose that compiled literal in their 2026-07-31 `KS_BASELINE_ABSENT.expected_path` events. All nine corresponding files are present and byte-identical in the seed, terminal-local, and common locations. No restart can fix a literal compiled into an EX5; a new binary is required.

The current EA-local source changes have historical July 24 compile artifacts, but the **exact current recursive include closures are not compile-proven** because shared includes changed after those artifacts. Focused validation also found that the current build guardrail fails for EAs 10919 and 10939 because seven backtest sets omit explicit time-exit inputs. The cohort is therefore not build-ready. This task deliberately did not compile or edit those strategy sets. Guardrail repair and PASS, an isolated Factory rebuild, review of the listed behavior changes, non-live canary, new EX5/closure hashes, and OWNER signature are mandatory before any deployment.

## Source proof

The relevant current call chain is:

- `framework/include/QM/QM_Common.mqh:257` calls `QM_KillSwitchKSInit(ea_id, _Symbol)` during framework initialization.
- `framework/include/QM/QM_KillSwitchKS.mqh:143` opens the supplied path in terminal-local `MQL5\Files`; `:145` retries the same relative path with `FILE_COMMON`.
- `QM_KillSwitchKS.mqh:209` constructs `QM\baselines\QM5_%d_%s.json` after replacing `.` with `_` in the broker symbol.
- `QM_KillSwitchKS.mqh:217` is the later tester-only gate. It does not suppress the loader on live.
- `QM_KillSwitchKS.mqh:229` emits `KS_BASELINE_ABSENT` only after both opens fail.

`git show d8b741d0 -- framework/include/QM/QM_KillSwitchKS.mqh` isolates the operative change:

```diff
- g_qm_ks_baseline_path = StringFormat("D:\\QM\\data\\baselines\\QM5_%d_%s.json", ea_id, sym_clean);
+ g_qm_ks_baseline_path = StringFormat("QM\\baselines\\QM5_%d_%s.json", ea_id, sym_clean);
```

The next commit touching this module, `841449513e63449a2dcd3d5c9c2950af91ccd1ed` at 15:20 +02:00, added the tester gate and hardening. It is not the path fix. The July 13 commit `cf2264bb09f1761b5340381647b0c5bb0144235b` records the first true post-no-op-compile rebuild of the DXZ-23 book. This chronology agrees with the already recorded live split in [`2026-07-31_ks_arming_after_owner_restart.md`](2026-07-31_ks_arming_after_owner_restart.md): post-July-13 binaries load, while these June 28/July 4 binaries do not.

### Direct live-binary evidence

The latest event for each sleeve on 2026-07-31 is below. The event path is the old compiled literal even though the named file exists in both supported sandbox locations.

| EA | Symbol / TF | Magic | Latest event UTC | Compiled `expected_path` | Baseline `n` / SHA256 prefix |
|---:|---|---:|---|---|---|
| 10911 | GDAXI / H1 | 109110003 | 13:10:48.625 | `D:\QM\data\baselines\QM5_10911_GDAXI.json` | 331 / `dbfb9a54fe8f` |
| 10919 | XTIUSD / H4 | 109190001 | 13:09:45.093 | `D:\QM\data\baselines\QM5_10919_XTIUSD.json` | 30 / `ea0dd3d63872` |
| 10939 | GBPUSD / H4 | 109390001 | 13:10:56.046 | `D:\QM\data\baselines\QM5_10939_GBPUSD.json` | 92 / `b07a39d01cec` |
| 11132 | SP500 / D1 | 111320000 | 13:10:56.921 | `D:\QM\data\baselines\QM5_11132_SP500.json` | 73 / `77b7056176d2` |
| 11421 | EURUSD / D1 | 114210000 | 13:09:45.359 | `D:\QM\data\baselines\QM5_11421_EURUSD.json` | 92 / `9e0c37ce68b2` |
| 11421 | AUDUSD / D1 | 114210003 | 13:10:47.015 | `D:\QM\data\baselines\QM5_11421_AUDUSD.json` | 90 / `c9435880a1c2` |
| 12567 | XAUUSD / D1 | 125670003 | 13:09:45.359 | `D:\QM\data\baselines\QM5_12567_XAUUSD.json` | 73 / `c7184fce94dd` |
| 12567 | XNGUSD / D1 | 125670002 | 13:10:48.265 | `D:\QM\data\baselines\QM5_12567_XNGUSD.json` | 58 / `806994cd24e1` |
| 12989 | XAUUSD / H4 | 129890003 | 13:09:45.171 | `D:\QM\data\baselines\QM5_12989_XAUUSD.json` | 51 / `432ba8bb1e7f` |

For every row, those bytes match across:

1. `D:/QM/data/baselines`;
2. `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/baselines`;
3. `C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/QM/baselines`.

This eliminates absent seed, copy skew, parse size, and broker-symbol normalization as explanations for this cohort.

## Affected-source and binary matrix

The comparison bases `4ea02837` (June 28) and `37b76514` (July 4) are nearby source-tree snapshots used to enumerate changes; they are **not claimed as binary provenance**. The actual live EX5 SHA and its embedded old path literal are the identity evidence. `mtime` is discovery context only.

| EA | T_Live preimage: UTC mtime / SHA prefix | Current MQ5 / closure SHA prefix | EA-local delta from nearby tree | Behavior pulled by a fresh compile | Exact current closure compile status |
|---:|---|---|---|---|---|
| 10911 | Jun 28 07:11 / `99e774ec0e03` | `2dfa0988d401` / `cc7c7d164bf8` | +10/−1 | H1 execution contract; H1-bound bar gate; new default 1.0% per-trade cap | Guardrail PASS; **compile unverified**; July 24 repo EX5 `2a1760492156` is historical only |
| 10919 | Jul 3 22:18 / `873e377197f4` | `91cb71322cea` / `37e53386697a` | +6/−1 | H4 execution contract and H4-bound bar gate | **Guardrail FAIL**; compile blocked; July 24 repo EX5 `9258fe631ec2` is historical only |
| 10939 | Jun 28 07:11 / `ed64e912ab95` | `2ad956417a71` / `415046a656e2` | +7/−2 | H4 contract; H4-bound entry and retrace-exit bar gates | **Guardrail FAIL**; compile blocked; July 24 repo EX5 `0c1278f5d44d` is historical only |
| 11132 | Jun 28 07:11 / `d5cbddaaa988` | `79f86dbe6ad1` / `326f1d4773c4` | +6/−1 | D1 contract and D1-bound bar gate | Guardrail PASS; **compile unverified**; July 24 repo EX5 `7fe65d4c86d8` is historical only |
| 11421 | Jun 28 07:12 / `db7ca15097c9` | `184b0df165ab` / `802883cc5bb0` | +6/−1 | D1 contract and D1-bound bar gate | Guardrail PASS; **compile unverified**; July 24 repo EX5 `03455d533ffb` is historical only |
| 12567 | Jun 28 07:12 / `086eee8a6fe3` | `e40bea7e231c` / `6a8cc6b954ac` | +6/−1 | D1 contract and D1-bound bar gate | Guardrail PASS; **compile unverified**; July 24 repo EX5 `353dddbb93c3` is historical only |
| 12989 | Jul 3 22:18 / `43cc9a91e604` | `2b84813c4e11` / `650640a5b6a5` | +6/−1 | H4 contract and H4-bound bar gate | Guardrail PASS; **compile unverified**; July 24 repo EX5 `27b9dc294fd6` is historical only |

All current recursive closures have 29 repository members, no unresolved repository include, and one external platform include, `Trade/Trade.mqh`. The JSON draft records every shared member hash and each EA-specific aggregate. The final build receipt must additionally bind the compiler/platform environment.

The guardrail run at 2026-07-31 15:24:43Z returned FAIL with only these findings:

- EA 10919: `time_sensitive_strategy_params_missing` for `strategy_time_exit_bars` in the NDX, SP500, and XAUUSD H4 backtest sets.
- EA 10939: `time_sensitive_strategy_params_missing` for `strategy_time_exit_h4_bars` in the EURUSD, GDAXI, USDJPY, and XAUUSD H4 backtest sets.

The other five EAs passed. No stale-news-limit or risk-mode violation was reported in this run. The seven findings must be fixed and the same validator must return PASS before `compile_ea` is invoked; the validator must not be bypassed or weakened.

The current profile matches every newly declared period: 10911 H1; 10919, 10939, and 12989 H4; 11132, 11421, and 12567 D1. Thus the explicit period change preserves the intended cadence under the current profile and prevents silent cadence drift on a wrong-period chart. The execution contract makes a wrong timeframe or Friday configuration fail at init instead of running silently. This is an intended safety behavior, but it still requires review and can change initialization outcomes.

### Shared changes that a fresh compile will pull

These are material even where EA-local signal formulas did not change:

- **KS and halt safety:** the baseline path fix (`d8b741d0`), sandbox-relative/book-scoped halt channel (`47f1d970`), restart persistence/day anchor (`eb5195a1`), tester hardening (`84144951`), and preservation of foreign-config persisted state (`6f239337`).
- **News entry gating:** native live calendar support (`ebdb5b67`), index mapping and tester-staleness correction (`89963ff7`), live UTC day/cache semantics (`41ce6633`), and event refresh/coverage warnings (`3ce7e67e`). These can change whether an otherwise valid signal is allowed to enter.
- **Risk/order context:** hardened risk sizing (`7546963a`), per-strategy magic/risk contexts (`2bd733c3`), explicit fixed-risk path (`f59855e8`), and execution-time limit-fill guard (`ae029ce5`). These are sizing and order-safety changes, not evidence-neutral recompilation noise.
- **Telemetry:** Q08 close capture (`234860d6`) and later observability work are not intended to change strategy signals, but their exact closure remains part of the binary identity.

The standing legacy execution path remains allowed unless an EA opts into strict V3 behavior, but that compatibility statement is not a substitute for compile and canary evidence. In particular, 10911's new risk cap is a visible behavior change and must be accepted explicitly; it must not be hidden inside a “KS-only” deployment description.

## Registry, preset, and profile checks

The nine target identities each have one active magic row, one generated resolver match, and a globally unique magic value:

| EA / symbol | Slot | Magic |
|---|---:|---:|
| 10911 / GDAXI | 3 | 109110003 |
| 10919 / XTIUSD | 1 | 109190001 |
| 10939 / GBPUSD | 1 | 109390001 |
| 11132 / SP500 | 0 | 111320000 |
| 11421 / EURUSD | 0 | 114210000 |
| 11421 / AUDUSD | 3 | 114210003 |
| 12567 / XNGUSD | 2 | 125670002 |
| 12567 / XAUUSD | 3 | 125670003 |
| 12989 / XAUUSD | 3 | 129890003 |

There are two important caveats:

1. `ea_id_registry.csv` contains two physically duplicated but identity-consistent active rows for EA 12567. Its magic rows and generated resolver mappings are unique, but strict target row uniqueness is therefore false.
2. The global `python framework/scripts/validate_registries.py` observation is FAIL (`ea_rows=4244`, `magic_rows=15391`) because of the existing broader registry backlog. The target-only identity check must not be relabeled a global PASS. Before signature, either the global gate must become clean or OWNER must sign an exact-baseline exception and explicitly dispose of the 12567 duplicate.

The nine active preset SHA256 values and the nine chart SHA256 values are bound in the JSON draft. Read-only profile parsing observed 25 charts, exactly nine target charts, and zero references to legacy IDs 10476, 10692, 10715, or 10940. Their old log files therefore do **not** indicate orphan charts in `DarwinexZero_V2_LiveOps`; they are stale files with no active-profile attachment. No chart or terminal interaction was used for this check.

All nine active charts retain `qm_news_stale_max_hours=336`, Friday close enabled at broker hour 21, and the expected symbol/period/slot. The live presets use live percentage-risk configuration; that is distinct from any proposed tester/canary set. Every future backtest/canary set must independently satisfy `RISK_FIXED > 0` and `RISK_PERCENT = 0`.

## Evidence-vintage consequence

MNT-043 requires every EX5 change to mark historical binary-bound evidence `EVIDENCE_VINTAGE_STALE` through an append-only adjudication overlay. Raw reports and raw verdicts remain unchanged, and admission-relevant Q gates rerun with the new EX5 SHA and closure. See [`MNT-043`](../mnt_page_updates_2026-07-28/MNT-043.md) and the [`closure/drift scanner contract`](../MNT043_044_CLOSURE_DRIFT_SCANNER.md).

The read-only scanner snapshot at 2026-07-31 17:08:27 +02:00 had fingerprint `41ae931be8df7cdd55ba660c8b08e9dbac32c2247b24e2208d902be54726b6be`: 581 adjudications, 7 already stale, 574 provenance-unverified, and 75 P0-live subjects. The affected live-symbol Q06/Q07 identities are already `PROVENANCE_UNVERIFIED / HOLD_OWNER_REVIEW`; a rebuilt binary adds explicit vintage drift. This task wrote no overlay. A future approved build must append new overlay events against its actual EX5 hashes, then rerun the admission-relevant Q evidence. Neither the build nor this plan supplies a pipeline verdict.

## Proposed build and deploy sequence — not authorized

1. **Review and source lock.** Claude reviews this change inventory. OWNER selects and signs an immutable clean commit. Recompute all 29-member closure hashes; if any differs from the draft, regenerate and review the manifest.
2. **Guardrails.** Repair the seven documented 10919/10939 time-exit setfile findings and require the same build guardrail validator to return PASS, then run EA-focused static tests. Keep `qm_news_stale_max_hours <= 336`. Any tester/canary set uses `RISK_FIXED > 0` and `RISK_PERCENT = 0`. Resolve or explicitly sign the registry caveats.
3. **Factory build only.** Compile all seven EAs serially through the registered Factory workflow into immutable staging outside T_Live and without interrupting active T1–T10 work. Capture compiler version, logs with zero errors and zero warnings, MQ5 hashes, complete closure, and staged EX5 hashes.
4. **Non-live safety canary.** In a registered tester/demo context, prove all nine identities emit `KS_BASELINE_LOADED`; prove the book-tag/halt-channel chain there, never experimentally on T_Live. Check contract init, news blackout, sizing, order flow, and signal/trade-stream deltas. Any unexplained delta blocks signature.
5. **Vintage bill.** Generate the append-only MNT-043/MNT-044 overlay for the actual new hashes and schedule the admission-relevant Q reruns. Old evidence remains historical and cannot be inherited.
6. **Final manifest and signature.** Fill the draft's null build fields and bind `source → closure → Factory EX5 → immutable stage → intended T_Live destination`, plus all presets, baselines, magic mappings, preimages, canary evidence, rollback hashes, and the approved Sunday window. Claude reviews; OWNER signs. An unsigned draft is not deploy authority.
7. **Sunday preflight and deployment.** Read-only check profile identity, open-position implications, baseline copies, current news-calendar freshness, destination preimages, and hashes. OWNER decides the controlled window. Use only the standing file-side workflow; never manually start `terminal64.exe`, never toggle AutoTrading, and never interrupt T1–T10.
8. **OWNER re-init and read-only verification.** OWNER performs the controlled Sunday T_Live re-init. Verify Factory/stage/T_Live SHA equality, nine fresh `KS_BASELINE_LOADED`, zero fresh target `KS_BASELINE_ABSENT`, `INIT_OK` and exact magic/symbol/timeframe for every chart, and unchanged preset hashes. If news staleness blocks init, refresh `D:/QM/data/news_calendar` and its FILE_COMMON copy; do not weaken the fail-closed check.
9. **Fail closed / rollback.** Any hash, registry, init, baseline, canary, or identity mismatch stops the action. Only an OWNER-signed rollback may restore the recorded preimage EX5 hashes and schedule another controlled re-init. Verification remains read-only.

## Focused verification performed for this plan

- Parsed all seven current recursive MQL5 include closures: 29 members each, zero unresolved repository includes; full shared-member and aggregate hashes are in the draft manifest.
- Ran the enforced build guardrail across all seven EA paths: five PASS; 10919 and 10939 FAIL on seven explicit time-exit setfile findings. No compile was attempted after that fail.
- Re-hashed the seven current T_Live EX5 preimages, seven historical repository EX5s, nine active presets, nine chart files, and all 27 baseline copies.
- Parsed the active UTF-16 chart profile: 25 charts, nine targets, zero legacy-ID hits; period, slot, news-staleness, Friday-close, and risk inputs captured read-only.
- Parsed the target EA/magic registries and generated resolver arrays: all nine identities consistent, one documented EA-12567 physical duplicate, global validator not clean.
- Parsed the latest structured `KS_BASELINE_ABSENT` event for every affected live sleeve and matched the old drive-letter literal to the pre-fix source.
- Ran the MNT closure/drift scanner read-only; no report or overlay was written.
- Ran the focused scanner/resolver test set: `11 passed` (`test_mnt_closure_drift.py` plus `test_magic_resolver_strict_default.py`). Manifest/hash verification and `git diff --check` also passed.

The machine-readable draft intentionally leaves build, signature, and deploy receipts null. That is the controlling evidence that this task stopped at the requested plan boundary.
