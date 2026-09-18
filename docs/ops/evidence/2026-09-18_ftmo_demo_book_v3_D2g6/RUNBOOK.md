# RUNBOOK — install FTMO demo book v3 (roster D2g6)

Operator: Fable. Every step has a readback check and a stop condition. If a check fails, stop at that
step — do not improvise past it. All commands run from `C:\QM\repo`.

**Scope.** This runbook concerns the FTMO **demo** terminal only — a separate MetaTrader install,
`C:\Program Files\FTMO Global Markets MT5 Terminal`, data dir
`C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850`,
login 1514536732, server FTMO-Demo. `C:\QM\mt5\T_Live` and `D:\QM\mt5\T1..T10` are never touched, and
`demo_install` refuses them structurally (`forbidden_terminal_target`). Nothing here authorises
AutoTrading on T_Live — that stays OWNER-only. The factory is unaffected: this is **not** a
`Factory_OFF` / `Factory_ON` procedure, and it is never a VPS reboot.

**AutoTrading.** Off from step 3 until step 8. Read step 8 before you start: the FTMO launcher
`FTMO_ON.ps1` **pins `[Experts] Enabled=1` itself**, so starting the terminal through it *is* the
AutoTrading-on event. Every intermediate start in this runbook therefore bypasses the launcher.

---

## Step 0 — PRECONDITION: two repo edits, or step 6 fails closed

The package itself is executable (PACKAGE.md). Two things outside it are not, and both must land
**in the same reviewed commit as step 2**:

- **G1 — re-pin the launcher's contract verifier.**
  `tools/strategy_farm/verify_ftmo_demo_instrumentation_contract.ps1` hard-pins the incumbent
  11-chart profile: exact file set `chart01..chart11 + order.wnd`, per-chart EA id, symbol,
  `period_type`/`period_size`, preset sha and binary sha. After the cutover the profile is 9 charts
  and the verifier exits 2. `FTMO_ON.ps1` runs it before launching and aborts on a non-zero exit
  (`profile_contract_failed`, launcher exit 2). **The verifier can only be re-pinned from the
  post-edit profile**, so its edit happens at step 7, not now — but budget it now.
- **G2 — rebind `ftmo_trial_pulse.EXPECTED_MAGICS`** to the D2g6 six. Until then the pulse's
  magic checks are uninterpretable (step 9).

Both are items (2) and (3)-adjacent of router ticket `57bfd3af`.

**Stop condition: do not begin if `sets/manifest.json` is absent** — it is present and validated in
this package (`62efe535e71794542bbccf163237f40819f708e6a9c1cb8d5e56587bc3107f57`, 6 candidates).

---

## Step 1 — back up the chart profile and the presets

The terminal is still running here, so this is a **reference snapshot**: MT5 rewrites the profile on
clean shutdown, so the authoritative backup is the one re-taken in step 3.

    Copy-Item -Recurse "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default" "C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\profile_backup_pre_D2g6_prestop" -Force
    Copy-Item -Recurse "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Presets\QM_FTMO_M13" "C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\presets_backup_pre_D2g6" -Force
    Get-ChildItem "C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\profile_backup_pre_D2g6_prestop" -File | Get-FileHash -Algorithm SHA256 | Select-Object Hash,Path

**Readback:** 12 files (11 `.chr` + `order.wnd`); the 11 `.chr` hashes match CHART_PLAN.md §1.
12 preset files, including `QM_FTMO_TrialTelemetry_1514536732.set` at `f4da1592…`.

**Stop if:** any `.chr` hash differs from CHART_PLAN §1 — the profile moved after this package was
built; re-read it and re-derive the plan before continuing.

---

## Step 2 — rebind the governor (the only step that writes the repo)

    python -m tools.strategy_farm.ftmo.governor_rebind --roster docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6/roster.json --challenge-id M13_D2G6_20260918_1514536732 --challenge-start-utc "2026.09.18 06:17:00" --receipt docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6/governor_rebind_receipt.json --apply

**Readback:** `applied: true`, `terminal_written: false`, `charts_changed: false`,
`autotrading_changed: false`, `sleeve_count: 6`, and `updates` identical to
`governor_rebind_dryrun.json` (except `challenge_start_utc` if you move the stamp). Preset re-pins
`bootstrap 15c18dc4… -> e2640e6e…`, `active f7345341… -> f1b277a6…`, binding
`52d9e27d… -> 0ed0df9f…`. The tool re-runs `load_binding()` as its own acceptance proof and rolls all
three files back on any failure, so `rebind_binding_incoherent` means nothing changed.

Commit with explicit pathspecs — the three rebound files **plus the two step-0 repo edits**:

    framework/EAs/QM5_13206_ftmo-account-governor/sets/QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_active.set
    framework/EAs/QM5_13206_ftmo-account-governor/sets/QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_bootstrap.set
    tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json
    tools/strategy_farm/ftmo_trial_pulse.py                      (G2)

(The verifier re-pin is committed at step 7, once the new profile exists.)

**Stop if:** `magic_not_in_registry` or `registry_symbol_mismatch` — roster and
`framework/registry/magic_numbers.csv` disagree; fix the registry, never the roster.

---

## Step 3 — clean terminal shutdown, AutoTrading off

1. In the FTMO demo terminal, **switch AutoTrading OFF** (toolbar button, or Ctrl+E). The button goes
   grey and the Journal logs `Expert Advisors auto trading disabled`.
2. Confirm nothing is mid-fill: Trade tab stable, no pending order about to trigger. Open positions
   may remain — this procedure does not close them, and the governor resumes watching them on
   restart.
3. **Shut MetaTrader down cleanly.** Preferred: `File -> Exit`, or the window close button. From a
   script, send WM_CLOSE to the FTMO terminal's main window — **never** `Stop-Process` / Task
   Manager, which skips the flush:

       $p = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -like 'C:\Program Files\FTMO Global Markets MT5 Terminal\*' }
       $p | ForEach-Object { $_.CloseMainWindow() | Out-Null }
       # then wait for exit; do NOT fall back to Kill()
       $p | ForEach-Object { $_.WaitForExit(120000) }

   A clean exit is what flushes `[Experts] Enabled=0` into `config\common.ini` **and** what writes the
   current chart profile to disk.
4. Wait until no `terminal64.exe` remains whose path is under
   `C:\Program Files\FTMO Global Markets MT5 Terminal`. Leave T_Live's and the factory's terminals
   alone — select processes by path, never by name.

**Readback:**

    Get-Process terminal64 -ErrorAction SilentlyContinue | Select-Object Id,Path
    Select-String -Path "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\config\common.ini" -Pattern "^Enabled=" -Encoding unicode

No FTMO-path process; `[Experts] Enabled` flips **1 -> 0**. (It reads `1` today — that is the single
refusal in `demo_install_dryrun.json`.)

Then re-take the authoritative backup, now that MT5 has written the profile:

    Copy-Item -Recurse "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default" "C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\profile_backup_pre_D2g6" -Force
    Get-ChildItem "C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2g6\profile_backup_pre_D2g6" -File | Get-FileHash -Algorithm SHA256 | Select-Object Hash,Path

**Stop if:** `Enabled` is still `1` — the shutdown was not clean, or something rewrote the file.
`demo_install` will refuse anyway (`autotrading_must_be_disabled`), which is the intended guard.
**Do not hand-edit `common.ini` to get past it.**

---

## Step 4 — install (dry run, then execute)

    python -m tools.strategy_farm.ftmo.demo_install --package docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6 --dry-run

**Readback:** it now runs to completion (it refused only on the AutoTrading gate before step 3):
`schema qm.ftmo-demo-install-plan/v1`, `mode: DRY_RUN`, `label: D2g6`,
`cycle_id: FTMO_DEMO_BOOK_V3_D2G6_20260918`,
`decision_id: OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917`, `autotrading_changed: false`,
`charts_changed: false`, `tlive_written: false`, `copy_count: 14`,
`sets_manifest_sha256: 62efe535…`, `backup_dir` ending `_pre_FTMO_DEMO_BOOK_V3_D2G6_20260918`.
Compare the 14 rows against PACKAGE.md §7 — in particular **10706 `.ex5` = REPLACE with a
`backup_to`**, **collector preset = REPLACE with a `backup_to`**, 11422 `.ex5`/`.set` and the 10706
`.set` and collector `.ex5` = `SKIP_IDENTICAL`, the other eight = `CREATE`. Every row carries a
64-char `source_sha256`.

Then:

    python -m tools.strategy_farm.ftmo.demo_install --package docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6 --execute

**Readback:** `status: INSTALLED_UNATTACHED_PARKED`, `authority.mode: OWNER_DECISION_RECEIPT`,
`decision_id` as above, `charts_changed: false`, `tlive_written: false`, 14 entries in `installed`,
1–2 entries in `backups`, and `install_receipt.json` written into the package.

**Stop if:** `login_mismatch` / `server_mismatch` / `origin_mismatch` (wrong terminal — never
override), `preset_hash_mismatch` / `sealed_binary_mismatch` (the package drifted — rebuild it),
`collector_preset_contract_mismatch` (the collector `.set` is malformed — see GAPS G7),
`receipt_exists_refusing_overwrite` (a previous install already ran; do **not** delete the receipt to
force a second one), `backup_collision` (a backup dir for this cycle id already exists).

Nothing is attached at this point. The EAs sit in `Experts\QM_FTMO`, the presets in
`Presets\QM_FTMO_M13`, and no chart references the four new ones.

---

## Step 5 — chart profile edit

Target state, field-level detail and rollback are in CHART_PLAN.md.

1. **Start the terminal directly — not through the launcher:**

       Start-Process -FilePath "C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe" -WorkingDirectory "C:\Program Files\FTMO Global Markets MT5 Terminal"

   This deliberately bypasses `FTMO_ON.ps1`, which would pin `[Experts] Enabled=1` and bring the
   terminal up **hot**. Verify the AutoTrading button is grey before doing anything else. If it is
   green, switch it off immediately and note it.
2. Navigator -> Expert Advisors -> `QM_FTMO` must list all six sleeve EAs plus
   `QM_FTMO_TrialTelemetry` and the governor. If not, right-click -> Refresh.
3. **Close the six leaving charts:** 11421 EURUSD D1, 11910 NZDUSD D1, 13054 USOIL.cash D1,
   20048 USOIL.cash D1, 1537 XAGUSD D1, 21505 XAGUSD D1.
4. **Open the four new charts** per CHART_PLAN §2c: USDJPY H1 -> 13213 **at RISK_PERCENT 0.15625**;
   XAUUSD H1 -> 10700; XAUUSD D1 -> 10403; XAUUSD D1 -> 41219. Load each preset from
   `Presets\QM_FTMO_M13` via the EA properties **Load** button — do not type inputs.
5. **Re-attach 10706 on its GBPUSD H1 chart** (remove the EA, attach it again, load the same preset)
   so MT5 loads the newly installed sealed binary. Its preset bytes do not change; the binary does.
6. **Leave the 11422 USDCAD D1 chart untouched** — binary and preset are both already correct.
7. Re-load the rebound governor **active** preset on the governor chart and the new collector preset
   on the collector chart (CHART_PLAN §2d). Leave the bare EURUSD chart alone.
8. **Shut the terminal down cleanly again** (`File -> Exit`). This is what persists the new profile
   to `.chr` — a chart change not followed by a clean shutdown is lost. Confirm no FTMO-path
   `terminal64.exe` remains.

**Stop if:** the AutoTrading button was ever green during this step, or a preset fails to load.

---

## Step 6 — file-level verification, terminal down

    python -c "import sys;sys.path.insert(0,'.');from pathlib import Path;from tools.strategy_farm.ftmo import demo_cycle as d;T=Path(r'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850');r=d.parse_chart_profile(T/'MQL5/Profiles/Charts/Default',T/'MQL5/Experts/QM_FTMO');print(len(r));[print(x) for x in r]"

**Readback:** 6 rows; magics exactly
`{104030002, 107000003, 107060001, 114220004, 132130000, 412190000}`; `risk_pct` sums to
**1.71875**; 13213 at `0.15625`; every `ex5_sha` equals the repo/seal sha in PACKAGE.md §3 — in
particular 10706 now reads `eaffda6f…`, not `6f290d49…`.

Then work CHART_PLAN §4 items 1–7, and list the new profile so the verifier can be re-pinned:

    Get-ChildItem "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default" -File | Get-FileHash -Algorithm SHA256 | Select-Object Hash,Path

**Stop if:** the count is not 6, a magic is wrong, `risk_pct` for 13213 is not `0.15625`, or any
`ex5_sha` is `UNKNOWN` (a chart names an EA that is not in `Experts\QM_FTMO`).

---

## Step 7 — re-pin the launcher contract verifier (repo edit, G1)

`tools/strategy_farm/verify_ftmo_demo_instrumentation_contract.ps1` is the gate `FTMO_ON.ps1` runs
before it launches. Rebuild it against the profile just read back:

- `Assert-ExactProfileFiles`: the new file set (9 `.chr` + `order.wnd`) — **MT5 renumbers the chart
  files**, so take the names from step 6's listing, do not assume `chart01..chart09` maps as before.
- `$legs`: one row per D2g6 sleeve — `chart`, `ea_id`, `slug`, `symbol` (the bare FTMO venue name),
  `period_type`/`period_size` (H1 = `1`/`1`, D1 = `1`/`24`), `expertmode=1`, `slot`, `risk_percent`
  (`0.15625` for 13213, `0.3125` for the rest), `risk_fixed=0`, `portfolio_weight=1`, `preset`
  filename and `preset_sha`, `binary_sha` — the preset and binary sha256 in PACKAGE.md §3/§4,
  **upper-case** (the script compares with `-ceq`).
- `$governorChartName` / `$telemetryChartName` / `$blankChartName` and the governor's
  `$governorChallengeId` (`M13_D2G6_20260918_1514536732`), `$governorAllowedMagicsCsv`,
  `$governorEaIdsCsv`, and the governor + telemetry preset/binary shas.

This is the **"verifier pin" SOP** from `docs/ops/FTMO_M13_CAPTURE_RUNBOOK_2026-09-06.md` §2:
*"after every FTMO demo attach/detach, EA rebuild, or preset change, rerun
`verify_ftmo_demo_instrumentation_contract.ps1` and re-pin the verifier in the same reviewed commit;
a mismatch remains fail-closed."* Precedent for the repair loop:
`docs/ops/OPEN_ITEMS_STATUS.md` 2026-09-09T18:15Z ("FTMO demo autostart restored (verifier re-pin)")
and `docs/ops/evidence/2026-09-09_ftmo_launcher_readiness_probe.md`.

**Readback:**

    powershell -NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\tools\strategy_farm\verify_ftmo_demo_instrumentation_contract.ps1"
    echo $LASTEXITCODE

Exit **0** and the line
`VERIFIED: FTMO account 1514536732 / Default = account governor + <n> SHA-pinned … sleeves …`
(update that message text to say six). Commit the verifier with an explicit pathspec.

**Stop if:** exit 2. `FTMO_ON.ps1` will refuse to launch (`profile_contract_failed`, launcher exit 2,
journalled to `D:\QM\reports\state\live_launcher_events.jsonl`). Fix the pin against the real profile;
never relax an assertion to make it pass.

---

## Step 8 — start via the normal launcher; this is the AutoTrading-on event (Fable)

Only once steps 4, 5, 6 and 7 have all passed.

    powershell -NoProfile -ExecutionPolicy Bypass -File "C:\QM\repo\tools\strategy_farm\FTMO_ON.ps1"

This is the canonical QM FTMO launcher — the same one scheduled task **`QM_FTMO_AtLogon`**
(`Ready`) runs after a reboot, so bringing the terminal up this way is also what proves auto-resume
still works for the new profile. It, in order: refuses if the data dir or profile is missing, runs
the contract verifier and aborts on a non-zero exit, then **pins `ProfileLast=Default` and
`[Experts] Enabled=1` in `config\common.ini`**, verifies that write, and launches `terminal64.exe`.

Consequences, stated plainly:

- **The launcher enables AutoTrading.** Fable does not toggle a button; Fable *decides to run the
  launcher*, and records that timestamp as the AutoTrading-on moment. The governor QM5_13206 takes
  over enforcement from then; `governor_dry_run` stays `false`.
- The launcher **no-ops if an FTMO `terminal64` is already running**, and then it does *not* pin
  `Enabled=1`. So the terminal must be **down** when you run it.
- It never touches T_Live or the factory, and it is not a reboot.
- If Fable prefers a manual toggle instead, start `terminal64.exe` directly and use Ctrl+E — but
  `common.ini` then stays `Enabled=0` and the next `QM_FTMO_AtLogon` will flip it to `1` anyway.

**Readback:** launcher exit 0; the latest record in `D:\QM\reports\state\live_launcher_events.jsonl`
is `launched` / exit 0 for launcher `FTMO`; one FTMO-path `terminal64.exe`; the AutoTrading button is
green; each of the six charts shows the EA smiley enabled.

**Stop and switch AutoTrading back off if:** the governor logs a policy refusal, a chart shows a sad
smiley, or the collector snapshot goes stale.

---

## Step 9 — runtime verification

    python -m tools.strategy_farm.ftmo.demo_cycle build --dark-after-days 5

**Readback:** `roster_hash` differs from
`6c5383d8777728ba17abd1a836858b9db87c306d2931445ac642762075ac9bf2`, `cycle_start_utc` is today,
`sleeve_count: 6`, `total_book_risk_pct: 1.71875`, state `NEW` (it becomes `RUNNING` on the next
build). A new cycle is the point: D2g6 is a rep-breaking change and the **two-week demo clock
restarts from zero — it runs from this cutover, not from 2026-09-15.**

Wait for the next `QM_FTMO_TrialPulse` run (task `QM_FTMO_TrialPulse`, `Ready`, every 30 min) and
read `D:\QM\reports\state\ftmo_trial_pulse.json`:

- `effective_state == "RUNNING"`, `expected_state_condition == "ok"`, `terminal_up == true`
- `collector_snapshot_path` points at
  `…\MQL5\Files\QM\ftmo_trial\FTMO_DEMO_BOOK_V3_D2G6_20260918\trial_telemetry_raw.jsonl` and
  `collector_snapshot_age_minutes` is under 5
- `verdict` is not `ALARM`; `day_loss_pct` / `total_dd_pct` sane

### What the pulse will show about magics — read this before reacting (ticket 57bfd3af)

`ftmo_trial_pulse.EXPECTED_MAGICS` is **still hard-coded to the incumbent eight**
`{107060001, 114210000, 114220004, 119100006, 130540000, 15370001, 200480000, 215050000}`, and
`magics_seen` only counts observed magics that are *in* that set. D2g6 shares exactly **two** magics
with it (107060001, 114220004). So, unless G2 is fixed:

- `expected_magics: 8` and `magics_seen: 0..2` — **never 6, and never 8**.
- `magics_missing: [15370001, 114210000, 119100006, 130540000, 200480000, 215050000]` — the six
  retired incumbents, which by construction can never appear again.
- The four genuinely new magics (104030002, 107000003, 132130000, 412190000) are **invisible** to the
  pulse: they are filtered out before `seen_magics`, `KS_DAY_ANCHOR_SET`, `KS_BOOK_TAG_SET` and the
  server-request counters.
- On a Prague weekday, `kill_switch_runtime_proof_warns` adds `ks_day_anchor_missing:<=2/8` and
  `ks_book_tag_missing:<=2/8`.
- `magics_missing` raises a **WARN**, not an ALARM, so the task still exits 0. That is the trap:
  the pulse will look "fine but warning" while telling you nothing about D2g6.

**Therefore: `magics_seen == N` is not an acceptance criterion for this cutover until
`EXPECTED_MAGICS` is roster-driven (G2).** Until then, use step 6's `parse_chart_profile` readback and
the `demo_cycle` ledger as the authority for which sleeves are attached, and treat the pulse's magic
block as stale. Do **not** "fix" a magics_missing warning by re-attaching a retired sleeve.

### First placements

Once the first market session of the new cycle opens, confirm each sleeve actually places:
look for `TM_OPEN` / `ENTRY_ACCEPTED` markers per magic in
`…\MQL5\Files\QM\QM*_ea-*.log`, and for the collector's own rows in
`…\ftmo_trial\FTMO_DEMO_BOOK_V3_D2G6_20260918\trial_telemetry_raw.jsonl`.
**See GAPS G3: `demo_cycle.observe_placements` currently returns `EVIDENCE_MISSING` for every
sleeve**, so an empty `attached_dark` list on day 5 is silence, not proof. A sleeve reporting
`EVIDENCE_MISSING` on day 5 is **unverified**, never "trading".

---

## Step 10 — day-5 dark check

After 5 trading days of the new cycle:

    python -m tools.strategy_farm.ftmo.demo_cycle build --dark-after-days 5

**Readback:** `attached_dark_count == 0`, `attached_dark_magics == []`,
`realised_book_risk_pct == 1.71875`. Meaningful only once G3 is closed.

**If a sleeve is dark:** do not leave it attached inflating the nominal book. Detach it, record the
realised book risk, and take the finding into the weekly recomposition.

---

## Stop conditions — summary

| where | condition | action |
|---|---|---|
| any step | a readback does not match | stop at that step; do not improvise forward |
| 1 | a `.chr` hash differs from CHART_PLAN §1 | re-read the profile, re-derive the plan |
| 2 | `magic_not_in_registry` / `registry_symbol_mismatch` | fix `magic_numbers.csv`, never the roster |
| 3 | `[Experts] Enabled` still `1` | redo the clean shutdown; never hand-edit `common.ini` |
| 3 | a non-FTMO `terminal64.exe` was selected | abort — path-anchored selection only; T_Live is off limits |
| 4 | `login_mismatch` / `server_mismatch` / `origin_mismatch` | abort; wrong terminal, never override |
| 4 | `receipt_exists_refusing_overwrite` / `backup_collision` | abort; a prior install ran — investigate, do not delete the receipt |
| 5 | AutoTrading green at any point | switch off, note it, re-verify before continuing |
| 6 | sleeve count != 6, wrong magic, 13213 not at 0.15625, any `ex5_sha` UNKNOWN | fix the charts, re-save via clean shutdown |
| 7 | verifier exit 2 | re-pin against the real profile; never weaken an assertion |
| 8 | launcher exit != 0, or governor policy refusal after start | AutoTrading off, roll back per CHART_PLAN §3 |
| 9 | `effective_state != RUNNING`, collector snapshot stale > 5 min, `verdict == ALARM` | AutoTrading off, investigate |
| 9 | `magics_seen != 8` | **expected, not a stop condition** — see the G2 note above |

---

## Evidence to record when done

- `install_receipt.json` (step 4) and `governor_rebind_receipt.json` (step 2)
- both profile backups and their hashes (steps 1, 3), plus the post-change profile listing (step 6)
- the re-pinned verifier and its exit-0 run (step 7); the launcher journal record (step 8)
- the post-change `parse_chart_profile` output and the first `demo_cycle build` ledger (steps 6, 9)
- the first `ftmo_trial_pulse.json` after AutoTrading on, and the launcher-start timestamp (step 8)
- a decision note under `decisions/2026-09-18_ftmo_demo_book_v3_d2g6.md` recording the cutover, the
  six retired sleeves, the two sleeves deferred to ticket `57bfd3af`, and the restarted two-week clock
- `docs/ops/OPEN_ITEMS_STATUS.md` entry — the order counts as done only when its RESULT is reported
