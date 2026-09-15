# DXZ live book — current + planned v2 cutover (audit)

Read-only audit for the CONTINUOUS BOOK EVOLUTION directive (§0–§1, §2, §9, §10, §68A).
Author: read-only auditor subagent. As-of: 2026-09-15 ~12:32Z. Working dir C:/QM/repo.
Directive: `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md`.

## Headline

1. DXZ is **live now** as a **24-sleeve** book on account **4000090541**, total risk **9.7499 %**, equity ~**99,389** (HWM 101,871, DD 2.44 %, halt at 10 %) — running, fresh, ENV=live, RISK_FIXED=0. The **v2 cutover has NOT happened yet**: recovery pointer absent, current profile is still `DarwinexZero_V2_LiveOps`, presets 01–24 unchanged.
2. The planned Sunday 2026-09-20 book is **28 sleeves / 29 charts** (28 trading + 1 `QM_AccountMonitor` monitor chart), applied cutover risk **9.801297 %** (VERIFIED = sum of the 28 non-monitor chart risks in `profile_manifest.json`). The **11.0 %** in the deploy manifest is the post-burn-in design budget (cap 1.5 %); the 4 new sleeves cut over at reduced burn-in weight, so the book cuts over at 9.8013 % and ramps toward 11.0 %.
3. All ceremony steps except two are autonomous (Freifahrtsschein 2026-09-15). **OWNER-only:** (a) add XAGUSD + WS30 to the T_Live Market Watch on Sunday before the ceremony; (b) the AutoTrading toggle stays exactly as the OWNER set it. Live per-sleeve evidence for weekly recomposition is **stale/partial** and is the main gap for §6/§58.

## Findings

### A. Current live DXZ book (as it runs today)

1. **Account / equity are live and fresh.** `D:/QM/reports/state/live_book_dd_guard_state.json`: `account_login=4000090541`, `last_equity=99389.17`, `hwm_equity=101871.44`, `last_dd_pct=2.4367`, `halt_dd_pct=10.0`, `breached=false`, `equity_observed_at_utc=2026-09-15T12:29:29Z` (source `account_snapshot`, age 56 s). Book tag `DXZ_4000090541`.
2. **Roster = 24 sleeves.** Deployed presets `C:/QM/mt5/T_Live/MT5_Base/MQL5/Presets/01..24_*.set` and matching EAs in `.../MQL5/Experts/Live EAs/` (24 `.ex5`). Book manifest `D:/QM/reports/state/live_book_pulse.json → book_manifest`: `portfolio_manifest_live_24sleeve_20260724.json`, sha256 `8c719b08…`, declared=actual=expected=24, enabled=true.
3. **Current total live risk = 9.7499 %** (sum of `RISK_PERCENT` across the 24 deployed `.set` files; per-file values below). Every set carries `; environment: live` and `RISK_FIXED=0` (checked `01_GDAXI…set`). Magic scheme `qm_magic_slot_offset` → e.g. 1556 magic 15560004 (`live_deployment_pointer.json`).
4. **Current book runtime is healthy.** `D:/QM/reports/state/live_uptime_watchdog.json` (ts 2026-09-15T12:32:06Z): `dxz_running=true`, `dxz_pids=[9288]`, `dxz_contract_ok=true`, session 1. Launch confirmed `live_launcher_events.jsonl` last DXZ launch 2026-09-11T19:46:38Z exit_code 0 `launched` (pid 9288 matches).
5. **Two live-health WARNs open.** `live_book_pulse.json → alarms`: `loaded_ok=23/24; missing_files=1` (WARN) and `journal_stale_gt_120m_open_position` (journal age 251 min, WARN). Pulse generated_at 2026-09-15T12:30:01Z.
6. **Three "dark" sleeves not trading (root cause = symbol literal).** `live_sleeve_drift.json`: `12778|AUDUSD` ALARM_DARK (0 fills / 47 days), `12969|USDJPY` ALARM_DARK (0 fills / 47 days), `13117|EURGBP` ALARM_DARK (0 fills / 46 days). `ANLEITUNG_DXZ_V2.md` §"Symbol-Literal-Defekt": those 3 EAs compare chart symbol against hard-compiled `".DWX"` literals while T_Live uses bare broker names, so entry paths never execute (violates the 2026-09-06 Hard Rule "symbols are inputs"). Exactly the 3 `.DWX`-literal EAs are dark; the other 21 trade.

Per-sleeve current live risk (source: the 24 deployed `.set` files):

| Preset | EA | Symbol | RISK_PERCENT |
|---|---|---|---|
| 01 | 13301 balke-minute-range-breakout | GDAXI | 0.0692 |
| 02 | 13213 balke-gmt3-range-breakout | USDJPY | 0.0431 |
| 03 | 1567 demark-td-reverse-seq-h4 | EURUSD | 0.1791 |
| 04 | 10919 grimes-overshoot | XTIUSD | 0.9181 |
| 05 | 11165 weiss-rsi-ma | AUDCAD | 0.5230 |
| 06 | 12778 edgelab-cointegration | AUDUSD | 0.4905 (DARK) |
| 07 | 11421 ohlc-daily-squeeze-rev | AUDUSD | 0.3614 |
| 08 | 11165 weiss-rsi-ma | EURUSD | 0.4127 |
| 09 | 11421 ohlc-daily-squeeze-rev | EURUSD | 0.3364 |
| 10 | 11708 anon-market-squeeze-d1 | EURUSD | 0.5080 |
| 11 | 10706 tv-mon-ls | GBPUSD | 0.0530 |
| 12 | 10939 grimes-context-pb | GBPUSD | 0.1887 |
| 13 | 10911 grimes-complex-pb | GDAXI | 0.1276 |
| 14 | 13128 pre-fomc-drift-ndx | NDX | 1.0000 |
| 15 | 10440 mql5-ohlc-mtf | NDX | 0.0577 |
| 16 | 11132 tm-cum-rsi2 | SP500 | 0.4562 |
| 17 | 12969 usdjpy-gotobi-nakane | USDJPY | 0.5100 (DARK) |
| 18 | 10403 et-turtle20x | XAUUSD | 0.2204 |
| 19 | 10513 mql5-ichimoku | XAUUSD | 0.3050 |
| 20 | 12567 cum-rsi2-commodity | XAUUSD | 0.7465 |
| 21 | 12989 grimes-nested-pb-v2 | XAUUSD | 0.2420 |
| 22 | 1556 aa-zak-mom12 | XAUUSD | 0.6017 |
| 23 | 12567 cum-rsi2-commodity | XNGUSD | 0.9797 |
| 24 | 13117 eurgbp-audjpy | EURGBP | 0.4199 (DARK) |
| **Σ** | 24 sleeves | | **9.7499** |

"Since when": the 24-sleeve book is the `portfolio_manifest_live_24sleeve_20260724.json` roster (live since ~2026-07-24; profile `DarwinexZero_V2_LiveOps` created 2026-07-26). Per-sleeve first-live dates are only approximable from `live_sleeve_drift.json` `days_live` (e.g. 10440/NDX 57d ≈ 2026-07-20, most others 46–47d ≈ 2026-07-30). Preset bytes last refreshed via the 10-preset repair (risk-freeze receipt 58b96908). Exact per-sleeve activation dates: **UNKNOWN** at file level (not carried in the manifest).

### B. Planned v2 book (Sunday 2026-09-20 cutover)

7. **Authoritative artifact = the profile manifest, not the 28-sleeve risk manifest.** `C:/QM/deploy/DXZ_V2_20260913/profile/DarwinexZero_Book2_LiveOps/profile_manifest.json` (generated 2026-09-15T07:53:27Z): `profile_name=DarwinexZero_Book2_LiveOps`, `n_sleeves=28`, `n_charts=29`, `total_risk_percent_at_cutover=9.801297`, kinds `{reweighted:23, replaced:1, new:4, monitor:1}`, `problems:[]`. The 29th chart is `QM_AccountMonitor` (chart_no 29, kind `monitor`, no trading risk) — this is the "+1" that makes 29 charts for 28 trading sleeves.
8. **29 charts / 9.8013 % is VERIFIED.** Sum of the 28 non-monitor chart `risk_percent` values in `profile_manifest.json` = **9.801297**, exactly the declared `total_risk_percent_at_cutover`.
9. **The 11.0 % figure is a different number (design budget, not cutover).** `manifest_v2_28_r11.json`: `total_risk_percent=11.0`, and its 28 sleeve `risk_percent` values sum to **11.0** exactly. The gap (11.0 vs 9.8013) is because the **4 new sleeves cut over at reduced burn-in weight**, not their full manifest weight — e.g. 1537/XAGUSD full weight 0.46845 (manifest) but 0.0769 in the profile (`presets/new_burnin/25_XAGUSD…set`). This is directive §10-compliant probation weighting (evidence-based introduction, not min-lot). Full design target after burn-in ≈ 11.0 %. **Both numbers are correct for different stages** — report 9.8013 % as the cutover risk, 11.0 % as the post-burn-in target.
10. **Change vs current = +4 new sleeves, 0 removals, 24 reweights, 1 binary replace.** New sleeves (from `manifest_v2_28_r11.json`, `is_new_sleeve:true`): **1537/XAGUSD (0.468), 9641/WS30 (0.373), 10700/XAUUSD (0.089), 13013/NDX (0.379)** — all at reduced burn-in risk at cutover. Binary replace: **41470 replaces 12969/USDJPY** (recompiled symbol-literal fix; `copy_plan_v3_cutover.json` class `repair_v2_41470` ×2, profile kind `replaced`). All existing 24 sleeves reweighted.
11. **Deploy plan = 34 copy items, preflight all-green.** `copy_plan_v3_cutover.json`: 24 `existing_risk_change` + 4 `new_binary` + 4 `new_preset_burn_in` + 2 `repair_v2_41470`; destination `C:/QM/mt5/T_Live/MT5_Base`, book `DXZ_4000090541`, as_of 2026-09-20, owner_approval_evidence `decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md`. Cutover preflight `D:/QM/reports/state/tlive_book_cutover_plan_20260915T080123Z.jsonl` (2026-09-15T08:01:27Z): `preflight_result ok=true, failed=[]` (single T_Live process pid 9288, freeze lifted, recovery pointer absent, governor SHAs bound).
12. **Two sleeves deferred out of v2.** `copy_plan_v3_cutover.json → skipped_pending`: 13054/XTIUSD and 21505/XAGUSD both `DEFERRED_SYMBOL_LITERAL_FIX`, plus 3 `dark_sleeve_repair_noop_until_source_fix` entries (the 12778/13117/12969 dark class). 12778 and 13117 stay dark no-ops in v2 (`BOOK_SPRINT_2026-09-20.md` D7, "accepted"); 12969 is fixed by the 41470 replace.
13. **Recovery pointer wiring is in place but inert (cutover not yet run).** `tools/strategy_farm/tlive_recovery_profile.ps1`: when `D:/QM/reports/state/tlive_recovery_profile.json` is written by the ceremony it makes `T_Live_ON.ps1` resume `DarwinexZero_Book2_LiveOps` and verify via `build_tlive_book_profile.py verify`. That pointer file **does not exist yet** (searched D:/QM; and cutover preflight `recovery_pointer_absent ok=true`), so the launcher still resumes the current `DarwinexZero_V2_LiveOps`.

### C. Where live performance evidence lives + freshness

14. **Live trade / deal stream (raw):** `C:/QM/mt5/T_Live/MT5_Base/Bases/Darwinex-Live/trades/4000090541/deals_2026.09.dat` (last write 2026-09-11T21:46). This is the source of the DXZ D-Score (computed externally by Darwinex from this deal stream). **Caveat (CLAUDE.md):** T1–T10 share the same Darwinex-Live account, so factory journals mirror these ticket lines — not a source of live-book truth by themselves.
15. **Normalized per-sleeve attribution:** `D:/QM/reports/portfolio/live_attribution_20260905_054540/` — `live_deals_normalized.csv` (2026-09-04T20:00), `validation.json` (2026-09-05T07:46), `audit_live_book_inventory.json` (2026-09-05T07:38). **Stale ~10 days** — this is the only per-sleeve PnL attribution artifact and it predates the sprint.
16. **Live equity / DD (fresh):** `live_book_dd_guard_state.json` (age 56 s) + `live_book_dd_guard.log`. Uptime `live_uptime_watchdog.json/.jsonl` (fresh). Book health `live_book_pulse.json` (2026-09-15T12:30Z, per-run) with sub-contracts (magic_registry, preset_consistency, deploy_pointer_reconciliation, terminal_journals).
17. **Sleeve activity / dark detection (fresh):** `live_sleeve_drift.json` (Poisson fill-rate alarms per sleeve). **This is the closest thing to a live per-sleeve evidence feed** but it measures *activity*, not PnL/return/correlation.
18. **D-Score inputs:** there is **no internal DXZ D-Score projection file** (search for `*dscore*`/`*d_score*` returns only an unrelated factory EA `QM5_41257_wti-mmedscore524-tr`). D-Score is Darwinex-side; QM ingests nothing back. **Gap.**

### D. Sunday ceremony — pending steps and OWNER-only

Fixed sequence (`BOOK_SPRINT_2026-09-20.md` D6; `decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md`; `ANLEITUNG_DXZ_V2.md`):

| Step | Actor | Status |
|---|---|---|
| 0. Add **XAGUSD + WS30** to T_Live Market Watch | **OWNER only** (Sunday, "Market Watch mache ich Sonntag") | open — if missing at 09:00 local, charts 25/XAGUSD + 9641/WS30 are skipped, rest cuts over |
| 1. `stage_tlive_presets_risk.py --apply` (24 reweighted presets) | Claude (autonomous, freeze lifted) | ready (staging verified) |
| 2. Deploy copy-plan v3 (34 items) | Claude | ready (preflight green 08:01Z) |
| 3. Load profile `DarwinexZero_Book2_LiveOps` (28 charts + monitor) + reseal | Claude (Freifahrtsschein covers the monitor attach) | ready |
| 4. Controlled T_Live restart (writes recovery pointer) | Claude | ready (pointer wiring 9977ae7c2c) |
| 5. Verification: SHA256 factory→T_Live, magics `ea_id*10000+slot`, ENV/risk-mode, calendar → `claude_verification_signature` | Claude | pending (runs in-ceremony; `claude_verification_signature` currently PENDING) |
| 6. Governor enforce switch | Claude | pending (closes freeze condition 3) |
| —. **AutoTrading toggle** | **OWNER only — Hard Rule, never touched by any AI seat** | stays as OWNER set it |

Residual Nacharbeit carried by the OWNER lift (not blockers): 11 Q10_NEWS `REVIEW_REQUIRED` rows + flag `QM_NEWS_IMPACT_MAPPING_V2` activation (freeze condition 2 residue); 1537/XAGUSD commission evidence OPEN (no live deal history yet, Q16 check 6); check 10 magic-embedding verify for 9641/WS30 after attach.

### E. What a weekly-recomposition live feed needs that does not exist

Per directive §6 (weekly recomposition) and §58 (continuous portfolio engine), the recomposition engine needs live inputs that are currently missing or stale:

19. **Fresh per-sleeve live PnL/return series** — only artifact is `live_attribution_20260905…` (10 days stale, one-off run). No weekly/automated per-sleeve attribution refresh.
20. **Live correlation / trade-overlap / downside-correlation matrix** from live deals — **does not exist**. §7/§8 marginal-contribution analysis needs it.
21. **Live-vs-book comparison for the actual roster** — `book_monitor_state.json` tracks only a **5-sleeve candidate pool** (10513/10940/11124/11132/12567), not the live 24 (or planned 28). `sunday_livevsbook_compare.log` exists but is not a structured per-sleeve feed. **Stale/mismatched.**
22. **Internal D-Score ingestion** — no feed pulls Darwinex D-Score back into `reports/state` for the engine (see finding 18).
23. **Dark-sleeve exclusion** — 12778 & 13117 produce zero live evidence indefinitely (symbol-literal, no source fix scheduled in v2); any live-evidence weighting must treat them as no-data, not zero-return.

## Drift table

| Topic | Doc/vault/manifest says | Runtime / authoritative artifact says | Path |
|---|---|---|---|
| v2 book risk | Deploy manifest `total_risk_percent=11.0` (28 sleeves sum 11.0) | Cutover applies **9.801297 %** (profile 28 non-monitor charts) — 4 new sleeves at burn-in weight | `manifest_v2_28_r11.json` vs `profile/DarwinexZero_Book2_LiveOps/profile_manifest.json` |
| Chart count | Sprint/decision prose: "28 charts + monitor" / "profile V3 (28 charts)" | Profile has **29 chart files** (28 trading + `QM_AccountMonitor` chart 29) | `BOOK_SPRINT_2026-09-20.md` D6 vs `profile_manifest.json n_charts=29` + `profile/DarwinexZero_Book2_LiveOps/chart29.chr` |
| Profile name | Decision #3 & sprint call it "profile V3" | Actual profile name is `DarwinexZero_Book2_LiveOps`; `DarwinexZero_V3` is a separate older dir in T_Live | `decisions/2026-09-15…` vs `profile_manifest.json` + `MQL5/Profiles/Charts/` |
| Risk freeze | `live_risk_freeze.json status=LIFTED` (top field) | Same file lists 3 lift_conditions still BLOCKED/PARTIAL; OWNER 2026-09-14 written lift overrides them (Freifahrtsschein) — file's condition block is stale | `live_risk_freeze.json` vs `decisions/2026-09-14_owner_risk_freeze_lift.md` + `2026-09-15_owner_freifahrtsschein…` |
| Book monitor | `book_monitor_state.json` = 5 sleeves (candidate pool) | Live book is 24 sleeves; planned 28 — monitor does not track the live roster | `book_monitor_state.json` vs `live_book_pulse.json → book_manifest` |
| Cutover status | Sprint reads as "ready for Sunday" | Cutover **not executed**: recovery pointer absent, presets still 01–24, profile still `DarwinexZero_V2_LiveOps` | cutover preflight `…080123Z.jsonl` + absent `D:/QM/reports/state/tlive_recovery_profile.json` |
| Per-sleeve attribution | (implied current) | Latest attribution run **2026-09-05** (~10 days stale) | `D:/QM/reports/portfolio/live_attribution_20260905_054540/` |

## Open questions strictly requiring OWNER

None new for this audit scope. The only OWNER acts are already decided and scheduled: (a) add XAGUSD + WS30 to the T_Live Market Watch Sunday, (b) the AutoTrading toggle. Both are covered by `decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md`.

## Recommended actions (for implementing phases B–H)

1. **Report both risk numbers explicitly** everywhere the v2 book is described: cutover **9.8013 %** (28 non-monitor charts, 4 new at burn-in weight) → post-burn-in target **11.0 %**. Fix the "28 charts" prose to "29 charts (28 + monitor)". Files: `docs/ops/BOOK_SPRINT_2026-09-20.md`, Mission Control Book-Evolution view, `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` (§68A/§60 build).
2. **Phase E portfolio engine — build the missing live feed**: an automated per-sleeve live attribution refresh (extend `live_attribution_*`), a live correlation/trade-overlap matrix from `Bases/Darwinex-Live/trades/4000090541/deals_*.dat`, and a live-vs-book comparison keyed to the actual roster (retire/repoint the stale 5-sleeve `book_monitor_state.json`). These are the §6/§58 inputs; today only activity (`live_sleeve_drift.json`) and equity (`live_book_dd_guard_state.json`) are fresh.
3. **Phase E — ingest DXZ D-Score** into `D:/QM/reports/state/` so the recomposition engine has the allocation signal (finding 18/22); currently no internal D-Score artifact exists.
4. **Q17 refactor (§10)**: the v2 book already implements evidence-based probation weighting (4 new sleeves at reduced burn-in risk, not min-lot) — codify this as the Q17 introduction stage, using the profile's burn-in vs full-weight split as the reference example. Files: `docs/ops` Q17 refactor + vault Q17 page.
5. **Dark-sleeve source fix (Codex work, not a book blocker)**: patch the `.DWX` symbol literal in 12778 + 13117 (same fix already applied as 41470 for 12969), recompile, DL-089 requalify — then they become live-evidence-bearing sleeves. Until then, treat them as no-data (not zero-return) in any live weighting. Ref: `ANLEITUNG_DXZ_V2.md` §Symbol-Literal-Defekt; Hard Rule 2026-09-06.
6. **Ceremony verification artifact**: ensure step 5 writes `claude_verification_signature` (SHA256 factory→T_Live, magic `ea_id*10000+slot`, ENV=live/RISK_FIXED=0, calendar present) and record under `decisions/2026-09-20_t_live_dxz_book_v2.md` per the CLAUDE.md T_Live workflow step 5.
7. **Clean the stale condition block** in `live_risk_freeze.json` so `status=LIFTED` is not contradicted by BLOCKED/PARTIAL sub-conditions (documentation drift, §65/§66).
