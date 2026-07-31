# QM5_20190 WTI/Brent Calendar Basket Build And Q02 Enqueue

Date: 2026-08-01 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20190_oilbench-cal`

Strategy ID: `KELOHARJU-GK-OILBENCH-CAL-2026_S01`

## Outcome

One new low-frequency energy candidate was researched, carded, allocated,
built, strictly compiled, and handed to the paced Q02 fleet. At the first
tradable WTI D1 bar of each broker month, it ranks WTI against Brent by the
mean synchronized WTI-minus-Brent return for that calendar month over exactly
ten prior years, requires at least five paired observations, buys the stronger
benchmark, and shorts the weaker benchmark.

This is a two-leg directional-neutral construction, not a claim of dollar,
beta, volatility, portfolio, or certified neutrality. Q01 is `PASS`. Q02 has
exactly one work item, `ec5fd9b7-8923-498f-a9fd-0a29d8a31d4c`. It was
initially `pending`, attempt 0, and unclaimed; a later read-only check found
the paced fleet had claimed it on `T9`, still with no verdict. No manual
backtest or downstream result is claimed.

## Source And Approval Boundary

The governed composite source packet is
`strategy-seeds/sources/KELOHARJU-GK-OILBENCH-CAL-2026/source.md`. It binds:

- Keloharju, Linnainmaa, and Nyberg (2016), *The Journal of Finance* 71(4),
  DOI `10.1111/jofi.12398`, for the recurring same-calendar cross-sectional
  commodity-return construction and five-observation minimum;
- Gorska and Krawiec (2015), *Problems of World Agriculture* 15(4), DOI
  `10.22630/PRS.2015.15.4.54`, for peer-reviewed WTI and Brent calendar
  evidence; and
- governed CME, ICE, and EIA references establishing the WTI/Brent spread as
  a standard traded crude-benchmark structure.

The bounded repository reviews for those lineages were read completely. The
deterministic public-source router was also invoked for the NBER paper URL and
returned `PERMISSION_REQUIRED` / `DEFERRED:SOURCE_POLICY`; that exact result is
stored in `retrieval_route_20260801.json`. No arbitrary fresh page text was
used or represented as approved evidence.

None of the sources tests this exact two-CFD carrier, equal stop-risk package,
Darwinex month boundary, broker costs, or the QM portfolio. No source profit
factor, return, drawdown, hedge ratio, trade count, or portfolio correlation
statistic was imported.

## Frozen Mechanic

- Logical basket: `QM5_20190_WTI_BRENT_CAL_D1`.
- Slot 0: `XTIUSD.DWX`, magic `201900000`; slot 1: `XBRUSD.DWX`, magic
  `201900001`.
- Decision: first tradable XTI D1 bar of every broker month.
- State: mean synchronized WTI-minus-Brent log return for the decision
  calendar month over exactly ten prior years, requiring at least five pairs.
- Direction: positive score buys WTI and sells Brent; negative score sells WTI
  and buys Brent; absolute score at or below `1e-12` remains flat.
- Attempt state: consume and persist the month before fallible history,
  signal, spread, sizing, news, or order gates; no same-month retry.
- Exit: next broker-month boundary or 40-calendar-day stale guard, plus hard
  stops and atomic orphan/partial-package repair.
- Risk: one `RISK_FIXED=1000` package budget split equally after independent
  `3.5 * ATR(20,D1)` stop normalization; `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, both news axes OFF, and Friday close OFF.
- Density prior: approximately 12 completed packages/year after warm-up; Q02
  retires below five/year.

## Non-Duplicate Evidence

Before allocation, the deterministic checker was run with slug
`oilbench-cal`, strategy ID `KELOHARJU-GK-OILBENCH-CAL-2026_S01`, author
`Keloharju Linnainmaa Nyberg Gorska Krawiec`, and the complete monthly
synchronized WTI/Brent same-calendar relative-return mechanic. It returned
`CLEAN` across 4,246 registry rows and 377 cards.

Manual review separated the candidate from the nearest built systems:

- `QM5_12843_wti-brent-spread` fades a rolling spread-level z-score.
- `QM5_12848_wti-brent-brk` follows a spread-level channel breakout.
- `QM5_12860_wti-brent-rshock` fades a short-horizon return shock.
- `QM5_13115_energy-samecal` ranks WTI against natural gas, not Brent.
- `QM5_20099_wti-samecal` and Brent calendar cards are outright carriers.

The prior-year same-calendar estimator, exact WTI/Brent pair, opposite
directions, and monthly rerank are jointly load-bearing. A recent z-score,
channel, shock, fixed month map, outright carrier, or XNG substitution is
outside this card.

## Deterministic Allocation

EA ID `20190` is active in `ea_id_registry.csv`. The magic registry contains
two active rows, `201900000` and `201900001`, for the two registered symbols.

Strict-default resolver generation exposed the existing missing-directory
condition for unrelated active legacy IDs `1001`, `1015`, and `1016`. The
supported `--keep-obsolete` generation retained 15,368 rows and dropped zero;
no `--allow-dropped` waiver was used. The resolver contains both new magics
and preserves the legacy rows. Current resolver SHA-256:
`0456b24b0b054a4da9e9337d8816bf41fd2691e022ad9bb0be3d481a318bf6f4`.

The factory's authorized deterministic artifact pump committed the registry,
resolver, initial EX5, and setfile on this branch as
`ffb35e951ff6983b5771710ce9f1c3c6b2acaf26`, then committed the final EX5 and
setfile refresh as `1831252658b0fca67f33e59991c389c94d2a7e54`. The source,
card, MQ5, SPEC, manifest, and audit evidence remain in the explicit candidate
commit.

## Q01 Evidence

- Strategy-card schema lint: PASS, with no missing sections or ML hits.
- G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Candidate build guard: PASS for approved card, registry row, magic rows,
  exact folder, and slug.
- V5 build guardrails: PASS, zero findings.
- Basket symbol-scope validation: `BASKET_OK`, zero violations.
- Strict MetaEditor compile:
  `D:/QM/reports/compile/20260731_233639/summary.csv` -- `PASS`, reason `OK`,
  strict true, zero errors, zero warnings.
- Strict compile log:
  `framework/build/compile/20260731_233639/QM5_20190_oilbench-cal.compile.log`.
- Full V5 build check:
  `D:/QM/reports/framework/21/build_check_20260731_233323.json` -- `PASS`,
  zero failures, zero warnings.
- Setfile build hash:
  `5649e055ca94816dfb36f09e4ecc32e2aed6a74c789642d568b3343f69fb2e2a`.

After those PASS results, diff hygiene removed only trailing spaces in SPEC
metadata and replaced one blank MQ5 end-of-file line with an end-of-file
comment. Two attempts to refresh the compile evidence reached the 60-second
command budget before MetaEditor produced a report; no compiler process
remained afterward and no tester was involved. The executable statements,
parameters, EX5, and setfile build hash were unchanged, so the completed
strict compile and full build check above remain the authoritative Q01
evidence.

## Artifact Hashes

| Artifact | SHA-256 |
|---|---|
| MQ5 | `7701a1179ffa12ad0914493bcdea8297f33b35fe929a33b201372aeda22dc1ba` |
| EX5 | `9c6fc99b43cd92f51733692d15a42f25c5aa0cb44399dd23965fd0c212cccbe9` |
| SPEC | `22903a613fb5497abda862707602b1c0e5e80b8fb9304a4f29dd01b9e05ca930` |
| backtest setfile | `d7427282e21cd669e99c2b22c66574c48171a7fd04470a61caec46c03bd04977` |
| basket manifest | `6ac3c5d64df1550eaf76cb964a9a0c9b8e1131f54f472bfbe139de21e082f103` |
| canonical/approved/EA-local card | `75ef2dffb04eb6ac1cb0b2e8ececbe3ec337f7545e2811a67931c7ca71eb8603` |
| composite source packet | `ac92a03a45d47d6fb55ff81214db0e0bfd0a7941c1da927c06cfb524842b23d8` |
| source-router record | `abdf0027038283001220658556b7f6fe086605e16501c276617c6a6c71fcfb0b` |

All three card copies are byte-identical.

## Paced Q02 Handoff

The EA-scoped dry run selected exactly one never-tested logical-basket item,
with no stranded retry and no deferred promotion. The first apply attempt
encountered the live factory mutation lock and made no mutation. After the
lock was naturally released, the same idempotent EA-and-symbol scope acquired
the lock and inserted exactly one row:

- item: `ec5fd9b7-8923-498f-a9fd-0a29d8a31d4c`;
- phase/kind: `Q02` / `backtest`;
- logical symbol/timeframe: `QM5_20190_WTI_BRENT_CAL_D1` / D1;
- setfile:
  `QM5_20190_oilbench-cal_QM5_20190_WTI_BRENT_CAL_D1_D1_backtest.set`;
- created: `2026-07-31T23:34:45+00:00`;
- status at enqueue confirmation: `pending`, attempt 0, unclaimed; a later
  read-only check found `active`, claimed by `T9`, with no verdict;
- queue at apply: 2,134 pending against the 7,000-row queue ceiling.

The immediate capacity scan found five non-live factory terminal processes,
below the seven-process tester ceiling. The separate
`C:/QM/mt5/T_Live/MT5_Base/terminal64.exe` process was excluded. This work did
not launch a tester or terminal.

## Safety And Next Gate

No live setfile, AutoTrading toggle, `T_Live` mutation, deploy manifest,
T_Live manifest, portfolio-gate change, portfolio admission, or correlation
waiver was created. Q02 must now falsify density, combined two-leg economics,
costs, deterministic execution, shared-risk sizing, and package integrity.
Later unchanged gates must independently establish realized book decorrelation
before the candidate can be called certified or added to the portfolio.
