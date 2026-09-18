# CHART_PLAN — FTMO demo Default profile, incumbent -> D2g6

Profile directory (the only chart surface that matters):

    C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default

Observed read-only 2026-09-18 ~04:05Z. Unchanged since the D2f package was built — all twelve file
hashes below are identical to D2f CHART_PLAN §1, so that reading still stands.

**The chart edit, not the install, is what changes the book.** `demo_install` adds files; the six
incumbent sleeves that leave D2g6 leave by being *detached here*. Their binaries and presets stay on
disk (that is what makes rollback cheap).

## 1. Current profile (11 charts + `order.wnd`)

| file | sha256 (16) | symbol | TF | expert | slot | magic | RISK_PERCENT | fate |
|---|---|---|---|---|---|---|---|---|
| chart01.chr | `0f3c448ec41d171d` | EURUSD | M1 | QM5_13206_ftmo-account-governor | — | — | — | **STAYS, inputs change** |
| chart02.chr | `2d88aa6f2e731771` | GBPUSD | H1 | QM5_10706_tv-mon-ls | 1 | 107060001 | 0.3125 | **STAYS** |
| chart03.chr | `8df0af0b936b123a` | EURUSD | D1 | QM5_11421_ohlc-daily-squeeze-reversal-d1 | 0 | 114210000 | 0.3125 | **DETACH** |
| chart04.chr | `55235430af923329` | USDCAD | D1 | QM5_11422_williams-18ma-outside-bar-entry-d1 | 4 | 114220004 | 0.3125 | **STAYS** |
| chart05.chr | `c6fb08c3b72740f6` | NZDUSD | D1 | QM5_11910_larry-williams-18ma-2outside-bars-d1 | 6 | 119100006 | 0.3125 | **DETACH** |
| chart06.chr | `d03c4b25f1e42a44` | USOIL.cash | D1 | QM5_13054_brent-tom-mom | 0 | 130540000 | 0.3125 | **DETACH** |
| chart07.chr | `61d848a8c122cda7` | USOIL.cash | D1 | QM5_20048_wti-preholiday | 0 | 200480000 | 0.3125 | **DETACH** |
| chart08.chr | `f6256e5f3ba6f612` | XAGUSD | D1 | QM5_1537_aa-vol-sma10 | 1 | 15370001 | 0.3125 | **DETACH** |
| chart09.chr | `f37f34db6dc12e07` | XAGUSD | D1 | QM5_21505_xag-weekly-lowvol-momentum | 0 | 215050000 | 0.3125 | **DETACH** |
| chart10.chr | `942de2ceb99b8783` | EURUSD | M1 | QM_FTMO_TrialTelemetry (collector) | — | — | — | **STAYS, inputs change** |
| chart11.chr | `a979e58410f1db77` | EURUSD | D1 | *(none — bare chart)* | — | — | — | leave as is |

`order.wnd` (`0e921e3c7570c2d1`) is terminal furniture; do not touch.

Incumbent `roster_hash = 6c5383d8777728ba17abd1a836858b9db87c306d2931445ac642762075ac9bf2`,
demo-cycle state `RUNNING`, `cycle_start_utc 2026-09-15T14:12:11Z`, `total_book_risk_pct 2.5`.

## 2. Target profile (D2g6)

Six sleeves detach, four attach, two stay, governor and collector are re-input.
Result: **9 charts** (governor + 6 sleeves + collector + blank) + `order.wnd`,
`parse_chart_profile` -> **6 sleeves**, book risk **1.71875 %**.

### 2a. DETACH (6)

| current file | expert | why |
|---|---|---|
| chart03.chr | 11421 EURUSD D1 | not in D2g6 |
| chart05.chr | 11910 NZDUSD D1 | not in D2g6 (a qualified class-A replacement, but it does not pay for its own risk on the full sample — Addendum 4) |
| chart06.chr | 13054 USOIL.cash D1 | not in D2g6; also **dark since 2026-09-06** — hard `_Symbol == "XTIUSD.DWX"` gate on a `USOIL.cash` chart (ticket 57bfd3af) |
| chart07.chr | 20048 USOIL.cash D1 | not in D2g6 |
| chart08.chr | 1537 XAGUSD D1 | not in D2g6 (−149 % financed per Addendum 3) |
| chart09.chr | 21505 XAGUSD D1 | not in D2g6; trades today only because of an untracked alias rebuild (ticket 57bfd3af) |

Preferred: **close these six charts** so the profile shrinks to exactly the D2g6 set. Acceptable
alternative: delete the `<expert>` block only and leave a bare chart — `parse_chart_profile` skips
charts with no expert, so the sleeve disappears from the demo-cycle roster. Do **not** merely set
`expertmode=0`: the expert block is still parsed as a sleeve and the book would still read 8.

Closing the charts is preferred here for a second reason: it takes the profile to a 9-chart layout
that the launcher's contract verifier has to be re-pinned to anyway (GAPS G1), and a half-empty
profile makes that re-pin ambiguous.

### 2b. STAY (2) — do the preset bytes change?

| chart | expert / magic | new preset | preset bytes change? |
|---|---|---|---|
| chart02.chr | 10706 / 107060001, GBPUSD H1 | `QM5_10706_GBPUSD_H1_live_trial.set` `31c37ec30421a51d…` | **NO — byte-identical to the installed 2026-09-06 preset** (`demo_install` plans `SKIP_IDENTICAL` for it). The chart's input values do not change. **But the binary underneath does**: the install replaces the untracked alias build `6f290d49…` with the sealed `eaffda6f…`. **Re-attach is still required** so MT5 loads the new binary — a chart keeps the EA it loaded at attach time. |
| chart04.chr | 11422 / 114220004, USDCAD D1 | `QM5_11422_USDCAD_D1_live_trial.set` `215615b5da7ae2f4…` | **NO — byte-identical**, and the binary already equals the seal (`SKIP_IDENTICAL` for both rows). **This chart is a genuine no-op** — leave it exactly as it is. |

So: **neither staying sleeve's preset bytes change.** The only reason to touch chart02 is the binary
swap; chart04 needs nothing at all.

### 2c. ADD (4 new charts)

Open a fresh chart per row, set symbol + timeframe, attach the EA from `Experts\QM_FTMO\`, load the
preset from `Presets\QM_FTMO_M13\` via the EA properties **Load** button — never type inputs.

| symbol | TF | `period_type` / `period_size` | expert (`name` / `path`) | preset | magic (`qm_ea_id` / `qm_magic_slot_offset`) | RISK_PERCENT |
|---|---|---|---|---|---|---|
| USDJPY | H1 | `1` / `1` | `QM5_13213_balke-gmt3-range-breakout` / `Experts\QM_FTMO\QM5_13213_balke-gmt3-range-breakout.ex5` | `QM5_13213_USDJPY_H1_live_trial.set` | 13213 / 0 -> 132130000 | **0.15625** |
| XAUUSD | H1 | `1` / `1` | `QM5_10700_tv-liq-break` / `Experts\QM_FTMO\QM5_10700_tv-liq-break.ex5` | `QM5_10700_XAUUSD_H1_live_trial.set` | 10700 / 3 -> 107000003 | 0.3125 |
| XAUUSD | D1 | `1` / `24` | `QM5_10403_et-turtle20x` / `Experts\QM_FTMO\QM5_10403_et-turtle20x.ex5` | `QM5_10403_XAUUSD_D1_live_trial.set` | 10403 / 2 -> 104030002 | 0.3125 |
| XAUUSD | D1 | `1` / `24` | `QM5_41219_cum-rsi2-commodity-requal8` / `Experts\QM_FTMO\QM5_41219_cum-rsi2-commodity-requal8.ex5` | `QM5_41219_XAUUSD_D1_live_trial.set` | 41219 / 0 -> 412190000 | 0.3125 |

`period_type=1` means "hours", `period_size` the number of hours: H1 = `1`/`1`, D1 = `1`/`24`
(the governor and collector charts are `0`/`1`, i.e. M1). `expertmode` must be `1` on every attached
chart.

Three XAUUSD charts are intentional (10700 H1, 10403 D1, 41219 D1). Two are same-symbol
same-timeframe but different EAs with different magics — MT5 allows it and the magics keep them
separate. The advisory `symbol<=2` cap is knowingly exceeded; Addendum 4 records measured
|r| <= 0.09 between them (10403–41219 negative), and under OWNER-DEC-CBE-20260915 caps are
guardrails, not hard gates.

**None of the six binaries contains a `.DWX` symbol literal** (zero occurrences, ASCII and UTF-16LE),
so the venue binding is purely the chart symbol and the bare FTMO names above are correct. This is
exactly the property 21505 and 13054 lack, and the reason they are not here.

**13213 is the one sleeve at half risk (0.15625 %).** Verify that number on the chart before saving —
a `0.3125` there silently turns a 1.71875 % book into 1.875 %.

### 2d. RE-INPUT (2)

| chart | change |
|---|---|
| chart01.chr (governor 13206) | Re-load the **rebound active preset** `QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_active.set` after `governor_rebind --apply` — do not type the values. It carries `allowed_magics_csv=104030002,107000003,107060001,114220004,132130000,412190000`, `governed_ea_ids_csv=10403,10700,10706,11422,13213,41219`, `governed_symbols_csv=GBPUSD,USDCAD,USDJPY,XAUUSD`, `challenge_id=M13_D2G6_20260918_1514536732`, `challenge_start_utc=2026.09.18 06:17:00`. Unchanged and **must stay**: `signed_policy_id=FTMO_2S_P1_100K_V2`, `expected_account_login=1514536732`, `expected_account_server=FTMO-Demo`, `governor_dry_run=false`, `challenge_state_bootstrap=false` (the *active* preset, never the one-shot bootstrap). |
| chart10.chr (collector) | Re-load `QM_FTMO_TrialTelemetry_1514536732.set` from this package (`9de24d3d…`): `InpOutputDir=QM\ftmo_trial\FTMO_DEMO_BOOK_V3_D2G6_20260918`, `InpTrialId=M13_D2G6_20260918_1514536732`. `InpTimerSeconds=1`, `InpExpectedLogin=1514536732`, `InpExpectedServer=FTMO-Demo` unchanged. |

chart11 (bare EURUSD D1, no expert block) stays untouched.

## 3. How to make the change — GUI, not hand-edited `.chr`

`.chr` files are **UTF-16LE with a BOM** (`FF FE`), CRLF-terminated, and carry a chart `id`, window
geometry, an `<expert>` block (`name` / `path` / `expertmode` / `<inputs>` enumerating **every** EA
input by name) and an `<indicator>`/`<window>` tail. MT5 **rewrites the whole profile on clean
shutdown**, so hand-editing while the terminal runs is silently discarded, and hand-editing while it
is down is fragile (duplicate chart ids, `windows_total` drift). Use the terminal UI and let MT5
write the files.

**MT5 renumbers the chart files on save.** After six closures and four additions the profile will be
`chart01.chr … chart09.chr` in window order — the new numbering is **not predictable from this
table** and must be read back from disk afterwards (RUNBOOK step 7). Everything pinned to the old
numbering has to be re-derived from that readback, in particular the launcher's contract verifier
(GAPS G1).

Ordering matters: MT5 **must be down** while `demo_install` copies, then started once so the new
`.ex5`/`.set` files are visible, then charts changed, then shut down cleanly so the profile is
written. Full sequence in RUNBOOK.md.

### Profile backup (mandatory, before anything)

With MT5 **not running**:

    Copy-Item -Recurse "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default" "C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\profile_backup_pre_D2g6" -Force
    Get-ChildItem "C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\profile_backup_pre_D2g6" -File | Get-FileHash -Algorithm SHA256 | Select-Object Hash,Path

12 files (11 `.chr` + `order.wnd`); the 11 hashes must match section 1. Keep the backup **outside**
the terminal tree so MT5 never sees it as a profile. Also back up the presets directory
`...\MQL5\Profiles\Presets\QM_FTMO_M13` the same way (only the collector preset is replaced, but the
restore path should not depend on that).

### Rollback

1. Shut MT5 down cleanly (AutoTrading off first).
2. Delete the contents of `...\Profiles\Charts\Default` and restore the backup copy verbatim.
3. Restore `QM5_10706_tv-mon-ls.ex5` from `Experts\QM_FTMO\_pre_FTMO_DEMO_BOOK_V3_D2G6_20260918\`
   (back to the alias build `6f290d49…`) and the collector preset from the same backup dir
   (`InpOutputDir=QM\ftmo_trial\2026-09-06`, `InpTrialId=M13_OPTION_B_20260906_1514536732`,
   sha `f4da1592…`). The four newly created `.ex5`/`.set` files may stay — nothing references them
   once the charts are gone.
4. Re-run `governor_rebind` with the incumbent roster, or `git checkout` the two `QM5_13206_…`
   presets and `tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json`.
5. Revert the verifier re-pin and the `EXPECTED_MAGICS` change (GAPS G1/G2) in the same commit.
6. Start MT5 via `FTMO_ON.ps1`, verify the 11 chart hashes match section 1 and the verifier exits 0.

Rollback restores the incumbent book — which includes the two sleeves Addendum 3/4 want gone and one
that is provably dark. It is a safety net, not a destination.

## 4. Post-change verification list

Run in this order. Every item is a stop condition if it fails.

| # | check | how | pass |
|---|---|---|---|
| 1 | profile parses to exactly 6 sleeves | `demo_cycle.parse_chart_profile(<Default>, <Experts\QM_FTMO>)` | `len == 6` |
| 2 | magics are the D2g6 six | same call | `{104030002, 107000003, 107060001, 114220004, 132130000, 412190000}` |
| 3 | book risk | sum of `risk_pct` | **1.71875** |
| 4 | 13213 at half risk | chart inputs | `RISK_PERCENT=0.15625` |
| 5 | binaries on the charts | `ex5_sha` per sleeve | equals the repo/seal sha in PACKAGE.md §3 for all six — in particular 10706 must now read `eaffda6f…`, not `6f290d49…` |
| 6 | governor allow-list | governor chart inputs | the five values in `governor_rebind_dryrun.json.updates`; `governor_dry_run=false`, `challenge_state_bootstrap=false` |
| 7 | collector bound to the new cycle | collector chart inputs | `InpOutputDir=QM\ftmo_trial\FTMO_DEMO_BOOK_V3_D2G6_20260918`, `InpTrialId=M13_D2G6_20260918_1514536732` |
| 8 | launcher contract verifier | `powershell -File tools\strategy_farm\verify_ftmo_demo_instrumentation_contract.ps1` | exit **0** against the re-pinned 9-chart profile (GAPS G1). Until it is re-pinned it exits 2 and `FTMO_ON.ps1` refuses to launch. |
| 9 | new cycle opened | `python -m tools.strategy_farm.ftmo.demo_cycle build --dark-after-days 5` | `roster_hash != 6c5383d8…`, `cycle_start_utc` today, `sleeve_count == 6`, `total_book_risk_pct == 1.71875`, state `NEW` then `RUNNING` |
| 10 | `ftmo_trial_pulse` RUNNING | `D:\QM\reports\state\ftmo_trial_pulse.json` after the next pulse (task `QM_FTMO_TrialPulse`, 30 min) | `effective_state == "RUNNING"`, `expected_state_condition == "ok"`, `terminal_up == true`, `collector_snapshot_path` under `…\ftmo_trial\FTMO_DEMO_BOOK_V3_D2G6_20260918\trial_telemetry_raw.jsonl`, `collector_snapshot_age_minutes < 5` |
| 11 | magics visible to the pulse | same file | **See GAPS G2** — `EXPECTED_MAGICS` is still the incumbent eight, so this check is *not* interpretable until it is rebound |
| 12 | `attached_dark` empty after 5 trading days | `demo_cycle build --dark-after-days 5` once `trading_days_observed >= 5` | `attached_dark_count == 0` — **and see GAPS G3: today this proves nothing** |
