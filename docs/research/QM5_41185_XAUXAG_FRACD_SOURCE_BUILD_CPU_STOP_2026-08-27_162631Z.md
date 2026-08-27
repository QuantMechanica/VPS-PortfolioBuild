# QM5_41185 XAU/XAG fractional-difference basket — source build and CPU stop

Date: 2026-08-27 UTC (`2026-08-27T16:26:31.6566343Z`)

Branch: `agents/board-advisor`

Status: a new, OWNER-approved structural XAU/XAG relative-value edge is
implemented and committed. Strict compilation, Q01, and Q02 stopped before
admission because the explicit backtest CPU ceiling was already binding.

## New commodity relative-value build

`QM5_41185_xauxag-fracd-rv` makes one decision per broker month from exactly
316 synchronized completed D1 XAU/XAG closes. It forms
`log(XAU)-log(XAG)`, applies a fixed `d=0.40` fractional-difference filter with
exactly 64 recurrence weights, uses the first 252 filtered outputs as a
baseline, and holds out the 253rd output. The strategy fades an inclusive
`abs(z)>=0.50` boundary:

- `z>=0.50`: SELL XAU / BUY XAG;
- `z<=-0.50`: BUY XAU / SELL XAG; and
- the interior consumes the monthly attempt flat.

The package targets equal absolute USD notionals, exits at the next broker
month with a forty-day stale repair, and uses one aggregate `RISK_FIXED=1000`
budget split equally across frozen `3.5*ATR(20,D1)` hard stops. All three
presets are backtest-only with `RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`.

The card translates approved peer-reviewed gold/silver fractional-
cointegration research and CME spread-market documentation into a deliberately
fixed, runtime-native rule. It does not claim that the cited papers tested this
exact CFD implementation. The preallocation scan returned `CLEAN` against the
current registry, card corpus, and strategy wiki. Market-neutral-style
construction is not evidence of realized portfolio decorrelation; unchanged
Q09 remains authoritative.

## Committed records

- `17d4b7b12` — reputable-source approval and clean preallocation dedup receipt.
- `53e171fe5` — bounded source-to-rule extraction packet.
- `6719100ab` — deterministic EA ID 41185, approved G0 card, and registry row.
- `8db5a0608` — V5 EA source, two-leg basket manifest, three fixed-risk
  backtest setfiles, reference suite, specification, and active magic rows.

The canonical and EA-local card copies are byte-identical with SHA-256
`47074A6FBB214B0707F6C418AEC969C4E118265EAA2890C55A72FB6303488685`.
The EA source SHA-256 is
`B3AF62CCBD3E36677A4278450905C97B205352803A67C6830D49A0A93423FBA5`.
The basket manifest follows the validated QM5_12533 logical-host recipe and
has SHA-256
`AD371947DFB68A5370DA741F526C95018AC6074A24C06A9D19F459AA126D4B55`.

Eight deterministic signal/reference tests pass, as do 23 targeted governed-
allocator and magic-resolver tests. Both card schema/ML lints pass, the G0
lint passed, and mechanical build hardening reports zero failures. Active
magic rows are XAU slot 0 magic `411850000` and XAG slot 1 magic `411850001`;
allocation added no status-aware collision.

## Q01 and Q02 disposition

Immediately before compile admission, five two-second whole-host CPU samples
were `[100, 100, 100, 100, 100]` percent. Both average and maximum were 100%,
above the governed hard ceiling of 97%. Six path-anchored factory terminals
(`T1`, `T2`, `T3`, `T4`, `T7`, and `T8`) were active; T_Live and non-factory
processes were excluded.

The ceiling bound before compilation, so no compile item was enqueued, no EX5
was created, and Q01 is not PASS. Consequently no Q02 row or tester run was
created. A later pass must recheck CPU below 97%, enqueue exactly one governed
compile item, require a current strict zero-error/zero-warning build plus a
source-fresh EX5 and Q01 PASS, then enqueue exactly one logical-basket Q02 row.
Component-leg Q02 rows are forbidden.

## Safety boundary

No terminal was started, stopped, reserved, released, or reaped. AutoTrading
was not toggled. Neither T_Live, its manifest, the portfolio gate, nor a
portfolio-admission record was touched. Concurrent public-data edits remained
unstaged and were preserved.

Machine-readable receipt:
`artifacts/qm5_41185_build_cpu_stop_20260827T162631Z_board_advisor.json`.
