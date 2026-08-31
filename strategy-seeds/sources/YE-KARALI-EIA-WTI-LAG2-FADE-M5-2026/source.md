---
source_id: YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026
title: WTI EIA five-minute lag-2 reaction fade
publisher: Energy Economics / AAEA / U.S. Energy Information Administration
source_type: peer_reviewed_intraday_event_study_bounded_mechanization
status: approved_source_complete_bounded
approval_basis: decisions/2026-08-31_wti_eia_lag2_fade_m5_source_approval.md
authors:
  - Shiyu Ye
  - Berna Karali
created: 2026-08-31
created_by: Research
cards_extracted:
  - wti-eia-lag2-fade-m5
---

# WTI EIA Five-Minute Lag-2 Reaction Fade Source Packet

## Source Identity And Retrieval

- Published source:
  `https://www.sciencedirect.com/science/article/pii/S0140988316302110`
- Title: "The informational content of inventory announcements: Intraday
  evidence from crude oil futures market"
- Journal: *Energy Economics* 59 (2016), 349-364
- Authors: Shiyu Ye and Berna Karali
- DOI: `10.1016/j.eneco.2016.08.011`
- Publisher status: complete read of the accessible landing record, abstract,
  introduction, method/result snippets, return-model snippet, and conclusion
  snippet on 2026-08-31; the paywalled journal PDF was not retrieved
- Authors' conference poster:
  `https://ageconsearch.umn.edu/record/205595/files/AAEA_Ye_Karali-2015.pdf`
- Poster status: complete read of both pages; SHA-256
  `C4112A7AB46E8CF6EB792409504E5DF164C8F4F667DEF22142C54FBBA3E047F3`
- Official schedule:
  `https://www.eia.gov/petroleum/supply/weekly/schedule.php`
- EIA status: complete read of the current public release-schedule page on
  2026-08-31
- Governed event packet:
  `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md`

The durable authorization and access boundary are recorded in
`decisions/2026-08-31_wti_eia_lag2_fade_m5_source_approval.md` at commit
`0144b8fbba`.

## Findings Used

Ye and Karali study how crude-oil futures returns and volatility respond to
unexpected inventory changes in API and EIA reports. The accessible published
record identifies immediate inverse return responses and positive volatility
responses to inventory shocks, with EIA effects larger and longer-lived than
API effects. Its return-model snippet reports negative and significant first-
and second-lag coefficients for five-minute returns.

The complete authors' poster identifies the normal EIA clock as Wednesday
10:30 Eastern, describes EIA as the main market mover, and reports a
concentration of significant intraday return jumps around the release. Its
regression uses the sign and size of unexpected crude-oil and product
inventory changes, not the sign of a price bar.

The official EIA schedule identifies Wednesday after 10:30 a.m. Eastern as
the standard WPSR release clock and lists holiday exceptions. The governed
WPSR packet preserves the existing standard-Wednesday-only proxy convention
and the no-external-runtime-feed boundary.

The source does not say that every five-minute return should be faded, does
not define a Darwinex M5 candle as inventory news, and does not prescribe a
10:35 market order or a 10:45 exit. The reported negative serial correlation
is small and belongs to an estimated return model. It may be statistical but
not economically tradable after CFD spreads and slippage.

No source return, hit rate, profit factor, drawdown, transaction-cost result,
single-CFD equivalence, trade frequency, correlation, or portfolio conclusion
is imported.

## Bounded QM Mechanization

The card treats the completed standard-Wednesday 10:30-10:35 New York M5 CFD
bar as a transparent price-reaction proxy. At the first tick of the 10:35 bar,
it trades opposite the proxy sign and exits after the two five-minute lag
intervals represented by the source's reported first and second negative
return lags, at 10:45.

This is a falsification hypothesis, not a replication. The source inventory
shock is measured from released data relative to expectations/API data,
whereas the card uses only a price bar. A positive price reaction need not
represent a negative inventory shock, a negative reaction need not represent
a positive inventory shock, and the model's negative lag coefficients need
not imply a profitable unconditional fade.

## Exact Calendar And Bar Contract

- Host and traded carrier: exact `XTIUSD.DWX`, M5, symbol slot zero.
- Convert broker timestamps to UTC and then New York using the V5 broker-time
  and U.S.-DST helpers.
- Decision label: Wednesday 10:35 New York.
- Release-proxy bar: immediately preceding completed M5 bar, same New York
  date, label 10:30, exactly 300 broker-time seconds before the current bar.
- Entry grace: current New York seconds 0 through 29 at the first observed
  tick of the 10:35 bar.
- Standard Wednesdays only. Do not infer or trade a Thursday/Monday holiday
  shift. A holiday week's ordinary Wednesday 10:30 bar remains a known false
  event risk of the frozen price-only proxy.
- Missing, displaced, nonfinite, nonpositive, inverted, or incomplete OHLC
  consumes the date flat. No neighboring bar, larger timeframe, or late
  attachment may substitute.

## Exact Signal Contract

For completed finite release-proxy OHLC:

```text
signal = SELL when close > open
         BUY  when close < open
         FLAT when close == open
```

The comparisons are strict. Do not require or infer an inventory value,
consensus, surprise, API report, minimum return, minimum body, range breakout,
pre-release range, reclaim, trend, season, volume, open interest, futures
curve, or another signal.

## Execution And Risk Contract

- Repair malformed owned state before entry-only checks.
- Persist the New York `yyyymmdd` attempt before history, signal, news,
  spread, quote, ATR, sizing, or submission. Never retry after any failure or
  stop-out on that date.
- Enter one market order opposite the completed release-proxy sign.
- Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` for the
  sole non-live backtest setfile.
- Attach one frozen `3.0 * ATR(20,M5)` broker hard stop and no take-profit.
- Reject crossed or negative spreads and a genuinely positive spread above
  1,500 points. Modeled zero spread is valid.
- Close at the first tick at or after 10:45 New York on the entry date. Close
  on New York date change or twenty elapsed minutes only as repair.
- Close duplicate, wrong-symbol, wrong-side relative to persisted entry state,
  wrong-magic, or stopless owned exposure immediately.
- Lock current news temporal/compliance axes and legacy news mode OFF because
  the scheduled WPSR is the strategy event.
- Never retry, reverse, place a pending order, scale in, pyramid, grid,
  martingale, partially close, trail, move to break even, optimize, or use an
  external runtime input.

## Non-Duplicate Boundary

The corrected-root canonical receipt
`artifacts/qm5_wti_eia_lag2_fade_m5_preallocation_dedup_20260831.json`,
SHA-256
`856BD94846ADB0A82E31D6FD899F69DE285AA410511E2AF006FB7C764278BF44`,
found no exact identity across 4,742 registry rows, 1,380 cards, and 45
Strategy Wiki nodes. Its fuzzy matches are name-only collisions on the generic
token `fade`.

The closest WTI WPSR builds place a pre-release M5 straddle, follow a completed
M30 release sign late in the day, use completed D1 states, or wait for a
separate M30 deep reclaim. `QM5_41242` follows only a negative first-minute
response and closes at 10:35. None enters at 10:35 opposite the completed
10:30 M5 sign and exits at 10:45.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_STANDARD_WEDNESDAY_COMPLETED_M5_REACTION_LAG2_FADE`.

## Allowability And Kill Boundary

- R1: one approved composite source ID preserves the named peer-reviewed study,
  complete authors' poster, official EIA schedule, and explicit access limit.
- R2: exact clock, bar label, strict sign, opposite direction, attempt, risk,
  stop, spread cap, and exit are fully mechanical.
- R3: `framework/registry/dwx_symbol_history_ranges.csv` records
  `XTIUSD.DWX,M5,2017,2025` on T1-T10. The trade still carries CFD/futures
  basis, DST, gap, spread, and holiday-proxy risk.
- R4: deterministic timestamps, native OHLC, ATR risk control, quotes,
  positions, deals, and terminal state only; no ML or banned signal.

Expected cadence of roughly 35-48 completed trades per full year is only a
weekly-calendar prior. Q02 must retire the unchanged rule on zero positions,
fewer than five in any full scored year, nonpositive governed economics,
wrong bar or direction, duplicate attempt, missing stop, wrong exit, invalid
risk mode, or nondeterminism.

The WTI event carrier is outside the certified XAU/SP500/NDX/XNG carrier set,
but realized orthogonality is unproven until unchanged Q09. No portfolio-gate
change, admission, correlation waiver, live preset, deployment, `T_Live`
manifest, or AutoTrading action is authorized.
