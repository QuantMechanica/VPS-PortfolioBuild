# 2026-07-25 — FTMO Trial: QM_AccountMonitor deployed (read-only telemetry)

**Decision:** Deploy the read-only `QM_AccountMonitor` EA into the FTMO trial
terminal (account 1513845506, FTMO-Demo), mirroring the T_Live LiveOps pattern.

**Authority:** OWNER, 2026-07-25, in-session instruction to Claude: *"ja,
deploy es!"* — following the finding that the cockpit's FTMO equity came from
EA day-close EQUITY_SNAPSHOTs that lag days across weekends.

## What was deployed

- `framework/monitor/QM_AccountMonitor.mq5` (zero trade calls — no OrderSend;
  exports deal history + account snapshot only) compiled with the FTMO
  terminal's own MetaEditor (build-matched, 0 errors / 0 warnings) to
  `<FTMO data dir>\MQL5\Experts\QM_AccountMonitor.ex5`
  SHA256 `39B8300595953A3E7AE4E08BF1D2A836067EF431156EB4077F21ACDACE3E4133`.
- `chart13.chr` (EURUSD H1, inputs: InpTimerSeconds=60,
  InpJournalDir=QM\journal, InpShowPanel=true) added to the contract-verified
  `Default` profile — adapted from the proven T_Live monitor chart
  (`DarwinexZero_V1/chart25.chr`), new unique chart id.
- `tools/strategy_farm/verify_ftmo_round25_live_contract.ps1` extended:
  chart13 is now part of the pinned profile file set, with EA name/path/
  expertmode and binary-SHA assertions (fail-closed as before).
- `tools/strategy_farm/ftmo_trial_pulse.py`: prefers the monitor's
  `account_snapshot.json` (fresh ≤10 min) as equity source over the stale EA
  day-close snapshots; records `equity_source` in its state JSON.

## Procedure (Saturday, market closed, 0 open positions)

1. FTMO terminal stopped gracefully (CloseMainWindow, clean exit).
2. chart13.chr written; verifier updated.
3. Relaunch via `FTMO_ON.ps1` 15:03:21 local — contract verification PASSED:
   `VERIFIED: FTMO account 1513845506 / Default = approved Round25 12-leg
   profile + 12 SHA-pinned binaries + AccountMonitor telemetry chart`.
4. First export confirmed 15:04 local: 119 deal rows (full history since
   2026-06-29 incl. the $100,000 BALANCE row) + `account_snapshot.json`.

## Evidence & findings from the first export

- `<FTMO data dir>\MQL5\Files\QM\journal\live_deals_normalized.csv`:
  the FTMO demo account **books commission** (56 deals, Σ −$89.41) **and swap**
  (23 deals, Σ −$168.61) into equity — same as the DXZ account.
- Deal-history balance $90,002.40 == monitor equity $90,002.40 (flat book) —
  internally consistent to the cent.
- **Material finding:** real total DD = **10.00% of the 10% max-loss limit**
  ($90,002.40 vs $90,000 floor). The stale day-close figure ($92,314.81,
  2026-07-23T22:05Z) had been hiding 2.3 percentage points of drawdown.
  Trial is de facto at its loss limit — OWNER decision on continue/reset
  pending.

## Rollback

Remove chart13.chr from the Default profile, revert the verifier commit,
delete the .ex5 — the 12 trading legs are untouched by this deploy.
