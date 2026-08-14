# QM5_21519 XNG Weekend Hold Q01 And Q02 Handoff

Date: 2026-08-14

Branch: `agents/board-advisor`

Owner: Codex

## Edge built

- EA: `QM5_21519_xng-wkend-hold`
- Strategy ID: `TGIF-XNG-WEEKEND-2017_S04`
- Host: `XNGUSD.DWX`, H1, slot 0, magic `215190000`
- Signal: consume one attempt on the genuine Friday 21:00 broker H1
  boundary and buy XNG within a five-minute attach grace.
- Lifecycle: deliberately hold through the closed-market weekend, close at
  Monday 21:00, repair a missed cutoff on the first Tuesday-through-Thursday
  tick, and enforce a 96-hour stale limit.
- Protection: frozen `3.5 * ATR(20,D1)` server stop, no target, retry, short,
  scale, grid, martingale, optimizer, or trained input.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

This calendar/event-risk state is materially different from the certified
`QM5_12567` cumulative-RSI pullback logic. Realized portfolio independence is
not claimed; it remains a later correlation gate.

## Source and claim boundary

The bounded packet uses the complete governed review of Hoelscher, Mbanga,
and Nelson (2017), "TGIF? The Weekend Effect in Energy Commodities," DOI
`10.58886/jfi.v16i1.2264`, and official U.S. EIA natural-gas demand context.
The paper supports the natural-gas Monday return family; EIA supports the
weather-sensitive information mechanism. Neither source tests this exact
Friday-to-Monday Darwinex CFD implementation, H1 cutoff, fixed risk, ATR
stop, costs, performance, or book correlation.

A fresh generic journal URL route returned `DEFERRED:SOURCE_POLICY`; no
access-control workaround was attempted and no ungoverned webpage text was
imported. R1-R4 are PASS using the existing complete source-of-record packet.

## Non-duplicate boundary

The canonical pre-card check found no exact slug or strategy-ID collision
across 4,391 EA-registry rows and 487 root cards. Its single source-family
fuzzy neighbor, `QM5_20016_xti-xng-mon-rv`, enters a required two-leg package
after Monday starts. `QM5_12806_xng-rev-weekend` buys Monday and sells Friday;
`QM5_12738_xng-weekend-gap` waits for a realized Monday gap; and
`QM5_12567_cum-rsi2-commodity` trades oscillator pullbacks. This EA is XNG-
only and enters before the closed-market interval with no gap, trend, or
oscillator state.

Verdict:
`CLEAN_AUTHORIZED_XNG_PREWEEKEND_TO_MONDAY_HOLD_AFTER_FAMILY_REVIEW`.

## Artifacts

- Card: `strategy-seeds/cards/xng-wkend-hold_card.md`
- Approved card:
  `strategy-seeds/cards/approved/QM5_21519_xng-wkend-hold_card.md`
- Source packet:
  `strategy-seeds/sources/TGIF-EIA-XNG-WKEND-2026/source.md`
- G0 decision: `decisions/2026-08-14_xng_wkend_hold_g0.md`
- EA:
  `framework/EAs/QM5_21519_xng-wkend-hold/QM5_21519_xng-wkend-hold.mq5`
- EX5:
  `framework/EAs/QM5_21519_xng-wkend-hold/QM5_21519_xng-wkend-hold.ex5`
- Q02 setfile:
  `framework/EAs/QM5_21519_xng-wkend-hold/sets/QM5_21519_xng-wkend-hold_XNGUSD.DWX_H1_backtest.set`
- Build record: `artifacts/qm5_21519_build_result.json`

## Q01 validation

- Card schema lint: PASS on root, approved, and EA-doc copies; their SHA-256
  hashes are identical.
- SPEC schema: PASS, 1/1.
- Weekend schedule reference: PASS, 7/7.
- Symbol scope: `SINGLE_SYMBOL_OK`, 0 violations.
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log:
    `C:\QM\repo\framework\build\compile\20260814_081808\QM5_21519_xng-wkend-hold.compile.log`
  - EX5 size: 373666 bytes.
- Final framework build check: PASS, 0 failures, 0 warnings.
  - Report:
    `D:\QM\reports\framework\21\build_check_20260814_082128.json`.
- P1 artifact: PASS.
  - Report:
    `D:\QM\reports\pipeline\QM5_21519\P1\P1_QM5_21519_result.json`.
- EX5 SHA-256:
  `35d5af689b56003f73e17c8677546c5d1ef66696b0c14c48f1ecae1761da6eaa`.

Targeted EA-ID, magic, resolver, and build guardrails pass. The broad
repository registry audit continues to report unrelated pre-existing legacy
row and duplicate-magic debt; none of its findings references `QM5_21519`.

## Q02 handoff

At `2026-08-14T08:21:49Z`, the capacity scan showed zero active factory MT5
terminals and no factory terminal reservations, so the 10-slot CPU ceiling
was not hit. The two visible `terminal64` processes were non-factory FTMO and
`T_Live`; neither was touched.

At `2026-08-14T08:26:13Z`, the canonical command
`farmctl.py enqueue-backtest --ea QM5_21519 --phase Q02` failed closed with
`reason=factory_off`. The OWNER-set flag states that claims are paused while
archive-file deletions during runs are investigated. Its SHA-256 was
`6c9aaf4a4aafce4a887e41d9d6cb46622c2be5efb42c6788da5cb88052b86c3c`.

The canonical queue readback returned zero work items for `QM5_21519`.
Therefore Q02 is accurately recorded as `BLOCKED_FACTORY_OFF`, not enqueued.
No flag, queue row, worker, reservation, terminal, or tester was bypassed or
manually changed. Once OWNER clears the forensic pause, the next operator can
rerun the same targeted canonical enqueue command and verify one pending,
unclaimed Q02 row.

## Safety

No MT5 test or live trade, AutoTrading toggle, `T_Live` file, deploy/T_Live
manifest, portfolio gate, portfolio admission, correlation waiver, or
portfolio KPI file was touched.
