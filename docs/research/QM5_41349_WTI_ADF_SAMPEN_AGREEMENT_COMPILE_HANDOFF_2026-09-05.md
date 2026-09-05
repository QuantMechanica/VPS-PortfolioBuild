# QM5_41349 WTI ADF/Sample-Entropy Agreement — Compile Handoff

Date: 2026-09-05  
Branch: `agents/board-advisor`  
Status: new structural commodity source build committed; governed compile
released and priority-bound; Q02 remains fail-closed behind Q01.

## Delivered edge

`QM5_41349_wti-adf-sampen-agree-tr` is a direct-WTI, D1, monthly strategy.
It reconstructs 61 completed broker-month endpoints, requires both a lag-one
intercept-only ADF statistic of at least `-2.594` and raw-return sample entropy
(`m=2`, `r=0.2*sample_sd`) of at most `2.5`, then follows the newest
12-month return sign for one month. The strategy is symmetric long/short,
consumes the month before fallible gates, uses a frozen `3.5*ATR(20)` hard
stop, exits next month or after 40 days, and never retries or adapts.

This adds direct crude-oil exposure outside the certified XAU/SP500/NDX/XNG
carrier set. It is mechanically distinct from `QM5_12567` and from the nearby
WTI ADF combinations: sample entropy counts overlapping raw-magnitude return
templates at dimensions two and three. Both disagreement directions abstain.
No decorrelation result or Q09 waiver is claimed.

## Committed evidence

- Source approval, G0 card, corrected-root dedup, and EA-ID reservation:
  `f711c0ffef`.
- Governed slot-zero magic `413490000`, resolver, and card copy:
  `0e28f3bb0f`.
- MQ5, SPEC, exact card metadata, independent reference fixtures, and one D1
  backtest set: `947e74f89e`.
- MQ5 SHA-256: `EC99EF12B459BA1D67D41286550E459CA44D361DF0B2C6A89C7A3999ABA6499A`.
- Approved-card and EA-local card-copy SHA-256 after the status update:
  `B1041362D6D0E525CE39B96EB1C20D8B184C069F618F64AE64540E3CE6BD3228`.
- Setfile SHA-256: `990DC5DA6DF0F899C05046F43A08C36365E17E13EF0EB2FCB5644EBF6F00BF1D`.

Both card linters pass with zero ML hits. The independent fixture suite passes
4/4, covering agreement, both disagreement directions, source contract, and
the single-set fixed-risk contract. The set locks `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; its build hash remains pending
until strict compile evidence exists.

## Governed compile state

Ad-hoc `build_check` correctly refused because factory terminals were alive.
No terminal was stopped. The canonical compile enqueue created work item
`58f2abcf-00c1-4d8e-a928-9a25dde9e1c9`. Bounded compile-wave dry-run and
apply revalidated the exact MQ5 hash, released only that row's rollout hold,
and the row was marked priority for this OWNER commodity-sleeve mission.

After paced worker checks, it remained `pending`, unheld, and unclaimed, with
no verdict, EX5, bound setfile, or compile evidence. Q02 was deliberately not
enqueued: a Q02 row without strict `COMPILE_OK` and a current binary would
violate the build and pipeline prerequisites.

## CPU and safety boundary

The pre-release five-sample whole-host CPU window measured `88.0875%`,
`76.2396%`, `75.5034%`, `72.5616%`, and `76.4767%`: average `77.7738%`,
maximum `88.0875%`. Both were strictly below the `97%` admission ceiling.

No manual backtest, optimization, terminal control, live/demo/shadow/stress
set, portfolio-gate change, portfolio admission, deploy manifest, `T_Live`
change, or AutoTrading change occurred. Unrelated shared-worktree changes were
excluded from the commits.

## Exact continuation

Reuse compile item `58f2abcf-00c1-4d8e-a928-9a25dde9e1c9`; do not enqueue a
duplicate. When the resident worker records strict `COMPILE_OK` with zero
errors/warnings and the current EX5/setfile binding, take a fresh five-sample
CPU window. Only if average and maximum are both below `97%`, enqueue exactly
one `XTIUSD.DWX / D1 / RISK_FIXED=1000` Q02 row.

Machine-readable evidence is
`artifacts/qm5_41349_q02_admission_handoff_20260905.json`; compile release
receipts are the adjacent `qm5_41349_compile_wave_*_20260905.json` files.
