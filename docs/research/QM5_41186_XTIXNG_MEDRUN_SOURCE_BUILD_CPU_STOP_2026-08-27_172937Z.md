# QM5_41186 XTI/XNG median-runs basket — source build and CPU stop

Date: 2026-08-27 UTC (`2026-08-27T17:29:37Z`)

Branch: `agents/board-advisor`

Status: a new, OWNER-approved structural XTI/XNG relative-value edge is
implemented and committed. A governed compile item is queued and activation-
held; Q01 and Q02 stopped because the explicit backtest CPU ceiling is
binding.

## New commodity/energy relative-value build

`QM5_41186_xtixng-median-runs-rv` makes one decision per broker month from
the latest exactly timestamp-matched XTI/XNG completed D1 endpoint in each of
the immediately prior thirteen broker months. It forms
`log(XTI)-log(XNG)`, strict-ranks the thirteen ratios, omits unique median rank
seven, maps the remaining ranks into six low and six high states, and counts
every chronological run after the omission bridge.

The basket fades a persistent newest ratio regime at the inclusive `R<=7`
boundary:

- newest rank above seven: SELL XTI / BUY XNG;
- newest rank below seven: BUY XTI / SELL XNG; and
- `R>7`, newest median, a tie, or an invalid path consumes the month flat.

It opens XTI first and XNG second with atomic rollback, targets equal absolute
USD notionals, and exits at the next broker month with a forty-day stale
repair. One aggregate `RISK_FIXED=1000` budget is split across frozen
`3.5*ATR(20,D1)` hard stops. All three presets are backtest-only with
`RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`.

The card combines complete government and peer-reviewed oil/gas relationship
evidence with the complete official NIST median-runs method. The exact ratio,
sample, threshold, CFD mapping, and contrarian package remain disclosed QM
hypotheses. The preallocation checker returned `CLEAN` across 4,685 registry
identities, 1,336 cards, and 45 Strategy Wiki nodes. This mechanic differs
from existing change-point, rank-association, fixed-block, paired-sign,
return-spread, fitted-residual, and outright WTI median-runs builds.

Market-neutral-style construction is not evidence of realized portfolio
decorrelation; unchanged Q09 remains authoritative.

## Committed records

- `4ddcc28dc` — reputable-source approval and clean preallocation dedup.
- `c199e510d` — bounded source-to-rule extraction packet.
- `f6809d8f0` — deterministic EA ID 41186, approved G0 card, and identity
  registry row.
- `fd4cab79f` — V5 EA source, two-leg basket manifest, three fixed-risk
  backtest setfiles, reference suite, specification, and active magic rows.

The canonical and EA-local card copies are byte-identical with SHA-256
`7993FF4B39693BD2C45FB2CC51DCC49FFEF26F6691056ADB43DE939BE54E7163`.
The EA source SHA-256 is
`2AE7F7B27F98ED76EA026557565445B3BF1DFFDDF2921171286BFCCA9616B7BC`.
The basket manifest follows the validated QM5_12533 logical-host recipe and
has SHA-256
`A0B733FED8385EBDBA25BE31FEB6149E8C260AC96F617D3B24BDF74E6C526E42`.

Ten deterministic reference tests pass. They cover monotone/reflected paths,
median bridging, the inclusive seven-run boundary, eight-run and newest-
median flats, invalid states, exact 12,012-representation enumeration with
6,744 symmetric qualifiers, month sequencing, basket contracts, and a fixed
fixture separated from Spearman, Mann-Whitney, Cox-Stuart, and outright WTI
median-runs logic. Card schema/ML lint, G0 lint, and SPEC validation pass.
Active magic rows are XTI slot 0 magic `411860000` and XNG slot 1 magic
`411860001`; the governed allocator reported zero new status-aware collision.

## Compile and Q02 disposition

The build skill's fail-closed compile interlock observed live factory terminal
processes and refused an ad-hoc compile/build check without retry. The
prescribed governed `COMPILE_EA` lane accepted exactly one source-hash-bound
item, `78d5f43e-d805-4748-923d-c36c33370b78`. It remains `pending` under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`; no EX5 exists and Q01 is not PASS.

The subsequent mandatory five-sample whole-host CPU check measured
`[100.0000, 100.0000, 95.2223, 100.0000, 99.7151]%`: average `98.9875%`,
maximum `100.0000%`. Both exceed the governed 97% average-or-maximum ceiling.
Five factory terminals (`T1`, `T2`, `T3`, `T6`, and `T8`) were visibly
running. T_Live and the unrelated FTMO process were excluded from the factory
count and left untouched.

The explicit ceiling stop therefore bound before Q02 admission. No Q02 row,
component-leg row, dispatch, smoke test, manual tester, or backtest was
created. A later pass must let the current governed compile item resolve,
require its exact source hash, strict zero-error/zero-warning EX5 and Q01
approval, recheck capacity below 97%, and append exactly one logical-basket
Q02 row. Component-leg Q02 rows remain forbidden.

## Safety boundary

No terminal was started, stopped, reserved, released, or reaped. AutoTrading
was not toggled. Neither T_Live, its manifest, the portfolio gate, nor a
portfolio-admission record was touched. Concurrent `dxz23_execution_contracts`
work remained unstaged and was preserved.

Machine-readable receipt:
`artifacts/qm5_41186_build_cpu_stop_20260827T172937Z_board_advisor.json`.
