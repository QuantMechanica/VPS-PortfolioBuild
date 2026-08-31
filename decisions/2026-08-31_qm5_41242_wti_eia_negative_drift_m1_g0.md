# G0 Decision — QM5_41242 WTI EIA Negative Drift M1

Date: 2026-08-31

Decision: `APPROVED`

Authority: the current explicit OWNER commodity/energy sleeve mission,
bounded by the durable source approval at commit `b1fc667fa`, the source
packet at commit `ce5313bdc`, and the deterministic identity reservation at
commit `f49e186a4`.

Approved card:
`strategy-seeds/cards/approved/QM5_41242_wti-eia-negdrift-m1_card.md`.

## Identity

- EA ID: `QM5_41242`
- slug: `wti-eia-negdrift-m1`
- strategy ID: `ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026_S01`
- source ID: `ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026`
- host / slot 0: exact `XTIUSD.DWX`, M1, intended magic `412420000`
- mechanic: on a standard Wednesday, classify a strictly negative completed
  10:30 New York M1 bar as the negative-news price proxy, short at 10:31, and
  flatten at 10:35

## Gate Findings

- R1 `PASS_WITH_PRICE_PROXY_AND_ACCESS_BOUNDARY`: the named-author,
  DOI-bearing, peer-reviewed JFE study directly reports negative-only
  five-minute crude-futures drift. Complete accessible publisher and abstract
  material was reviewed; full text was not retrieved. The M1 CFD sign is an
  explicit QM proxy rather than the paper's inventory-surprise variable.
- R2 `PASS`: exact DST-aware clock, completed M1 label, strict sign, short
  direction, consumed date, fixed risk, stop, spread, and exit are mechanical
  and locked.
- R3 `PASS_WITH_CFD_MICROSTRUCTURE_HOLIDAY_AND_TIME_MAPPING_RISK`: governed
  `XTIUSD.DWX` M1 history covers 2017-2025. CFD/futures basis, aggregation,
  spreads, DST, and standard-Wednesday false labels on holiday shifts remain
  binding.
- R4 `PASS`: timestamps, OHLC, strict comparison, ATR risk control, quotes,
  positions, deals, and terminal state only; no ML, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Duplicate Review

The corrected-root canonical receipt
`artifacts/qm5_wti_eia_negdrift_m1_preallocation_dedup_20260831.json`,
SHA-256
`0421E9B96BF80F46439170824993450BB335BAE6297DE933CEFADF416090133C`,
is clean across 4,741 registry rows, 1,379 cards, and 45 Strategy Wiki nodes.

The rule is not the pre-release M5 straddle (`QM5_1121`), delayed symmetric
M30 sign (`QM5_10319`), D1 event/aftershock/fade family, multiweek momentum
(`QM5_12988`), or the completed two-M30-bar pullback/failure pair
(`QM5_20133` / `QM5_20134`). Its load-bearing state is negative-only first-M1
reaction, 10:31 entry, and 10:35 exit.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_STANDARD_WEDNESDAY_NEGATIVE_FIRST_MINUTE_REACTION_SHORT_DRIFT`.

## Approved Build Contract

Development may build exactly the approved card after deterministic magic
verification with:

- exact `XTIUSD.DWX` M1 slot 0 under registered magic `412420000`;
- one persistent New York `yyyymmdd` attempt recorded before every fallible
  entry gate;
- exact standard-Wednesday 10:31 current label and same-date completed 10:30
  M1 proxy bar separated by exactly 60 broker-time seconds;
- strict `release_close < release_open`, SELL only, equality/positive flat;
- entry only during seconds 0-29 of the 10:31 New York minute;
- exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1` in one M1 backtest setfile;
- one frozen `3.0 * ATR(20,M1)` broker hard stop, no target, and a 1,500-point
  spread ceiling;
- both current news axes and legacy news OFF, framework Friday close ON,
  malformed-position repair, 10:35 New York exit, date-change repair, and
  ten-minute stale guard; and
- deterministic reference fixtures, card lint, strict compile, registry,
  resolver, setfile, and static Q01 validation before Q02 handoff.

No alternate event day, holiday schedule inference, timeframe, direction,
return threshold, body/range filter, pre-range, pullback, reclaim, trend,
season, target, external surprise feed, optimizer output, trained signal,
retry, reversal, scale-in, grid, martingale, pyramid, or after-result rescue
is approved.

## Pipeline And Safety Boundary

This G0 decision authorizes the branch-only non-live build, one `RISK_FIXED`
backtest setfile, strict Q01, and one paced Q02 enqueue only while the fresh
whole-host CPU window remains strictly below the 97% ceiling. It does not
authorize a manual tester dispatch or tester control.

Q02 must retire on zero positions, fewer than five in any full scored year,
nonpositive governed economics, wrong clock/bar, long entry, positive/flat
proxy entry, repeated entry, missing stop, wrong exit, nondeterminism,
invalid risk mode, or insufficient history. Q09 alone may establish realized
portfolio correlation.

This decision excludes live/demo/shadow/stress/optimization setfiles;
AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate edits;
portfolio admission; decorrelation claims; and correlation waivers.
