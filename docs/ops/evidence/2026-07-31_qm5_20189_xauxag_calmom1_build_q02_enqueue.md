# QM5_20189 XAU/XAG Calendar-Momentum Build And Q02 Enqueue

Date: 2026-07-31

Branch: `agents/board-advisor`

EA: `QM5_20189_xauxag-calmom1`

Strategy ID: `KELOHARJU-FMR-XAUXAG-CALMOM1-2026_S01`

## Outcome

One new low-frequency commodity basket was researched, carded, allocated,
built, strictly compiled, and handed to the paced Q02 queue. The EA trades
XAU versus XAG only when a ten-year recurring same-calendar relative-return
sign agrees with the exact immediately completed relative-month sign. It is a
two-leg directional-neutral construction, not a claim of dollar, beta,
volatility, portfolio, or certified neutrality.

Q01 is `PASS`. Q02 has exactly one pending work item:
`2897ad06-5996-4c5a-8a4b-1de95c867c52`. No manual backtest or dispatch was
run, and no downstream result is claimed.

## Source And Approval Boundary

The governed composite source packet is
`strategy-seeds/sources/KELOHARJU-FMR-XAUXAG-CALMOM1-2026/source.md`. It binds
two already approved, completely reviewed peer-reviewed lineages:

- Keloharju, Linnainmaa, and Nyberg (2016), *The Journal of Finance* 71(4),
  DOI `10.1111/jofi.12398`, for recurring same-calendar commodity returns and
  the five-observation minimum.
- Fuertes, Miffre, and Rallis (2010), *Journal of Banking & Finance* 34(10),
  DOI `10.1016/j.jbankfin.2010.04.009`, for one-month cross-sectional
  commodity momentum with a one-month hold.

Both bounded repository reviews were read completely. No fresh public URL was
supplied for source intake, so no unapproved arbitrary web retrieval was used.
Neither paper tests this exact conjunction, two-name CFD carrier, equal
stop-risk package, or the QM portfolio; no source performance statistic was
imported.

## Frozen Mechanic

- Logical basket: `QM5_20189_XAU_XAG_CALMOM1_D1`.
- Slot 0: `XAUUSD.DWX`, magic `201890000`; slot 1: `XAGUSD.DWX`, magic
  `201890001`.
- Decision: first tradable XAU D1 bar of each broker month.
- Seasonal state: mean synchronized XAU-minus-XAG log return for the decision
  calendar month over exactly ten prior years, with at least five pairs.
- Momentum state: synchronized XAU-minus-XAG log return for the immediately
  completed broker month.
- Entry: trade only on strict sign agreement beyond `1e-10`; buy XAU/sell XAG
  on positive agreement and reverse both legs on negative agreement.
- Exit: next month boundary or 40-day stale guard, plus hard-stop and atomic
  package repair.
- Risk: one `RISK_FIXED=1000` budget, split equally by `3.5 * ATR(20)` stop
  risk; `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, news OFF, Friday close OFF.
- Density prior: about 5-8 completed packages/year; Q02 retires below five.

## Non-Duplicate Evidence

Before allocation, the deterministic checker was run with slug
`xauxag-calmom1`, strategy ID
`KELOHARJU-FMR-XAUXAG-CALMOM1-2026_S01`, and the complete mechanic string. It
returned `CLEAN` across 4,246 registry rows and 377 cards.

Manual review separated the card from the nearest built parents:

- `QM5_20186_xauxag-samecal` uses the calendar state alone.
- `QM5_20057_xauxag-xmom1` uses the one-month state alone.
- `QM5_20184_xauxag-xmom3` uses three contiguous months without a recurring
  calendar estimator.
- Ratio, OLS-residual, return-spread, and WTI calendar systems use different
  estimators, directions, horizons, or instruments.

Both states and their strict agreement are load-bearing. Removing either
state recreates a built parent.

## Deterministic Allocation

`farmctl reserve-ea-ids` allocated EA ID `20189`. The registry contains two
active magic rows, `201890000` and `201890001`, for the registered XAU and XAG
symbols.

The resolver generator initially stopped because three unrelated active legacy
IDs (`1001`, `1015`, and `1016`) have no matching EA directory. To preserve
those active registry rows without using a dropped-row waiver, exact empty
directories were created only for generator validation and removed
immediately afterward. The final resolver generation retained 15,366 rows,
dropped zero, and contains both new magics. No `--allow-dropped` option was
used. Final resolver SHA-256:
`4c6fc13fa506f41e29fcbbd2b64f95462a9a2bc68453c01bc4dcc77ca058f93d`.

## Q01 Evidence

- Final strict compile:
  `D:/QM/reports/compile/20260731_175613/summary.csv` — `PASS`, reason `OK`,
  zero errors, zero warnings.
- Compile log:
  `framework/build/compile/20260731_175613/QM5_20189_xauxag-calmom1.compile.log`.
- Static/set/registry build check, with the independent compile step skipped:
  `D:/QM/reports/framework/21/build_check_20260731_175224.json` — `PASS`, zero
  failures, zero warnings.
- Basket manifest parsed successfully as JSON.
- Canonical card schema lint: required sections present and no ML/banned-term
  hits.
- Setfile header build hash:
  `c6f134509905808fbe85678500c4de22d9cebe821a9dc973337a7001c63686d9`.

The combined build-check wrapper had earlier exceeded the 60-second command
budget after starting its compile substep. No tester was involved. The final
authoritative evidence is the completed independent strict compile and the
completed static build check above.

## Artifact Hashes

| Artifact | SHA-256 |
|---|---|
| MQ5 | `3c3e310ba13502e091fff39818a3bb9ad4c75ad5a1c7ae46162edb1a2af5a307` |
| EX5 | `5f4c3aeed41fe3c965aac468fd13f456242bad966c69247eb515f78a35c651ca` |
| backtest setfile | `0fb5fff021e27e5d0aa7e5f357369879671d01e6b77edb1dc1bede8b89eeaa93` |
| basket manifest | `90ccceb584f437b0b4793a645967c52fad328d7ec10fae6a725c65244eefc03c` |
| canonical card | `1163b7b2b544d58b35c69a7e7711e32f4a971cd6160b6afd17c70b6230d32727` |
| composite source packet | `acc8e3647abbb7debbfc7a429b415faa9c74c73fad98727f7e79c0a7de8d6fe8` |

The EA-local card copy is byte-identical to the canonical card.

## Paced Q02 Handoff

The scoped dry run selected one never-tested logical-basket item. Apply
attempts respected the live factory mutation lock and did not steal or delete
it. The legitimate pump established the item at `2026-07-31T17:52:58+00:00`;
the final scoped reconciliation was idempotent and created no duplicate.

Read-only queue confirmation:

- count: `1`;
- item: `2897ad06-5996-4c5a-8a4b-1de95c867c52`;
- phase: `Q02`;
- symbol: `QM5_20189_XAU_XAG_CALMOM1_D1`;
- status: `pending`;
- attempt count: `0`;
- claimed by: null.

At `2026-07-31T17:55:28+00:00`, the path-anchored process scan found six
non-live factory terminal processes (`T1`, `T2`, `T4`, `T5`, `T7`, `T10`).
The separate `C:/QM/mt5/T_Live/MT5_Base/terminal64.exe` process was explicitly
excluded. The factory count was below the seven-process tester ceiling, and
this work did not launch another terminal.

## Safety And Next Gate

No live setfile, AutoTrading toggle, `T_Live` mutation, deploy manifest,
T_Live manifest, portfolio-gate change, portfolio admission, or correlation
waiver was created. Q02 must now falsify density, combined two-leg economics,
costs, deterministic execution, risk, and package integrity. Later unchanged
gates must independently establish book decorrelation before this candidate
can be called certified or added to the portfolio.
