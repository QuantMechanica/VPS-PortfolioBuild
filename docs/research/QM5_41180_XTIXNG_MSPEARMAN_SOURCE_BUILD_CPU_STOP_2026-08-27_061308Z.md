# QM5_41180 XTI/XNG Spearman basket — source build and CPU stop

Date: 2026-08-27 UTC (`2026-08-27T06:13:08.9491001Z`)

Branch: `agents/board-advisor`

Status: the previously unbuilt, OWNER-approved XTI/XNG structural
relative-value edge is implemented and committed. Q01 compilation and Q02
enqueue stopped at the explicit backtest CPU ceiling.

## New energy-relative-value build

`QM5_41180_xtixng-mspearman-rv` evaluates thirteen synchronized completed
monthly `log(XTI)-log(XNG)` endpoints. It assigns strict ranks, calculates
`D=sum((R[i]-(i+1))^2)` and `T=364-D`, and fades only the inclusive
`abs(T)>=104` boundary:

- `T>=104`: SELL XTI / BUY XNG;
- `T<=-104`: BUY XTI / SELL XNG; and
- an interior score or exact ratio tie consumes the monthly attempt flat.

The atomic opposite-leg package targets equal absolute USD notionals, holds to
the next broker month with a forty-day stale repair, and uses one aggregate
`RISK_FIXED=1000` budget split across frozen `3.5*ATR(20,D1)` hard stops.
All three presets are backtest-only with `RISK_PERCENT=0` and
`PORTFOLIO_WEIGHT=1`.

This is mechanically distinct from certified
`QM5_12567_cum-rsi2-commodity`, which is a two-day, long-only XNG oscillator
pullback. It is also distinct from outright WTI Spearman continuation
`QM5_41173`, the XAU/XAG Spearman basket `QM5_41174`, and the XTI/XNG
Pettitt, Mann-Whitney, Cox-Stuart, and daily OLS-residual neighbors. The
preallocation receipt returned `CLEAN` across 4,679 registry identities,
1,330 cards, and 45 Strategy Wiki nodes. Market-neutral-style construction is
not a portfolio-correlation claim; unchanged Q09 owns that evidence.

## Committed records

- `0f841c028` — reputable government, peer-reviewed, and pinned-method source
  packet plus clean dedup receipt.
- `68ffc2256` — deterministic EA ID 41180, approved G0 card, and registry
  identity.
- `cdd868925` — V5 source, basket manifest, three fixed-risk backtest
  setfiles, reference suite, and specification.

The canonical and EA-local card copies are byte-identical with SHA-256
`6050F5F740B8CB90ED46A6F0DCAB88D198315875EF5D11BCF4F7F106DCE281CD`.
The EA source SHA-256 is
`CBA7056423594C42C52A4B03FAE96372BA96259ACB5157D80E05DEFB987CCA77`.
The logical basket manifest follows the validated QM5_12533 host-symbol
recipe and has SHA-256
`CE7B69809C2941067826BFF68CB70D78525E478723D38354CB3E644973D21EB5`.

Eight deterministic reference tests pass, including exact threshold sides,
rank invariants, exact 13! density, tie handling, month sequencing, ratio
orientation, set/manifest contracts, card-copy identity, fixed-risk-only
presets, and a banned runtime-token scan. Both card schema/ML lints pass. The
active registry rows are XTI slot 0 magic `411800000` and XNG slot 1 magic
`411800001`.

## Q01 and Q02 disposition

The framework guard refused ad-hoc `build_check` because terminal64
processes are alive and directed the build to the governed compile lane. No
retry or bypass was attempted. Read-only compile status returned
`NOT_ENQUEUED`; there is no EX5 and therefore no Q01 PASS.

Immediately before any queue mutation, five two-second whole-host CPU samples
were `[100, 100, 100, 100, 99]` percent. The maximum `100%` exceeds the
hard `97%` ceiling. Five path-anchored factory terminals (T2, T4, T6, T8,
and T9) were active; `T_Live` and FTMO processes were excluded from the
factory count.

The read-only work-item query returned zero rows for `QM5_41180`. Because
the CPU ceiling bound before governed compile/Q01, no compile item and no Q02
row were created, and no tester was launched. A later pass must first recheck
the ceiling, enqueue exactly one governed compile item if capacity permits,
require current strict compile/build-check PASS and a source-fresh EX5, then
enqueue exactly one logical-basket Q02 row. Component-leg Q02 rows are
forbidden.

## Safety boundary

No terminal was started, stopped, reserved, released, or reaped. AutoTrading
was not toggled. Neither `T_Live`, the `T_Live` manifest, nor the portfolio
gate was touched. Concurrent unrelated public-data changes remained unstaged
and were preserved.

Machine-readable receipt:
`artifacts/qm5_41180_build_cpu_stop_20260827T061308Z_board_advisor.json`.
