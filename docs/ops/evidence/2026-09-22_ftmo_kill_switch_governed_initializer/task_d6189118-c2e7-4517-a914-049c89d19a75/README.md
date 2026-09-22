# FTMO governed kill-switch initializer

Task: `d6189118-c2e7-4517-a914-049c89d19a75`

Verdict: **PASS_FOR_REVIEW**. The implementation and build evidence are complete. This is not a deploy approval, a pipeline verdict, or authorization to enable AutoTrading.

## Delivered contract

- `QM_FrameworkInit` now owns the one governed FTMO initialization path. When `qm_ftmo_execution_mode=QM_FTMO_EXECUTION_GOVERNED`, it must apply the validated generation book tag and a named Prague-midnight anchor before the framework can emit `INIT` or an EA can emit `INIT_OK`. A failed kill-switch initializer, setter, or required timer arm fails initialization.
- `FTMO_BALANCE_AT_MIDNIGHT` represents the current FTMO balance-at-midnight rule. `MAX_BALANCE_EQUITY` is the conservative QuantMechanica overlay and the governed input default. Non-FTMO EAs remain on the legacy path because governed execution defaults OFF.
- The Prague day key is derived from the US-DST-coupled broker server clock and the Europe/Prague calendar. The offset is `-1` in stable seasons and `-2` only during US/EU DST divergence.
- Live governed EAs use an advancing wall clock from `TimeGMT()` and a one-second `OnTimer` path, so a Friday-frozen `TimeCurrent()` cannot suppress a Sunday restart re-anchor or the next Prague-midnight rollover.
- State now persists `anchor_offset`, `anchor_mode`, `book_tag`, `prague_calendar`, and `prague_date`. `KS_DAY_ROLLOVER` records old/new day keys, synthesized server time, effective Prague time, offset, mode, selected anchor, and book tag.
- The read-only FTMO pulse checks every active-roster magic's `ks_state`, including current Prague day/date, dynamic offset, named mode, generation tag, and positive day anchor. State mismatch warnings remain active on weekends even if historical setter events exist.
- Server request thresholds are WARN at 200, ALARM at 500, and ALARM above 25 requests in any rolling 60-second window.

The required strict build checks also surfaced two mechanical pre-existing guard findings in named sleeves. `QM5_11422` now calls the standard Q08 MAE telemetry hook before early returns; `QM5_10403` explicitly zeroes three `QM_EntryRequest` structs. These changes do not alter entry or exit mechanics.

## Verification

- `python -m pytest -q tools/strategy_farm/tests/test_ftmo_trial_pulse.py tools/strategy_farm/tests/test_ftmo_kill_switch_governed_initializer.py tools/strategy_farm/tests/test_killswitch_state_lifecycle_static.py` -> **51 passed**.
- `python -m py_compile tools/strategy_farm/ftmo_trial_pulse.py` -> **PASS**.
- `git diff --check` across all task source/test files -> **PASS** (line-ending notices only).
- Strict `framework/scripts/build_check.ps1` on a detached task-scoped Git worktree -> **PASS for all six sleeves**. Every compiler result was 0 errors / 0 warnings. `QM5_13213` and `QM5_41219` retained three non-fatal missing-card inference warnings each; their final build status is PASS.

| Sleeve | Final receipt | Compile log | Compiled EX5 SHA-256 | Installed SHA-256 |
|---|---|---|---|---|
| `QM5_13213_balke-gmt3-range-breakout` | [receipt](build_reports/QM5_13213_balke-gmt3-range-breakout.build_check.json) | [log](compile_logs/QM5_13213_balke-gmt3-range-breakout.compile.log) | `d4bb740652f43974c9187db6088505d458b461ea5ccabad16a339cbbf26a32cb` | Pending authorized deploy |
| `QM5_10706_tv-mon-ls` | [receipt](build_reports/QM5_10706_tv-mon-ls.build_check.json) | [log](compile_logs/QM5_10706_tv-mon-ls.compile.log) | `6980e6eb4f4e78c038bbb3334150f6315fc3d47b3b09844ed861bc5cd9ac8724` | Pending authorized deploy |
| `QM5_10700_tv-liq-break` | [receipt](build_reports/QM5_10700_tv-liq-break.build_check.json) | [log](compile_logs/QM5_10700_tv-liq-break.compile.log) | `eb5b11ad3d01e894af8b3beb759191377bff2b6563ef74fe79674deb8db41783` | Pending authorized deploy |
| `QM5_11422_williams-18ma-outside-bar-entry-d1` | [receipt](build_reports/QM5_11422_williams-18ma-outside-bar-entry-d1.build_check.json) | [log](compile_logs/QM5_11422_williams-18ma-outside-bar-entry-d1.compile.log) | `d8c63c759bbb072f4349ddd88df50bf44f71efa965b035f8390fce454a15feac` | Pending authorized deploy |
| `QM5_10403_et-turtle20x` | [receipt](build_reports/QM5_10403_et-turtle20x.build_check.json) | [log](compile_logs/QM5_10403_et-turtle20x.compile.log) | `988ac73c35e9d3b89de948b07fe919ea0f6cc5bfeec1d3c5b8705ad659d0322b` | Pending authorized deploy |
| `QM5_41219_cum-rsi2-commodity-requal8` | [receipt](build_reports/QM5_41219_cum-rsi2-commodity-requal8.build_check.json) | [log](compile_logs/QM5_41219_cum-rsi2-commodity-requal8.compile.log) | `217ca85459769153e97b0e73e44a4ecc1fdb262369e1ab1aed0fda611ac7a53b` | Pending authorized deploy |

Machine-readable hashes and verification facts are in [verification.json](verification.json).

## Required runtime proof chain

Fable must complete this chain only under an OWNER-signed deploy manifest; this Codex task did not install binaries, attach charts, enable AutoTrading, or change T_Live.

1. Preserve the final build-check receipt for each sleeve, hash each authorized installed EX5, and prove every installed hash equals the corresponding reviewed compiled hash above.
2. For every roster magic, capture `KS_DAY_ANCHOR_SET` with the named mode and dynamic `-1`/`-2` offset, plus `KS_BOOK_TAG_SET` with the exact generation tag.
3. Read back every `ks_state_<ea_id>_<magic>.state` and prove its day key/date are current in Prague, its offset/mode/tag match the roster contract, and its day-start anchor equals the selected balance or conservative overlay.
4. With no market tick required, capture the next Prague-midnight `KS_DAY_ROLLOVER` and verify old/new keys, server/effective Prague times, offset, mode, and anchor.

Until all four runtime steps are attached, deployment proof remains **PENDING** and this artifact remains in REVIEW.
