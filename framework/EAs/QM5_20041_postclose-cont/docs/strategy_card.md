---
card_schema_version: 2
ea_id: QM5_20041
slug: postclose-cont
status: DRAFT
g0_status: APPROVED
symbol: GDAXI.DWX
timeframe: M15
variant_id: POSTCLOSE_CONT_BASELINE
execution_contract_ref: framework/registry/dxz23_execution_contracts.json#ea_id=20041
execution_contract_status: DRAFT
target_symbols: [GDAXI.DWX, UK100.DWX]
expected_trades_per_year_per_symbol: 240
g0_approval_reasoning: "R1 Chiu et al. 2024 PLOS ONE 19(3) DOI 10.1371/journal.pone.0299207; R2 mechanical cash-close sign, one-bar delay, 240-minute hold and fixed ATR stop; R3 GDAXI/UK100 .DWX M15 ticks/calendars; R4 deterministic no-ML port"
last_updated: 2026-07-22
expected_pf: 1.25
expected_dd_pct: 12.0
source_id: CHIU-ET-AL-2024
ml_required: false
r1_track_record: PASS
r1_reasoning: "Peer-reviewed PLOS ONE 19(3), 2024, DOI 10.1371/journal.pone.0299207 documents positive regular-to-after-hours return continuity; target-market port, stop, costs, and four-hour horizon remain explicit QM interpretations."
r2_mechanical: PASS
r2_reasoning: "Mechanical DST-aware cash-session sign, one completed post-close M15 observation bar, next-bar same-sign entry, frozen 1.0-ATR hard stop, and earliest-of 240-minute or pre-rollover exit."
r3_data_available: PASS
r3_reasoning: "GDAXI.DWX and UK100.DWX M15 real ticks plus DST-aware Xetra/LSE session and broker-break metadata are available for DEV 2018-2023, OOS 2024, and sealed 2025."
r4_ml_forbidden: PASS
r4_reasoning: "Deterministic session-return sign and RISK_FIXED sizing with one position per magic; no grid, martingale, order book, discretionary news interpretation, or ML."
source_citations:
  - type: academic_paper
    citation: "Chiu, C.-L., Chang, T.-H., Hsiao, I-F. & Chiou, D.-S. (2024). The price continuity, return and volatility spillover effects of regular and after-hours trading. PLOS ONE 19(3):e0299207. DOI 10.1371/journal.pone.0299207."
    location: "Regular-session return positively affecting the following after-hours return in nearby Taiwan Stock Index Futures; not a European CFD trading-rule backtest."
    quality_tier: A
    role: primary
---

# Cash-session return continuation after the close

## Source-defined rules

Chiu, Chang, Hsiao and Chiou (2024), *The Price Continuity, Return and
Volatility Spillover Effects of Regular and After-Hours Trading*, *PLOS ONE*
19(3), e0299207, DOI https://doi.org/10.1371/journal.pone.0299207, analyze
nearby Taiwan Stock Index Futures around separate regular and after-hours
sessions. Their mean-equation evidence supports positive regular-session to
after-hours return continuity and also documents volatility spillover.

The source estimates a return relation; it does not publish this sign-only
strategy, a `GDAXI.DWX` or `UK100.DWX` port, `M15` execution, a one-bar delay,
an ATR stop, transaction-cost P&L, financing treatment, or a four-hour hold.
Those are QM interpretations. The reverse after-hours-to-next-regular link is
out of scope because it belongs to an overnight reversal family.

## QM interpretations

Every rule in this section belongs to variant `POSTCLOSE_CONT_BASELINE`.

- **Cash-session anchors.** Resolve the official local cash session from
  provenance-locked, DST-aware calendars: Xetra for `GDAXI.DWX` and LSE for
  `UK100.DWX`, including holidays and early closes. At the official close,
  freeze `P_open` as the first valid target midquote at or after the official
  cash open, `P_close` as the last valid target midquote at or before the
  official cash close, and `r_cash=P_close/P_open-1`. Do not use broker D1
  boundaries. Missing, stale, or non-positive anchors fail closed.
- **Entry.** Observe exactly one complete post-close `M15` bar. If
  `r_cash > 0`, enter LONG at the first tradable quote of the next `M15` bar;
  if `r_cash < 0`, enter SHORT; equality after tick-size normalization gives no
  trade. Maximum one entry per symbol/cash session with no re-entry or
  reversal. An unresolved calendar, intended-entry news pause, missing
  observation bar, or a hold that cannot finish safely on the same local
  trading day blocks rather than delays the entry.
- **Stop and time exit.** At the observation-bar close, freeze Wilder
  `ATR(14)` from completed `M15` bars through that bar. LONG broker hard stop
  is `actual_fill-1.0*ATR14`; SHORT stop is
  `actual_fill+1.0*ATR14`. The stop never moves or widens. There is no target,
  trail, breakeven move, partial close, scaling, averaging, or reversal.
  Define `scheduled_exit=entry_time+240 minutes` and
  `safety_exit=next symbol trading-session break/rollover minus 15 minutes`;
  force-flat at the first tradable tick at or after the earlier time. If the
  earlier exit cannot be guaranteed on the same local trading day, skip entry.
- **Financing verification.** The four-hour hold is a near-swap-free design,
  not a free-financing assumption. Before each entry, bind the symbol's current
  authoritative broker daily-break, rollover, and financing schedule to the
  session-date audit. Enter only when the full proposed interval is verified
  not to cross a financing assessment boundary. Missing, stale, contradictory,
  or unhashable financing metadata fails closed. Log the source/version and
  decision; do not hard-code a commission, swap, financing, break, or DST
  value. If the port cannot remain same-day and financing-safe, reject it rather
  than lengthen it overnight.
- **Sizing and cost.** Size once from the setfile's locked `RISK_FIXED` amount
  and actual fill-to-stop monetary distance; `RISK_PERCENT` is not authorized.
  Require the 1.0-ATR stop distance in price units to be at least four times
  modeled round-trip friction and require
  `(commission + spread) / initial_monetary_risk <= 0.10R`. Resolve current
  commission, spread, tick value, conversion, volume step, and stop constraints
  from governed per-symbol runtime data. Missing inputs or unrepresentable
  volume blocks entry.
- **Density and risk family.** Approximately 240 trades/year/symbol is a
  session-opportunity prior, not observed profitable fills. News, cost,
  calendar, data, and financing gates reduce realized density. GDAXI and UK100
  are one European post-close index family under a shared exposure cap.

## Framework execution overrides

- The framework emergency/account kill switch disables entries and may flatten
  an open position before the hard stop or deterministic time exit.
- The default high-impact-news pause remains active at intended entry. A
  blocked entry is never delayed into a later post-close bar.
- Approved early-close, daily-break, rollover, and financing metadata may
  shorten eligibility but may not extend the 240-minute maximum. The framework
  Friday safety close remains enabled after the card's same-day exit.
- No expiration-day branch, broker-D1 anchor, overnight extension, MOC
  pre-close signal, profit target, grid, martingale, pyramid, or loss-dependent
  sizing override is authorized.

## Exit precedence

1. Framework emergency/account kill-switch close.
2. Executed frozen 1.0-ATR broker hard stop.
3. Earlier of `entry_time+240 minutes` and 15 minutes before the next verified
   symbol trading-session break/rollover; after restart or rejected close,
   retry immediately before any entry evaluation.
4. Framework Friday safety close if a position somehow remains open.
5. Calendar, financing, or provenance expiry blocks new entries only; it never
   removes the hard stop or already-bound deterministic exit from an open
   trade.

## Runtime data dependencies

- Primary chart, signal, and order route: `GDAXI.DWX`, `M15`.
- Sibling symbol — **per-symbol setfile to generate at build**: `UK100.DWX`.
  Generate one setfile for each target. Each route owns its exchange calendar,
  cash anchors, observation bar, attempt key, position, stop, time exit,
  financing decision, and cost state; the portfolio owns the shared cap.
- Pin IANA timezone data for the relevant Xetra and LSE local jurisdictions and
  provenance-locked exchange holiday/early-close calendars. Also bind the
  governed broker symbol-session, daily-break, rollover, and financing metadata
  used by the pre-entry verifier. All calendar and financing inputs have
  `valid_through=2025-12-31` for the prescribed study.
- Tester account currency is USD. Runtime needs executable bid/ask ticks,
  current tick value, account-currency conversion, volume step, stop level,
  commission schedule, and spread for each target. No numeric commission or
  financing constant is authorized by this card.
- `GDAXI.DWX` and `UK100.DWX` real-tick histories must cover complete cash and
  post-close sessions for DEV 2018-2023, OOS 2024, and untouched sealed 2025;
  dataset `valid_through=2025-12-31`. No order book, futures basis, settlement,
  or ML service is required.

## Falsification and requalification

- Freeze DEV 2018-2023, OOS 2024, and untouched sealed 2025. Report each
  symbol, LONG/SHORT, calendar year, DST transition week, holiday/early-close
  exclusion, stop-to-friction ratio, hold duration, and financing-verification
  result separately.
- Reproduce the source-sign baseline first. Any 60-, 120-, or 240-minute hold
  comparison or observation-delay ablation is sequential and preregistered,
  never a Cartesian optimization or permission to replace the baseline after
  OOS. Reject the European port if the four-hour same-day segment fails; do not
  use overnight carry to rescue it.
- Apply governed nonzero commission and historical spread, then shift entry and
  exit one tick adversely. Reject if OOS or sealed expectancy is not positive,
  if any admitted trade requires `cost_R > 0.10R`, or if financing cannot be
  verified absent for the bound hold.
- Dedup boundary: unlike `QM5_20033_moc-imom` and
  `QM5_10326_close-auct-rev`, this card does not enter or fade before the cash
  close or trade closing-auction pressure. It waits for the venue to close,
  measures the entire cash open-to-close sign, observes one full post-close
  `M15` bar, follows that sign, and exits the same local day. It is also not a
  US close-to-next-open or after-hours-to-next-regular reversal sleeve.
- Any change to exchange calendar, cash-anchor quote rule, sign, observation
  delay, entry time, ATR convention, stop, hold, safety buffer, financing
  verifier, cost model, risk mode, symbol route, or variant identity requires a
  new binary, tick/calendar/financing reconciliation, and full portfolio
  requalification. An unresolved item is `BLOCKED`; Development may not fill
  it in.

