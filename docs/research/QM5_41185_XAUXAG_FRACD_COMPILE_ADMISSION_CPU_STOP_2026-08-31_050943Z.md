# QM5_41185 XAU/XAG fractional-difference basket — compile admission CPU stop

Date: 2026-08-31 UTC (`2026-08-31T05:09:43.0684568Z`)

Branch: `agents/board-advisor`

Status: the approved market-neutral-style commodity edge is build-intake
ready, but no compile work item or Q02 row was created because the explicit
97% CPU ceiling bound immediately before admission.

## Edge and non-duplicate boundary

`QM5_41185_xauxag-fracd-rv` is a monthly XAU/XAG opposite-leg basket. It
exact-joins 316 completed synchronized D1 closes, forms
`log(XAU)-log(XAG)`, applies one fixed `d=0.40`, 64-term fractional-difference
recurrence, standardizes the held-out 253rd output against the prior 252
outputs, and fades inclusive `abs(z)>=0.50`:

- `z>=+0.50`: SELL XAU / BUY XAG;
- `z<=-0.50`: BUY XAU / SELL XAG; and
- the interior consumes the month flat.

The package targets equal absolute notionals under one aggregate
`RISK_FIXED=1000` stop budget, retains frozen `3.5*ATR(20,D1)` hard stops,
and exits at the next broker month with a forty-day stale repair. The clean
preallocation verdict is
`CLEAN_XAUXAG_FIXED_D040_K64_HELDOUT252_FRACTIONAL_DIFFERENCE_REVERSION`.
Opposite legs do not establish realized neutrality or book decorrelation;
unchanged Q09 remains authoritative.

## Completed work

The deterministic build intake initially rejected the older approved card
because its strict R3 frontmatter stored
`PASS_WITH_SYNCHRONIZATION_AND_CFD_BASIS_RISK` instead of the serializer's
literal `PASS`. Commit `8fa6f70d1d` records and applies an editorial-only
normalization. The existing R3 reasoning and body table continue to disclose
synchronization and continuous-CFD basis risks; no mechanic or criterion was
changed.

The normalized canonical and runtime approved cards both hash to
`E6735BCAFA7FC8A401C1E9038E502BB964FA43316903350FD4721010B4978ADE`.
The governed pending build task is
`4e9284dd-56e0-4618-9166-2d51f8caa320`, with its committed handoff at
`artifacts/qm5_41185_build_task_20260831.md` (`93da842e26`).

Pre-compile checks all passed:

- eight fixed-filter reference tests;
- card schema and G0 lints;
- QM build-skill preflight;
- SPEC validation;
- build guardrails;
- basket symbol-scope validation (`BASKET_OK`); and
- raw-MQ5 quarantine validation.

The active registries remain slots 0/1, magics `411850000`/`411850001`, and
the basket manifest follows the `QM5_12533` logical-host recipe. All three
presets are backtest-only and lock `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; only the logical basket may become a Q02 row.

## CPU stop and exact state

The five whole-host samples immediately before the intended governed compile
enqueue were `95%, 78%, 82%, 100%, 93%`: average `89.6%`, maximum `100%`.
The maximum exceeded the 97% hard ceiling, so the enqueue command was not
executed.

Readback after the stop:

- compile status: `NOT_ENQUEUED`;
- COMPILE_EA work items: zero;
- EX5: absent;
- Q01: not PASS;
- Q02 work items: zero; and
- build task: pending.

## Resume contract

After a fresh five-sample window stays wholly below 97%, use the exact pending
task binding:

```text
python tools/strategy_farm/farmctl.py enqueue-compile QM5_41185_xauxag-fracd-rv --build-task-id 4e9284dd-56e0-4618-9166-2d51f8caa320
```

Require the governed COMPILE_EA row to produce a current strict Q01 PASS,
zero errors/warnings, and source-fresh EX5 before recording the build task.
Then allow exactly one logical-basket Q02 row and zero component-leg rows.

No tester or terminal control was started here. AutoTrading, `T_Live`, the
T_Live/deploy manifests, portfolio gate, portfolio admission, and unrelated
dirty worktree files were untouched.

Machine-readable receipt:
`artifacts/qm5_41185_compile_admission_cpu_stop_20260831T050943Z_board_advisor.json`.
