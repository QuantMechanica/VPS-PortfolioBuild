---
card_schema_version: 2
ea_id: QM5_20185
slug: wti-win-bearfade
type: strategy
strategy_id: BURAKOV-MOP-WTI-WINBEAR-2026_S01
variant_id: BURAKOV-MOP-WTI-WINBEAR-2026_S01
source_id: BURAKOV-MOP-WTI-WINBEAR-2026
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20185_wti-win-bearfade_card.md
execution_contract_status: DRAFT
created: 2026-07-31
created_by: Research+Development
last_updated: 2026-07-31
source_authors: "Dmitry Burakov, Max Freidin, Yuriy Solovyev; Tobias J. Moskowitz, Yao Hua Ooi, Lasse Heje Pedersen"
strategy_mechanic: november-may-weekly-wti-long-only-when-completed-252d-return-is-negative
source_citation: "Burakov, Freidin and Solovyev (2018), International Journal of Energy Economics and Policy 8(2); Moskowitz, Ooi and Pedersen (2012), Journal of Financial Economics 104(2)."
source_citations:
  - type: peer_reviewed_open_access_paper
    citation: "Burakov, D., Freidin, M. and Solovyev, Y. (2018). The Halloween Effect on Energy Markets: An Empirical Study."
    location: "Complete governed review at strategy-seeds/sources/BURAKOV-WTI-HALLOWEEN-2018/source.md"
    quality_tier: B
    role: winter_long_regime
  - type: peer_reviewed_journal_paper
    citation: "Moskowitz, T. J., Ooi, Y. H. and Pedersen, L. H. (2012). Time Series Momentum."
    location: "Complete governed lineage at strategy-seeds/sources/MOP-TSMOM-2012/source.md"
    quality_tier: A
    role: completed_return_state
sources:
  - "[[sources/BURAKOV-MOP-WTI-WINBEAR-2026]]"
concepts:
  - "[[concepts/wti-winter-regime]]"
  - "[[concepts/negative-trend-counterfade]]"
  - "[[concepts/seasonal-state-interaction]]"
indicators:
  - "[[indicators/rolling-return]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, negative-trend-state, counterfade, long-only, weekly-entry, atr-hard-stop, friday-close-flatten, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: XTIUSD.DWX
symbol: XTIUSD.DWX
period: D1
timeframe: D1
timeframes: [D1]
expected_trade_frequency: "Approximately 5-14 completed weekly WTI packages/year when November-May overlaps a strictly negative completed 252-D1 return; Q02 must prove or retire the density."
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
q02_status: PENDING
review_focus: "Falsify whether Burakov's WTI November-May long survives specifically in a negative 252-D1 state and adds direct crude-oil exposure distinct from the certified XAU/SP500/NDX/XNG book."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency, friday_close, risk_mode_dual, enhancement_doctrine, cfd_futures_basis, restart_attempt_state, portfolio_correlation]
g0_approval_reasoning: "OWNER commodity/energy sleeve mission 2026-07-31: R1 PASS two peer-reviewed, completely reviewed governed source lineages; R2 PASS locked November-May weekly WTI long gated by strictly negative completed 252-D1 return, frozen ATR stop, Friday close, stale exit, and restart-safe consumed attempt; R3 PASS registered XTIUSD.DWX D1; R4 PASS deterministic native MT5 data only with no prohibited model, banned indicator, external feed, grid, martingale, scale-in, or pyramiding. Deterministic dedup CLEAN across 4,242 registry rows and 377 cards plus manual parent/neighbor resolution."
---

# QM5_20185 WTI Winter Negative-Trend Counterfade Long

## Hypothesis

Burakov, Freidin, and Solovyev document a November-May WTI winter premium.
Moskowitz, Ooi, and Pedersen provide a reproducible way to label WTI's slow
state from its own completed 12-month return. This card tests whether the
source-directed winter long persists specifically when the completed 252-D1
WTI return is negative.

This is a direct crude-oil counterfade whose calendar and information clock
differ from the certified XAU, SP500, NDX, and XNG book. Profitability,
decorrelation, certification, and portfolio admission are not claimed; Q02
and the unchanged downstream gates must establish them.

## Source traceability

The approved composite packet
`strategy-seeds/sources/BURAKOV-MOP-WTI-WINBEAR-2026/source.md` preserves the
two fully reviewed parent lineages and the current retrieval-policy evidence.
Burakov supplies the November-May WTI long direction. MOP supplies only the
completed 252-D1 state definition. Neither paper tests the negative-state
conjunction, a continuous CFD, weekly packages, the ATR stop, or QM portfolio
behavior.

Runtime reads only registered Darwinex MT5 price, calendar, execution,
position, deal, and framework state. No external source is queried by the EA.

## Non-duplicate decision

The deterministic pre-allocation check returned `CLEAN` for slug
`wti-win-bearfade`, strategy ID
`BURAKOV-MOP-WTI-WINBEAR-2026_S01`, and the exact mechanic in frontmatter.

- `QM5_20135_wti-winter-trend` sells the admitted negative state and renews
  monthly; this card buys it in weekly Friday-flat packages.
- `QM5_20015_wti-halloween-winter` is unconditional and reads no price state.
- `QM5_20046_wti-halloween-ls` maps season directly to direction.
- `QM5_12963_wti-winter-exhaust` is a short price-stretch fade.
- `QM5_20141` and `QM5_20182` use the disjoint July-November short window.
- `QM5_12603_wti-tsmom12m` follows the sign year-round and sells this card's
  negative state.
- `QM5_12567_cum-rsi2-commodity` is short-horizon oscillator pullback logic.

The fixed winter gate, negative slow state, long direction, weekly consumed
attempt, and Friday-flat lifecycle are jointly load-bearing.

## Markets, timeframe, and cadence

- Exact host and traded symbol: `XTIUSD.DWX`.
- Timeframe: D1.
- Magic slot: 0; allocated magic `201850000`.
- Decision clock: first tradable D1 bar of each Monday-anchored broker week.
- Active entry months: November, December, January, February, March, April,
  and May.
- Direction: long only when completed 252-D1 log return is strictly negative.
- Expected cadence: approximately 5-14 completed packages/year; retire below
  five/year after warm-up.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

## Rules

The following rules are the complete authorized baseline. No parameter sweep
or post-result rescue is authorized.

## 4. Entry Rules

1. Require exact `XTIUSD.DWX`, D1, EA 20185, magic slot 0, and every baseline
   input locked to its declared value.
2. Evaluate only on the first tradable D1 bar of a new broker-calendar week.
3. Require the current broker month to be November through May inclusive.
4. Persist the Monday-anchored week key as consumed before history, state,
   spread, quote, news, stop, or order gates. Never retry the week.
5. Reject when an entry deal or EA-owned position already exists for the week.
6. Read completed D1 closes at shifts 1 and 253 and calculate
   `ln(Close[1] / Close[253])`.
7. Permit one BUY only when that return is strictly negative. Exact zero,
   positive return, insufficient history, or invalid arithmetic remains flat.
8. Require completed ATR(20), spread from zero through 1,500 points, and a
   valid executable BUY price.
9. Attach one frozen hard stop `3.0 * ATR(20)` below entry. No take-profit.
10. Open at most one position for magic `201850000`; no pending order,
    same-week retry, scale-in, or second entry is permitted.

## 5. Exit Rules

1. Framework Friday close at broker hour 21 is the ordinary exit.
2. If Friday close did not complete, close an older-week package on the first
   D1 bar of the next broker week before evaluating a replacement.
3. Close immediately on a D1 management pass outside November-May.
4. Close immediately if an unexpected short position exists for the magic.
5. Close after seven elapsed calendar days as a stale guard.
6. The frozen broker stop and framework kill switch remain authoritative.
7. No target, state-reversal exit, trail, break-even move, partial close, or
   discretionary exit is authorized.

## 6. Filters (No-Trade Module)

- Fail closed for wrong symbol, timeframe, EA ID, slot, unlocked input,
  invalid week key, missing completed history, non-positive close, invalid
  logarithm, non-negative state, unavailable ATR, excessive spread, invalid
  quote or stop, consumed week, same-week deal, or owned position.
- Lock both news axes OFF for the native-price Q02 baseline. Lifecycle exits
  are never delayed by entry-only gates.
- Require Friday close enabled at broker hour 21.
- Runtime may not read a futures curve, inventory release, volume, options,
  external calendar, file feed, API, analyst forecast, or model output.

## 7. Trade Management Rules

- Preserve the original broker stop; never move it.
- Close older-week, outside-window, wrong-side, or seven-day-stale positions
  before entry-only gates.
- Maintain at most one EA-owned position and one consumed decision per week.
- Restart recovery combines terminal-persistent state with position/deal
  history; future-dated tester state is cleared at initialization.
- No grid, martingale, pyramid, partial close, scale-in, randomness, or
  adaptive fit.

## Parameters to test

| parameter | default | authorized values | role |
|---|---:|---|---|
| `strategy_start_month` | 11 | [11] | first winter month |
| `strategy_end_month` | 5 | [5] | final winter month |
| `strategy_momentum_lookback_d1` | 252 | [252] | completed state horizon |
| `strategy_min_abs_return_pct` | 0.0 | [0.0] | strict negative sign |
| `strategy_atr_period` | 20 | [20] | completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.0 | [3.0] | frozen hard-stop distance |
| `strategy_max_hold_days` | 7 | [7] | weekly stale guard |
| `strategy_max_spread_points` | 1500 | [1500] | entry spread ceiling |

## Author claims

Burakov et al. report historical WTI November-May strength. MOP reports broad
time-series momentum. Neither claims that this negative-state interaction,
continuous CFD carrier, weekly package, risk controls, or portfolio objective
is profitable. No source return, hit rate, PF, drawdown, count, or correlation
estimate is imported.

## Risk

Q02 uses exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Position size derives from executable distance to the
frozen ATR stop. WTI gaps, long-side crash continuation during negative slow
states, continuous-CFD roll/basis, financing, winter seasonality decay, and
conditional density are first-order kill risks.

## Kill criteria

- Retire on zero trades or fewer than five completed packages/year on average.
- Fail on any short entry, entry outside November-May, entry without a
  strictly negative completed 252-D1 return, same-week retry, hold beyond
  seven days, missing Friday close, missing hard stop, invalid risk mode,
  nondeterminism, or any governed PF/DD failure.
- Do not rescue failure by changing season, state sign, return horizon, entry
  clock, direction, stop, hold, spread cap, or retry policy.
- Later gates must reject the sleeve if it does not diversify the certified
  book. No correlation waiver is authorized.

## Strategy allowability check

- [x] R1: two peer-reviewed named-author lineages with complete durable
  repository reviews.
- [x] R2: fixed calendar gate, completed-return sign, weekly attempt state,
  hard stop, Friday close, and stale exit.
- [x] R3: registered `XTIUSD.DWX` D1 history and native inputs only.
- [x] R4: deterministic calendar/OHLC/logarithm/ATR arithmetic; no prohibited
  runtime component.
- [x] Dedup: deterministic CLEAN plus manual parent/neighbor resolution.

## Framework alignment

- no_trade: exact host/D1/EA/slot, locked input, history, state, spread,
  quote, stop, consumed-week, and owned-position guards.
- trade_entry: first weekly D1 bar in November-May, negative completed 252-D1
  state, one BUY, and frozen ATR stop.
- trade_management: older-week, outside-window, wrong-side, and seven-day
  stale exits before entry gates.
- trade_close: framework Friday close, broker stop, position-close helper,
  and kill switch.

## Safety boundary

This approval covers one card, deterministic registries, one EA build, strict
compile, one `RISK_FIXED` backtest setfile, and one paced Q02 enqueue. It does
not authorize a manual backtest, live setfile, AutoTrading, `T_Live`, deploy
manifest change, portfolio admission, portfolio-gate change, KPI claim, or
correlation waiver.

## Pipeline history

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-07-31 | source-backed winter negative-state counterfade card | G0 | APPROVED |
| v1-q02 | 2026-07-31 | strict build recorded and paced baseline enqueued | Q02 | ACTIVE |

## Pipeline phase status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-31 | APPROVED | this card and governed source packet |
| Q01 Build Validation | 2026-07-31 | PASS | `D:/QM/reports/framework/21/build_check_20260731_121933.json` |
| Q02 Baseline Screening | 2026-07-31 | ACTIVE | work item `7639ee30-e765-4211-b276-97a779730a90` |
