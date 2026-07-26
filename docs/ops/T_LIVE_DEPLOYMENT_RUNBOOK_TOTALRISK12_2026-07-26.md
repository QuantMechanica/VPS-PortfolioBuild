# T_Live deployment runbook — Sunday 2026-07-26, TOTAL_RISK 9.75 → 12.0

Status: OWNER-approved (A+B, 2026-07-25). Execution window: **Sunday 2026-07-26 EVENING** (OWNER chart session). Q07 rerun landed; composition = FINAL24b. This file is canonical; the Vault
copy (`G:\My Drive\QuantMechanica - Company Reference\`) is a mirror made at sign-off.

Authority: T_Live AutoTrading = OWNER + Claude only. Deployment executes only after OWNER approves
the manifest **in writing** (Decision B below).

## What changes

| artifact | from | to |
|---|---|---|
| Book risk | TOTAL_RISK 9.75 | **12.0** — same 24 sleeves, same magics, capped inverse-vol, 3 at cap, all others ×1.313 |
| Manifest | `portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json` | `portfolio_manifest_sunday_FINAL24b_TOTALRISK12_20260726.json` — FINAL24b: −10440/NDX (Q10 FAIL dd 31.0 %), +11422/USDCAD (clean admit) per decisions/2026-07-26_book_final24b_minus10440_plus11422.md (Sharpe 2.3440, MaxDD faithful 3.4952 %) |
| Presets | 24 deployed (mtime 07-19) | staged at `D:\QM\exports\tlive_presets_FINAL24b_20260726\` — 23 patched incumbents + NEW `25_USDCAD_D1_QM5_11422…` (magic 114220004, RISK_PERCENT 0.195664); preset 15 (10440/NDX) deliberately ABSENT. Diff proof: `D:/QM/reports/portfolio/staging_report_FINAL24b_20260726.json`. (The earlier `tlive_presets_TOTALRISK12_20260726\` dir is the superseded same-composition staging — do not deploy it.) |
| Binaries | live mtimes 06-28…07-17, **0/21 match repo** | Thursday-recompiled repo `.ex5` + the two basket EAs recompiled with WP-9 (Decision A) |

## OWNER decisions required before execution

- **Decision A — deploy the new binaries.** Strongly recommended: 11 live sleeves currently log the
  absolute `D:\QM\data\halt\` path — that directory is empty, their manual-halt/portfolio-DD channel
  lands nowhere. The recompiled binaries carry the relative `QM\halt\` fix. Keeping old binaries
  keeps the dead channel.
- **Decision B — written approval of the 12.0 manifest** (it is `status: DRAFT`,
  `manual_approval_required: true`). Evidence-completeness precondition (Codex challenge
  2026-07-26): before the written approval, OWNER sees the WS-C decay audit and WS-D swap
  scenario for the composition — or explicitly acknowledges each `UNKNOWN` sleeve. The
  12.0 raise scales uncapped sleeves ×~1.313 while decay/swap were unquantified; tonight
  they are quantified or acknowledged, not silent.
- Pending input: **Q07 rerun results** for the sealed cohort (11 vacuous + 13128) and the basket
  track (12778/13117 Q06+Q07 on WP-9 binaries). If a sleeve fails, composition — not the 12.0 —
  is what changes, and the manifest is regenerated over the survivors
  (`gen_dxz_final_manifest.py --total-risk 12.0 --out <new path>`).
- **Decision C (new 2026-07-26) — 12567/XNGUSD keep or drop.** Its fresh sealed Q08 is
  **FAIL_HARD twice** (07-18 + 07-25, identical pattern): `8.8_edge_decay` 41.5 % (PF first half
  1.764 → last half **1.032**, threshold 40), `8.4_seasonal` 9/12, `8.10_regime` low-vol P&L
  negative. Q10 full-history PASS (the closing verdict) stands; neighborhood / chopping-block /
  MC-shuffle all PASS; the sleeve sits **at cap 1.0**. Evidence:
  `D:\QM\reports\work_items\084a05e0-…\QM5_12567\Q08\XNGUSD_DWX\aggregate.json`.
  **KEEP** → deploy FINAL24b exactly as approved (A+B). **DROP** → deploy the staged OPTION B:
  manifest `portfolio_manifest_sunday_FINAL23_TOTALRISK12_20260726.json` (Sharpe 2.2953 vs
  2.3440, MaxDD faithful 3.9871 % vs 3.4952 % — the *historical* composite worsens because
  XNGUSD diversified; the case for dropping is *forward* decay, not history), presets
  `D:\QM\exports\tlive_presets_FINAL23_20260726\` (23 files, RISK_PERCENT sum 12.0 verified,
  report `D:\QM\reports\portfolio\staging_report_FINAL23_20260726.json`), close the XNGUSD
  chart, no preset 23.
- **Decision D (optional, 2026-07-26) — two fresh Q10-certified candidates; recommendation: no
  add tonight.** 10938/GDAXI (Q10 PASS pf 1.27 / dd 6.87 % / Q08 61 trades, sha-sealed stream)
  and 10692/NDX (Q10 PASS pf 1.08 / dd 14.87 % / 687 trades). Both are ~zero-corr to the
  composite, but **neither is Sharpe-accretive at 12.0** (10938 ΔSharpe −0.0016; 10692 −0.0055,
  though it improves faithful MaxDD by 0.42 pp at corr −0.018). Full arithmetic:
  `D:\QM\reports\portfolio\admission_eval_20260726\admission_10938_10692_20260726.json`
  (computed against both FINAL24b and FINAL23 bases). Park as documented challengers; if OWNER
  opts in tonight, the manifest+presets regenerate in-session via the gen_dxz pattern.

## OWNER decisions ANSWERED (2026-07-26 midday chat) — deploy target is now FINAL22

- **Decision C: DROP 12567/XNGUSD** („1: deine Empfehlung") **PLUS remove 10939/GBPUSD with
  re-qualification** („2: entfernen und Re-Qualifikation" — overrides the keep-recommendation;
  sealed Q08 re-qual enqueued). 10919/XTI (UNKNOWN, low-N) and 13128/NDX (WATCH) stay,
  explicitly acknowledged. → **Deploy target = FINAL22**:
  manifest `D:\QM\reports\portfolio\portfolio_manifest_sunday_FINAL22_TOTALRISK12_20260726.json`
  (Sharpe 2.2058, MaxDD faithful 4.0065 %, base-verify exact vs FINAL24b, weight err 4.3e-7),
  presets `D:\QM\exports\tlive_presets_FINAL22_20260726\` (22 files, sum 12.0 verified, report
  `staging_report_FINAL22_20260726.json`). Close the XNGUSD **and** GBPUSD-H4(10939) charts;
  presets 12 and 23 deliberately absent. **Decision B's written approval tonight applies to the
  FINAL22 manifest** (composition changed after the original „2 ja").
- **Decision D: PARK 10938/10692** („3: parken").
- **KS baselines: DEPLOY** („4: ja") — step 7 executes.
- **Swap capture: YES** („5: ja") — new step: at the terminal, snapshot
  SYMBOL_SWAP_MODE/LONG/SHORT/ROLLOVER3DAYS per the capture spec in
  `D:\QM\reports\ultracode_20260726\wsd\swap_rates_current_scenario.json` to close the
  current-rate scenario.
- **Recency axis: RATIFIED per recommendation** („6") — enforcement from the next Q10 cohort
  once the WS-C shadow patch merges tonight; quarterly rolling sealed re-Q08 for live sleeves
  (decision record `decisions/2026-07-26_q10_recency_axis_enforcement.md`).
- **FTMO B1 contract D1-D6: RATIFIED** („7: ja"; D5 min-trading-days read from the NEW trial
  account, which OWNER creates tonight — „9: ja heute Abend").

## Execution sequence (Claude, after A+B)

1. **Verify quiescence & T_Live health.** T_Live terminal running, watchdog tasks Running/Ready.
   Factory state irrelevant to T_Live but note it in the decision record.
2. **Binaries** (Decision A): copy per sleeve from `C:\QM\repo\framework\EAs\<label>\<label>.ex5`
   to `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs\`. Then **SHA256 factory == T_Live for all
   21 unique binaries** — record the table. The two basket EAs must be the post-WP-9 rebuilds
   (`--force`; verify `verdict: COMPILED`, not `COMPILED_CACHED`, and the new SHA differs from
   `367B047A…`/`1FEDB7B5…`).
3. **Presets:** copy the 24 staged files over `C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\`. Verify
   each against `_staging_report.json` (`sha256_staged`). Sum of RISK_PERCENT = 12.0 (±1e-6).
4. **Magic registry:** every preset's `ea_id*10000 + qm_magic_slot_offset` == manifest
   `magic_number` (was 24/24 on 07-25; re-verify after copy).
5. **Symbols:** live charts/presets use **broker symbols without `.DWX`** — `.DWX` custom symbols
   are tester-only. Preset filenames already carry bare symbols (`04_XTIUSD_…`); chart symbol per
   sleeve = the bare form (EURUSD, XAUUSD, GDAXI, …).
6. **News filter:** live = native MT5 calendar (DL-080; CSV staleness is tester-only). Verified
   healthy 07-25: `NEWS_CALENDAR_LOADED rows=96123`, selftest `healthy:true`. Re-check both log
   lines in `MQL5\Files\QM\QM5_*_ea-*.log` after terminal restart, plus `KILL_SWITCH_INIT` showing
   the **relative** `QM\halt\` path on all 24 (closes the 11-sleeve dead-channel finding).
7. **KS baselines:** per WP-11 the existing baselines are corrupt (gross vs net + parser).
   Regenerated NET baselines are staged at `D:\QM\reports\state\q10_baselines_regen_wp11_20260725\`.
   Deploying them into `Common\Files\QM\baselines\` is OWNER-gated and requires the WP-11 review to
   have passed. If not deployed, note: the KS layer stays unreliable (16 dormant / 8 false-kill) —
   the 3 % daily-loss halt and the DD guard remain the operative protections.
8. **AutoTrading:** OWNER or Claude flips it, only after 1–7 are green.
9. **Decision record:** `decisions/2026-07-26_t_live_totalrisk12_deploy.md` with the SHA table,
   preset verification, calendar check, Q07 rerun outcomes and both OWNER decisions. Mirror the
   runbook to the Vault. Then **`Factory_ON.ps1 -NoPause`** — and per the WP-1b audit, no new bulk
   synth/ablation injection waves.


## FINAL24b additions to the sequence

- Step 2 addition: **11422 is a NEW EA on T_Live** — copy its `.ex5` (sha `159e6168…`), open a
  USDCAD D1 chart (broker symbol, no .DWX), attach with preset 25. Verify `KILL_SWITCH_INIT`
  and `NEWS_CALENDAR_LOADED` appear in its `MQL5\Files\QM\` log after attach.
- Step 2 OVERRIDE for 1567 (2026-07-26 05:56Z): the repo working tree now holds a NEW seed-wired
  1567 build (sha `87486226…`, exposes `qm_rng_seed`/stress inputs) whose fresh Q07/Q10 evidence
  is still queued. **Do NOT copy 1567 from `framework/EAs\` tonight unless a Q10 PASS on sha
  `87486226…` has landed.** Default deploy source = the evidence-anchored Thursday binary staged
  at `D:\QM\exports\tlive_binary_1567_thursday_20260726\` (sha `ee2a437d…`, git `a181f57c286f`,
  SHA proof in `SHA256.txt`; the 07-25 Q10 PASS ran on THIS blob).
- Step 3 addition (reboot damage 2026-07-26): **12778/AUDUSD's chart is MISSING from the live
  profile** since the 00:27 VPS reboot — the unclean shutdown profile save dropped it (clean
  DEINIT reason 9 at 00:24, no load line after the 06:36 restart; the profile now has one AUDUSD
  chart instead of two, plus one expert-less EURUSD chart). Recreate the AUDUSD D1 chart, attach
  QM5_12778 with staged preset 06, delete the orphan EURUSD chart, verify `INIT_OK` +
  `KILL_SWITCH_INIT` in `MQL5\Files\QM\QM5_12778_ea-12778.log`. **Post-deploy invariant: chart
  inventory == manifest (24 EA charts + QM_AccountMonitor), count per symbol verified** — the
  profile save has proven lossy across unclean shutdowns.
- Step 3 addition: **remove** the deployed `15_NDX…QM5_10440` preset and close the 10440 chart
  (sleeve removed; decision record has the Q10 FAIL evidence).
- Verification addition: 11422's preset carries no explicit `qm_filter_*` block (relies on EA
  defaults + `qm_news_compliance=DXZ` / `PRE30_POST30`) — confirm the news self-test line for
  11422 specifically.

## Evening-window activation appendix (post-round-3, 2026-07-26)

Codex round-3 verdict (`docs/ops/evidence/2026-07-26_codex_review_round3.md`):
WAVE-READY(wsa2, wsc1, wsc2, wsd2, WS-E1, wse32, wse42, wsg2) — cumulative merge simulated
clean, 382 tests green after all eight. Sequence for the Factory-OFF window, BEFORE the
T_Live deployment steps above:

1. **Factory_OFF** + quiescence proven by process scan (echo '' | Factory_OFF.ps1; verify
   no terminal64/phase-runner/pump lineage remains — Factory_OFF does not reap runners).
2. **Patch merges in Codex's exact order** (re-run `git apply --check` at the live HEAD
   first): wsa2 → wsc1 → wsc2 → wsd2 → wse1 → wse32 → wse42 → wsg2 (+ wse23 and wsf3 in
   their slots — after WS-E1/wse32 resp. before wsg2 — once their micro-review passes).
   Patches live under `D:\QM\reports\ultracode_20260726\<ws>*\`. Preserve LF on the
   watchdog file. Commit series with explicit pathspecs, one commit per workstream.
3. **WS-E1 activation edge:** the minute-task rereads the watchdog script — the merge IS
   the activation; do not install/start anything. Verify `live_alarm_state.json` appears.
4. **Worker restart + claim canary** (one worker, observe ordering: priority_track >
   frontier > recovery idle-cap ≤1/5), then **requeue canary-50**
   (`requeue_stranded_infra.py --limit 50 --apply --snapshot-out <journal>`), verify, then
   full Factory_ON only AFTER the T_Live session completes.
5. **Recovery-classifier apply** (CAS-tag ~1,678 rows, census regenerated Factory-OFF
   first) + regenerate WS-A census.
6. **FINAL22 deploy-stamp (NEW, before written approval):** stamp the manifest with
   account 4000090541, server, deployment_epoch, manifest SHA-256, phase, and per-sleeve
   ex5_sha256 pins (fields per wse32/wse22 deploy-stamp contract), then OWNER signs.
   Close the wse32 pre-deploy diff: restore 12778, add 11422 chart, remove
   10939/10440/XNGUSD charts+presets, apply 19 risk re-sizes — then re-run
   `verify_live_deployment_contract` and require GREEN before the AutoTrading flip.
7. **Open diagnostics carried into the session:** 12969 five-market-day telemetry silence
   (binary/runtime — check deployed binary age vs source emit-call); 1567 lacks
   QM_EquityStreamOnNewBar entirely (source gap — schedule with its pending requal
   rebuild, do NOT hot-patch tonight).
8. Activation stays blocked for: WS-G MQL parity/compile (terminal work, separate),
   wse22/wsf2 until micro-review passes, wsb2 doc artifact (fixed, pending re-check).

## Rollback

Presets: the deployed 07-19 files are preserved in the staging report (deployed SHA256) and on
disk until overwritten — take a copy of `Presets\` before step 3. Binaries: keep the current
`Live EAs\` set in a dated backup dir before step 2. Risk rollback = redeploy the 9.75 presets
(they reproduce exactly via `gen_dxz_final_manifest.py` defaults). Anything ambiguous → halt via
the manual halt files (post-fix channel) rather than AutoTrading toggling mid-session.
