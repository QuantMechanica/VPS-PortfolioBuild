# QM5_41187 XAU/XAG signed-KS basket — source build and CPU stop

Date: 2026-08-27 UTC (`2026-08-27T18:25:42Z`)

Branch: `agents/board-advisor`

Status: a new, OWNER-approved structural XAU/XAG relative-value edge is
implemented and committed. A governed compile item is queued and activation-
held; Q01 and Q02 stopped because the explicit backtest CPU ceiling is
binding.

## New commodity relative-value build

`QM5_41187_xauxag-mks-rv` makes one decision per broker month from twelve
exactly timestamp-matched completed XAU/XAG month-end observations. It forms
`log(XAU)-log(XAG)`, fixes the first six endpoints as the older block and the
last six as the newer block, then scans the combined strict ascending order.
At each ordered endpoint it records the largest older-minus-newer and newer-
minus-older cumulative count gaps. Exact endpoint ties invalidate the signal.

The basket fades one dominant distribution shift at the inclusive three-count
boundary:

- dominant older-minus-newer gap: the newer ratio distribution is higher, so
  SELL XAU / BUY XAG;
- dominant newer-minus-older gap: the newer ratio distribution is lower, so
  BUY XAU / SELL XAG; and
- both maxima below three, tied maxima, exact observation ties, or an invalid
  path consume the month flat.

Exact enumeration of all `C(12,6)=924` strict block-label orders gives 218
high-ratio fades, 218 low-ratio fades, 486 weak flats, and 2 tied-maxima flats.
The locked qualifier density is therefore `436/924 = 109/231`, about 5.662
opportunities per year before execution filters.

The EA opens XAU first and XAG second with atomic rollback, targets equal
absolute USD notionals, and exits at the next broker month with a forty-day
stale repair. One aggregate `RISK_FIXED=1000` budget is split across frozen
`3.5*ATR(20,D1)` hard stops. All three presets are backtest-only with
`RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`; news and Friday overrides are off.

The card uses complete peer-reviewed evidence on state-dependent gold/silver
relations, the official CME ratio/spread carrier, and the complete official
NIST two-sample KS procedure. Runtime external data is not required. The
preallocation checker examined 4,686 registry identities, 1,337 cards, and 45
Strategy Wiki nodes. It conservatively returned a shared-carrier fuzzy match;
manual semantic review resolved the mechanic as distinct. In particular, this
fixed six-by-six signed ECDF count-gap rule is not the existing XAU/XAG
Mann-Whitney rank-sum rule: fixed separating fixtures make each rule qualify
while the other remains flat.

Market-neutral-style construction is not evidence of realized portfolio
decorrelation; unchanged Q09 remains authoritative.

## Committed records

- `673be5a44` — reputable-source approval and preallocation dedup evidence.
- `9a7ed8613` — bounded source-to-rule extraction packet.
- `675534401` — deterministic EA ID 41187, approved G0 card, and identity
  registry row.
- `df23ce4c3` — V5 EA source, two-leg basket manifest, three fixed-risk
  backtest setfiles, reference suite, specification, and active magic rows.

The canonical and EA-local card copies are byte-identical with SHA-256
`FA81618B43A356CEB36666C5A9A4D7D05E0E5F2C097C077A257D9494B2FD6B18`.
The EA source SHA-256 is
`EC8B6AFBD1FF01F77C7B0A1D8996DAB22F7CC53E3D4FE14611089AFF98E7FA56`.
The basket manifest follows the validated QM5_12533 logical-host recipe and
has SHA-256
`66CC7F95B887B3C9E1FCE71226C527572AE9E6E514F6535BAFA6DB77038392F0`.

Nine deterministic reference tests pass. They cover both directions, weak
and tied-maxima flats, exact observation-tie refusal, fixed old/new blocks,
month sequencing, the full 924-order density, log-ratio orientation, basket
contracts, and Mann-Whitney separating fixtures. Card schema/ML lint, G0 lint,
the build guard, and SPEC validation pass. Active magic rows are XAU slot 0
magic `411870000` and XAG slot 1 magic `411870001`; the governed allocator
reported zero new status-aware collisions. No banned or ML indicator was
found.

## Compile and Q02 disposition

The build skill's fail-closed compile interlock observed live factory terminal
processes and refused an ad-hoc compile/build check before execution, without
retry. The prescribed governed `COMPILE_EA` lane accepted exactly one source-
hash-bound item, `37dbc847-cf01-47cf-b89d-9ab761262f8c`. It remains `pending`
under `COMPILE_EA_WORKER_ROLLOUT_PENDING`; no EX5 exists and Q01 is not PASS.

The subsequent mandatory five-sample whole-host CPU check measured
`[99.9028, 100.0000, 100.0000, 100.0000, 100.0000]%`: average `99.9806%`,
maximum `100.0000%`. Both exceed the governed 97% average-or-maximum ceiling.
Seven factory terminals (`T1`, `T2`, `T3`, `T4`, `T7`, `T8`, and `T10`) were
visibly running. T_Live and the unrelated FTMO process were excluded from the
factory count and left untouched.

The explicit ceiling stop therefore bound before Q02 admission. No Q02 row,
component-leg row, dispatch, smoke test, manual tester, or backtest was
created. A later pass must let the existing governed compile item resolve,
require its exact source hash, strict zero-error/zero-warning EX5 and Q01
approval, recheck capacity below 97%, and append exactly one logical-basket
Q02 row. Component-leg Q02 rows remain forbidden.

## Safety boundary

No terminal was started, stopped, reserved, released, or reaped. AutoTrading
was not toggled. Neither T_Live, its manifest, the portfolio gate, nor a
portfolio-admission record was touched. Concurrent factory-generated EA and
`public-data` changes remain unstaged and were preserved.

Machine-readable receipt:
`artifacts/qm5_41187_build_cpu_stop_20260827T182542Z_board_advisor.json`.
