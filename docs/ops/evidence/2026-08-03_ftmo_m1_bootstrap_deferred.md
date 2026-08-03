# FTMO M1 bootstrap — fail-closed defer evidence

Date: 2026-08-03  
Router task: `1b00f708-37d1-4a9d-b344-a051cde8c809`

## Outcome

`DEFERRED_ACTIVE_CHALLENGE_AUTOTRADING`.

No FTMO research terminal was launched.  The Program Files challenge terminal
was running as PID 8344 on shared demo account `1514165262`; its bound terminal
log records the challenge EAs loaded and `automated trading is enabled` at
2026-08-02 19:37:38 local.  The latest account synchronization records zero
positions and zero orders, but also records trading enabled.  Absence of an
open position is not authorization to overlap the OWNER's active challenge
terminal, so the requested coordinated nontrading window is not established.

This is the hard safety condition in the routed payload.  Stopping or changing
that terminal, disabling AutoTrading, or assuming that a weekend is a window
would exceed agent authority.

## Read-only work completed

- Refreshed `qm.ftmo-lane-provision-receipt/v1` artifacts via
  `ftmo_lane_runner.py provision-receipt` for STREAM1 and then STREAM2.
- Both receipts remain `HOLD`, `campaign_ready=false`, with zero FTMO lane
  processes and no XAUUSD / GER40.cash M1 cache.
- Recorded a per-symbol book-plus-majors inventory in
  `2026-08-03_ftmo_m1_bootstrap_coverage.json`.  The four incidental
  `Bases/Default` FX HCC files are explicitly unbound and do not prove an FTMO
  first/last bar or coverage depth.
- Executed the calibrated-spread tool against the reviewed spec.  It correctly
  returned `REFUSED` because the required XAUUSD FTMO HCC is absent; no spread,
  commission, or swap value was invented.

## Durable identities

| Artifact | SHA-256 |
|---|---|
| `D:/QM/reports/state/FTMO_STREAM1_provision_2026-08-03.json` | `1340bb513ed16e5cbf8c65a73d1c1b85de078d3d56c0dd6b4e401ccf2645af14` |
| `D:/QM/reports/state/FTMO_STREAM2_provision_2026-08-03.json` | `83b82ce1100f86ef44e2ac534d12ac5b881e7bf62b5d9f1bda92efb6f16e7bb8` |
| Program Files challenge terminal log | `70a3e4c6829251a638d70a904ca83930af62f6f1323bd8d93335f9d70ccfc635` |
| Calibration refusal | `b366ed3ffed04371f6a8ed565de6d751d079108c71585fbe6d03d54cd3bac9f6` |

## Focused verification

`python -m pytest -q tools/strategy_farm/tests/test_ftmo_lane_runner.py`
completed with `13 passed`.

The lane receipts each record `autotrading_touched=false`; the observed peak
FTMO lane concurrency was zero.  T_Live, the challenge terminal, AutoTrading,
and all T1–T10 backtests were untouched.

## Required continuation

OWNER must establish a durable nontrading window for demo account 1514165262.
Only then may `FTMO_STREAM1` and `FTMO_STREAM2` run, strictly serially and only
through `ftmo_lane_runner.py`, to produce actual first/last M1 bars, depth,
lane receipts, and the session-bucket calibration.
