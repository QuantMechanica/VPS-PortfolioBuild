---
ea_id: TBD
slug: fx-carry-unwind
type: strategy
strategy_id: SRC04_S11b
source_id: SRC04
source_citation: "Kathy Lien (2015), Day Trading and Swing Trading the Currency Market, 3rd ed., Chapter 18, pp. 153-160."
source_citations:
  - type: book
    citation: "Lien, Kathy. Day Trading and Swing Trading the Currency Market. 3rd ed., Wiley, 2015."
    location: "Chapter 18, pp. 153-160; local bounded extract strategy-seeds/sources/SRC04/raw/ch17-20_fundamental.txt lines 71-455"
    quality_tier: A
    role: primary
sources:
  - "[[sources/SRC04]]"
concepts:
  - "[[concepts/carry-unwind]]"
  - "[[concepts/safe-haven-currency]]"
  - "[[concepts/cross-sectional-ranking]]"
indicators:
  - "[[indicators/broker-swap]]"
  - "[[indicators/realized-volatility]]"
  - "[[indicators/atr-stop]]"
strategy_type_flags: [carry-direction, cross-sectional-ranking, vol-regime-gate, symmetric-long-short, atr-hard-stop, time-stop, multi-symbol-basket]
target_symbols: [AUDCHF.DWX, AUDJPY.DWX, GBPCHF.DWX, GBPJPY.DWX, NZDCHF.DWX, NZDJPY.DWX]
primary_target_symbols: [AUDCHF.DWX, AUDJPY.DWX, GBPCHF.DWX, GBPJPY.DWX, NZDCHF.DWX, NZDJPY.DWX]
signal_symbols: [EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX, NZDUSD.DWX, USDJPY.DWX, USDCHF.DWX, USDCAD.DWX]
markets: [forex]
period: D1
timeframes: [D1]
expected_trade_frequency: "One consumed decision per broker week; high-volatility gating and top-two ranking should produce roughly 4-12 two-leg packages/year, or about 2-6 entries/year per target symbol."
expected_trades_per_year_per_symbol: 4
g0_status: DRAFT
status: DRAFT
r1_track_record: PENDING_REVIEW
r2_mechanical: PENDING_REVIEW
r3_data_available: PENDING_REVIEW
r4_ml_forbidden: PENDING_REVIEW
pipeline_phase: G0
created: 2026-08-06
created_by: Research
last_updated: 2026-08-06
expected_pf: TBD
expected_dd_pct: TBD
risk_class: high
ml_required: false
single_symbol_only: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
hard_rules_at_risk: [magic_schema, risk_mode_dual, one_position_per_magic_symbol, kill_switch_coverage]
---

# FX Carry-Unwind Basket In High Global-FX Volatility

## Hypothesis

Crowded positive-carry FX positions can reverse sharply when risk aversion rises:
capital leaves the higher-yielding currency and returns to lower-yielding funding
currencies such as CHF and JPY. The proposed sleeve ranks the broker's currently
positive carry trades, then takes the opposite side of the two most carry-efficient
trades only when realized volatility is unusually high across the liquid FX-major
network.

This is a falsifiable Darwinex-native translation, not a claimed replication of
Lien. Lien identifies the carry-unwind direction and recommends bond-yield spreads
as one possible risk-aversion measure; the global realized-FX-volatility gate is a
QM substitution because the registered DWX matrix has no governed rate instrument.
No performance claim from the book transfers to this card.

## Source Boundary

The OWNER-approved SRC04 source was read over the complete bounded Chapter 18
extract (`strategy-seeds/sources/SRC04/raw/ch17-20_fundamental.txt`, lines
71-455). The load-bearing observations are:

- a carry trade buys a higher-rate currency and sells a lower-rate currency;
- high risk aversion causes investors to close or unwind carry positions;
- the unwind reverses the normal carry direction by buying the lower-rate
  currency and selling the higher-rate currency;
- rapid risk-aversion shifts historically benefited JPY and CHF; and
- leverage can magnify losses, so this port uses fixed-dollar risk and hard stops.

Lien describes the unwind as “buying the currency with the low interest rate and
selling the currency with the high interest rate” (Chapter 18, p. 157).

## Markets And Timeframe

- Traded universe: `AUDCHF.DWX`, `AUDJPY.DWX`, `GBPCHF.DWX`, `GBPJPY.DWX`,
  `NZDCHF.DWX`, and `NZDJPY.DWX`.
- Signal-only global-FX-volatility universe: `EURUSD.DWX`, `GBPUSD.DWX`,
  `AUDUSD.DWX`, `NZDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, and
  `USDCAD.DWX`.
- Base timeframe: `D1`; all calculations use completed bars.
- Decision cadence: once per broker week, on the first tradable D1 bar after
  the broker-week key changes.
- The six target crosses and seven signal majors are present in
  `framework/registry/dwx_symbol_matrix.csv`. Synchronized history and tester
  fills remain Q02 facts to prove, not assumptions in this card.

## Rules

### 1. Global-FX stress state

For each of the seven signal symbols on the last completed D1 bar:

1. Compute 21 closed-bar log returns.
2. Compute annualized realized volatility
   `rv21 = stdev(log_returns, 21) * sqrt(252)`.
3. Divide `rv21` by the median of that symbol's prior 252 completed rolling
   `rv21` observations, excluding the current observation.
4. Require at least five valid symbol ratios. The global stress ratio is the
   median of all valid ratios.

`HIGH_STRESS` is true when the global stress ratio is at least `1.50`.
Entry stays closed otherwise. The median-of-ratios construction prevents one
volatile pair or one missing series from defining the global regime.

### 2. Carry crowding rank

For every target cross, convert `SYMBOL_SWAP_LONG` and `SYMBOL_SWAP_SHORT`
through the symbol's declared `SYMBOL_SWAP_MODE`, tick value, tick size, and
contract metadata into expected account-currency cash per lot per ordinary
rollover day. Unsupported swap modes, non-finite metadata, or ambiguous
three-day-roll handling make that symbol ineligible; the EA must fail closed
rather than rank incomparable raw swap numbers.

Normalize each side by the cash value of ATR(20, D1) for one lot:

`carry_efficiency(side) = positive_daily_swap_cash(side) / atr20_cash_per_lot`.

For each target, retain only its higher positive-carry side. Rank eligible
targets by carry efficiency, descending, with symbol name as the deterministic
tie-break. The crowded carry cohort is the top two targets. If fewer than two
targets have positive, comparable carry, consume the weekly attempt and stay
flat.

### 3. Entry

On the first tradable D1 bar of a new broker week:

- persist the new week key before history, signal, spread, quote, stop, or
  order checks so a blocked attempt cannot retry every tick;
- require `HIGH_STRESS`;
- require at least five valid global-volatility ratios;
- require two eligible ranked target crosses;
- require each target's current spread to be no more than three times its
  median spread over the prior 20 completed D1 bars; and
- open the **opposite** of each selected target's positive-carry side.

Examples: if long `AUDJPY.DWX` is the favorable carry side, the unwind leg
sells `AUDJPY.DWX`; if short `GBPCHF.DWX` is the favorable carry side, the
unwind leg buys `GBPCHF.DWX`. Both package legs must be sized before the first
order is sent. A second-leg failure immediately closes the first leg and marks
the weekly attempt consumed.

### 4. Exit

- Recompute the global stress ratio on every new completed D1 bar.
- Close the complete package when the ratio is at or below `1.10`.
- Close the complete package after five completed D1 bars from entry.
- The standard framework Friday close remains enabled; no cross-week hold
  waiver is requested by this baseline.
- Each leg has a frozen `2.5 * ATR(20, D1)` hard stop from entry.
- If exactly one package leg remains open, close it immediately as orphan
  repair. Do not replace a stopped or missing leg during the same week.
- No take-profit, trailing stop, scale-in, partial close, or same-week re-entry.

## Risk

- Backtest contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Split the fixed package budget equally: `PORTFOLIO_WEIGHT=0.50` on each of
  the two selected legs. The combined intended initial stop loss is therefore
  `$1,000`, not `$2,000`.
- Later build work must create backtest setfiles only, each preserving the
  fixed-risk contract. This draft authorizes no live setfile.
- One position per registered magic/symbol; no grid, martingale, pyramiding,
  leverage multiplier, or adaptive sizing.
- The package participates only in high-volatility states, so gap and slippage
  risk are intrinsically elevated. Q05/P5 stress must test joint-leg slippage,
  missing-leg repair, and correlated stop losses.
- This card does not authorize `T_Live`, AutoTrading, a deploy manifest,
  portfolio admission, or any portfolio-gate change.

## Filters And State

- D1 closed bars only; never infer a signal from the forming bar.
- At least 273 completed D1 bars are required for each signal symbol used in
  the 21/252 volatility ratio.
- At least five of seven signal symbols and two of six target symbols must be
  valid at the decision point.
- Quotes, ATR, swap metadata, spread history, and magic-slot mappings must be
  valid before sizing.
- Standard V5 news, kill-switch, environment/risk-mode, and Friday-close
  guards remain active.
- The weekly attempt key and package state must survive terminal restart.

## Trade Management Rules

- One atomic two-leg package at a time for the EA.
- The two selected symbols retain their entry-time direction and frozen ATR
  stop for the package lifetime.
- A stopped leg causes immediate flattening of the surviving leg.
- A terminal restart reconstructs package membership from the EA's registered
  magic slots before evaluating a new entry.
- Entries are blocked while any owned target position or unresolved orphan
  exists.

## Parameters To Test

The Q02 baseline is locked as written. To limit Q04 overfit pressure, P3 may
vary only these predeclared axes:

| Parameter | Baseline | Bounded sweep |
|---|---:|---|
| `strategy_stress_entry_ratio` | 1.50 | 1.25, 1.50, 1.75 |
| `strategy_stress_exit_ratio` | 1.10 | 1.00, 1.10, 1.20 |
| `strategy_selected_legs` | 2 | 1, 2 |
| `strategy_max_hold_d1_bars` | 5 | 3, 5 |

The 21-day realized-volatility window, 252-observation baseline, median
aggregation, ATR(20), and carry-efficiency definition are structural and not
optimization axes. Any later change requires a versioned rebuild.

## Expected Behavior

- Long flat periods during normal FX volatility.
- Clusters of weekly packages during carry-unwind episodes.
- Roughly 4-12 packages per year across the EA and 2-6 entries per target
  symbol, with sparse calm years expected.
- High right-tail opportunity but high gap/slippage risk; fixed risk and atomic
  package repair bound implementation loss without guaranteeing economics.

## Reputable-Source And Allowability Evidence

- [ ] R1 review evidence: named long-standing FX author, Wiley book, precise
  chapter/page boundary, OWNER-approved SRC04 intake, and complete local
  bounded text reviewed.
- [ ] R2 review evidence: fixed weekly clock, fixed realized-volatility state,
  deterministic swap conversion/rank, opposite-side mapping, hard stops,
  hysteresis exit, and time exit.
- [ ] R3 review evidence: all required symbols are registered `.DWX` FX instruments;
  runtime uses MT5 OHLC, swap, contract, spread, quote, and position metadata
  only.
- [ ] R4 review evidence: arithmetic and fixed ranks only; no trained model, banned
  indicator, external runtime feed, grid, martingale, scale-in, or pyramiding.
- [ ] Low-frequency review evidence: at most one attempted package per broker week and entry
  only in the high-volatility regime.
- [ ] Governance review: OWNER and quality review remain required before allocation or
  build.

## Non-Duplicate Boundary

- `QM5_1127_menkhoff-carry-fxvol-filter` trades normal carry only when global
  FX volatility permits risk and stays flat in high volatility. This card is
  flat in normal volatility and trades the **reverse** of live broker carry in
  high volatility.
- `QM5_13023_ftq-audjpy-riskoff-short` is single-symbol AUDJPY technical
  momentum using SMA/Donchian state. This card has no SMA or Donchian input,
  ranks six crosses by broker carry, uses a seven-major volatility state, and
  owns an atomic two-leg package.
- `QM5_1193_qp-stress-usd-rebound` is a one-day long-USD basket triggered by
  simultaneous SP500/oil declines. This card reads neither index nor energy
  data and expresses CHF/JPY funding-currency repatriation instead of USD
  rebound.
- `QM5_10027`, `QM5_1091`, `QM5_10885`, and `QM5_1249` are positive-carry
  harvesters. This card never opens the favorable carry direction.
- Changing the stress regime to price trend, replacing broker swap with policy
  rates, or reducing the design to a single fixed pair would cross this card's
  identity boundary and require new review.

## Framework Alignment

- `no_trade`: week-attempt latch, symbol/timeframe guard, high-stress gate,
  warmup/breadth checks, comparable-swap guard, spread caps, quote validation,
  package-flat guard, and framework controls.
- `trade_entry`: cross-sectional carry-efficiency rank and atomic opposite-side
  two-leg entry with equal fixed-risk weights.
- `trade_management`: frozen per-leg ATR stops, package membership recovery,
  orphan flattening, and five-D1-bar age tracking.
- `trade_close`: stress-ratio hysteresis exit, hard stop propagation, orphan
  repair, time stop, and standard Friday close.

Hard-rule notes:

- `magic_schema`: six traded symbols require deterministic preallocated slots
  after approval; Research allocates none.
- `risk_mode_dual`: build validation must prove `RISK_FIXED=1000` and
  `RISK_PERCENT=0` in every backtest setfile.
- `one_position_per_magic_symbol`: atomic package logic may own two symbols,
  but never more than one position per registered magic/symbol.
- `kill_switch_coverage`: combined package exposure and orphan repair must stay
  visible to the framework kill switch.

## Kill Criteria

Reject or recycle the card if any of the following occurs:

- swap modes cannot be converted comparably without an external data file;
- synchronized signal breadth produces fewer than two entries per year per
  target on pooled Q02 history;
- the stress gate is always open, never opens, or depends materially on one
  signal symbol;
- Q02 cannot open and repair the complete two-leg package deterministically;
- pooled Q04 after-cost profit factor is below 1.0; or
- later analysis shows material identity overlap with an incumbent sleeve.

## Pipeline History

| version | date | rebuild reason | phase reached | verdict |
|---|---|---|---|---|
| v1 | 2026-08-06 | initial research extraction | G0 | DRAFT |

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-06 | DRAFT | this card |
| Q01 Build Validation | TBD | TBD | TBD |
| Q02 Baseline Screening | TBD | TBD | TBD |
| Q03 Parameter Sweep | TBD | TBD | TBD |
| Q04 Walk-Forward | TBD | TBD | TBD |
| Q05+ | TBD | TBD | TBD |

## Lessons Captured

- 2026-08-06: The buildable distinction from incumbent carry sleeves is the
  conjunction of a high global-FX-volatility state, broker-native carry rank,
  opposite-side entry, and atomic two-leg package; none is optional.
