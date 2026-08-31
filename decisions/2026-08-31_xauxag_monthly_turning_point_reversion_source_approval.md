# XAU/XAG Monthly Turning-Point Persistence Reversion — Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded market-neutral gold/silver
Strategy Card, deterministic EA-ID and two-slot magic allocation, one
branch-only non-live build, strict Q01 validation, and one paced logical Q02
enqueue only while the governed whole-host CPU ceiling remains clear. This
decision does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission asks for one new structural,
low-frequency commodity sleeve outside the certified directional
XAU/SP500/NDX/XNG book, expressly permits an `XAUUSD`/`XAGUSD` market-neutral
gold/silver-ratio reversion basket, requires reputable-source criteria and a
`RISK_FIXED` backtest preset, and forbids live, AutoTrading, portfolio-gate,
and `T_Live` manifest changes.

## Candidate Identity

- proposed slug: `xauxag-mturnpoint-rv`
- proposed strategy ID:
  `SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026_S01`
- source ID:
  `SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026`
- host / slot 0: exact `XAUUSD.DWX`, D1
- companion / slot 1: exact `XAGUSD.DWX`, D1
- signal: thirteen synchronized completed broker-month gold/silver log-ratio
  endpoints, strict local-extrema count below its iid null mean, followed by
  a contrarian position against the oldest-to-newest ratio displacement
- lifecycle: one consumed broker-month attempt, one atomic opposite-leg
  equal-notional package, next-month renewal, and forty-calendar-day stale
  repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Completely Read Governed Sources

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`.
   It preserves Karsten Schweikert (2018), “Are gold and silver
   cointegrated? New evidence from quantile cointegrating regressions,”
   *Journal of Banking & Finance* 88, 44–51, DOI
   `10.1016/j.jbankfin.2017.11.010`, and explicitly bounds the evidence to a
   state-dependent gold/silver relation rather than one universal constant
   equilibrium.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
   CME Group defines gold divided by silver as an intermarket ratio spread
   and distinguishes gold's monetary/safe-haven drivers from silver's larger
   industrial-cycle exposure.
3. `strategy-seeds/sources/MOP-WALLIS-MOORE-WTI-MTURNPOINT-TREND-2026/source.md`,
   SHA-256
   `91C2B08A1CEB8384CCEB8B1264E5CFF69FC590E544D052DB58C0C38CB19A2EBB`.
   That governed packet preserves the named peer-reviewed Wallis-Moore
   phase-frequency lineage and complete pinned public CRAN method files. It
   fixes strict turning-point counting and the iid null mean
   `2*(n-2)/3` without importing inaccessible article text.

The single R1 lineage for this card is the bounded child packet
`strategy-seeds/sources/SCHWEIKERT-WALLIS-MOORE-CME-XAUXAG-MTURNPOINT-RV-2026/source.md`.
The three records above remain its governed parents.

Schweikert and CME support testing a relative-value gold/silver carrier.
Wallis-Moore and the complete method files support the deterministic path
statistic. None of the sources tests the exact thirteen-month conjunction,
the below-mean gate, contrarian direction, continuous Darwinex CFDs,
equal-notional construction, fixed cash risk, ATR stops, or QM portfolio.
Those are disclosed pre-result QM choices. No source return, alpha, trade
density, cost result, hedge ratio, neutrality, decorrelation, or portfolio
fitness transfers.

## Locked Mechanic

At the first synchronized executable D1 tick of each genuine broker month:

1. Persist the broker `yyyymm` attempt before history, arithmetic, news,
   spread, quote, stop, sizing, margin, or order checks. Never retry that
   month.
2. Reconstruct the latest synchronized XAU/XAG D1 close pair in each of the
   immediately prior thirteen consecutive broker months, oldest to newest.
   Require exact month continuity, strict timestamp order, positive finite
   closes, and no endpoint more than ten calendar days before its month end.
3. Define `L[i]=ln(XAU[i])-ln(XAG[i])` for `i=0..12`. Require every `L[i]`
   finite and every endpoint pair separated by more than `1e-12`; a tie or
   invalid value consumes the month flat.
4. For `i=1..11`, count one strict turning point when `L[i]` is greater than
   both neighbors or less than both neighbors. Require `0 <= TP <= 11` and
   qualify only when `3*TP < 22`, exactly `TP <= 7`, which is below the iid
   null mean `22/3` for thirteen observations. Do not compute a p-value or
   scale risk by the count.
5. Require a nonzero oldest-to-newest displacement beyond `1e-12`. When
   `L[12] > L[0]`, sell XAU and buy XAG. When `L[12] < L[0]`, buy XAU and
   sell XAG. The persistent path is treated as an exhaustion gate and faded;
   this contrarian translation is load-bearing and untested.
6. Open one atomic opposite-leg package with equal target absolute USD
   notionals, at most 20% realized notional mismatch, aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Each leg
   receives a frozen `3.5*ATR(20,D1)` broker hard stop; no target exists.
   Entry spread ceilings are 1,500 XAU points and 500 XAG points.
7. Close both legs on the first tick of a later broker month or after forty
   calendar days. Malformed, orphaned, duplicated, same-side, wrong-magic,
   stopless, or notional-invalid ownership flattens immediately.

Both news axes, the legacy news mode, and Friday close remain off. There is no
same-month retry, target, trail, break-even, partial, grid, scale-in,
martingale, pyramid, external runtime feed, or fitted/adaptive parameter.

## Reputable-Source Criteria

- R1 `PASS_WITH_CARRIER_STATISTIC_AND_DIRECTION_TRANSLATION_RISK`: one
  canonical child preserves peer-reviewed gold/silver relation research, an
  official-exchange spread record, named peer-reviewed turning-point lineage,
  complete public method files, and exact access boundaries.
- R2 `PASS`: symbols, synchronization, month clock, endpoints, logarithm,
  strict comparison, tie tolerance, count, integer gate, contrarian sides,
  attempt, risk, hard stops, atomicity, spread caps, and exits are fixed.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native `XAUUSD.DWX` and `XAGUSD.DWX` D1 history and MT5 execution state
  supply all runtime inputs. Holiday alignment, CFD basis, financing, gaps,
  spreads, and fills remain Q02 falsification items.
- R4 `PASS`: timestamps, completed prices, logarithms, strict comparisons,
  integer arithmetic, ATR risk control, quotes, positions, deals, and
  persistent terminal state only; no ML, trained output, banned signal
  indicator, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_xauxag_mturnpoint_rv_preallocation_dedup_20260831.json`,
SHA-256 `B7839F5EC0EC0E9EF188908B0D168F600AB76E183D2D657EC1491AEE93812D18`,
scanned 4,745 registry identities, 1,383 card files, and all 45 Strategy Wiki
nodes. It returned `CLEAN` with no exact or fuzzy match.

Manual mechanic review fixes the semantic boundary:

- `QM5_41171_wti-mturnpoint-tr` uses the same strict-count method on one
  outright WTI path and follows its endpoint direction. This candidate uses
  synchronized gold/silver ratio endpoints, fades displacement, and owns an
  atomic equal-notional two-leg package.
- `QM5_41181_xauxag-mkendall-rv` compares every ordered endpoint pair and
  gates on a Mann-Kendall rank sum. This candidate compares only eleven local
  triples and retains only the number of strict direction reversals.
- `QM5_41174_xauxag-mspearman-rv` ranks all thirteen levels against time;
  `QM5_41168_xauxag-mcoxstuart-rv` compares six fixed early/late pairs; and
  `QM5_41187_xauxag-mks-rv` compares two fixed endpoint distributions. This
  candidate has no ranks, global time score, fixed half split, or ECDF.
- `QM5_41123_xauxag-mpath-eff-rv` retains move magnitudes in a net-to-L1
  ratio, while this statistic discards magnitudes after strict comparisons.
- `QM5_12577`, `QM5_20157`, `QM5_20161`, and `QM5_20263` fit a rolling level
  center, beta, scale, or threshold crossing. This candidate fits none.
- certified `QM5_12567_cum-rsi2-commodity` is a short-horizon long-only XNG
  oscillator pullback, not a monthly precious-metals relative-value basket.

Verdict:
`CLEAN_XAUXAG_THIRTEEN_MONTH_STRICT_TURNING_POINT_PERSISTENCE_CONTRARIAN_EQUAL_NOTIONAL_REVERSION`.

## Kill And Safety Boundary

The below-null-mean split is expected to admit roughly half of otherwise
valid monthly observations, or approximately six packages/year. That is a
design prior, not market evidence. Q02 retires the unchanged baseline on zero
packages, fewer than five completed packages in any full post-warm-up year,
nonpositive governed economics, or any synchronization, endpoint, count,
side, risk, atomicity, attempt, lifecycle, or determinism defect. No failed
result may be rescued by changing the sample, threshold, direction, carrier,
stop, hold, notional tolerance, or retry contract.

Opposite equal-notional legs reduce common outright-metal direction by
construction but do not prove dollar, beta, volatility, factor, or portfolio
neutrality. Q09 alone may evaluate realized overlap.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or
T_Live manifests; portfolio-gate changes; portfolio admission; correlation
claims; and correlation waivers.

