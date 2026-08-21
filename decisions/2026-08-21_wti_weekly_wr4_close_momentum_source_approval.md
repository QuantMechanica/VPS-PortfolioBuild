# WTI weekly WR4 close-momentum source approval

Date: 2026-08-21

Decision: `APPROVED_SOURCE`

## Authority and scope

The OWNER instruction delivered to Codex on branch `agents/board-advisor` authorizes one new
structural, low-frequency commodity/energy edge, specifically including a structural XTIUSD
trend/seasonality candidate. It also requires a reputable-source record, `RISK_FIXED` backtest
setfiles, Q02 enqueueing, branch-only commits, and no T_Live, AutoTrading, portfolio-gate, or
T_Live-manifest changes.

This decision approves source intake for:

- source ID: `CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026`
- strategy ID: `CRABEL-MOP-WTI-WR4-CLOSE-MOM-2026_S01`
- slug: `wti-wr4-close-mom`
- instrument: `XTIUSD.DWX`
- timeframe: `D1`, evaluated once at the first tradable bar of a new Monday-anchored broker week

It is source approval only. It does not approve live use or waive any G0, build, compile, static,
Q02, or downstream pipeline gate.

## Complete source set read

The bounded source records below were read in full:

| Source record | Role | SHA-256 |
|---|---|---|
| `strategy-seeds/sources/MOP-TSMOM-2012/source.md` | Peer-reviewed time-series momentum evidence; explicitly includes crude-oil futures | `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042` |
| `strategy-seeds/sources/MOP-WTI-WCLOSE-LOCATION-MOM-2026/source.md` | Existing governed translation of weekly WTI close location and momentum | `60292F608787EEC685AAF7B375D66B5A819E21EF2711FA2970AE73945B70F25D` |
| `strategy-seeds/sources/CRABEL-WTI-NR7-BRK-2026/source.md` | Existing governed record of Crabel's range-contraction/expansion framework | `F16BDC01745C6A5A7ABB3B2F2924BE23A66A3E215C74E49B863457A1E2423D1E` |
| `strategy-seeds/sources/CRABEL-WTI-WEEK-ORB-2026/source.md` | Existing governed weekly WTI translation of Crabel's range framework | `4C97D7148BE4A5507AB440F0D980B81A32F1302B01059BC29CF3FF3D7DFA4F82` |

## Approved deterministic mechanic

At the first tradable D1 bar of a new Monday-anchored broker week, aggregate the four immediately
preceding completed broker weeks. Each week must contain three to five D1 sessions, and the four
anchors must be consecutive; the current decision week is excluded.

For each completed week compute:

- full range: `high - low`;
- own-week log body: `ln(close / open)`;
- close-location value: `(close - low) / (high - low)`.

The newest completed week qualifies only when its full range is strictly greater than each of the
other three completed-week ranges. Ties do not qualify.

- BUY when the newest week qualifies, its own-week log body is positive, and close location is
  strictly greater than `0.75`.
- SELL when the newest week qualifies, its own-week log body is negative, and close location is
  strictly less than `0.25`.
- Otherwise remain flat.

Persist the weekly decision attempt before fallible execution gates. Allow one XTIUSD position.
Use a frozen `3.5 * ATR(20, D1)` stop at entry, no take profit, maximum spread 1500 points, and
close on the first tick of a later broker week, with a ten-calendar-day hard cap. News and Friday
close gates are OFF. Backtest risk is fixed at 1000 account-currency units with
`RISK_PERCENT=0.0` and portfolio weight 1.

## Evidence boundary

Moskowitz, Ooi, and Pedersen support the broad proposition that an asset's own past return can
carry directional information and include crude-oil futures in their tested universe. Crabel
supports systematic range expansion/contraction concepts. The governed weekly records show a
reproducible D1-to-broker-week translation.

No cited source tests this exact four-week widest-range rank, weekly close-location quartile, and
own-week body conjunction on the DarwinexZero XTIUSD CFD. That conjunction is a transparent QM
engineering hypothesis. Source approval therefore establishes reproducibility and provenance,
not efficacy.

## Non-duplicate boundary

The candidate is mechanically distinct from the existing book:

- `QM5_41080_wti-wclose-location-mom` uses two weeks, parent-close-to-new-close momentum, and
  0.80/0.20 close-location thresholds; it has no range rank.
- `QM5_41073_wti-woutside-settle` requires outside-week geometry and settlement beyond the parent
  range; it has no four-week range rank.
- `QM5_41061_wti-week-nr7-brk` requires the prior week to be the narrowest of seven and waits for a
  current-week breakout.
- `QM5_13075_xti-inweek-brk` uses inside-week containment followed by a later breakout.
- `QM5_12965_wti-week-orb` uses the current week's first D1 bar as an opening range.
- `QM5_12567` is an XNG cumulative-RSI2 pullback strategy on a different energy market.

The canonical dedup check returned CLEAN across 4,574 registry rows, 625 cards, and zero vault
nodes, with no fuzzy matches for the proposed slug, strategy ID, author set, or mechanic.

## Intake rubric

- R1 — economic/source plausibility: `PASS_WITH_WEEKLY_WR4_TRANSLATION_RISK`
- R2 — deterministic mechanization: `PASS`
- R3 — instrument/data fit: `PASS_WITH_LABEL_AND_CFD_BASIS_RISK`
- R4 — operational safety: `PASS`

Expected cadence is approximately five to eight entries per full year. Q02 remains the empirical
arbiter: fewer than five full-year trades is a retirement result, not permission to loosen the
mechanic.

## Safety boundary

This approval authorizes creation of the source packet and subsequent G0 consideration only.
It does not authorize T_Live activity, AutoTrading changes, portfolio-gate edits, T_Live-manifest
edits, parameter salvage, or a second queue row. Q02 may be enqueued only through the canonical
factory path and only if the backtest CPU ceiling permits it.

