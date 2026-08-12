---
strategy_id: SRC10_S01
source_id: SRC10
ea_id: 4007
slug: index-mac5-rev
status: APPROVED
created: 2026-07-17
created_by: Research
last_updated: 2026-07-17
review_state: APPROVED_OWNER_DELEGATED_CEO_CTO_QB_2026_07_17
approval_basis: "OWNER delegated the terminal technical release on 2026-07-17 with: 'mach weiter, gib du frei, wir brauchen ein komplettes Buch!'. Independent Quality-Business v3 re-review returned APPROVE after the causal execution, retained-risk, frequency, and route contracts were frozen."
book_account_type: FTMO_2_STEP_SWING_ONLY
strategy_type_flags:
  - daily-index-reversal
  - linear-lag-signal
  - time-exit
  - cost-sensitive
---

# Strategy Card — Index MAC(5) Reversal

## 1. Source

source_citations:

- type: paper
  citation: "Baltussen, Guido, Sjoerd van Bekkum, and Zhi Da. Indexing and Stock Market Serial Dependence Around the World. Journal of Financial Economics. DOI 10.1016/j.jfineco.2018.07.016."
  location: "Accepted-manuscript pages 3-4, 13-19, 32-40, Tables 2-3, and Appendix B; especially equations (2) and (20)."
  quality_tier: A
  role: primary

Author manuscript: https://personal.eur.nl/vanbekkum/2018%20JFE%20BaltussenVanBekkumDa.pdf

## 2. Concept

Equity-index returns became negatively serially dependent as index futures, ETFs, and index arbitrage grew. The paper measures this with MAC(5), a linearly weighted combination of the prior four daily returns. A tradable reversal sleeve takes the opposite side of that weighted return driver and rebalances daily, providing liquidity after index-level price pressure.

This is a time-series rule on one index. It is not cross-sectional loser/winner ranking and does not use constituent, ETF-flow, futures-open-interest, or external runtime data.

## 3. Markets and timeframes

markets:

- equity-index CFDs

timeframes:

- D1 signal and holding period
- M15 execution event loop only if required by the framework runner

primary_target_symbols:

- SP500.DWX

cross_sectional_falsification_only:

- GDAXI.DWX after symbol validation PASS
- NDX.DWX after symbol validation PASS and with its shorter 2021-2026 window disclosed

The first build, if approved, is single-symbol `SP500.DWX`. Multi-index capital allocation belongs to Q09, not this card.

## 4. Entry rules

Define completed broker-D1 close-to-close log returns:

`r1 = ln(Close[1] / Close[2])`

`r2 = ln(Close[2] / Close[3])`

`r3 = ln(Close[3] / Close[4])`

`r4 = ln(Close[4] / Close[5])`

and the source driver:

`m = 4*r1 + 3*r2 + 2*r3 + r4`.

At the first executable tick of each new D1 bar, calculate the desired sign-only target and apply only the required position delta under section 5:

- if `m > 0`, the desired target is short;
- if `m < 0`, the desired target is long;
- if `m == 0` within machine precision, the desired target is flat.

No threshold, trend filter, volatility regime, weekday filter, or return-weight search is authorized for the baseline. The four weights `[4,3,2,1]`, the contrarian sign, and daily rebalance are source locked.

The source's `1/(5*sigma^2)` term is a constant full-sample scaling factor and cannot use future data in live trading. This card freezes a **sign-only, fixed-planned-risk operational port** before Q02. It preserves the exact `[4,3,2,1]` driver and contrarian direction but does not claim to replicate the paper's continuously varying target magnitude. Rolling or full-sample variance scaling, signal-strength sizing, and performance-based choice between exposure modes are forbidden for this lineage.

The causal execution contract is broker-D1 native:

- all inputs are completed `Close[1]` through `Close[5]`; the forming bar is never read for the signal;
- the decision timestamp is `iTime(symbol, PERIOD_D1, 0)` and the first executable quote of that new broker D1 bar is the intended fill;
- a target may be applied only within 900 seconds of that D1 timestamp; a later terminal start closes any stale prior target and skips the new one rather than catching up;
- holidays simply create no new D1 bar; the next actual broker D1 bar is the next decision event;
- no civil-time or DST conversion is applied because the broker's own D1 partition is the contract;
- the operational port applies target changes on the first eligible next tick and is marked to market at every broker-D1 boundary, not the paper's idealized close-to-close series. A retained position can span several D1 bars, so completed-deal P/L is not described as one-day realized open-to-open P/L. Fill delay, daily marked P/L, holding-period P/L, and gap P/L must be reported separately.

The source-supported one-day implementation-lag form is preregistered as a falsification diagnostic only. It cannot replace or rescue the zero-lag baseline in this EA lineage.

## 5. Exit rules

- Recompute the sign-only target at the first executable tick of each new D1 bar.
- If the target direction is unchanged, retain the existing fixed-risk position and record a no-trade target update.
- If the target direction flips, close the old position, confirm flat, and open the opposite fixed-risk target within the same 900-second application window.
- If flat, open the new target within that window. If the close is not confirmed in time, continue flatten retries but do not catch up the missed reverse entry.
- A missing new target never prevents the mandatory old-target exit.
- Rejected or unconfirmed exits retry until flat; entries are one-shot within the new-bar execution window.
- Friday positions are source-valid and may remain through the weekend. This lineage is therefore restricted to **FTMO Challenge: 2-Step Swing from purchase through funded operation**. The generic Friday flatten rule is disabled for this EA; weekend gap and financing are included in Model-4 evidence. A Standard or 1-Step Friday-flat interpretation requires a separate card, ID, and evidence lineage.
- No take-profit, trailing stop, break-even, partial close, or discretionary exit is source authorized.
- On a retained same-direction target, the entry volume and its originally frozen 2.0-ATR stop remain unchanged until flip, flat/invalid target, stop hit, or a stale-restart flatten. There is no daily lot recalculation, position addition, stop replacement, stop widening, or risk increase.

Frozen non-alpha safety overlay:

- frozen prior-D1 ATR(20) catastrophic stop;
- exactly 2.0 ATR, fixed before Q02 and never selected from outcomes;
- Q03 may report non-selecting 1.5/2.0/2.5 ATR sensitivity, but the production candidate remains 2.0 ATR and all cells must be disclosed;
- the stop bounds FTMO risk and is not described as a source alpha rule.
- after a stop hit, remain flat until the next new D1 target; no same-day re-entry.
- gap loss beyond the stop and stop-hit frequency are mandatory report fields.

## 6. Filters (No-Trade module)

- fail closed on fewer than six valid completed D1 closes, nonpositive closes, invalid quote, missing account-governor snapshot, unknown magic, or stale/mismatched policy fingerprint;
- the OWNER-approved build contract fixes the entry-only abnormal-spread ceiling at exactly `100` `SP500.DWX` points (`1.00` index-price unit at two digits) before Q02. It is immutable, is not an optimization axis, applies only to the `SP500.DWX` research build, and grants no spread or route evidence for `US500.cash`; exits are never spread blocked;
- no news filter in source-replication baseline; Q08 may measure compliance modes but may not block required exits;
- no external runtime data;
- no grid, martingale, averaging, pyramiding, catch-up entry, or re-entry on the same D1 target.

Research route and FTMO execution route are deliberately separate:

- Q02 signal and fill evidence use `SP500.DWX`, whose registered D1 history is 2018-2026.
- The existing `SP500.DWX -> SP500` routing proof is Darwinex-Zero evidence only and grants no FTMO route.
- FTMO's official snapshot identifies the intended contract as `US500.cash`, contract size 1, two digits, no commission, swap long -86.56 points, swap short -68.93 points, and 2% margin.
- Any deployment candidate requires a complete `SP500.DWX -> US500.cash` price, session, contract, volume, stop-distance, spread, swap-day, and order-routing requalification. No evidence is transferred from the Darwinex-Zero `SP500` route.

Numeric cost gate, frozen before Q02:

- bound snapshot: `artifacts/ftmo_symbol_snapshot_2026-07-11.json`, SHA-256 `7309310ad92f794407d25452127c38e7db175b841be0f70b82b201b841b932da`; cost adapter precedent: `artifacts/ftmo_q02_cost_scout_1162_SP500_DWX_2026-07-12.json`;
- refresh the official FTMO symbols snapshot no more than seven calendar days before Q02 and again before every release decision; any contract-field change invalidates the cost binding;
- Q02 window is 2018-01-01 through 2024-12-31 on native Model-4 bid/ask ticks, followed by current FTMO commission, swap, contract-size, and rollover reconciliation;
- record turnover, spread, commission, financing, and gap contribution separately;
- baseline acceptance requires two deterministic runs, net profit greater than zero, PF at least 1.20 after current FTMO costs, at least 336 completed trades across the seven full years, and at least 36 completed trades in every full calendar year;
- 2x spread-plus-commission stress requires net profit greater than zero and PF at least 1.10;
- 2x swap plus explicit FTMO triple-swap/weekend stress requires net profit greater than zero and PF at least 1.05;
- any baseline full calendar year below PF 0.90 or any internal-book floor breach rejects the candidate;
- page 19's cost warning is a falsification requirement: gross profitability or paper Sharpe can never qualify the EA.

## 7. Trade Management Rules

- one position per symbol and magic;
- no intraday signal recomputation;
- on restart, reconstruct whether the current D1 target was already attempted from open position and deal history;
- after a new D1 boundary, retain an old position only when the newly computed target has the same direction. Flatten it before any other action when the target flips, is flat, is invalid/missing, or the terminal is recovering more than 900 seconds after the decision timestamp;
- backtest convention is `RISK_FIXED = 1000` only after the stop contract and exposure-normalization method are frozen;
- Phase-1 planned risk is deliberately fixed at 0.15 percent at full governor scale because this is a daily index, weekend-gap, and cost-sensitive port. This is an explicit conservative exception to the target book's generic 0.25-0.30 percent band, not an unresolved choice. Verification uses 70 percent of Phase-1 size and funded risk is 0.10 percent maximum, all subordinate to the account governor and equity-cluster cap;
- strategy and TOM/MAC5 variants share the equity-index cluster; simultaneous planned equity-cluster loss must remain at or below 0.45 percent in Phase 1.

## 8. Parameters to test

Source locked:

| name | default | authorized test |
|---|---:|---|
| lag weights | 4,3,2,1 | fixed |
| direction | contrarian | fixed |
| return type | log close-to-close | fixed |
| rebalance | each new D1 bar | fixed |
| primary symbol | SP500.DWX | fixed baseline; cross-symbol falsification only |
| implementation lag | 0 | 1-day source-supported diagnostic only; never a rescue selection |

Implementation safety, frozen before Q02:

| name | proposed default | authorized test |
|---|---:|---|
| exposure mode | sign-only fixed planned risk | fixed; no magnitude alternative |
| catastrophic ATR period | 20 D1 | fixed |
| catastrophic ATR multiple | 2.0 | fixed; 1.5/2.5 non-selecting sensitivity only |
| target application window | 900 seconds | fixed from broker D1 timestamp |
| exit retry interval | 5 seconds | fixed |
| entry-only abnormal-spread ceiling | 100 `SP500.DWX` points (`1.00` price unit at two digits) | fixed and immutable; not optimizable; research build only and not transferable to `US500.cash` |

## 9. Author claims

- Post-1999 MAC(5) is negative for all 20 indexes and significantly negative for 13 in Table 2.
- Trading against MAC(5) produced an annualized Sharpe ratio of 0.63 across all indexes and 0.67 for the S&P 500 alone after 2 March 1999.
- Futures and ETF MAC(5) were negative from their inception in the sample.
- The authors explicitly caution that frequent rebalancing may prevent exploitation after transaction costs.

These are historical research claims through 2016, not FTMO return promises.

## 10. Initial risk profile

expected_pf: TBD

expected_dd_pct: TBD

expected_trade_frequency: approximately 240-255 target evaluations per year; completed trades occur only on flat-to-target entries, direction flips, and post-stop next-day entries. Planning band 48-120 completed trades per year is unverified; Q02 must report actual counts and meet the frozen lower-band gate of at least 336 across 2018-2024 with at least 36 in each full year. This D1 reserve is an explicit 4-10 completed-trades/month book exception and is a diversifier, not the book's primary speed engine.

risk_class: medium-high because turnover is daily, index gaps can jump the stop, and the source gives no stop-loss study

gridding: false

scalping: false

ml_required: false

The economic edge may be too small for CFD costs. Q02 is expected to reject the card unless net metrics, cost attribution, and independent repeated runs all pass.

## 11. Strategy allowability check

- [x] Primary paper read completely and cited to exact equations/pages.
- [x] Mechanical `[4,3,2,1]` signal and contrarian direction.
- [x] Research evidence uses native `SP500.DWX` data only; any FTMO lifecycle requires separately qualified native `US500.cash` price, contract, cost, session, and order-route evidence.
- [x] No ML, grid, martingale, averaging, or pyramiding.
- [x] Manual duplicate review distinguishes weekly/cross-sectional reversals.
- [x] Sign-only exposure normalization frozen before Q02; no variance/magnitude selection.
- [x] Target-delta rebalance, 2.0 ATR catastrophic stop, and 2-Step Swing-only Friday exception frozen for re-review.
- [x] Current SP500 research and FTMO execution contracts separated; snapshot path/hash and numeric cost gates bound.
- [x] Independent v3 review returned terminal `APPROVE` on 2026-07-17.
- [x] Sequential production EA ID 4007 and `SP500.DWX` slot-0 magic 40070000 allocated after approval.

## 12. Framework alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "History/quote validity, one-shot day state, entry-only spread, governor snapshot, magic and policy fingerprint."
  trade_entry:
    used: true
    notes: "One daily contrarian target from four completed log returns with source-locked 4,3,2,1 weights."
  trade_management:
    used: false
    notes: "No source-authorized trailing, break-even, scale-out, grid, or intraday recomputation."
  trade_close:
    used: true
    notes: "Target-delta rebalance: retain unchanged-direction volume and frozen stop; otherwise repeated-until-flat recovery, catastrophic stop, and stale-position restart flattening."
```

## 13. Pipeline history

| version | date | change | phase | result |
|---|---|---|---|---|
| v1 | 2026-07-17 | full-paper extraction; no ID or build | Research | DRAFT |
| v2 | 2026-07-17 | resolved causal timing, sign-only delta target, fixed stop/risk, Swing-only route, and numeric cost gates | Pre-G0 review | DRAFT_REVIEW_PENDING |
| v3 | 2026-07-17 | removed daily-flatten ambiguity; froze retained lot/stop lifecycle; aligned frequency and route gates | G0 review | APPROVED; EA ID 4007 allocated |
| v4 | 2026-07-17 | OWNER ratified the 100-point `SP500.DWX` entry-only abnormal-spread ceiling as immutable before Q02 and explicitly non-transferable to `US500.cash` | Build-contract ratification | APPROVED; code/set value unchanged; no Q02 |
| v5 | 2026-07-17 | two valid deterministic Model-4 runs produced 0/0 trades; market orders at the broker-D1 boundary were rejected as market closed after the one-shot attempt flag had already been persisted | Q02 | `FAIL_ZERO_TRADES_BELOW_COHORT_NO_DISPATCH`; excluded from current book |

Q02 evidence is bound in `framework/EAs/QM5_4007_index-mac5-rev/ZT_RootCause_QM5_4007_20260717.md`. Its summary SHA-256 is `D9005A82B18CFBE4F881EC95B3935A7DBD0FF37D04E62E668AD909BD094480A3`. Evidence from another reversal EA may not be transferred to this lineage.
