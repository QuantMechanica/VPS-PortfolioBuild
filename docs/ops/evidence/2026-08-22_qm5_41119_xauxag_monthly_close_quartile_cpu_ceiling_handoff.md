# QM5_41119 XAU/XAG monthly close-quartile reversion — CPU-ceiling handoff

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41119_xauxag-mclose-quartile-rv`

Outcome: **SOURCE BUILD COMMITTED; GOVERNED COMPILE PENDING; CPU CEILING HIT; Q01 PENDING; Q02 NOT ENQUEUED**

## Edge delivered

QM5_41119 is one low-frequency, opposite-leg gold/silver relative-value
package. At the first synchronized D1 boundary of a broker month, it
reconstructs every synchronized `XAUUSD.DWX` and `XAGUSD.DWX` close in the
immediately completed calendar month. A valid month contains 17 through 23
timestamp-identical close pairs.

For each session, `s[i]=ln(XAU close)-ln(XAG close)`. Let `z` be the final
completed-month observation, `rank` the count of observations strictly below
`z`, and `tail=ceil(n/4)`. A unique `rank<tail` enters BUY XAU / SELL XAG; a
unique `rank>=n-tail` enters SELL XAU / BUY XAG. Every interior rank, exact
tie, invalid package, or late attempt consumes the month flat. The attempt is
persisted before history, signal, quote, spread, ATR, sizing, and order gates,
so no downstream failure can introduce a retry option.

The two legs target equal absolute USD notionals, cap aggregate frozen-stop
risk at one `RISK_FIXED=1000` budget, and normally exit at the next broker
month. This is a structural relative-value carrier different from the
certified outright XAU/SP500/NDX/XNG book, but paired construction does not
prove market neutrality, profitability, or decorrelation. Q09 alone owns any
realized portfolio finding.

## Reputable source and non-duplicate boundary

The governed extraction packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026/source.md`.
Its lineage is Schweikert (2018), *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; and CME
Group's *Gold & Silver Ratio Spread*. Those sources support testing a
state-dependent gold/silver relation and its intermarket ratio carrier. The
completed-month close rank, ceiling-quartile tails, contrarian direction, CFD
mapping, fixed risk, performance, and correlation are disclosed QM
falsification choices rather than source claims.

Fail-closed canonical pre-allocation dedup scanned the EA registry, Strategy
Cards, and the actual Strategy Wiki and returned CLEAN. Post-allocation dedup
returned only the expected QM5_41119 self-hits. The mechanic is not
QM5_41079's weekly exact-minimum/maximum rule, QM5_20268's rolling 126-ratio
tail rule, QM5_41118's two-month late-half dominance rule, QM5_41110's outside
residence rule, QM5_41103's range-migration rule, or any rolling center,
regression, scale, or oscillator system. It ranks only the final close inside
one exact completed month against that month's exhaustive close set.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| source approval and pre-allocation receipt | `7649b3e95` |
| bounded reputable-source extraction | `123c8cf71` |
| atomic EA-ID reservation | `ad4f24de1` |
| approved G0 card and post-allocation receipt | `a95e2c73d` |
| governed two-leg magic allocation and resolver regeneration | `86b320f0e` |
| EA source, SPEC, basket manifest, reference suite, fixed-risk set, and compile release receipt | `980aa37f7` |

The exact identities are slot 0 `XAUUSD.DWX` / magic `411190000` and slot 1
`XAGUSD.DWX` / magic `411190001`, both D1. The logical tester symbol is
`QM5_41119_XAU_XAG_MCLOSE_QUARTILE_RV_D1`.

## Source-level validation and compile state

- Strategy Card schema/G0 lint and canonical approval: PASS.
- Approved card, EA registry identity, directory slug, active magic rows, and
  resolver: PASS.
- Deterministic reference suite: 9 tests PASS. Coverage includes all allowed
  17-23-session ceiling-quarter sizes; every unique rank; exact-tie flat
  handling; malformed, asynchronous, non-descending, incomplete, nonadjacent,
  and current-month history rejection; month/grace/attempt/year boundaries;
  aggregate equal-notional fixed-risk sizing; and static card/source/set/
  manifest alignment.
- SPEC validator: PASS.
- Build guardrails: PASS for source and set.
- Symbol-scope validator: `BASKET_OK`, zero violations.
- Approved and EA-local cards are byte-identical at SHA-256
  `07B407F2B407F37705E7276A99BF24D5132ADCF00B0BBADB136F809045CAB8D7`.

The sole logical-basket set is backtest-only and locks `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Its `build_hash` remains `pending`
until strict compile/Q01.

An ad-hoc strict compile was refused before execution by the live-factory
include-mirror guard because terminal processes were active. The target was
then enqueued through `COMPILE_EA` and released in a target-only governed wave.
Work item `df4cc97d-a372-4036-935e-cc5a2ff72d88` is source-hash-bound to
`d99a4c331ccecfc9623796bcdc65022ad577c3e7e645abac910453f41229e7a1` and had
no active release hold at handoff. It remained pending behind occupied factory
capacity, with no EX5, compile verdict, final set binding, or Q01 claim.

## CPU-ceiling stop

A fresh five-sample whole-host `Processor(_Total)` check at
`2026-08-22T20:38:10Z` observed `99.95`, `98.54`, `99.95`, `100.00`, and
`99.47` percent CPU: average `99.58`, maximum `100.00`. Four path-anchored
factory `terminal64.exe` processes and four active `metatester64.exe`
processes were present. This exceeds the paced-fleet ceiling of 97 percent and
is the mission's binding stop condition.

Q02 was therefore not previewed or enqueued. The second blocking gate is the
pending strict compile/EX5/final set binding/Q01 result. The already-released
compile utility row was left untouched in its governed queue; no terminal,
worker, tester, or process was stopped or restarted.

## Safe continuation and safety boundary

The governed compile worker should first produce zero errors/warnings, a
non-empty EX5, build-check PASS, and the final set binding. Only after Q01
passes and a fresh sustained capacity check is below the ceiling should exactly
one logical-basket Q02 be enqueued. Q02 must retire the baseline below five
completed packages per full post-warm-up year rather than modify the approved
rule.

No manual backtest, dispatcher tick, AutoTrading action, live/deploy artifact,
`T_Live` mutation, `T_Live` manifest change, portfolio-gate change, portfolio
admission, correlation waiver, or decorrelation claim occurred. `T_Live` was
visible only in the read-only process inventory and was not touched.

Machine-readable companion:
`artifacts/qm5_41119_source_build_compile_queue_q02_cpu_ceiling_handoff_20260822T203810Z_board_advisor.json`.
