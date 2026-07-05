# T_Live decision — D2-d S3: 15-sleeve book (2 admissions + exit-surgery swap + capped inv-vol reweight)

**Status: OWNER-APPROVED (S3) — FILE-SIDE DEPLOYED; CHART APPLICATION = SUNDAY SESSION**

## Decision

OWNER selected **S3** (chat, 2026-07-04, "Ja los gehts, ich folge deinen Empfehlungen und nehm s3")
on the D2-d composite package `docs/ops/evidence/D2D_COMPOSITE_PACKAGE_2026-07-03.md`:

1. **ADMIT QM5_10919 grimes-overshoot / XTIUSD H4** (magic 109190001, RISK_PERCENT 1.0000 capped)
   — Q09 PASS_PORTFOLIO 07-03, PF 8.40, corr 0.19, adds Sharpe +0.21 and cuts book MaxDD.
2. **ADMIT QM5_10476 mql5-pamxa / USDCAD H1** (magic 104760004, RISK_PERCENT 0.2227)
   — Q09 PASS_PORTFOLIO 07-03, PF 1.27, 233 trades, corr 0.07.
3. **SWAP QM5_10940 → QM5_12989 grimes-nested-pb-v2 / XAUUSD H4** (magic 129890003,
   RISK_PERCENT 0.5431) — exit-surgery challenger, CHALLENGER_SUPERIOR with BOTH Sharpe and
   DD improving; full cascade Q02→Q08 same day.
4. **Reweight all 15 sleeves**: capped inverse-vol, 1.0% hard cap, total risk UNCHANGED 9.75%.

S3 vs current flat-13 on frozen streams: Sharpe 1.44→2.03, MaxDD 15.3%→4.8%, VaR95m
4.64%→2.07%, annual 16.9%→11.2%. Supersedes the Variant-B-v1/v2 13-sleeve reweight
(`2026-07-03_t_live_d2c_variant_b_riskparity_reweight.md`) — its charts step never executed;
S3 presets replace the v1 set wholesale.

## File-side deployment log (2026-07-04, Claude)

- **Preset regeneration (defect caught pre-deploy):** the lane-staged S3 presets carried NO
  strategy params for carry-over sleeves (would have silently reset 9 live sleeves to compiled
  defaults, incl. OWNER-decided 12567 `cum_rsi_entry=30.0` and 11165 tuned RSI values).
  Regenerated as **staged_s3_v2**: carry-over base = CURRENT LIVE preset with only
  RISK_PERCENT/RISK_FIXED/PORTFOLIO_WEIGHT normalized; new sleeves 10476/12989 = lane-staged
  (params present, canonical evidence basis); 10919 = canonical backtest set.
- **10919 has deliberately ZERO strategy params**: its entire Q08/Q09 evidence (PF 8.40) was
  produced on compiled defaults with a param-empty canonical set. Live deploys identically
  (survivor purity). Do NOT "fix" this by injecting params — that would decouple live from
  evidence.
- ✅ Verification: 15/15 presets — RISK_PERCENT matches the S3 table, RISK_FIXED=0; 12/12
  carry-overs param-identical to their current live presets (BOM-aware diff).
- ✅ Copied to `T_Live\MT5_Base\MQL5\Presets\` as `*_d2d_s3_live.set` (new names, nothing
  overwritten); SHA256 15/15 identical to staged (`C:\QM\deploy\D2d_S3_2026-07-04\`).
- ✅ New binaries deployed to `MQL5\Experts\Live EAs\`: QM5_10919, QM5_10476, QM5_12989 —
  SHA256 identical to framework builds (3/3).
- ✅ News calendar current (2026-07-03 05:30 refresh).
- ⚠️ live_book_pulse WARN `journal_stale_gt_120m` at deploy time (~4h, around midnight, quiet
  market; terminal process running) — watch item, re-check before Sunday session.

## Sunday session checklist (OWNER, terminal UI; Claude verifies after)

1. Pre-check: Claude confirms pulse healthy + 10940 position FLAT (if a 10940 position is
   open, close it or postpone its chart removal until flat).
2. 12 existing charts (all except 10940): EA Properties → Load → matching `*_d2d_s3_live.set`.
3. 10940 chart: remove EA (chart can stay/be deleted) — only when flat.
4. 3 new charts: XTIUSD H4 → attach QM5_10919 + slot1 preset; USDCAD H1 → attach QM5_10476 +
   slot4 preset; XAUUSD H4 → attach QM5_12989 + slot3 preset.
5. AutoTrading state untouched throughout; sizing affects new entries only.
6. Claude: journal re-init verification, live_book_pulse consistency (15 sleeves), record
   "Charts applied" here.

Rollback: original 13 presets remain in place untouched (plus dated backup
`C:\QM\deploy\VariantB_reweight_2026-07-03\preset_backup\`); reload per chart; detach the 3
new EAs.


## Saturday prep log (2026-07-04, Claude — OWNER-authorized cleanup)

- ✅ Full backup: 41 presets + 14 EA binaries → `C:\QM\deploy\D2d_S3_2026-07-04\pre_sunday_backup\`
- ✅ Cleanup executed: 26 obsolete presets deleted (13 originals + 13 Variant-B-v1); ONLY the
  15 `*_d2d_s3_live.set` remain in T_Live Presets; post-cleanup SHA 15/15 identical to staged.
- ✅ OWNER guide written: `C:\QM\deploy\D2d_S3_2026-07-04\ANLEITUNG_SONNTAG.md`
  (note: 11132 preset filename carries a wrong slug, content verified — match by magic).
- ✅ T_Live post-reboot autostart verified: `QM_T_Live_AtLogon` + `FactoryON_AtLogon` enabled.
- Controlled VPS reboot Saturday afternoon (LSM/session repair; market closed; no Factory_OFF
  needed — plain reboot uses the designed autologon recovery chain). 10940 binary deletion
  deferred until after Sunday chart detach.

## Sunday pre-session verification (2026-07-05 evening, Claude)

- ✅ Provider-panel reboot landed 15:26 local; `sunday_go_ampel.ps1` = **GO**
  (4 boot-grace WARNs, all cleared: watchdog+governor now result=0 with jsonl
  heartbeat; lsm probe reinstalled).
- ✅ `install_hygiene_and_lsm_tasks.ps1` executed: HygieneReboot + LsmHealthProbe +
  WorkerDedupe registered (all Ready).
- ✅ `live_book_pulse` verdict OK; 13 experts `loaded successfully` post-reboot;
  T_Live S3 preset SHA re-verified **15/15** vs `post_cleanup_sha256.txt`.
- ✅ News calendar refreshed 2026-07-05 15:42 local.
- ★ **10940 position is CLOSED** — broker sync `'4000090541': 0 positions` repeatedly
  today incl. post-reboot 15:27:06 (terminal journal 20260705.log). The EA log holds
  no TM_CLOSE (close happened broker-side while disconnected/market closed; position
  was BE-secured, worst case ≈ 0). Terminal > derived logs. → **Teil 2 (10940 EA
  removal) is UNBLOCKED for tonight's session**; OWNER to note the closing deal
  timestamp from the History tab for this record.

## Sign-off

- Package recommendation (S3): Claude, 2026-07-04, on evidence D2D_COMPOSITE_PACKAGE_2026-07-03
- **Decision + manifest approval: OWNER, 2026-07-04, chat — "Ja los gehts … nehm s3"**
- File-side deployed: **2026-07-04, Claude (15 presets + 3 binaries, SHA-verified)**
- **Charts applied: 2026-07-05 ~16:13–16:23 local, OWNER (Teil 1+2+3 in one session —
  10940 was flat, so Teil 2 ran same-day).** Claude verification evidence:
  - Journal 20260705.log: 10940 `removed` 16:13:10; 10919 (XTIUSD,H4) / 10476
    (USDCAD,H1) / 12989 (XAUUSD,H4) `loaded successfully` 16:16–16:18.
  - QM EA logs: fresh `INIT_OK` for **all 15 sleeves** 16:17–16:23 local; magic set
    matches the S3 target table **15/15, 0 unexpected** (magic comes from the preset →
    proves correct preset per chart).
  - `live_book_pulse`: verdict **OK**, loaded_sleeve_count **15**, alarms **[]**
    (pulse updated same day: EXPECTED_LIVE_SLEEVES 13→15 + removal-aware journal count).
  - Obsolete `QM5_10940_grimes-nested-pb.ex5` deleted from Live EAs (backup in
    `pre_sunday_backup\`). AutoTrading untouched throughout.
  - ✅ Closing loop resolved (OWNER, 2026-07-05 chat): 10940 ticket 3162733509 closing
    deal = **2026-06-30 09:32** (DXZ live account history; BE-stop, worst case ≈ 0).
    The position had therefore been flat since Tuesday 06-30 — the Sat-night (07-04)
    "position still open" reading was a stale EA-log artifact: server-side SL/TP fills
    never appear as TM_CLOSE in EA-derived logs. Lesson: position state comes ONLY
    from broker sync / terminal position list, never from EA logs.
