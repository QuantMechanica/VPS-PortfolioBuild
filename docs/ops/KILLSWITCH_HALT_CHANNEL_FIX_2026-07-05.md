# Kill-switch halt-file channel: dead-path fix + book scoping (H2)

**Date:** 2026-07-05 (night shift, OWNER standing directive „Arbeite die Nacht durch")
**Status:** patched + compile-validated (PASS 0/0, QM5_10163 full include chain);
**rollout to live books pending** (next rebuild cycle; NOT deployed to any live
terminal tonight). SELF_REVIEW → Codex ticket (below).

## Finding 1 — the halt-file channel was dead code on live terminals

`QM_KillSwitchInit` defaulted `manual_halt_file` / `portfolio_dd_signal_file` to
absolute `D:\QM\data\halt\...` paths and fed them to `FileIsExist`/`FileOpen`.
The MQL5 file sandbox cannot resolve drive-letter paths — both checks always
returned false. Evidence: `D:\QM\data\halt\` empty since 2026-05-23 creation;
zero `KS_MANUAL`/`KS_PORTFOLIO_DD` events in any live log ever; the write-side
cross-restart suppression (`QM_Common.mqh` ks_distribution_divergence) wrote to
the same invalid path (silently failed). Only the tester was unaffected — file
checks are skipped under `is_tester`, and the (functioning) daily-loss equity
halt never depended on files.

## Finding 2 — the channel was also un-scoped (H2 blocker)

A working global `portfolio_dd.signal` would have halted BOTH live books
(T_Live DXZ + FTMO) — the original H2 concern.

## The patch (commit-ref in git)

1. **Sandbox-valid defaults** (`QM_KillSwitch.mqh`): `QM\halt\<ea_id>.halt` and
   `QM\halt\portfolio_dd.signal`. Semantics: terminal-LOCAL `MQL5\Files\QM\halt\`
   checked first (terminal-scoped halt), then `Common\Files\QM\halt\` via
   FILE_COMMON (machine-wide halt) — the proven channel family (news calendar,
   q08 streams live in Common\Files\QM).
2. **Book scoping**: new `QM_KillSwitchSetBookTag(tag)` — reroutes the portfolio
   signal to `QM\halt\book_<tag>\portfolio_dd.signal`. Rollout pattern identical
   to `QM_FrameworkSetRiskCapPct` (proven on the FTMO deploy): book EAs gain an
   input `qm_ks_book_tag` at their next rebuild; runtime proof = `KS_BOOK_TAG_SET`
   event. No-op for explicit init paths; default-preserving for all other EAs.
3. **Write-side fix** (`QM_Common.mqh`): suppression halt-file now
   `QM\halt\<ea_id>.halt` (sandbox-relative).

## Operational semantics after rollout (runbook delta)

- Manual halt one EA in ONE terminal: drop `<terminal>\MQL5\Files\QM\halt\<ea_id>.halt`.
- Manual halt one EA machine-wide: drop `Common\Files\QM\halt\<ea_id>.halt`
  (NB: EAs living in both books, e.g. 10440/10692, are halted in both).
- Total-DD floor per book: operator/pulse writes
  `Common\Files\QM\halt\book_<tag>\portfolio_dd.signal` (content: threshold value
  per existing `QM_KillSwitchPortfolioSignalTriggered` parsing).
- Newly built EAs (incl. tonight's 29-build wave) get the fixed defaults
  immediately — the halt lever WORKS for them once they go live. Existing live
  binaries keep the dead paths until rebuilt (unchanged risk posture).

## Rollout plan (pending)

1. FTMO challenge rebuild (challenge start): add `qm_ks_book_tag=ftmo_r25` input
   + `QM_KillSwitchSetBookTag` call to the 12 book EAs (with the planned scale
   presets); verify `KS_BOOK_TAG_SET` in 12 logs; arm the pulse watcher
   (`ftmo_trial_pulse.py`, −8% floor → writes the book signal; gated by
   `D:\QM\reports\state\FTMO_DD_FLOOR_ARMED.flag`).
2. T_Live DXZ book: same pattern (`dxz`) at the next book-change rebuild —
   full T_Live workflow (OWNER manifest + verification), never hot.
3. Update the manual-halt runbooks/vault (old D:\QM\data\halt references).

## Validation

- compile_one QM5_10163 vs patched includes: PASS, 0 errors, 0 warnings
  (D:\QM\reports\compile\20260705_191059\summary.csv).
- Repo `.ex5` of the validation EA restored via git (no build-lane record).
- Empirical live-fire of the new channel: part of rollout step 1 (drop a test
  halt file for one FTMO-demo EA before AutoTrading of the challenge).
