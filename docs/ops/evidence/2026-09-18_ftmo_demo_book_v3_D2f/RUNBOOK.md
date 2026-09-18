# RUNBOOK — install FTMO demo book v3 (roster D2f)

Operator: Fable. Every step has a readback check and a stop condition. If a check fails, stop at
that step — do not improvise past it. All commands run from `C:\QM\repo`.

**AutoTrading on the FTMO demo terminal is switched off before step 3 and is switched back on only
in step 8, by Fable, after every verification in step 7 has passed.** No AI seat toggles
AutoTrading on T_Live; this runbook concerns the FTMO **demo** terminal only, which is a separate
MetaTrader installation (`C:\Program Files\FTMO Global Markets MT5 Terminal`, data dir
`...\Terminal\81A933A9AFC5DE3C23B15CAB19C63850`, login 1514536732, server FTMO-Demo). `C:\QM\mt5\T_Live`
and `D:\QM\mt5\T1..T10` are never touched by anything in this runbook, and `demo_install` refuses
them structurally.

---

## Step 0 — PRECONDITION: the package is not executable yet

Two blockers stand between this package and step 1. Both are in GAPS.md.

- **G1** `trial_setpath --roster` refuses `sealed_source_hash_drift` for 21505 and 13054, so
  `sets/` does not exist.
- **G2** the shipped `.ex5` for 21505 and 13054 still carries a hard `_Symbol == "<X>.DWX"` gate;
  21505 only trades today because of an untracked alias rebuild that this install would overwrite,
  and 13054 is already dark.

**Stop condition: do not start at step 1 while `sets/manifest.json` is absent.** Steps 1-9 below are
written for the state after G1 and G2 are closed, and step 1 regenerates the presets from scratch at
that point.

---

## Step 1 — regenerate the presets

    cd C:/QM/repo
    python -m tools.strategy_farm.ftmo.trial_setpath --roster docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f/roster.json --run-name ftmo_demo_book_v3_D2f_20260918 --dry-run

Note the **module form** (`python -m ...`). Running the file path directly fails with
`ImportError: attempted relative import with no known parent package` (GAPS G4).

The tool writes to `D:\QM\strategy_farm\artifacts\ftmo_trial_sets_review\ftmo_demo_book_v3_D2f_20260918\`.
Copy that directory's contents into the package as `sets/`:

    Copy-Item "D:\QM\strategy_farm\artifacts\ftmo_trial_sets_review\ftmo_demo_book_v3_D2f_20260918\*" "C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2f\sets\" -Force

**Readback:** `sets/manifest.json` has `schema qm.ftmo-trial-setpath/v2`, `installed:false`,
`installable:false`, `ENV:"live"`, `book_risk_percent: 2.34375`, `risk_percent: [0.15625, 0.3125]`,
8 candidates, and `roster_sha256` equal to the sha256 of `roster.json`. Eight `.set` files exist and
each one's sha256 equals its `output_sha256`.

**Stop if:** any refusal at all. `sealed_source_hash_drift` means G1 is not closed;
`roster_timeframe_mismatch` means a seal moved to a different timeframe; `unmapped_symbol_slot_input`
means an EA carries a second `.DWX` symbol slot whose venue name the roster does not know — never
paper over it, that leg would be silently dark.

**Readback (symbol rebind):** in the manifest, the 21505 and 13054 candidates must show
`symbol_slot_changes` rewriting `strategy_host_symbol` from `XAGUSD.DWX -> XAGUSD` and
`XTIUSD.DWX -> USOIL.cash`. If those two dictionaries are empty, the recompile from G2 did not
land and the sleeves will be dark — stop.

---

## Step 2 — rebind the governor (the only step that writes the repo)

    python -m tools.strategy_farm.ftmo.governor_rebind --roster docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f/roster.json --challenge-id M13_D2F_20260918_1514536732 --challenge-start-utc "2026.09.18 06:17:00" --receipt docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f/governor_rebind_receipt.json --apply

**Readback:** `applied: true`, `terminal_written: false`, `charts_changed: false`, and `updates`
identical to `governor_rebind_dryrun.json` (except `challenge_start_utc` if you moved the stamp).
The tool re-runs `load_binding()` as its own acceptance proof and rolls all three files back on any
failure, so `rebind_binding_incoherent` means nothing changed.

Then commit the three touched files with explicit pathspecs:
`framework/EAs/QM5_13206_ftmo-account-governor/sets/QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_active.set`,
`..._demo_bootstrap.set`, `tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json`.

**Stop if:** `magic_not_in_registry` or `registry_symbol_mismatch` — the roster and
`framework/registry/magic_numbers.csv` disagree; fix the registry first, never the roster.

---

## Step 3 — quiesce the terminal

1. In the FTMO demo terminal, **switch AutoTrading OFF** (toolbar button, or Ctrl+E). Confirm the
   button is grey and the journal logs `Expert Advisors auto trading disabled`.
2. Confirm no position is opening: Trade tab stable, no pending order about to fill. Open positions
   may remain — they are not closed by this procedure and the governor still watches them on
   restart.
3. **Shut MetaTrader down cleanly** (File -> Exit, or the window close button; never Task Manager).
   A clean exit is what flushes `[Experts] Enabled=0` into `config\common.ini` and what writes the
   current chart profile to disk.
4. Wait until no `terminal64.exe` remains whose path is under
   `C:\Program Files\FTMO Global Markets MT5 Terminal`.

**Readback:**

    Get-Process terminal64 -ErrorAction SilentlyContinue | Select-Object Id,Path
    Select-String -Path "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\config\common.ini" -Pattern "Enabled" -Encoding unicode

No FTMO-path process; `Enabled=0`.

**Stop if:** `Enabled` is still `1` — the shutdown was not clean, or a different process re-wrote
the file. `demo_install` will refuse anyway (`autotrading_must_be_disabled`), which is the intended
guard. Do not edit `common.ini` by hand to get past it.

**Do not touch the factory.** This step is unrelated to `Factory_OFF.ps1` / `Factory_ON.ps1`, and
T1-T10 keep running. Never reboot the VPS for this — that would stop T_Live live trading.

---

## Step 4 — back up the chart profile

With MT5 down:

    Copy-Item -Recurse "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Profiles\Charts\Default" "C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2f\profile_backup_pre_D2f" -Force
    Get-ChildItem "C:\QM\repo\docs\ops\evidence\2026-09-18_ftmo_demo_book_v3_D2f\profile_backup_pre_D2f" -File | Get-FileHash -Algorithm SHA256 | Select-Object Hash,Path

**Readback:** 12 files copied (11 `.chr` + `order.wnd`); the 11 hashes match CHART_PLAN.md section 1.

**Stop if:** any hash differs — the profile changed after this package was built; re-read it and
re-derive the plan before continuing.

---

## Step 5 — install (dry run, then execute)

    python -m tools.strategy_farm.ftmo.demo_install --package docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f --dry-run

**Readback:** `mode: DRY_RUN`, `autotrading_changed: false`, `charts_changed: false`,
`tlive_written: false`, `copy_count: 18`, `decision_id: OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917`,
`cycle_id: FTMO_DEMO_BOOK_V3_D2F_20260918`, `backup_dir` ending `_pre_FTMO_DEMO_BOOK_V3_D2F_20260918`.
Every copy row carries a 64-char `source_sha256`. Compare the row actions against PACKAGE.md
section 7 — in particular 10706 and 21505 must be `REPLACE` with a `backup_to`, and 11422/13054
`SKIP_IDENTICAL` **only if** G2 left their binaries unchanged (after a recompile they become
`REPLACE` too, which is expected).

Then:

    python -m tools.strategy_farm.ftmo.demo_install --package docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2f --execute

**Readback:** `status: INSTALLED_UNATTACHED_PARKED`, `authority.mode: OWNER_DECISION_RECEIPT`,
`charts_changed: false`, `tlive_written: false`, 18 entries in `installed`, and
`install_receipt.json` written into the package.

**Stop if:** `login_mismatch` / `server_mismatch` / `origin_mismatch` (wrong terminal —
never override), `preset_hash_mismatch` or `sealed_binary_mismatch` (the package drifted since
step 1 — rebuild it), `receipt_exists_refusing_overwrite` (a previous install already ran; do not
delete the receipt to force a second one), `backup_collision` (a backup dir for this cycle id
already exists).

Nothing is attached at this point. The EAs sit in `Experts\QM_FTMO`, the presets in
`Presets\QM_FTMO_M13`, and no chart references them.

---

## Step 6 — chart profile switch

Detailed target state, backup path and rollback are in CHART_PLAN.md. Sequence:

1. **Start the FTMO demo terminal** (normal desktop start, from
   `C:\Program Files\FTMO Global Markets MT5 Terminal\terminal64.exe`). It comes up with AutoTrading
   **off** — verify the toolbar button is grey before doing anything else. If it came up enabled,
   switch it off immediately and note it.
2. Confirm the terminal sees the new files: Navigator -> Expert Advisors -> `QM_FTMO` lists all
   eight sleeve EAs plus `QM_FTMO_TrialTelemetry` and the governor. If not, right-click ->
   Refresh.
3. Close the four leaving charts: chart03 (11421 EURUSD), chart05 (11910 NZDUSD), chart07 (20048
   USOIL.cash), chart08 (1537 XAGUSD).
4. Open the four new charts and attach, per CHART_PLAN.md section 2c: USDJPY H1 -> 13213 **at
   RISK_PERCENT 0.15625**; XAUUSD H1 -> 10700; XAUUSD D1 -> 10403; XAUUSD D1 -> 41219. Load each
   preset from `Presets\QM_FTMO_M13` via the EA properties Load button — do not type inputs.
5. Re-load presets on the four staying sleeve charts (02, 04, 06, 09) so they pick up the new
   binaries and, for 06/09, the venue `strategy_host_symbol`.
6. Re-load the rebound governor preset on chart01 and the new collector preset on chart10.
7. Leave chart11 (bare EURUSD) untouched.
8. **Shut the terminal down cleanly again** (File -> Exit). This is what persists the new profile
   to `.chr` — a change that is not followed by a clean shutdown is lost.
9. **Start the terminal once more**, still with AutoTrading **off**.

**Readback after step 6.9, with the terminal up and AutoTrading still off:**

    python -c "import sys;sys.path.insert(0,'.');from pathlib import Path;from tools.strategy_farm.ftmo import demo_cycle as d;T=Path(r'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\81A933A9AFC5DE3C23B15CAB19C63850');r=d.parse_chart_profile(T/'MQL5/Profiles/Charts/Default',T/'MQL5/Experts/QM_FTMO');print(len(r));[print(x) for x in r]"

Expect 8 rows, the D2f magics, `total risk 2.34375`, and every `ex5_sha` equal to the repo/seal sha
in PACKAGE.md section 3.

**Stop if:** the count is not 8, a magic is wrong, `risk_pct` for 13213 is not `0.15625`, or any
`ex5_sha` is `UNKNOWN` (the chart names an EA that is not in `Experts\QM_FTMO`).

---

## Step 7 — verification, AutoTrading still OFF

Work through CHART_PLAN.md section 4 items 1-7 first. Then:

    python -m tools.strategy_farm.ftmo.demo_cycle build --dark-after-days 5

**Readback:** `roster_hash` differs from `6c5383d8777728ba17abd1a836858b9db87c306d2931445ac642762075ac9bf2`,
`cycle_start_utc` is today, `sleeve_count: 8`, `total_book_risk_pct: 2.34375`, state `NEW` (it
becomes `RUNNING` on the next build). A new cycle is the point: D2f is a rep-breaking change and the
14-day representative clock restarts from zero.

Wait for the next `QM_FTMO_TrialPulse` run (every 30 min) and read
`D:\QM\reports\state\ftmo_trial_pulse.json`:

- `magics_seen == 8` and `expected_magics == 8`
- `effective_state == "RUNNING"`, `expected_state_condition == "ok"`, `terminal_up == true`
- `collector_snapshot_path` points at `...\ftmo_trial\FTMO_DEMO_BOOK_V3_D2F_20260918\trial_telemetry_raw.jsonl`
  and `collector_snapshot_age_minutes` is under 5

**Stop if:** `magics_seen != 8`. Note this check fails by construction until `EXPECTED_MAGICS` in
`tools/strategy_farm/ftmo_trial_pulse.py` is rebound to the D2f eight (GAPS G3) — do that in step 2's
commit, not here.

---

## Step 8 — AutoTrading ON (Fable, after step 7 passes)

Only once every readback in steps 5, 6 and 7 has passed: **Fable** switches AutoTrading on in the
FTMO demo terminal and records the timestamp. The governor QM5_13206 takes over enforcement from
that moment; `governor_dry_run` stays `false`.

Nothing in this runbook authorises AutoTrading on `C:\QM\mt5\T_Live` — that remains OWNER-only.

**Readback:** within one pulse cycle, `ftmo_trial_pulse.json` still reports `RUNNING`, `verdict` is
not `ALARM`, and `day_loss_pct` / `total_dd_pct` are sane. The eight charts show the EA smiley
enabled.

**Stop and switch AutoTrading back off if:** the governor logs a policy refusal, `magics_seen` drops
below 8, or the collector snapshot goes stale.

---

## Step 9 — day-5 dark check

After 5 trading days of the new cycle:

    python -m tools.strategy_farm.ftmo.demo_cycle build --dark-after-days 5

**Readback:** `attached_dark_count == 0`, `attached_dark_magics == []`, `attached_dark_risk_pct == 0`,
`realised_book_risk_pct == 2.34375`.

**This check is only meaningful once GAPS G7 is closed.** Today `observe_placements` finds no
`TM_OPEN` / `ENTRY_ACCEPTED` evidence at all and every sleeve reports
`placements_observed = EVIDENCE_MISSING`, so an empty `attached_dark` list is silence, not proof. A
sleeve that reports `EVIDENCE_MISSING` on day 5 must be treated as unverified, not as trading.

**If a sleeve is dark:** do not quietly leave it attached inflating the nominal book. Detach it,
record the realised book risk, and take the finding back into the weekly recomposition.

---

## Evidence to record when done

- `install_receipt.json` (written by step 5) and `governor_rebind_receipt.json` (step 2)
- the profile backup and its hashes (step 4)
- the post-change `parse_chart_profile` output and the first `demo_cycle build` ledger (steps 6, 7)
- the first `ftmo_trial_pulse.json` after AutoTrading on, and the timestamp of the toggle (step 8)
- a decision note under `decisions/` recording the D2f cutover, the two sleeves that needed a
  recompile, and the incumbent sleeves retired
