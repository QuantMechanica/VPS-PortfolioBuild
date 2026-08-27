# QM5_41181 XAU/XAG pair-rank basket — source build and CPU stop

Date: 2026-08-27 UTC (`2026-08-27T10:42:44.2392881Z`)

Branch: `agents/board-advisor`

Status: a new, OWNER-approved XAU/XAG structural relative-value edge is
implemented and committed. Q01 compilation and Q02 enqueue stopped at the
explicit backtest CPU ceiling.

## New commodity relative-value build

`QM5_41181_xauxag-mkendall-rv` selects thirteen synchronized completed
monthly `log(XAU)-log(XAG)` endpoints, oldest to newest. Every one of the 78
older/newer pairs contributes its sign to score `S`. The strategy fades only
the inclusive `abs(S)>=14` boundary:

- `S>=14`: SELL XAU / BUY XAG;
- `S<=-14`: BUY XAU / SELL XAG; and
- an interior score or any exact ratio tie consumes the monthly attempt flat.

The threshold is a fixed pre-market density choice, not a runtime significance
test. Exact inversion enumeration gives 2,711,123,108 qualifying paths among
13!, or probability `0.4353804483839206`, before market data. The package
targets equal absolute USD notionals, holds to the next broker month with a
forty-day stale repair, and uses one aggregate `RISK_FIXED=1000` budget split
across frozen `3.5*ATR(20,D1)` hard stops. All three presets are backtest-only
with `RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`.

The source packet is bounded to peer-reviewed Schweikert gold/silver-ratio
research, CME spread-market documentation, and the pinned Moskowitz-Ooi-
Pedersen arithmetic precedent. The preallocation scan found the neighboring
`QM5_41174_xauxag-mspearman-rv` fuzzy match. It was resolved as mechanically
distinct with two fixed rank permutations: one qualifies Spearman only
(`S=12`, `T=118`), while the other qualifies this all-pairs score only
(`S=14`, `T=80`). Market-neutral-style construction is not a portfolio-
correlation claim; unchanged Q09 owns that evidence.

## Committed records

- `796c2934a` plus correction `e44cdaa93` — approved reputable-source packet,
  exact density arithmetic, and resolved preallocation dedup receipt.
- `1e4685a91` — deterministic EA ID 41181, approved G0 card, and registry
  identity.
- `718fdd184` — V5 source, two-leg basket manifest, three fixed-risk backtest
  setfiles, reference suite, specification, and active magic rows.

The canonical and EA-local card copies are byte-identical with SHA-256
`C0A2C57DD7B6B04D5B1910EB3FEF75CB884C5A7C4B859E2E9F1709FCC83F9672`.
The EA source SHA-256 is
`3A8D76484925BE9F9FEA5ECC08D6AB17CC131A1FD7EDA25CA7E9F952C9971431`.
The logical basket manifest follows the validated QM5_12533 host-symbol recipe
and has SHA-256
`EE6B6EF050896A433FC5B7F0C39F209974365FDE9465ECE2A2828571E93E990B`.

Eight deterministic signal/reference tests pass, as do eight targeted magic-
resolver tests and ten governed-allocator tests. Both card schema/ML lints and
the G0 card lint pass. The active registry rows are XAU slot 0 magic
`411810000` and XAG slot 1 magic `411810001`; allocation added no status-aware
magic collision.

## Q01 and Q02 disposition

The framework guard refused ad-hoc `build_check` because `terminal64`
processes are alive and directed the build to the governed compile lane. No
retry or bypass was attempted. Read-only compile status returned
`NOT_ENQUEUED`; there is no EX5 and therefore no Q01 PASS.

Immediately before any queue mutation, five two-second whole-host CPU samples
were `[100, 100, 100, 100, 100]` percent. The maximum `100%` exceeds the hard
`97%` ceiling. Seven path-anchored factory terminals (T2, T3, T4, T6, T7, T8,
and T10) were active, also reaching the 7/7 terminal ceiling; `T_Live` and
FTMO processes were excluded from the factory count.

The read-only work-item query returned zero rows for `QM5_41181`. Because
capacity bound before governed compile/Q01, no compile item and no Q02 row
were created, and no tester was launched. A later pass must first recheck both
ceilings, enqueue exactly one governed compile item if capacity permits,
require current strict compile/build-check PASS and a source-fresh EX5, then
enqueue exactly one logical-basket Q02 row. Component-leg Q02 rows are
forbidden.

## Safety boundary

No terminal was started, stopped, reserved, released, or reaped. AutoTrading
was not toggled. Neither `T_Live`, the `T_Live` manifest, the portfolio gate,
nor any portfolio-admission record was touched. The unrelated QM5_12958
setfile remained unstaged and was preserved.

Machine-readable receipt:
`artifacts/qm5_41181_build_cpu_stop_20260827T104244Z_board_advisor.json`.
