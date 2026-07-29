---
card_schema_version: 2
ea_id: QM5_20182
slug: wti-sum-bull
type: strategy
strategy_id: EWALD-MOP-WTI-SUMBULL-2026_S01
variant_id: EWALD-MOP-WTI-SUMBULL-2026_S01
source_id: EWALD-MOP-WTI-SUMBULL-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20182_wti-sum-bull_card.md
execution_contract_status: DRAFT
created: 2026-07-29
created_by: Research+Development
last_updated: 2026-07-29
source_authors: "Christian-Oliver Ewald, Erik Haugom, Gudbrand Lien, Stale Stordal, Yuexiang Wu; Tobias J. Moskowitz, Yao Hua Ooi, Lasse Heje Pedersen"
strategy_mechanic: july-november-weekly-wti-short-only-when-completed-252d-return-is-positive
source_citation: "Ewald et al. (2022), Energy Economics 115; Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104."
source_citations:
  - type: peer_reviewed_paper
    citation: "Ewald, C.-O., Haugom, E., Lien, G., Stordal, S., and Wu, Y. (2022). Trading time seasonality in commodity futures: An opportunity for arbitrage in the natural gas and crude oil markets? Energy Economics 115, 106324."
    location: "Full paper, especially Section 5.1; DOI https://doi.org/10.1016/j.eneco.2022.106324; governed packet strategy-seeds/sources/EWALD-WTI-TRDTIME-2022/source.md"
    quality_tier: A
    role: seasonal_regime
  - type: peer_reviewed_paper
    citation: "Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012). Time Series Momentum. Journal of Financial Economics 104(2), 228-250."
    location: "DOI https://doi.org/10.1016/j.jfineco.2011.11.003; governed packet strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: slow_state
sources:
  - "[[sources/EWALD-MOP-WTI-SUMBULL-2026]]"
concepts:
  - "[[concepts/wti-trading-time-seasonality]]"
  - "[[concepts/time-series-momentum]]"
  - "[[concepts/seasonal-counterfade-interaction]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [trading-time-seasonality, positive-trend-state, counterfade, short-only, weekly-entry, atr-hard-stop, friday-close-flatten, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 5-14 completed weekly WTI packages/year when July-November overlaps a strictly positive completed 252-D1 return; Q02 must prove or retire the density."
expected_trades_per_year_per_symbol: 9
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
q02_status: QUEUED_FACTORY_OFF
review_focus: "Falsify whether Ewald's WTI July-November short persists in the mutually exclusive positive 252-D1 state and supplies direct crude-oil exposure distinct from the certified XAU/SP500/NDX/XNG book."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency, friday_close, risk_mode_dual, enhancement_doctrine, cfd_futures_basis, restart_attempt_state, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission 2026-07-29: R1 PASS two peer-reviewed, fully reviewed governed source lineages; R2 PASS locked July-November weekly WTI short gated by strictly positive completed 252-D1 return, frozen ATR stop, Friday close, stale exit, and restart-safe consumed attempt; R3 PASS registered XTIUSD.DWX D1; R4 PASS deterministic native MT5 data only with no trained model, banned indicator, external feed, grid, martingale, scale-in, or pyramiding. Deterministic dedup CLEAN across 4,239 registry rows and 375 cards plus manual parent/neighbor resolution."
---

# QM5_20182 WTI Summer Positive-Trend Counterfade Short

## Hypothesis

Ewald et al. document a July-to-December WTI trading-time effect in
fixed-maturity futures. Moskowitz, Ooi, and Pedersen provide a transparent way
to identify WTI's slow state from its own completed 12-month return. This card
tests whether the source-directed July-November short persists specifically
when WTI's completed 252-D1 return is positive.

The positive state is mutually exclusive with `QM5_20141_wti-sumtrend`, which
requires a negative return. The candidate is a direct crude-oil counterfade
whose calendar and information clock differ from the certified XAU, SP500,
NDX, and XNG book. Profitability and decorrelation are not claimed; Q02 and
the unchanged downstream gates must establish both.

## Source traceability

The approved composite packet
`strategy-seeds/sources/EWALD-MOP-WTI-SUMBULL-2026/source.md` preserves the two
completely reviewed parent lineages. Ewald et al. supply the WTI seasonal short
direction; Moskowitz, Ooi, and Pedersen supply the completed 252-D1 own-return
state. Neither paper tests this conjunction, a continuous CFD, weekly tranches,
the ATR stop, or QM portfolio behavior.

No source statistic is imported. Runtime reads only registered Darwinex MT5
price, calendar, execution, position, deal, and framework state.

## Non-duplicate decision

The deterministic pre-allocation check returned `CLEAN` for slug
`wti-sum-bull`, strategy ID `EWALD-MOP-WTI-SUMBULL-2026_S01`, and mechanic
`July-November weekly WTI short only when completed 252-D1 return is positive`.

- `QM5_20141_wti-sumtrend` trades only the disjoint negative 252-D1 state.
- `QM5_13107_wti-juldec-short` and `QM5_20093_wti-summer-short` are
  unconditional seasonal shorts.
- `QM5_12603_wti-tsmom12m` follows the return sign year-round and would buy in
  this card's positive state.
- `QM5_20136_wti-caltrend` uses adaptive same-calendar-month history and 63-D1
  agreement, not this fixed source window and positive 252-D1 state.
- `QM5_12567_cum-rsi2-commodity` is an XNG short-horizon oscillator pullback.

The fixed season, positive slow state, weekly attempt clock, and short
direction are jointly load-bearing. Removing the state recreates an existing
unconditional parent; changing the sign recreates QM5_20141.

## Markets, timeframe, and cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `201820000`.
- Decision clock: first tradable D1 bar of each Monday-anchored broker week.
- Active entry months: July, August, September, October, and November.
- Direction: short only when the completed 252-D1 log return is strictly
  positive.
- Expected cadence: approximately 5-14 completed packages/year; retire below
  five/year after warm-up.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. No parameter sweep
or post-result rescue is authorized.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, D1, EA 20182, magic slot 0, and every baseline
   input locked to its declared value.
2. Evaluate only on the first tradable D1 bar of a new broker-calendar week.
3. Require the current broker month to be July through November inclusive.
4. Derive a stable Monday-anchored week key and persist it as consumed before
   history, signal, spread, quote, news, stop, or order gates. Never retry the
   week after a flat signal, rejection, restart, stop, or blocked gate.
5. Reject when an entry deal or EA-owned position already exists for the week.
6. Read completed D1 closes at shifts 1 and 253 and compute
   `ln(Close[1] / Close[253])`.
7. Permit one SELL only when the completed return is strictly positive. Exact
   zero, a negative return, insufficient history, or invalid arithmetic stays
   flat for the consumed week.
8. Require completed ATR(20), a non-negative spread no greater than 1,500
   points, and a valid executable SELL price.
9. Attach one frozen hard stop `3.0 * ATR(20)` above entry, normalized by V5
   stop rules. There is no take-profit.
10. Open at most one position for magic `201820000`; no pending order,
    same-week retry, scale-in, or second entry is permitted.

## 5. Exit Rules

1. Framework Friday close at broker hour 21 is the ordinary exit.
2. If Friday close did not complete, close an older-week package on the first
   D1 bar of the next broker week before considering replacement risk.
3. Close immediately on a D1 management pass outside July-November.
4. Close immediately if an unexpected long position exists for the magic.
5. Close after seven elapsed calendar days as a stale-position guard.
6. The frozen server-side hard stop and framework kill switch remain
   authoritative.
7. No target, signal-reversal exit, trailing stop, break-even move, partial
   close, or discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, EA ID, slot, unlocked input,
  invalid week key, missing completed history, non-positive close, invalid
  logarithm, non-positive state, unavailable ATR, excessive spread, invalid
  quote, invalid stop, consumed week, same-week deal, or owned position.
- Lock news temporal and compliance axes OFF for this native-price Q02
  baseline. Lifecycle exits are never delayed by entry-only gates.
- Require Friday close enabled at broker hour 21.
- Runtime may not read a futures curve, inventory release, volume, options,
  external calendar, file feed, API, analyst forecast, or trained output.
- No entry is permitted after the broker week has been consumed, even when a
  later tick would pass a previously blocked gate.

## 7. Trade Management Rules

- Preserve the original broker stop; do not move it.
- Close an older-week, outside-window, wrong-side, or seven-day-stale position
  before any entry-only gate is evaluated.
- Maintain at most one EA-owned position and one consumed decision per broker
  week. Restart recovery combines the persistent marker with position and deal
  history; a future-dated tester marker is cleared at initialization.
- No grid, martingale, pyramid, partial close, scale-in, randomness, or
  adaptive fit.

## Parameters to test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_start_month` | 7 | [7] | first Ewald short-window month |
| `strategy_end_month` | 11 | [11] | last entry month before December cover |
| `strategy_momentum_lookback_d1` | 252 | [252] | completed own-return horizon |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] | strict positive sign; no deadband |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 7 | [7] | stale guard around weekly lifecycle |
| `strategy_max_spread_points` | 1500 | [1500] | WTI entry spread ceiling |

## Kill criteria

- Retire on zero trades or fewer than five completed packages/year on average.
- Fail on any long entry, entry outside July-November, entry without a
  strictly positive completed 252-D1 return, same-week retry, hold beyond
  seven days, missing Friday close, missing hard stop, invalid risk mode, or
  nondeterminism.
- Do not rescue failure by changing the season, state sign, return horizon,
  entry clock, direction, stop, hold, spread cap, or retry policy.
- Later gates must reject the sleeve if its realized return stream does not
  diversify the certified book. No correlation waiver is authorized.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position size comes from executable distance to the
frozen ATR stop. WTI gaps, short squeezes during positive slow trends,
continuous-CFD roll/basis, financing, seasonal decay, and conditional density
are first-order kill risks.

No live setfile, live risk mode, deploy manifest, `T_Live` action, AutoTrading
change, portfolio-gate edit, or portfolio admission is authorized.

## Strategy allowability check

- [x] R1: two peer-reviewed named-author journal lineages with completely
  reviewed durable repository packets.
- [x] R2: fixed calendar gate, completed-return sign, weekly attempt state,
  hard stop, Friday close, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 history and native V5 inputs only.
- [x] R4: deterministic calendar/OHLC/logarithm/ATR arithmetic; no prohibited
  runtime component.
- [x] Dedup: deterministic CLEAN plus manual parent and neighbor resolution.

## Framework alignment

- no_trade: exact host/D1/EA/slot, locked input, history, state, spread,
  quote, stop, consumed-week, and owned-position guards.
- trade_entry: first weekly D1 bar in July-November, positive completed
  252-D1 state, one SELL, and frozen ATR stop.
- trade_management: older-week, outside-window, wrong-side, and seven-day
  stale exits before entry gates.
- trade_close: framework Friday close, broker hard stop, position-close helper,
  and kill switch.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-29 | initial source-backed WTI summer positive-state counterfade card and strict build | Q01 | PASS |
| v1 | 2026-07-29 | initial targeted sweep refused by FACTORY_OFF; canonical build record then enqueued one pending Q02 row without dispatch | Q02 | QUEUED_FACTORY_OFF |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-29 | APPROVED | this card and governed source packet |
| Q01 Build Validation | 2026-07-29 | PASS | strict build gate: 0 errors, 0 warnings, all static checks PASS |
| Q02 Baseline Screening | 2026-07-29 | QUEUED_FACTORY_OFF | work item `60181936-0403-49bc-b221-dda4f35eb584`; pending, unclaimed, attempt 0 |
