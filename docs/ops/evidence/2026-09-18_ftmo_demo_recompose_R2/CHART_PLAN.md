# Chart-profile plan — FTMO Demo `R2_capped` recomposition (PREPARE ONLY)

Profile directory (the only one that matters; `demo_cycle.observe_demo_terminal` reads
exactly this path):

```
C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default\
```

**Nothing in this plan has been executed.** The profile was read, never written. AutoTrading
is currently ON on this demo (OWNER), so every step below is an OWNER-gated action.

---

## 1. Current profile, as observed (read-only, 2026-09-18)

11 chart files + `order.wnd`, all written 2026-09-11 21:45.
Roster hash `6c5383d8777728ba17abd1a836858b9db87c306d2931445ac642762075ac9bf2`.

| chart | symbol | expert | slot | magic | RISK_PERCENT | live ex5 sha (12) | disposition |
|---|---|---|--:|--:|--:|---|---|
| `chart01.chr` | EURUSD | `QM5_13206_ftmo-account-governor` | — | — | — | — | **KEEP, edit inputs** (§3) |
| `chart02.chr` | GBPUSD | `QM5_10706_tv-mon-ls` | 1 | `107060001` | 0.3125 | `6f290d49defd` | **KEEP sleeve, restage binary** (drift, §3.2) |
| `chart03.chr` | EURUSD | `QM5_11421_ohlc-daily-squeeze-reversal-d1` | 0 | `114210000` | 0.3125 | `4ff02978ae5d` | **REPLACE** → 13213 USDJPY H1 |
| `chart04.chr` | USDCAD | `QM5_11422_williams-18ma-outside-bar-entry-d1` | 4 | `114220004` | 0.3125 | `2b98e9e90231` | **KEEP unchanged** |
| `chart05.chr` | NZDUSD | `QM5_11910_larry-williams-18ma-2outside-bars-d1` | 6 | `119100006` | 0.3125 | `ae53f3bcca17` | **REPLACE** → 10700 XAUUSD H1 |
| `chart06.chr` | USOIL.cash | `QM5_13054_brent-tom-mom` | 0 | `130540000` | 0.3125 | `2e65488fccdb` | **REPLACE** → 11660 US100.cash H4 ⚠B1 |
| `chart07.chr` | USOIL.cash | `QM5_20048_wti-preholiday` | 0 | `200480000` | 0.3125 | `1312391ad7e6` | **REPLACE** → 10145 XAUUSD D1 |
| `chart08.chr` | XAGUSD | `QM5_1537_aa-vol-sma10` | 1 | `15370001` | 0.3125 | `16d66a0f7b86` | **REPLACE** → 20266 USOIL.cash D1 ⚠B1 |
| `chart09.chr` | XAGUSD | `QM5_21505_xag-weekly-lowvol-momentum` | 0 | `215050000` | 0.3125 | `81386c2dcd80` | **REPLACE** → 12710 USOIL.cash D1 ⚠B1 |
| `chart10.chr` | EURUSD | `QM_FTMO_TrialTelemetry` | — | — | — | — | **KEEP unchanged** |
| `chart11.chr` | EURUSD | *(none)* | — | — | — | — | **KEEP** (spare, no expert) |

⚠B1 = the sleeve is subject to `PACKAGE.md` §4 B1 and will initialise but **never trade** on
the FTMO venue name. Do not execute those three rows until B1 is resolved.

---

## 2. Target profile

The plan replaces the profile **wholesale**: the v1 profile is detached before the v2
profile loads. That ordering is what makes the `107060001` / `114220004` magic carry-over
safe (`PACKAGE.md` §5.2) — the two identities never coexist.

| chart | symbol | `period_type`/`period_size` | TF | expert | preset (`MQL5\Profiles\Presets\QM_FTMO_M13\`) | slot | magic |
|---|---|---|---|---|---|--:|--:|
| `chart01.chr` | EURUSD | 2 / 1 | D1 | `QM5_13206_ftmo-account-governor` | `…_ACCOUNT_TIMER_M13_demo_active.set` **(revised, §3.1)** | — | — |
| `chart02.chr` | `GBPUSD` | 1 / 1 | H1 | `QM5_10706_tv-mon-ls` | `QM5_10706_GBPUSD_H1_live_trial.set` | 1 | `107060001` |
| `chart03.chr` | `USDJPY` | 1 / 1 | H1 | `QM5_13213_balke-gmt3-range-breakout` | `QM5_13213_USDJPY_H1_live_trial.set` | 0 | `132130000` |
| `chart04.chr` | `USDCAD` | 2 / 1 | D1 | `QM5_11422_williams-18ma-outside-bar-entry-d1` | `QM5_11422_USDCAD_D1_live_trial.set` | 4 | `114220004` |
| `chart05.chr` | `XAUUSD` | 1 / 1 | H1 | `QM5_10700_tv-liq-break` | `QM5_10700_XAUUSD_H1_live_trial.set` | 3 | `107000003` |
| `chart06.chr` | `US100.cash` | 1 / 4 | H4 | `QM5_11660_pp-wedge` | `QM5_11660_US100.cash_H4_live_trial.set` | 4 | `116600004` |
| `chart07.chr` | `XAUUSD` | 2 / 1 | D1 | `QM5_10145_tsm-meanret` | `QM5_10145_XAUUSD_D1_live_trial.set` | 34 | `101450034` |
| `chart08.chr` | `USOIL.cash` | 2 / 1 | D1 | `QM5_20266_collins-66mom` | `QM5_20266_USOIL.cash_D1_live_trial.set` | 0 | `202660000` |
| `chart09.chr` | `USOIL.cash` | 2 / 1 | D1 | `QM5_12710_commodity-tsmom-12m-atr` | `QM5_12710_USOIL.cash_D1_live_trial.set` | 0 | `127100000` |
| `chart10.chr` | EURUSD | unchanged | — | `QM_FTMO_TrialTelemetry` | `QM_FTMO_TrialTelemetry_1514536732.set` **(revised, §3.3)** | — | — |
| `chart11.chr` | EURUSD | unchanged | — | *(none)* | — | — | — |

`period_type`: `0`=minutes, `1`=hours, `2`=days. MT5 writes the pair; `demo_cycle`'s parser
does **not** read it (see `GAPS.md` G4 — a timeframe error is invisible to the cycle ledger
and must be checked by eye).

Each chart's `<expert>` block must carry `path=Experts\QM_FTMO\<name>.ex5`,
`expertmode=1`, and an `<inputs>` section whose `qm_ea_id` / `qm_magic_slot_offset` match
the table (this is what `parse_chart_profile` derives `magic` from, and what the EAs'
own `Strategy_NoTradeFilter()` slot checks compare against).

New binaries to stage into `MQL5\Experts\QM_FTMO\` before the profile loads (sha256 in
`PACKAGE.md` §1.3):

```
QM5_13213_balke-gmt3-range-breakout.ex5
QM5_10700_tv-liq-break.ex5
QM5_11660_pp-wedge.ex5
QM5_10145_tsm-meanret.ex5
QM5_20266_collins-66mom.ex5
QM5_12710_commodity-tsmom-12m-atr.ex5
QM5_10706_tv-mon-ls.ex5              (RE-stage: live copy has drifted, §3.2)
```

`QM5_11422_…ex5` is already present at the correct sha and needs no restage.

---

## 3. Coupled changes that are not chart edits

### 3.1 Governor preset (blocking — `PACKAGE.md` §4 B2)

`chart01.chr`'s `<inputs>` and the repo preset both carry the R0 allow-list. Both must be
revised to the R2 lists given in `PACKAGE.md` §4 B2, **and** the pinned sha256 in
`tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json`
(`governor.active_preset_sha256`) must be updated in the same change, or
`trial_setpath.load_binding()` refuses with `active_preset_hash_drift`. `challenge_id` and
`challenge_start_utc` should be re-minted for the new cycle.

### 3.2 10706 binary drift

The live `chart02.chr` runs `ex5_sha = 6f290d49defd…`; the canonical repo binary (and the
2026-09-06 installed one) is `eaffda6f03c8b422…`. Restaging from the repo is the correct
action — it is the sha the Q08 stream and the R2 simulation are bound to — but it is a
`MECHANICS_CHANGED` event and belongs in the receipt.

### 3.3 Telemetry collector

`QM_FTMO_TrialTelemetry_1514536732.set` pins `InpOutputDir=QM\ftmo_trial\2026-09-06` and
`InpTrialId=M13_OPTION_B_20260906_1514536732`. Leaving them writes the new cycle's telemetry
into the old cycle's folder. Revise to a `2026-09-18` (or post-decision) path and trial id,
and create the matching `MQL5\Files\QM\ftmo_trial\<date>\` and
`D:\QM\reports\ftmo_trial\<date>\` directories.

---

## 4. `demo_cycle` material-change classification (expected)

Feeding the current ledger and the target roster through
`demo_cycle.classify_material_change` yields, deterministically:

| change | count | `material` | `representative_breaking` |
|---|--:|---|---|
| `SLEEVE_REMOVED` (11421, 11910, 13054, 20048, 1537, 21505) | 6 | true | true |
| `SLEEVE_ADDED` (13213, 10700, 11660, 10145, 20266, 12710) | 6 | true | true |
| `RISK_CHANGED` | 0 | — | — (0.3125 unchanged on both survivors) |
| `MECHANICS_CHANGED` (10706, §3.2) | 1 | true | share `0.3125/2.5 = 0.125` vs threshold Y |
| `COMPLIANCE_CHANGED` | 0 | — | — (rulepack unchanged) |
| `PRODUCT_CHANGED` | 0 | — | — |

⇒ `material = true`, `representative_breaking = true`, `resets_cycle = true`.
`build_demo_cycle` therefore sets `is_new_cycle = true`, stamps a fresh `cycle_start_utc`,
appends the new `roster_hash` to `roster_history`, clears `material_changes`, and
`advance_state` returns **`NEW`** (→ `RUNNING` on the next observation, → `REPRESENTATIVE`
only after `policy_config.VALIDATION_MIN_DAYS`).

**Expected new roster hash** — `sha256` over the sorted `(magic, ea_id, symbol)` triples,
which for the target table is:

```
("101450034","10145","XAUUSD") ("107000003","10700","XAUUSD") ("107060001","10706","GBPUSD")
("114220004","11422","USDCAD") ("116600004","11660","US100.cash") ("127100000","12710","USOIL.cash")
("132130000","13213","USDJPY")  ("202660000","20266","USOIL.cash")
```

Compute it after the change with `demo_cycle.roster_hash(observation["roster"])` and record
it; it must differ from `6c5383d877…`. It is deliberately not precomputed here, because the
value depends on the exact `symbol` strings MT5 writes into the `.chr` files, and guessing
those would be an invented value.

Consequence for the campaign: **the 14-day representativeness clock restarts at zero.** Any
existing demo evidence (including the realised −10.26 % max-DD that keeps readiness at
`NOT_READY`) belongs to the old cycle and does not carry over.

---

## 5. Backup

Take **before any write**, from an elevated shell, with the terminal's writes quiesced:

```
Copy-Item -Recurse `
  "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default" `
  "D:\QM\reports\ftmo_trial\backup_20260918\Charts_Default"
Copy-Item -Recurse `
  "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Presets\QM_FTMO_M13" `
  "D:\QM\reports\ftmo_trial\backup_20260918\Presets_QM_FTMO_M13"
Copy-Item -Recurse `
  "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Experts\QM_FTMO" `
  "D:\QM\reports\ftmo_trial\backup_20260918\Experts_QM_FTMO"
Copy-Item `
  "D:\QM\reports\state\ftmo_demo_cycle.json" `
  "D:\QM\reports\ftmo_trial\backup_20260918\ftmo_demo_cycle.pre.json"
```

Then write a `backup_manifest.json` next to it recording, per file, path + sha256 + bytes,
and verify the count: **12** chart-profile files (11 `.chr` + `order.wnd`), **12** presets,
**10** `.ex5` in `QM_FTMO` (excluding the `_pre_*` subfolders, which are themselves prior
backups and should be copied too or explicitly excluded in the manifest).

Do **not** reuse `MQL5\Experts\QM_FTMO\_pre_m13_20260906\` — `demo_install.py`'s backup
scheme writes one file per name into a flat folder and refuses on `backup_collision`. A new
dated folder per change is the only safe convention.

---

## 6. Rollback

Reverses cleanly because nothing in this plan is destructive outside the three copied trees.

1. OWNER turns **AutoTrading OFF** in the FTMO terminal. *(AI seats never toggle this.)*
2. Close the terminal (OWNER; do not kill `terminal64.exe` on this host — it is not a
   factory worker and the factory's process-selection rules do not apply).
3. Restore, overwriting:
   * `Charts\Default\` ← `backup_20260918\Charts_Default\` (all 11 `.chr` **and**
     `order.wnd` — restoring `.chr` without `order.wnd` leaves MT5 with a stale window
     order and can open the wrong chart set)
   * `Presets\QM_FTMO_M13\` ← `backup_20260918\Presets_QM_FTMO_M13\`
   * `Experts\QM_FTMO\` ← `backup_20260918\Experts_QM_FTMO\`
4. Revert the repo-side changes (governor preset + its pinned sha in
   `ftmo_m13_standard_demo.v1.json`, telemetry preset) together — they are coupled.
5. Restore `D:\QM\reports\state\ftmo_demo_cycle.json` from `ftmo_demo_cycle.pre.json`,
   **or** simply re-run `demo_cycle.py build`: the ledger is a pure function of
   `(observation, prev_ledger, now)`, so once the profile is back the next build re-derives
   the old `roster_hash`. It will still log a fresh `cycle_start_utc` — a rollback cannot
   un-break the 14-day clock, and that is a real, irreversible cost of attempting the change.
6. Restart the terminal, verify `roster_hash == 6c5383d877…`, then OWNER re-enables
   AutoTrading.

**Irreversible even after rollback:** the validation clock. Everything else is byte-restorable.

---

## 7. Post-change verification list

Run in order. Every item is a readback, not an assumption.

| # | check | how | pass condition |
|--:|---|---|---|
| 1 | binaries staged at the right sha | `Get-FileHash` each `.ex5` in `MQL5\Experts\QM_FTMO\` | 8 sleeve binaries match `PACKAGE.md` §1.3 exactly |
| 2 | presets staged at the right sha | `Get-FileHash` each `.set` in `Presets\QM_FTMO_M13\` | match `sets/manifest.json` `output_sha256` |
| 3 | profile parses to 8 sleeves | `demo_cycle.parse_chart_profile(profile, experts)` | `len == 8`; governor + telemetry correctly excluded |
| 4 | **`magics_seen == 8`** and correct | compare the parsed `magic` set with §2 | exactly `{101450034, 107000003, 107060001, 114220004, 116600004, 127100000, 132130000, 202660000}` |
| 5 | risk | parsed `risk_pct` per sleeve | `0.3125` × 8; `total_book_risk_pct == 2.5` |
| 6 | timeframes | read `period_type`/`period_size` per `.chr` **by eye** | matches §2 (the parser does not check this — `GAPS.md` G4) |
| 7 | `demo_cycle` new cycle | `python tools/strategy_farm/ftmo/demo_cycle.py build` | `is_new_cycle_this_observation = true`; `state = NEW`; new `roster_hash` ≠ `6c5383d877…`; `roster_history` gained one entry; **record the hash** |
| 8 | governor bound | `chart01.chr` `<inputs>` | `allowed_magics_csv` == the 8 magics of #4; `governed_ea_ids_csv` and `governed_symbols_csv` per §3.1; `expected_account_login=1514536732` |
| 9 | `ftmo_trial_pulse` RUNNING | read the pulse read-model (cf. `docs/ops/evidence/2026-09-06_ftmo_demo_install/pulse_dry_read.json` for the prior shape) | state `RUNNING`, clock fresh |
| 10 | calendar live and fresh | per-EA logs `MQL5\Files\QM\QM5_<ea>_ea-<ea>.log` | `NEWS_CALENDAR_LOADED` on all 8; no `FRAMEWORK_INIT_FAILED` |
| 11 | init clean | same logs | `SYMBOL_GUARD_INIT` with the bare venue symbol, then `INIT_OK`, on all 8 |
| 12 | **first placements — the real test** | same logs, after ≥1 full session per timeframe | `ENTRY_ACCEPTED` / `TM_OPEN` appear for sleeves that had a signal. **Any sleeve with `INIT_OK` but zero `TM_OPEN` after its first eligible bar is the `PACKAGE.md` §4 B1 failure mode and must be escalated, not waited out.** |
| 13 | no magic resolution failures | same logs | zero `EA_MAGIC_RESOLUTION_FAILED`, zero `EA_MAGIC_NOT_REGISTERED`, zero `EA_MAGIC_COLLISION_DETECTED` |
| 14 | telemetry lands in the new folder | `MQL5\Files\QM\ftmo_trial\<new date>\` | files appearing, not in `2026-09-06\` |

Checks 1-8 are done with the terminal closed or AutoTrading off. Checks 9-14 need the
terminal running with AutoTrading enabled — **by OWNER only.**
