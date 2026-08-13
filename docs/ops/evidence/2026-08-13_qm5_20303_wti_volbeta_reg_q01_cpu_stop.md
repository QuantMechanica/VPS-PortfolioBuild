# QM5_20303 WTI Vol-Beta Regime - Q01 PASS / Q02 Enqueued / CPU Stop

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

`QM5_20303_wti-volbeta-reg` is a new low-frequency outright-WTI structural
candidate. It is card-approved, allocated, built, Q01 `PASS`, and has exactly
one Q02 row. The row was inserted by a concurrent canonical producer while
the source/build race was being repaired; this agent did not issue the enqueue
or a dispatch. It remained pending and unclaimed because the paced factory
ceiling was binding.

No manual backtest, dispatch tick, requeue, terminal reservation, or terminal
process control was performed by this mission. The only direct T1-T10
mutation was canonical build-artifact deployment; `T_Live`, AutoTrading, the
live manifest, and the portfolio gate were not used or changed.

## Edge And Execution Contract

At the first processed D1 bar after a genuine broker-month transition, the EA
loads exactly 545 synchronized completed `XTIUSD.DWX` and `XNGUSD.DWX` closes.
It converts them to 544 chronological simple returns and splits them into two
disjoint 272-return blocks: preceding indices `0..271` and recent indices
`272..543`.

Each block independently:

1. estimates XTI and XNG sample standard deviations on local indices
   `20..271` and forms normalized inverse-volatility weights;
2. constructs all 272 common-energy returns;
3. calculates the factor mean and sample deviation on indices `20..271`;
4. forms exact 20-return sample-volatility changes, setting the change to zero
   rather than dropping the row when the factor return is at least two sample
   deviations from its block mean;
5. regresses WTI return on an intercept, common-energy return, and smooth
   volatility change over exactly 252 rows, requiring at least 200 non-jump
   rows and a finite full-rank solution.

The EA buys WTI when the recent smooth-volatility beta exceeds the preceding
beta by more than `1e-12`, sells when it is below by more than `1e-12`, and
consumes a tie or invalid state flat. XNG is read-only: it has no magic and no
order path. The one WTI position has a frozen `3.5 * ATR(20,D1)` stop, no
take-profit, next-month replacement, and a forty-day stale guard.

The sole setfile is `environment=backtest`, `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. News modes and Friday close are
OFF. There is no trained output, prohibited signal indicator, external runtime
feed, optimizer result, grid, martingale, scale-in, or pyramid.

## Source And Claim Boundary

The Tier-A source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies in
Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The bounded packet is
`strategy-seeds/sources/HOLLSTEIN-WTI-VOLBETA-REG-2026/source.md`; durable G0
authorization is
`decisions/2026-08-13_qm5_20303_wti_volbeta_reg_g0.md`.

The paper defines an option-derived aggregate smooth-volatility beta and a
monthly positive high-minus-low commodity relation. It does not test the EA's
realized two-CFD factor, two own-history blocks, outright WTI rule, continuous
CFD, fixed-risk stop, or QM portfolio. Its result also does not clear the
paper-wide multiple-testing threshold. The closest family build,
`QM5_13151_energy-volbeta`, reached Q08 and then failed hard on runs-test
`p=0.02295` and a losing low-volatility regime. Those limitations remain part
of the card.

## Non-Duplicate Boundary

The canonical checker scanned 4,368 EA-registry rows and 479 cards, found no
exact identity, and returned one expected source-family fuzzy neighbor. Manual
review separated it: `QM5_13151` estimates concurrent XTI and XNG betas in one
block, ranks the assets, and trades both legs. `QM5_20303` estimates WTI beta
in two disjoint history blocks, compares recent with preceding, trades one WTI
leg, and makes XNG read-only. WTI VoV, tail, moment, trend, calendar, event,
breakout, reversal, variance-ratio, and robust-location EAs use different
state objects. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_SMOOTH_VOL_BETA_AFTER_MANUAL_REVIEW`.

## Allocation And Q01 Evidence

- EA / magic: `QM5_20303` / slot 0 / `203030000`.
- Strict compile: `D:/QM/reports/compile/20260813_095341/summary.csv`, PASS,
  zero errors and zero warnings.
- Final target build check:
  `D:/QM/reports/framework/21/build_check_20260813_095552.json`, PASS, zero
  failures and zero warnings.
- P1 artifact: `D:/QM/reports/pipeline/QM5_20303/P1/P1_QM5_20303_result.json`,
  PASS.
- Independent reference suite: six of six tests PASS for sample denominators,
  block-local weights, exact OLS rows, disjoint supports, jump-row zeroing,
  direction/tolerance, chronological return mapping, synchronization, and
  freshness.
- Deployed EX5 SHA-256:
  `EA2EC9A3BC16E363F2A610DB0D679941331884FF44D5C62AD611BAE47C50C83D`;
  verifier PASS across T1-T10.
- Deploy receipt:
  `D:/QM/strategy_farm/artifacts/deploy/QM5_20303_wti-volbeta-reg_deploy_20260813T0956Z.json`.
- Backtest set normalized-content build hash:
  `8f0d5bd5245f1904aee2868330fcca4031588562a5c1ab7d9e877713c38e5702`.

## Q02 Enqueue And Capacity Stop

At `2026-08-13T09:44:04Z`, read-only `farmctl.py mt5-slots` found two active
factory terminals, T5 and T7. The authoritative paced maximum in
`D:/QM/strategy_farm/state/launch_gate_max.txt` was `1`. `farmctl.py
work-items --ea QM5_20303` returned zero existing rows.

At `2026-08-13T09:53:13Z`, the canonical producer created Q02 work item
`81939741-407c-40dc-b6ad-91baa91c0e92` for `XTIUSD.DWX` D1. Final readback
found it pending, unclaimed, attempt zero, with no evidence path or verdict.
This agent did not enqueue or dispatch it.

At `2026-08-13T09:59:20Z`, capacity had worsened to four running factory
terminals (T5, T7, T9, and T10) against the ceiling of one. The row was left
pending; no dispatch, tester, reservation, stop, or reap followed. FTMO and
`T_Live` were excluded from the factory count and were not controlled. The
card therefore records `pipeline_phase: Q02_ENQUEUED` and
`q02_status: ENQUEUED`, without claiming a Q02 verdict.

Machine-readable evidence is
`artifacts/qm5_20303_wti_volbeta_reg_cpu_stop_20260813T095720Z_board_advisor.json`.

## Scoped Mission Commits

- `fadc7aa22` - durable mission G0 authorization.
- `7063bb40a` - bounded source packet and synchronized approved/intake cards.
- `c32ee5235` - deterministic EA-ID reservation.
- `7b3441218` - slot-0 WTI magic, SPEC, and regenerated resolver.
- `2ca1168d3` - initial EA package and Q01 bindings.
- `fd89295ca` - correct smooth-volatility-beta source/binary binding after an
  overlapping workspace write was detected and repaired.
- `98ce2e969` - independent build-only review, final set hash, and zero-warning
  post-set validation.

No efficacy, certification, realized decorrelation, portfolio admission, or
correlation waiver is inferred from the build or Q01 PASS.
