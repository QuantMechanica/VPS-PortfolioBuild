# Codex Review: Kill-Switch Halt Channel H2

Task: `27c36fb7-d8e3-4d6f-b279-6d6b2c423a19`  
Review target: `SELF_REVIEW (R21): QM_KillSwitch halt-channel fix + book scoping (H2)`  
Date: 2026-07-07

## Verdict

PASS_CONDITIONAL for code acceptance. The halt-channel fix is directionally correct and the current canonical code preserves tester/non-book behavior while making the default halt files sandbox-reachable. Do not treat this as live rollout approval: book-scoped portfolio-DD use still requires the planned rebuild-time `qm_ks_book_tag` wiring and a runtime `KS_BOOK_TAG_SET` proof per live book.

## Evidence Reviewed

- `C:/QM/repo/docs/ops/KILLSWITCH_HALT_CHANNEL_FIX_2026-07-05.md`
- Commit `47f1d9709` (`fix(killswitch): halt-file channel was dead...`)
- Current `C:/QM/repo/framework/include/QM/QM_KillSwitch.mqh`
- Current `C:/QM/repo/framework/include/QM/QM_Common.mqh`
- Later hardening commit `841449513` (`fix(review-83be4dd3): C-2 tester-gate...`)
- Official MQL5 file-sandbox documentation:
  - https://www.mql5.com/en/docs/files
  - https://www.mql5.com/en/docs/files/fileisexist
  - https://www.mql5.com/en/docs/files/fileopen

## Claim Checks

1. MQL5 sandbox/dead-channel claim: VERIFIED. MQL5 file functions are restricted to the terminal file sandbox or `FILE_COMMON`; a default like `D:\QM\data\halt\...` is outside that contract. The patch changes default manual and portfolio signal paths to `QM\halt\...`, which `FileIsExist` checks locally first and then in Common via `FILE_COMMON`.

2. Default-preserving for tester runs: VERIFIED. `QM_KillSwitchCheck()` still computes daily-loss protection, but operator signal-file checks are behind `if(!is_tester)`, so tester runs do not consume manual halt or portfolio-DD files. The later state persistence code also skips restore/save under `MQL_TESTER`.

3. Default-preserving for non-book EAs: VERIFIED. `QM_FrameworkInit()` still calls `QM_KillSwitchInit(ea_id, g_qm_fw_magic, 3.0, 0.0, 1.0)` with no explicit signal paths. These EAs get the same daily-loss settings and now use `QM\halt\<ea_id>.halt` plus unscoped `QM\halt\portfolio_dd.signal`; since `portfolio_dd_halt_pct` remains `0.0`, the file only acts if an operator deliberately drops the signal.

4. `QM_KillSwitchSetBookTag()` explicit-path behavior: VERIFIED WITH WORDING NOTE. The function does not overwrite an explicit `portfolio_dd_signal_file` because `g_qm_ks_portfolio_signal_explicit` gates the reroute. It still stores the tag and logs `KS_BOOK_TAG_SET`; the "no-op" claim should be read as "no signal-path rewrite", not as "function returns false/no event".

5. New-build halt lever: VERIFIED for manual halt defaults. Newly compiled EAs that call the framework default path will check `QM\halt\<ea_id>.halt` in terminal-local files and Common files. Book-scoped portfolio-DD is not automatic; it requires the rollout-time `QM_KillSwitchSetBookTag(tag)` call.

## Focused Verification

Static verifier run from `C:/QM/repo`:

```text
no_runtime_old_manual_default: PASS
manual_default_relative: PASS
portfolio_default_relative: PASS
book_scoped_relative: PASS
explicit_path_guard: PASS
tester_file_gate: PASS
common_write_relative: PASS
old_common_write_absent: PASS
```

Compile evidence from the original patch note remains valid for syntax coverage:

```text
D:/QM/reports/compile/20260705_191059/summary.csv
QM5_10163_tv-rsi-macd-long: PASS, errors=0, warnings=0
```

## Review Notes

- The old `D:\QM\data\halt` string remains only in explanatory comments, not in the runtime default assignments or the framework suppression write path.
- `QM_Common.mqh` now writes KS-distribution suppression to `QM\halt\<ea_id>.halt`, removing the prior invalid absolute write-side path.
- The current code includes additional hardening beyond the July 5 H2 patch: state file is magic-scoped, tester state persistence is disabled, stale manual/portfolio halt state is not restored, pendings are deleted on trip, and halted exposure is re-swept.
- Operational docs correctly distinguish terminal-local and Common paths, and note that existing live binaries retain the old behavior until rebuilt.

## Conditions Before Live Reliance

- Rebuilt book EAs must expose/provide `qm_ks_book_tag` and call `QM_KillSwitchSetBookTag()` after `QM_KillSwitchInit`.
- Rollout evidence must include `KS_BOOK_TAG_SET` for each rebuilt book EA.
- Operator runbooks/vault references must not continue to point to `D:\QM\data\halt`.
- A live-fire test should drop a single-EA halt file while AutoTrading remains under the owner-approved rollout process; this review did not enable T_Live or AutoTrading.
