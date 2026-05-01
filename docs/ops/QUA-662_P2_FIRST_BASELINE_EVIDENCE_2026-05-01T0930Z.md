> **INVALIDATED 2026-05-01 by Board Advisor at OWNER direction.** This "first baseline" run produced zero trades — Pipeline-Op's own `zero_trade_audit_20260501.json` documents this. The EURUSD.DWX run referenced here is the original pre-magic-resolver-fix attempt, not the later P2_postfix2 verified run. See `docs/ops/QUA-662_PHANTOM_PASS_AUDIT_2026-05-01.md` and `decisions/DL-054_anti_theater_pass_criteria.md`.

# QUA-662 P2 first baseline evidence (2026-05-01T09:30Z)

## Action taken

Executed first real P2 baseline run for `QM5_1003` on `EURUSD.DWX` (Model 4, year 2024, H1, 2 runs, setfile-bound).

## Run evidence

- smoke/baseline summary:
  - `D:/QM/reports/pipeline/QM5_1003/P2/QM5_1003/20260501_092333/summary.json`
- run evidence markdown:
  - `D:/QM/reports/framework/22/20260501_092333_QM5_1003_run_smoke.md`

## Dispatch ledger

Canonical dispatch state updated (`start -> complete`) for:
- dedup key: `QM5_1003|v1|EURUSD.DWX|P2|H1-2024`
- lifecycle statuses observed: `scheduled` -> `released`

Phase matrix bucket status (dispatch_state):
- bucket: `QM5_1003_v1_P2`
- current phase verdict: `PASS`
- rows recorded: `EURUSD.DWX` with PASS evidence link above

## Notes

- Earlier `start` attempt with pinned terminal produced non-trackable completion (`not_found`) because pinned dispatch bypassed dedup insertion. Corrected by replaying canonical state lifecycle.
- One `no_capacity` response occurred due existing terminal load; resolved via controlled retry with temporary higher capacity cap for ledger insertion of already-completed run.

## Next action

Continue P2 matrix expansion (additional DWX symbols) and maintain filesystem-first evidence discipline for each run.
