# DL — T_Live DXZ: ADD_SLEEVE 10700/XAUUSD.DWX, 24→25 sleeves (2026-09-20)

**Status: DRAFT — PREPARATION ONLY, NOT STAGED, NOT DEPLOYED.**
Nothing under `C:\QM\mt5\T_Live` was written. This record captures the evidence and the
concrete gaps found while preparing the cutover; it is not yet an executable deploy
package. Written by Claude (board-advisor fork) at OWNER's request ("bereite alles vor").

## What changes (proposed)

Add `10700:XAUUSD.DWX` (`QM5_10700_tv-liq-break`, magic `107000003`, registry slot 3,
`framework/registry/magic_numbers.csv:5320`) to the live 24-sleeve DXZ book (`live_24`),
producing a 25-sleeve book at total risk budget 11.0% (up from the currently deployed
9.7499% — see "Risk budget" below, this is not a new ceiling, see caveat).

## Evidence (this week's CBE cut, 2026-W38)

- Cut instant `2026-09-18T21:15:00Z`, cut `c1`, git `412e6fd897c2ec4dafa3d844769f937965cb918b`.
- Package: `D:\QM\reports\book_evolution\2026-W38\cuts\c1\OWNER_DECISION_PACKAGE.md`.
- Evidence: `D:\QM\reports\book_evolution\2026-W38\cuts\c1\analysis\2026-W38\dxz\evidence.md`,
  `evaluation.json` (proposal + alternatives_assessed[*] for `add:10700:XAUUSD.DWX`).
- Outcome: **ADD_SLEEVE**, materiality `True` (`material_alternative_selected`).
- Expected metrics (25 sleeves vs 24-sleeve incumbent, both evaluated at the same 11.0%
  risk budget): ann return 11.876144% (was 11.009072%), maxDD 3.48282% (was 3.681782%),
  Sharpe 2.5806530778 (was 2.4349049634), ENB 23.89522565, tail ES5 -0.53645595%.
- Confidence: bootstrap CI (α=0.1, 2000 reps, block_days=10, n_days=1550) excludes zero:
  `[0.0009245788, 0.0056121655]`, point mean `0.0032487875`.
- Hard portfolio guards: passed. Advisory (non-blocking): XAUUSD book exposure rises
  2.3939%→2.4714% (already the largest symbol; 22.47% of the risk budget after the add).
- 12 other alternatives tested this cut (mostly `replace:13213:USDJPY.DWX->X`) — all
  **not material** (`bootstrap_ci_does_not_exclude_zero_positively`, `downside_risk_worsens`,
  `improvement_not_split_half_consistent`).

## Risk-budget caveat (important, read literally)

`evaluation.json.risk_budget_pct = 11.0` and `sleeve_cap_pct = 1.5` are the CBE engine's
configured evaluation parameters for this venue — not a number newly proposed this week.
The currently *deployed* book (`portfolio_manifest_live_24sleeve_20260724.json`, OWNER-
approved 2026-07-24) sums to **9.7499%** actual risk; the evaluation compares candidate
compositions at the already-configured 11.0% budget. So "risk increases 9.75%→11.0%" is
this proposal filling existing, previously-approved headroom, not a fresh ceiling change —
but it IS a real increase in deployed risk and should be read/approved as one, not waved
through as "no change." Where the 11.0%/1.5% figures themselves were set is not verified
in this session — flag for confirmation before relying on it further.

## Verification done (read-only, this session)

- **10700 is genuinely new to T_Live**: no `*10700*` preset or expert file found under
  `C:\QM\mt5\T_Live\MT5_Base\MQL5\{Presets,Experts}`.
- **Magic registry**: clean single entry, `10700,tv-liq-break,3,XAUUSD.DWX,107000003,
  2026-05-31,Development,active` (`framework/registry/magic_numbers.csv:5320`). No
  collision found against other rows checked. Registry lifecycle tag reads "Development" —
  not independently resolved whether that blocks a live deploy; flag for the apply step.
- **News calendar**: `D:\QM\data\news_calendar` last refreshed 2026-09-19 05:30 (bundle
  manifest + both CSVs) — current, not stale, as of this cut.
- **Live-mode set file: MISSING.** `framework/EAs/QM5_10700_tv-liq-break/sets/` has only
  backtest / q05 / q06 / q10-confirmation sets for XAUUSD.DWX H1 — no `ENV=live`,
  `RISK_PERCENT`-bearing set file exists yet. One must be generated
  (`framework/scripts/gen_setfile.ps1` per the documented SOP) before staging.
- **Per-sleeve risk weight: NOT COMPUTED.** `evaluation.json` and the OWNER decision
  package carry only aggregate portfolio metrics for the 25-sleeve candidate (total risk,
  Sharpe, maxDD, ENB, tail ES5) — no per-sleeve `RISK_PERCENT` breakdown for 10700 or for
  whether the other 24 sleeves get rescaled. This number does not exist anywhere in this
  week's evidence and was NOT invented here.
- **Cutover tooling mismatch**: `tools/strategy_farm/tlive_book_cutover.py` (the script the
  OWNER decision package's own suggested command list names) is hardcoded to a *different*,
  already-scoped 28-sleeve `DarwinexZero_Book2_LiveOps` cutover from 2026-09-13/14
  (`STAGING = C:\QM\deploy\DXZ_V2_20260913`, preflight hard-requires
  `n_sleeves == 28 and n_charts == 29`, decision refs
  `decisions/2026-09-14_owner_risk_freeze_lift.md` +
  `decisions/2026-09-15_owner_freifahrtsschein_scope_1_to_3.md` +
  `decisions/2026-09-13_owner_governor_enforce_dxz.md`). It is not a generic "add one
  sleeve" tool and was not run against this proposal (running its `plan` preflight would
  check the wrong target book and fail on the sleeve-count assertion).

## Backup (done, additive, read-only against T_Live)

Full copy of the currently live profile, all deployed presets, and `common.ini`:
`D:\QM\strategy_farm\tlive_staging\backups\preflight_20260920T200807Z\` (137 files:
`profile_DarwinexZero_V2_LiveOps/`, `presets/`, `config/common.ini`). Nothing in
`C:\QM\mt5\T_Live` was modified to produce this backup.

## Rollback path

Not yet applicable — no live change has been made. If a future cutover based on this
proposal needs to be reverted, restore from the backup above (or from whatever backup
the actual cutover tool produces under `D:\QM\reports\state\backups\` at apply time) and
relaunch T_Live on the previous profile (`DarwinexZero_V2_LiveOps`).

## What remains before this can go live

1. Compute the per-sleeve `RISK_PERCENT` for `10700:XAUUSD.DWX` (and confirm whether the
   other 24 sleeves' weights change) under the 25-sleeve/11.0%-budget target — a portfolio-
   construction step, not yet run.
2. Generate a live-mode (`ENV=live`, `RISK_PERCENT` set, `RISK_FIXED=0`) set file for
   `QM5_10700_tv-liq-break` / XAUUSD.DWX from that weight.
3. Build a proper staging manifest in the schema `stage_tlive_presets_risk.py` /
   `build_tlive_book_profile.py` expect (`sleeves[]` with `ea_id`, `symbol`, `risk_percent`
   or `weight_risk_percent`/`burn_in_risk_percent`, `is_new_sleeve`, `magic`) — the existing
   `portfolio_manifest_live_24sleeve_20260724.json` is a reporting snapshot, not this format.
4. Either extend/adapt `tlive_book_cutover.py` for a 25-sleeve delta cutover, or confirm
   whether a smaller single-sleeve-add path is preferred, before running any `--apply`.
5. Only then: `build_tlive_book_profile.py build` (dry-run first) → verify → the actual
   apply/deploy/AutoTrading step, which is Fable-operable per
   `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917` under the production-discipline
   steps above (this record itself is part of that discipline).
