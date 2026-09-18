# CHART_PLAN — FTMO demo Default profile, incumbent -> D2f

Profile directory (the only chart surface that matters):

    C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default

Observed 2026-09-18 read-only. `roster_hash` of the incumbent = `6c5383d8777728ba17abd1a836858b9db87c306d2931445ac642762075ac9bf2`,
demo-cycle state `RUNNING`, `cycle_start_utc 2026-09-15T14:12:11Z`, `total_book_risk_pct 2.5`.

**No chart change is authorised until GAPS G1 and G2 are closed** (see GAPS.md). This plan is the
target state, not a green light.

## 1. Current profile (11 files)

| file | sha256 (16) | symbol | expert | slot | magic | RISK_PERCENT | fate |
|---|---|---|---|---|---|---|---|
| chart01.chr | `0f3c448ec41d171d` | EURUSD | QM5_13206_ftmo-account-governor | — | — | — | **STAYS, inputs change** |
| chart02.chr | `2d88aa6f2e731771` | GBPUSD | QM5_10706_tv-mon-ls | 1 | 107060001 | 0.3125 | **STAYS** |
| chart03.chr | `8df0af0b936b123a` | EURUSD | QM5_11421_ohlc-daily-squeeze-reversal-d1 | 0 | 114210000 | 0.3125 | **LEAVES** |
| chart04.chr | `55235430af923329` | USDCAD | QM5_11422_williams-18ma-outside-bar-entry-d1 | 4 | 114220004 | 0.3125 | **STAYS** |
| chart05.chr | `c6fb08c3b72740f6` | NZDUSD | QM5_11910_larry-williams-18ma-2outside-bars-d1 | 6 | 119100006 | 0.3125 | **LEAVES** |
| chart06.chr | `d03c4b25f1e42a44` | USOIL.cash | QM5_13054_brent-tom-mom | 0 | 130540000 | 0.3125 | **STAYS** |
| chart07.chr | `61d848a8c122cda7` | USOIL.cash | QM5_20048_wti-preholiday | 0 | 200480000 | 0.3125 | **LEAVES** |
| chart08.chr | `f6256e5f3ba6f612` | XAGUSD | QM5_1537_aa-vol-sma10 | 1 | 15370001 | 0.3125 | **LEAVES** |
| chart09.chr | `f37f34db6dc12e07` | XAGUSD | QM5_21505_xag-weekly-lowvol-momentum | 0 | 215050000 | 0.3125 | **STAYS** |
| chart10.chr | `942de2ceb99b8783` | EURUSD | QM_FTMO_TrialTelemetry (collector) | — | — | — | **STAYS, inputs change** |
| chart11.chr | `a979e58410f1db77` | EURUSD | *(none — bare chart)* | — | — | — | leave as is |

`order.wnd` (`0e921e3c7570c2d1`) is terminal furniture; do not touch.

## 2. Target profile (D2f)

Four sleeves detach, four attach, four stay, the governor and the collector are re-input.

### 2a. DETACH (4)

| current file | expert | why |
|---|---|---|
| chart03.chr | 11421 EURUSD | not in D2f |
| chart05.chr | 11910 NZDUSD | not in D2f |
| chart07.chr | 20048 USOIL | not in D2f |
| chart08.chr | 1537 XAGUSD | not in D2f (also -149 % financed per Addendum 3) |

Preferred: **close these four charts** so the profile shrinks to the exact D2f set. Acceptable
alternative: remove the `<expert>` block only and leave a bare chart; the sleeve then disappears
from `parse_chart_profile` (which skips charts with no expert) and from the demo-cycle roster.
Do **not** merely set `expertmode=0` — the expert block would still be parsed as a sleeve.

### 2b. STAY (4) — do the preset bytes change?

| chart | expert / magic | new preset | preset bytes change? |
|---|---|---|---|
| chart02.chr | 10706 / 107060001, GBPUSD H1 | `QM5_10706_GBPUSD_H1_live_trial.set` `31c37ec30421a51d...` | **NO — byte-identical to the installed 2026-09-06 preset.** Chart inputs stay as they are. But the **binary underneath changes**: `demo_install` replaces the untracked alias build `6f290d49...` with the sealed `eaffda6f...`. Re-attach is still required so MT5 reloads the EA. |
| chart04.chr | 11422 / 114220004, USDCAD D1 | `QM5_11422_USDCAD_D1_live_trial.set` `215615b5da7ae2f4...` | **NO — byte-identical.** Binary already matches the seal. This chart is a genuine no-op. |
| chart06.chr | 13054 / 130540000, USOIL.cash D1 | *(cannot be derived — blocked)* | **UNKNOWN / BLOCKED.** The new preset must carry `strategy_host_symbol=USOIL.cash`, which only exists after the recompile + re-seal (GAPS G1/G2). Today's chart has no such input and the running binary is the hard-`XTIUSD.DWX` build, i.e. **this sleeve is dark**. |
| chart09.chr | 21505 / 215050000, XAGUSD D1 | *(cannot be derived — blocked)* | **UNKNOWN / BLOCKED**, and worse: replacing the alias binary `81386c2d...` with the sealed `395c4747...` without a recompile turns a currently-trading sleeve dark. |

### 2c. ADD (4 new charts)

Open a fresh chart per row, set the timeframe, attach the EA from
`Experts\QM_FTMO\`, load the preset from `Presets\QM_FTMO_M13\`, leave AutoTrading off.

| symbol | TF | expert | preset | magic (`qm_magic_slot_offset`) | RISK_PERCENT |
|---|---|---|---|---|---|
| USDJPY | H1 | `QM5_13213_balke-gmt3-range-breakout.ex5` | `QM5_13213_USDJPY_H1_live_trial.set` | 132130000 (slot 0) | **0.15625** |
| XAUUSD | H1 | `QM5_10700_tv-liq-break.ex5` | `QM5_10700_XAUUSD_H1_live_trial.set` | 107000003 (slot 3) | 0.3125 |
| XAUUSD | D1 | `QM5_10403_et-turtle20x.ex5` | `QM5_10403_XAUUSD_D1_live_trial.set` | 104030002 (slot 2) | 0.3125 |
| XAUUSD | D1 | `QM5_41219_cum-rsi2-commodity-requal8.ex5` | `QM5_41219_XAUUSD_D1_live_trial.set` | 412190000 (slot 0) | 0.3125 |

Three XAUUSD charts are intentional (10700 H1, 10403 D1, 41219 D1). Two of them are same-symbol
same-timeframe but different EAs and different magics — MT5 allows this and the magics keep them
separate. The advisory `symbol<=2` cap is knowingly exceeded (Addendum 3 records it as an advisory
warning under OWNER-DEC-CBE-20260915; caps are guardrails, not hard gates).

**13213 is the one sleeve at half risk (0.15625 %).** Verify that number on the chart before saving
— a 0.3125 there silently turns the book into 2.5 %.

### 2d. RE-INPUT (2)

| chart | change |
|---|---|
| chart01.chr (governor 13206) | `allowed_magics_csv`, `governed_ea_ids_csv`, `governed_symbols_csv`, `challenge_id`, `challenge_start_utc` — exactly the five values in `governor_rebind_dryrun.json`. Re-load the rebound `QM5_13206_..._ACCOUNT_TIMER_M13_demo_active.set` after `governor_rebind --apply` rather than typing them in. |
| chart10.chr (collector) | `InpOutputDir=QM\ftmo_trial\FTMO_DEMO_BOOK_V3_D2F_20260918`, `InpTrialId=M13_D2F_20260918_1514536732`. Re-load `QM_FTMO_TrialTelemetry_1514536732.set` from the package (`3b01a12b...`). `InpTimerSeconds`, `InpExpectedLogin`, `InpExpectedServer` are unchanged. |

Target roster after the change: 8 trading sleeves, `total_book_risk_pct` **2.34375**, governor and
collector excluded from the sleeve count by `_NON_SLEEVE_MARKERS`.

## 3. How to make the change — GUI, not hand-edited `.chr`

`.chr` files are UTF-16, carry a chart `id`, window geometry and an `<indicator>`/`<window>` tail,
and MT5 **rewrites the whole profile on clean shutdown**. Hand-editing them while the terminal is
running is silently discarded; hand-editing them while it is down works but is fragile (duplicate
chart ids, `windows_total` drift). Use the terminal UI and let MT5 write the files.

Ordering matters: **MT5 must be down while `demo_install` copies**, then started once so the new
`.ex5`/`.set` files are visible, then charts changed, then shut down cleanly so the profile is
written. The full sequence is in RUNBOOK.md section 5.

### Profile backup (mandatory, before anything)

With MT5 **not running**, copy the whole directory:

    Copy-Item -Recurse "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default" "C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2f\profile_backup_pre_D2f" -Force

Record the per-file sha256 of the backup next to it. The 11 pre-change hashes are in section 1 and
are the authoritative comparison set. Keep the backup **outside** the terminal tree so MT5 never
sees it as a profile.

### Rollback

1. Shut MT5 down cleanly (AutoTrading off first).
2. Delete the contents of `...\Profiles\Charts\Default` and restore the backup copy verbatim.
3. Restore the two replaced binaries from `Experts\QM_FTMO\_pre_FTMO_DEMO_BOOK_V3_D2F_20260918\`
   (10706 -> `6f290d49...`, 21505 -> `81386c2d...`) if the alias builds are wanted back.
4. Re-run `governor_rebind` with the incumbent roster, or restore the three governor files from git
   (`git checkout` of the two `QM5_13206_...` presets and `ftmo_m13_standard_demo.v1.json`).
5. Restore the collector preset to `InpOutputDir=QM\ftmo_trial\2026-09-06` /
   `InpTrialId=M13_OPTION_B_20260906_1514536732`.
6. Start MT5, verify the 11 chart hashes match section 1, then OWNER re-enables AutoTrading.

Rollback restores the incumbent book, which includes the two sleeves Addendum 3 wants gone — it is
a safety net, not a destination.

## 4. Post-change verification list

Run in this order. Every item is a stop condition if it fails.

| # | check | how | pass |
|---|---|---|---|
| 1 | profile parses to exactly 8 sleeves | `demo_cycle.parse_chart_profile(<Default>, <Experts\QM_FTMO>)` | `len == 8` |
| 2 | magics are the D2f eight | same call | `{104030002,107000003,107060001,114220004,130540000,132130000,215050000,412190000}` |
| 3 | book risk | sum of `risk_pct` | **2.34375** (not 2.5) |
| 4 | 13213 at half risk | chart inputs | `RISK_PERCENT=0.15625` |
| 5 | binaries on the charts | `ex5_sha` per sleeve | equals the repo/seal sha in PACKAGE.md section 3 for all 8 |
| 6 | governor allow-list | chart01 inputs | `allowed_magics_csv` equals `governor_rebind_dryrun.json.updates` |
| 7 | collector bound to the new cycle | chart10 inputs | `InpOutputDir=QM\ftmo_trial\FTMO_DEMO_BOOK_V3_D2F_20260918` |
| 8 | **`magics_seen == 8`** | `D:\QM\reports\state\ftmo_trial_pulse.json` after the next pulse run (task `QM_FTMO_TrialPulse`, every 30 min) | `magics_seen == 8` **and** `expected_magics == 8` |
| 9 | **`ftmo_trial_pulse` RUNNING** | same file | `effective_state == "RUNNING"`, `expected_state_condition == "ok"`, `terminal_up == true`, `collector_snapshot_age_minutes` < 5 |
| 10 | new cycle opened | `python -m tools.strategy_farm.ftmo.demo_cycle build --dark-after-days 5` | `roster_hash != 6c5383d8...`, `cycle_start_utc` = today, `state == "NEW"` then `RUNNING`, `sleeve_count == 8`, `total_book_risk_pct == 2.34375` |
| 11 | **`attached_dark` empty after 5 trading days** | same command re-run once `trading_days_observed >= 5` | `attached_dark_count == 0`, `attached_dark_magics == []`, `attached_dark_risk_pct == 0` |

Item 8 will **fail** until `EXPECTED_MAGICS` in `tools/strategy_farm/ftmo_trial_pulse.py` is
rebound from the incumbent eight to the D2f eight — that is a repo edit, GAPS G3.

Item 11 is currently **not measurable**. `demo_cycle.observe_placements` counts `TM_OPEN` /
`ENTRY_ACCEPTED` lines in `MQL5\Files\QM\QM*_ea-*.log`; the read-only build run for this package
returned `placements_observed = EVIDENCE_MISSING` for all eight incumbent sleeves, so
`attached_dark` can never become true and an empty `attached_dark` list proves nothing. It must be
made to report real counts before it is used as the go/no-go on day 5 — GAPS G7. Given section 4 of
PACKAGE.md, 13054 is exactly the sleeve this check exists to catch.
