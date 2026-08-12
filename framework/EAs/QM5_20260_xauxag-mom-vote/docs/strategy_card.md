---
card_schema_version: 2
type: strategy
strategy_id: FMR-MOMTS-2010_XAU_XAG_MAJ1312_S05
variant_id: FMR-MOMTS-2010_XAU_XAG_MAJ1312_S05
source_id: FMR-XAUXAG-MOMVOTE-2026
ea_id: QM5_20260
slug: xauxag-mom-vote
status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20260_xauxag-mom-vote_card.md
execution_contract_status: DRAFT
created: 2026-08-07
created_by: Research+Development
last_updated: 2026-08-07
g0_status: APPROVED
source_authors: "Ana-Maria Fuertes; Joelle Miffre; Georgios Rallis"
source_citation: "Fuertes, A.-M., Miffre, J., and Rallis, G. (2010), Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals, Journal of Banking & Finance 34(10), 2530-2548, DOI 10.1016/j.jbankfin.2010.04.009."
source_citations:
  - type: peer_reviewed_paper
    citation: "Fuertes, Ana-Maria, Miffre, Joelle, and Rallis, Georgios (2010). Tactical Allocation in Commodity Futures Markets: Combining Momentum and Term Structure Signals. Journal of Banking & Finance 34(10), 2530-2548."
    location: "Complete 47-page accepted manuscript; momentum construction pp. 6-7 and 17-18; DOI https://doi.org/10.1016/j.jbankfin.2010.04.009; governed packet strategy-seeds/sources/FMR-MOMTS-2010/source.md"
    quality_tier: A
    role: primary
strategy_mechanic: monthly-xau-xag-one-three-twelve-month-cross-sectional-return-rank-majority-vote
sources:
  - "[[sources/FMR-XAUXAG-MOMVOTE-2026]]"
  - "[[sources/FMR-MOMTS-2010]]"
concepts:
  - "[[concepts/cross-sectional-commodity-momentum]]"
  - "[[concepts/multi-horizon-momentum]]"
  - "[[concepts/market-neutral-basket]]"
  - "[[concepts/majority-vote]]"
indicators:
  - "[[indicators/completed-month-average-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [commodity, precious-metals, cross-sectional-momentum, multi-horizon-vote, market-neutral-basket, monthly-rebalance, atr-hard-stop, time-stop, low-frequency]
markets: [commodities, precious_metals]
timeframes: [D1]
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
primary_target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_20260_XAU_XAG_MOMVOTE_D1
symbol: QM5_20260_XAU_XAG_MOMVOTE_D1
symbol_slot: 0
magic: 202600000
period: D1
timeframe: D1
expected_trade_frequency: "Approximately twelve completed two-leg XAU/XAG packages/year after thirteen synchronized completed month ends; Q02 must prove at least five/year or retire."
expected_trades_per_year_per_symbol: 12
expected_pf: 1.01
expected_dd_pct: 25.0
risk_class: high
ml_required: false
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: ENQUEUED
review_focus: "Falsify a monthly XAU/XAG market-neutral construction that votes across the source-defined one-, three-, and twelve-month cross-sectional ranks; only Q09 may establish realized decorrelation."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [synchronized_completed_months, arithmetic_average_returns, strict_no_tie, majority_vote, basket_atomicity, aggregate_fixed_risk, monthly_attempt_state, monthly_package_renewal, risk_mode_dual, cfd_futures_basis, q02_frequency_floor, portfolio_correlation]
g0_approval_reasoning: "APPROVED under decisions/2026-08-07_qm5_20260_xauxag_mom_vote_g0.md: tier-A peer-reviewed complete-read source packet explicitly tests one-, three-, and twelve-month cross-sectional commodity-momentum formation ranks with one-month holds; locked thirteen synchronized XAU/XAG month ends, three arithmetic-average return differences, strict no-tie components, two-of-three vote, opposite legs, shared risk, hard stops, persisted monthly attempt, renewal, and atomic repair; registered native XAU/XAG D1 route; deterministic arithmetic only. Dedup scanned 4,317 registry rows and 434 cards, found no exact collision, and seven expected source/mechanic-family fuzzy neighbors were manually resolved. The vote and two-CFD translation are transparent QM hypotheses, and no source efficacy, neutrality, or decorrelation transfers."
---

# QM5_20260 XAU/XAG Multi-Horizon Momentum Vote

## Hypothesis

Commodity supply, demand, inventory, industrial-use, and hedging shocks can
diffuse at different speeds across gold and silver. A fixed majority of their
completed one-, three-, and twelve-month cross-sectional momentum ranks may
retain persistent relative direction while allowing two faster ranks to
recognize a reversal before the slow rank changes.

The two opposite legs aim to suppress common precious-metal and USD direction,
leaving relative gold-versus-silver momentum. That is a market-neutral
construction intent, not proof of dollar, beta, volatility, industrial-demand,
or portfolio neutrality. Q02 owns density and baseline economics. Q09 alone
may measure overlap with the certified XAU/SP500/NDX/XNG book after the
candidate survives every preceding gate.

## Source Traceability And Claim Boundary

The governed extraction is
`strategy-seeds/sources/FMR-XAUXAG-MOMVOTE-2026/source.md`. Its completely
reviewed parent records Fuertes, Miffre, and Rallis's peer-reviewed article,
the complete 47-page accepted manuscript, average-past-return commodity ranks,
and explicit one-, three-, and twelve-month formation horizons with one-month
holds. The repository separately implements each source-family XAU/XAG
horizon.

The two-of-three aggregation and two-metal CFD translation are transparent QM
hypotheses. The source does not test this vote, a two-name precious-metals
subset, synchronized Darwinex month-end reconstruction, equal fixed-risk
halves, ATR stops, spread caps, attempt persistence, or the QM portfolio. No
source PF, return, Sharpe ratio, drawdown, constituent result, trade count,
cost, neutrality, or correlation statistic transfers.

## Non-Duplicate Decision

The deterministic checker scanned 4,317 registry rows and 434 cards. It found
no exact identity and seven expected source/mechanic-family fuzzy neighbors.
Manual review fixes the boundary:

- `QM5_20057_xauxag-xmom1`, `QM5_20184_xauxag-xmom3`, and
  `QM5_20050_xauxag-xmom12` rank a single horizon; this candidate requires all
  three non-tied ranks and trades their majority.
- `QM5_13126_energy-momcarry` combines one-month XTI/XNG momentum with a
  broker-swap proxy, and `QM5_20051_energy-xmom1` ranks XTI/XNG on one month.
- `QM5_20258_wti-mom-vote` and `QM5_20259_xng-mom-vote` vote on one
  instrument's own cumulative return signs. This candidate votes on three
  XAU-minus-XAG cross-sectional arithmetic-average-return ranks and must open
  an opposite two-leg package.
- XAU/XAG ratio, residual, return-spread, volatility-rank, reversal, calendar,
  conditional-quantile, and other momentum baskets use different states or
  lifecycles.

A content-level scan of all intake cards requiring both metals found no
existing vote or majority mechanic. The two-metal carrier, synchronized
calendar-month endpoints, exact three horizons, arithmetic-average ranks,
strict no-tie components, majority mapping, shared-risk opposite legs,
monthly attempt clock, and monthly renewal are jointly load-bearing. Verdict:
`CLEAN_AFTER_EXPECTED_FUZZY_AND_MANUAL_REVIEW`.

## Markets, Timeframe, And Cadence

- Logical basket: `QM5_20260_XAU_XAG_MOMVOTE_D1`.
- Host/slot 0: `XAUUSD.DWX`, D1, intended magic `202600000` after allocation.
- Companion/slot 1: `XAGUSD.DWX`, D1, intended magic `202600001` after
  allocation.
- Decision clock: first processed host D1 bar of each genuine broker-month
  transition.
- Formation: thirteen synchronized consecutive completed broker-month-end
  observations per leg.
- Expected cadence: approximately twelve completed packages/year after
  warm-up; retire below five per full post-warm-up year.
- Runtime data: native MT5 D1 time/close, ATR, spread, quotes, positions, deal
  history, broker calendar, and contract metadata only.

## Formula

For each metal `i`, store synchronized completed month-end closes newest-to-
oldest as `C_i[0]..C_i[12]`, with `C_i[0]` in the month immediately preceding
the decision month. For `h` in `{1,3,12}`:

```text
A_i(h) = (1/h) * sum(C_i[k] / C_i[k+1] - 1, k=0..h-1)
D(h)   = A_XAU(h) - A_XAG(h)
vote   = sign(D(1)) + sign(D(3)) + sign(D(12))
```

Require every component to be finite and `abs(D(h)) > 1e-10`. BUY XAU and
SELL XAG when `vote` is `1` or `3`; SELL XAU and BUY XAG when `vote` is `-1`
or `-3`. A tie at any horizon, nonconsecutive or unsynchronized endpoint,
invalid price, or invalid arithmetic consumes the month flat. Vote magnitude
does not alter the fixed package-risk budget.

## Rules

The following rules are the complete authorized Q02 baseline. There is no
signal-parameter sweep.

## 4. Entry Rules

1. Require exact EA ID `20260`, logical basket host `XAUUSD.DWX` D1, slot 0,
   registered magics for both symbols, and every baseline input locked.
2. Evaluate only on a new host D1 bar that opens a genuine new broker month;
   use completed bars only.
3. Persist the broker month as evaluated before reconstructing history or
   applying signal, news, spread, quote, stop, sizing, or order gates. A flat,
   invalid, rejected, failed, partial, or stopped outcome cannot retry that
   month.
4. Reject owned exposure or any same-month entry deal for either registered
   magic.
5. Reconstruct exactly thirteen consecutive completed broker-month-end closes
   from bounded D1 history for both legs. Require matching month keys and
   endpoint timestamps, positive prices, and the newest endpoint in the
   immediately preceding broker month.
6. Compute the arithmetic average of exactly one, three, and twelve completed
   simple monthly returns for each metal. Require every XAU-minus-XAG
   difference to be finite and outside `[-1e-10,1e-10]`.
7. Sum the three cross-sectional rank signs. A positive two-of-three majority
   buys XAU and sells XAG; a negative majority sells XAU and buys XAG. There
   is no weighting, volatility state, ratio state, calendar direction,
   significance gate, or post-result override.
8. Require XAU spread in `[0,1500]` points, XAG spread in `[0,3000]` points,
   executable quotes, completed `ATR(20,D1)` for both legs, valid stop
   geometry, volume metadata, and no owned exposure.
9. Split one package risk budget equally after independent volatility
   normalization. Attach one frozen `3.5 * ATR(20,D1)` hard stop to each leg
   and no take-profit.
10. Open XAU then XAG. Keep the package only when exactly one correctly
    directed position exists in each registered slot. Flatten every owned leg
    immediately if either order or final package validation fails.

## 5. Exit Rules

1. Close both legs on the first processed D1 bar of the next broker month
   before considering the new month's vote, even when direction repeats.
2. Close both legs after forty elapsed calendar days as a stale guard.
3. Immediately flatten an orphan, duplicate, wrong-symbol, wrong-magic,
   same-direction, invalid-type, or missing-stop package.
4. Broker hard stops and the framework kill switch remain authoritative.
5. Friday close is disabled because a valid package spans the full source
   month and may cross weekends.
6. No intramonth signal reversal, target, trail, break-even, partial close,
   scale-in, grid, martingale, pyramid, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed outside exact `XAUUSD.DWX` D1 slot 0 or on unlocked inputs.
- Require synchronized consecutive month endpoints, positive closes, valid
  simple returns, three non-tied rank differences, registered magics, valid
  attempt state, acceptable spreads, executable quotes, ATR, stop, and volume
  metadata.
- Both news axes and legacy news mode are locked OFF for Q02. Lifecycle exits
  run before entry-only gates.
- Runtime may not read a futures curve, external file/API, inventory, volume,
  open interest, analyst input, trained output, optimizer result, or portfolio
  state.

## 7. Trade Management Rules

- The EA may own exactly two opposite-direction positions: XAU slot 0 and XAG
  slot 1.
- One `RISK_FIXED` budget is shared equally; it is not applied independently
  in full to both legs.
- Month-transition and stale exits run before entry-only news gates.
- Restart recovery combines a terminal-persistent evaluated-month marker with
  owned positions and deal history; future-dated tester state is cleared.
- A broker stop, failed qualified order, repair, or lifecycle exit cannot cause
  a same-month retry.
- No randomness, adaptive fit, external state, partial close, scale-in, or
  pyramiding is allowed.

## Parameters To Test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_fast_months` | 1 | [1] | newest completed average-return horizon |
| `strategy_medium_months` | 3 | [3] | intermediate completed average-return horizon |
| `strategy_slow_months` | 12 | [12] | slow completed average-return horizon |
| `strategy_required_votes` | 2 | [2] | fixed majority threshold |
| `strategy_history_bars_d1` | 800 | [800] | bounded synchronized endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | [20] | completed D1 stop estimator |
| `strategy_atr_sl_mult` | 3.5 | [3.5] | frozen per-leg hard-stop distance |
| `strategy_max_hold_days` | 40 | [40] | monthly stale guard |
| `strategy_xau_max_spread_pts` | 1500 | [1500] | XAU entry spread ceiling |
| `strategy_xag_max_spread_pts` | 3000 | [3000] | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | [20] | order deviation |

Changing a horizon, average-return definition, vote rule, tie handling,
carrier, leg weighting, stop, holding clock, spread cap, or retry policy
requires a new card and full pipeline run.

## Author Claims

Fuertes, Miffre, and Rallis define average-past-return cross-sectional
commodity momentum and test one-, three-, and twelve-month formation horizons
with one-month holds. They do not claim that this three-horizon majority, a
two-metal CFD subset, or equal fixed risk at both vote strengths is profitable,
frequent enough, neutral, or diversifying. Q02 and later gates are the only
strategy evidence.

## Risk

Q02-Q10 use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, split equally across the two ATR-normalized legs. Risk is
high: two-name concentration, residual common-metal and USD beta, industrial-
silver exposure, continuous-CFD roll and financing, gaps, legging, lot
granularity, false relative trends, hard-stop slippage, source-translation
risk, and post-publication decay may dominate the intended state. Market-
neutral construction does not establish portfolio decorrelation.

## Kill Criteria

- Retire on zero trades or fewer than five completed packages per full post-
  warm-up year.
- Fail on missing, nonconsecutive, or unsynchronized endpoints; wrong simple-
  return orientation or arithmetic average; incorrect rank signs or vote;
  entry with a tied component; repeated month attempt; non-opposite legs;
  aggregate-risk breach; persistent orphan; missing hard stop; invalid risk
  mode; or nondeterminism.
- Retire on nonpositive governed economics or later portfolio-correlation
  rejection.
- Do not rescue failure by changing a horizon, vote, tie threshold, direction,
  weighting, stop, hold, spread cap, retry policy, or carrier.

## Strategy Allowability Check

- [x] R1: tier-A peer-reviewed source with complete-read record; the three
  formation horizons and monthly hold are explicit.
- [x] R2: fixed synchronized endpoints, three average-return ranks, strict
  ties, vote, shared risk, stops, attempt state, rollover, and repair.
- [x] R3: registered `XAUUSD.DWX` and `XAGUSD.DWX` D1 logical-basket route; no
  external runtime data.
- [x] R4: deterministic simple-return/calendar/ATR arithmetic; no banned
  signal indicator, adaptive fit, grid, martingale, or pyramid.
- [x] Dedup: no exact collision; expected source and vote-family siblings were
  manually resolved.

## Framework Alignment

- no_trade: exact host/D1/EA/slot, locked inputs, news/Friday contract, magics,
  and cheap parameter guards.
- trade_entry: synchronized month-end reconstruction, three cross-sectional
  average-return ranks, majority vote, persisted attempt, spread/quote/ATR/
  stop checks, shared sizing, two opposite orders, and atomic repair.
- trade_management: owned-package validation, next-month close, stale close,
  and malformed-state repair before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Safety Boundary

This card authorizes only research, build, strict compile/Q01, one non-live
logical-basket `RISK_FIXED` backtest setfile and manifest, and one paced Q02
handoff. It does not authorize a manual backtest; live, demo, shadow, stress,
or optimization setfile; AutoTrading; `T_Live`; deploy or T_Live manifest;
portfolio admission; portfolio-gate edit; or correlation waiver.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-07 | initial source-bounded XAU/XAG momentum-rank vote card | G0 | APPROVED |
| v1-q01 | 2026-08-07 | deterministic V5 logical-basket build and strict compile | Q01 | PASS |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-07 | APPROVED | `decisions/2026-08-07_qm5_20260_xauxag_mom_vote_g0.md` |
| Q01 Build Validation | 2026-08-07 | PASS | `D:/QM/reports/framework/21/build_check_20260807_051735.json`; `D:/QM/reports/compile/20260807_051735/summary.csv` |
| Q02 Baseline Screening | 2026-08-07 | ENQUEUED | work item `247fc177-43a3-4bc2-aa66-9a10ed42c151` |
