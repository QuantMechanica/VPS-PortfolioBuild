# QM5_20303 WTI Vol-Beta Regime - Q01 PASS / Q02 Enqueued (Pending) / CPU Stop

Date: 2026-08-13 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

`QM5_20303_wti-volbeta-reg` is a new low-frequency outright-WTI structural
candidate. It is card-approved, allocated, built, and Q01 `PASS`. Exactly one
canonical Q02 row exists: work item
`81939741-407c-40dc-b6ad-91baa91c0e92`, pending and unclaimed at final
readback. A concurrent canonical sweep created that row after this mission's
initial zero-row check. The build-result recorder detected it and skipped a
duplicate.

No Q02 dispatch or manual backtest followed because the paced launch ceiling
was already binding. The configured maximum was one research terminal and the
first bounded sample found two. This mission's explicit CPU-stop rule therefore
took precedence over any further pipeline action.

No terminal was launched, stopped, reserved, or reaped. The canonical EX5 was
hash-staged to the T1-T10 research terminals and verified; `T_Live`,
AutoTrading, the live manifest, and the portfolio gate were not used or
changed.

## Edge And Execution Contract

At the first processed D1 bar after a genuine broker-month transition, the EA
loads exactly 545 synchronized completed `XTIUSD.DWX` and `XNGUSD.DWX` closes.
It converts them to 544 chronological simple returns and splits them into two
disjoint 272-return blocks: preceding indices `0..271` and recent indices
`272..543`.

Each block independently uses local inverse-volatility weights, constructs a
common-energy return, zeroes rather than drops the 20-return smooth-volatility
change on fixed two-sigma jump rows, and estimates WTI's coefficient with a
252-row three-column OLS. At least 200 non-jump rows and a finite full-rank
solution are required. The EA buys WTI when the recent coefficient exceeds the
preceding coefficient by more than `1e-12`, sells when it is below by more than
`1e-12`, and consumes a tie or invalid state flat. XNG is read-only and has no
magic or order path.

The one WTI position has a frozen `3.5 * ATR(20,D1)` stop, no take-profit,
next-month replacement, and a forty-day stale guard. The sole setfile is
`environment=backtest`, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. News modes and Friday close are OFF. There is no trained
output, prohibited signal indicator, external runtime feed, optimizer result,
grid, martingale, scale-in, or pyramid.

## Source And Non-Duplicate Boundary

The Tier-A source is Hollstein, Prokopczuk, and Tharann (2021), "Anomalies in
Commodity Futures Markets," *Quarterly Journal of Finance* 11(4), article
2150017, DOI `10.1142/S2010139221500178`. The bounded packet is
`strategy-seeds/sources/HOLLSTEIN-WTI-VOLBETA-REG-2026/source.md`; durable G0
authorization is
`decisions/2026-08-13_qm5_20303_wti_volbeta_reg_g0.md`.

The paper does not test this realized two-CFD factor, two own-history blocks,
outright WTI rule, continuous CFD, fixed-risk stop, or QM portfolio. Its result
also does not clear the paper-wide multiple-testing threshold. The closest
family build, `QM5_13151_energy-volbeta`, reached Q08 and then failed hard on
runs-test `p=0.02295` and a losing low-volatility regime. Those adverse facts
remain in the card.

The canonical checker found no exact identity. Manual review separated the one
source-family neighbor: `QM5_13151` estimates concurrent XTI and XNG betas in
one block, ranks the assets, and trades both legs; `QM5_20303` compares WTI's
coefficient over two disjoint history blocks, trades only WTI, and uses XNG as
a read-only factor input. Verdict:
`CLEAN_AUTHORIZED_WTI_TIME_SERIES_SMOOTH_VOL_BETA_AFTER_MANUAL_REVIEW`.

## Allocation And Q01 Evidence

- EA / slot / magic: `QM5_20303` / 0 / `203030000`.
- Strict compile: `D:/QM/reports/compile/20260813_095442/summary.csv`, PASS,
  zero errors and zero warnings.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260813_095552.json`, PASS, zero
  failures and zero warnings.
- P1 artifact: `D:/QM/reports/pipeline/QM5_20303/P1/P1_QM5_20303_result.json`,
  PASS.
- Independent reference suite: six of six tests PASS for sample denominators,
  block-local weights, exact OLS rows, disjoint supports, retained jump rows,
  direction/tolerance, chronology, synchronization, and freshness.
- Deployed EX5 SHA-256:
  `EA2EC9A3BC16E363F2A610DB0D679941331884FF44D5C62AD611BAE47C50C83D`;
  read-only verification passed across T1-T10.
- Deploy receipt:
  `D:/QM/strategy_farm/artifacts/deploy/QM5_20303_wti-volbeta-reg_deploy_20260813T0956Z.json`.
- Backtest-set normalized-content build hash:
  `8f0d5bd5245f1904aee2868330fcca4031588562a5c1ab7d9e877713c38e5702`.

## Farm Claim, Queue, And CPU Stop

- Build claim: `ab9ebab8-c37c-4e38-b935-835ee1b1de32`.
- Router claim: `0f9884af-dfa7-4921-aec3-f1cac4df76df`.
- Pre-claim online DB backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_qm5_20303_claim_20260813T093927Z.sqlite` (`quick_check=ok`).
- At `2026-08-13T09:44:04Z`, `farmctl.py mt5-slots` found two active
  research terminals, T5 and T7, against
  `D:/QM/strategy_farm/state/launch_gate_max.txt = 1`.
- At `2026-08-13T09:59:20Z`, the read-only census found four active research
  terminals, T5, T7, T9, and T10, against the same ceiling of one.
- The initial target work-item check returned zero rows. The canonical
  `claude_sweep_enqueue_2026-06-10.never_tested` producer then inserted the
  sole Q02 row at `2026-08-13T09:53:13+00:00`.
- Recording the completed build transitioned its farm task to `done` and
  returned `enqueued=[]`, `skipped=[existing_q02_pending]`; no duplicate was
  created.
- The router claim was released to `PIPELINE` with this evidence file bound as
  its artifact.
- Final queue readback found exactly one row, phase Q02, symbol
  `XTIUSD.DWX`, attempt 0, pending, unclaimed, with no evidence or verdict.

Machine-readable evidence is
`artifacts/qm5_20303_wti_volbeta_reg_cpu_stop_20260813T095720Z_board_advisor.json`.

## Scoped Commits

- `fadc7aa22` - durable mission G0 authorization.
- `7063bb40a` - bounded source packet and approved/intake cards.
- `c32ee5235` - deterministic EA-ID reservation.
- `7b3441218` - slot-0 WTI magic, SPEC, and resolver.
- `2ca1168d3` - initial EA package and Q01 bindings.
- `fd89295ca` - corrected smooth-volatility-beta source/binary binding.
- `98ce2e969` - build review, final fixed-risk set hash, and Q01 evidence.
- `3d2365147` - canonical Q02 handoff state and paced CPU-stop evidence.

## Safety Boundary

- No manual smoke, backtest, optimizer, dispatch tick, or downstream verdict
  was run by this mission.
- No active tester was interrupted and no terminal process was controlled.
- No live, demo, shadow, optimization, or stress setfile was created.
- No AutoTrading setting, deploy manifest, `T_Live` file, or T_Live manifest
  was used for control or changed.
- No portfolio-gate path was touched.
- Q01 PASS and a pending Q02 row are not efficacy, certification,
  decorrelation, or portfolio admission.
