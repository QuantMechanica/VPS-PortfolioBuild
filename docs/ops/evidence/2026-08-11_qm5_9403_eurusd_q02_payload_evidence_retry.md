# QM5_9403 EURUSD H4 Q02 payload-evidence recovery

Date: 2026-08-11 (Europe/Berlin)

Branch: `agents/board-advisor`

Farm claim: `4a01860a-7992-4b74-b825-5ffa08efe233`

Status at readback: one append-only Q02 successor pending and unclaimed

## Outcome

The approved build queue contained zero open `build_ea` tasks with the
required deterministic prerequisites, so the mission advanced to its second
priority. The selected recovery is `QM5_9403_williams-pro-go-h4` on
`EURUSD.DWX` H4.

The preserved EURUSD predecessor
`1d72f99b-2c1a-473b-8cae-6974c51577e8` is terminal
`failed / INFRA_FAIL`; it never produced an economic Q02 verdict. The guarded
append-only operation created successor
`d81b27ac-586b-4925-abd2-85c8d69d73c1` at
`2026-08-11T20:55:08Z`. Immediate readback found it `pending`, attempt zero,
unclaimed, without a verdict, and the only open EURUSD Q02 row for this EA.

Normal paced workers own claim, dispatch, custom-history privatization, and
tester evidence. This unit did not launch a smoke test or backtest.

## Diversity and funnel value

The OWNER-approved Card cites Larry Williams, *Long-Term Secrets to
Short-Term Trading* (Wiley, 1999), chapter 14, in addition to its public
reproductions. Its R1-R4 gates and `g0_status` are PASS/APPROVED.

The rule is a structural, closed-form H4 decomposition of professional
intra-bar participation (`Close - Open`) versus gap participation, combined
with fixed SMA and ATR filters. It estimates 45 trades/year/symbol and uses
no ML, online fitting, grid, martingale, or PnL-adaptive mechanics.

The unchanged family reached `Q08 FAIL_SOFT` on `GDAXI.DWX`; EURUSD was never
economically classified because every one of its twelve historical Q02 rows
ended in infrastructure failure. Recovering the FX lane is therefore a
direct instrument-diversity probe for a family that reached the deep funnel
on an index. It is not claimed as a Q02 pass or a certified sleeve.

## Failure diagnosis and guard repair

The predecessor carries exact MQ5, EX5, setfile, expert, symbol, and H4
bindings, all of which still match the canonical artifacts. Its terminal
failure is `shared_bases_history_lock_transient_cap_exhausted`.

The first supported enqueue attempt failed closed with
`q02_rerun_target_mismatch_or_not_terminal_supported_verdict`. Diagnosis
showed a legacy evidence-shape mismatch:

- `work_items.evidence_path` is null;
- the immutable source payload names the retained terminal log in
  `transient_infra_evidence_path`;
- that file exists at `D:\QM\mt5\T3\logs\20260729.log` and records repeated
  `EURUSD.DWX` Windows file-sharing error 32 followed by
  `some error after pass finished`;
- log SHA-256 is
  `d6e4d3052d753fbf2569908bd432ab4d6c6d73f1dd368c5d213d410da22b7ca3`.

The exact-row Q02 guard now recognizes only this purpose-specific payload
field when the terminal verdict is `INFRA_FAIL` and the evidence column is
blank. It still requires the evidence file to exist, authenticates the
source row's complete execution identity, and records the evidence path,
binding source, and SHA-256 in both the append-only successor and enqueue
event. Rows without either evidence form remain fail-closed. The predecessor
was not updated.

Validation:

- `python -m pytest tools/strategy_farm/tests/test_candidate_repair_enqueue.py -q`:
  26 passed;
- positive regression: payload-bound transient evidence creates one sealed
  successor while leaving the historical evidence column null;
- negative regression: a null evidence column without that payload binding
  is refused;
- `py_compile`: PASS;
- `git diff --check`: PASS.

## Immutable execution contract

| Binding | Value |
|---|---|
| EA / slug | `QM5_9403` / `williams-pro-go-h4` |
| Symbol / timeframe | `EURUSD.DWX` / H4 |
| Magic slot / magic | `0` / `94030000`, ACTIVE |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` |
| Card SHA-256 | `2d968a4f6b66edfacc72f1c3a7d86c6f97231c8a7990e6915ce3a0941b783806` |
| MQ5 SHA-256 | `0b2b68f986d28daa4b34681c754a4ae9a07de7cc94dcdd1c025d2252671ecb50` |
| EX5 SHA-256 | `240e0fe04b1a93fbabb6c4996a9507424ee88941a3de7b43ef3ed9dc61bd4526` |
| Setfile SHA-256 | `576a03a4308657745ae6ad49d09bc848c4130b23c9dd87a452005b9e41b570ab` |
| Source payload SHA-256 | `f239be365754ece5da27b61de6d721d91e32d925054d8b79ed351decf429bf58` |

The setfile retains fixed risk. The EA's 336-hour news staleness limit was
also checked: the source and MT5 Common copies were hash-identical and at
most 41.96 hours old.

## Capacity, isolation, and enqueue readback

The final pre-enqueue scan found three governed factory terminals running
(`T1`, `T5`, `T8`) with three reservations, below the binding ceiling of
seven. There were no duplicate workers or orphaned terminal processes. A
five-sample host CPU check earlier in the same guarded window averaged
77.79% and peaked at 82.24%; the ceiling was not reached.

Variant A custom-history isolation remained activated and containment
remained disabled. The supported command inserted exactly one successor and
the duplicate guard reports exactly one successor for the predecessor.
SQLite `PRAGMA quick_check` returned `ok`.

## Safety boundary

- No Strategy Card, EA source, EX5, setfile, or strategy mechanic changed.
- No manual dispatch, smoke test, backtest, or pipeline phase was run.
- No `T_Live` path, AutoTrading setting, portfolio gate, deploy manifest, or
  live-trading artifact was changed.
- Pre-existing unrelated worktree changes were preserved and excluded.

Machine-readable evidence:
`artifacts/qm5_9403_eurusd_q02_payload_evidence_retry_20260811T205508Z.json`.
