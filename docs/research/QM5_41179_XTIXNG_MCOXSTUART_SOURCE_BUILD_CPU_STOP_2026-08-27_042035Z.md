# QM5_41179 XTI/XNG Cox-Stuart basket — source build and CPU stop

Date: 2026-08-27 UTC (`2026-08-27T04:20:35.3845563Z`)

Branch: `agents/board-advisor`

Status: a new, non-duplicate XTI/XNG structural relative-value source build is
committed and its governed compile is queued. Q02 was not enqueued because Q01
does not yet exist, the compile worker is activation-held, all seven permitted
factory terminals are occupied, and the explicit backtest CPU ceiling is
binding.

## New energy sleeve

`QM5_41179_xtixng-mcoxstuart-rv` evaluates fourteen synchronized completed
monthly `log(XTI)-log(XNG)` endpoints. It applies the fixed Cox-Stuart split:
seven differences pair endpoint `i` with endpoint `i+7`. At least five positive
differences fade the high ratio with SELL XTI/BUY XNG; at least five negative
differences fade the low ratio with BUY XTI/SELL XNG. Any zero difference or a
4/3 split consumes the monthly attempt flat. An open package exits at the next
broker month or after forty days.

The aggregate package uses one `RISK_FIXED=1000` budget split across both
frozen `3.5 * ATR(20,D1)` stops, with equal target USD notionals and a 20%
maximum mismatch. No ML, banned indicator, external runtime dataset, live
setfile, or percent-risk setfile was introduced.

The construction is mechanically distinct from the two-day, long-only XNG
cum-RSI2 build `QM5_12567`; outright WTI Cox-Stuart trend build `QM5_41167`;
XAU/XAG Cox-Stuart metal basket `QM5_41168`; adaptive Pettitt XTI/XNG basket
`QM5_41175`; and fixed-block Mann-Whitney XTI/XNG basket `QM5_41178`. The
preallocation receipt found no canonical duplicate across 4,678 EA-registry
rows, 1,329 cards, and 45 wiki nodes. Actual portfolio decorrelation remains a
later portfolio-evidence question and is not claimed by this source build.

## Source and committed records

The durable source packet combines complete official U.S. EIA energy-market
research, peer-reviewed energy-market records, the named peer-reviewed
Cox-Stuart record, and the complete official NIST algorithm record. It does not
claim to have read the paywalled Cox-Stuart article body.

- `184c3536b` — reputable composite source approval and clean dedup receipt.
- `91126bdbe` — deterministic EA ID 41179, approved G0 card, and decision.
- `ecebbc466` — two-leg V5 source, basket manifest, three fixed-risk backtest
  setfiles, reference suite, documentation, magic rows `411790000/411790001`,
  and resolver update.

Both card copies have SHA-256
`9E479165639FCE3A7956ED57106D52495D685EA0021ADC3C5FF1E9E2BC2C7413`.
The EA source has SHA-256
`5E373104EE5BF0F0428C5C277E0D8ECEA10E83FCAE80386D27DDB74B58A1E6BE`.

Nine deterministic reference tests pass, including exact signal sides, tie
handling, month sequencing, log-ratio calculation, set/manifest contracts,
separation witnesses against Pettitt and Mann-Whitney, and the banned runtime
token scan. Card schema and ML lint pass. Governed magic allocation reported no
collision.

## Governed compile and Q02 disposition

Ad-hoc compilation correctly refused while factory terminals were alive and
was not retried. Governed compile work item
`9ced0252-9ceb-4fe7-a2c5-d7a8d0b30a82` was enqueued once, but its last status
was `pending` under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. There is no `.ex5` and
no Q01 PASS yet.

Five fresh two-second whole-host CPU samples were each `100.0%`, above the
`97.0%` ceiling. The seven allowed factory terminal slots were occupied by T2,
T4, T5, T6, T7, T9, and T10. Therefore no Q02 row was enqueued and no tester
was launched. The next pass must reuse, not duplicate, the pending compile
item; require current strict compile/build-check PASS and `.ex5`; recheck
capacity; then enqueue exactly one logical-basket Q02 only if the ceiling has
cleared.

## Safety boundary

No terminal was started or stopped, AutoTrading was not toggled, and neither
the portfolio gate, `T_Live`, nor the `T_Live` manifest was touched by this
work. Existing unrelated worktree changes were preserved.

Machine-readable receipt:
`artifacts/qm5_41179_compile_handoff_20260827T042035Z_board_advisor.json`.
