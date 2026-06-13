---
ea_id: QM5_12546
slug: katz-seasonal-crossover-stoch-confirmation-stop-d1
type: strategy
source_id: katz-encyclopedia-2000-ch8
sources:
  - "[[sources/katz-mccormick-encyclopedia-trading-strategies]]"
concepts:
  - "[[concepts/seasonality]]"
  - "[[concepts/stochastic-confirmation]]"
  - "[[concepts/momentum-crossover]]"
indicators:
  - "[[indicators/seasonal-series]]"
  - "[[indicators/stochastic]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Katz & McCormick (2000), The Encyclopedia of Trading Strategies, McGraw-Hill, Ch.8 (Seasonality), pp. 185-189, Tests 7-9 (crossover-with-confirmation model), Table 8-3. IS 1985-1995 / OOS 1995-1998 split, $15/round-turn costs. OOS avg trade $1,677 (44% wins, 19.6% annualized return) — strongest of all seasonal model variants tested. Trade count: 292 IS, 121 OOS."
r2_mechanical: PASS
r2_reasoning: "Strategy has fully specified, deterministic directional entry and exit rules (per-date seasonal series, SMA crossover, stochastic confirmation gate, stop entry, SES exit); R2 rejects only pure-discretion strategies, not complex-but-mechanical ones."
r3_data_available: PASS
r3_reasoning: "XAUUSD.DWX is available as a precious-metals proxy for Katz's best markets; R3 permits porting even when source markets (Silver, Palladium, Lumber) have no DWX equivalent — ≥1 testable DWX instrument suffices."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed seasonal averaging (equal-weighted across years), fixed SMA(15) crossover, fixed %K thresholds; no ML."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 8
expected_pf: 1.35
expected_dd_pct: 18
last_updated: 2026-06-12
g0_approval_reasoning: "G0 2026-06-12 Claude (library-mining task 7143e208): DEDUP = NEW. Pool has ~18 seasonality/calendar cards, all based on event-driven effects (FOMC, options expiry, pre-holiday, turn-of-month) or composite seasonal indexes. None uses Katz's adaptive per-date momentum crossover with stochastic confirmation. Delta: (a) per-date seasonal average (each calendar date has its own seasonal momentum from ≥6 prior years); (b) SMA crossover on the integrated seasonal pseudo-price (signal fires when seasonal momentum trend changes, not when a calendar date arrives); (c) Fast %K stochastic < 25 confirmation gate (requires market price to also confirm the expected seasonal bottom). The combination produces the strongest OOS result in Ch.8. R2 CONDITIONAL flagged — Codex must implement the seasonal series carefully to avoid lookahead contamination. High complexity P1 task."
---

# Katz Seasonal Crossover with Stochastic Confirmation + Stop Entry (D1)

## Source
- Katz, J. & McCormick, D. (2000), "The Encyclopedia of Trading Strategies", McGraw-Hill,
  Ch.8 (Seasonality), pp. 185-189, Tests 7-9, Table 8-3 (crossover-with-confirmation model).
- OWNER library copy; text cache `D:/QM/strategy_farm/source_cache/katz-mccormick-encyclopedia-2000.txt`.
- IS 1985-1995: avg trade $846, 41% win, 5.8% return-on-account.
- OOS 1995-1998: avg trade $1,677, 44% win, 19.6% return-on-account.
- OOS outperformed IS — the strongest OOS result across ALL seasonal model variants tested in Ch.8.

## Dedup Verdict
NEW. Existing seasonal cards are event-driven (specific dates: FOMC, options expiry, pre-holiday). None computes a continuous per-date seasonal momentum series and applies an SMA crossover to it with stochastic confirmation. The Stochastic gate (requiring market price to also be near its recent bottom before entering) is the additional constraint that elevates OOS performance vs simpler seasonal models.

## Market Universe
- XAUUSD.DWX — precious metals proxy for Katz's best markets (Silver, Palladium)
- Note: Lumber, Unleaded Gasoline, Coffee (Katz's other best markets) have no DWX equivalent. If GDAXI.DWX is available, it is a secondary candidate as equity-index proxy for NYFE.

## Timeframe
D1. Long warm-up period required (minimum 6 years of D1 history before first trade valid).

## Seasonal Series Algorithm (for Codex — high-priority implementation spec)

### Step 1: Per-Date Seasonal Momentum
For each trading bar at time `T` (date `D_M_Y`):
1. Identify calendar date components: month `M`, day of month `D` (or day-of-year `DOY`).
2. For each of the prior `N_years` years (default N_years=10, minimum 6): find the bar closest to the same calendar date.
3. For each such past-year bar at time `t_k`, compute ATR-normalized 1-day momentum: `mom_k = (Close[t_k] - Close[t_k+1]) / ATR(20, t_k)`.
4. Average the N_years momentum values: `seasonal_mom[T] = mean(mom_k for k=1..N_years)`.
5. Integrate: `seasonal_price[T] = seasonal_price[T-1] + seasonal_mom[T]` (cumulative sum, reset at year start to avoid drift).
- **Lookahead safety:** only bars with `t_k < T - 365` (from prior years) are used — no future data contamination.

### Step 2: Seasonal MA Crossover
- Compute `seasonal_SMA[T] = SMA(seasonal_price, period=15)` with `disp=7` (displacement: shift SMA 7 bars into the future to compensate for lag — acceptable since seasonal values are based on ≥1-year-old data, per Katz p.187).
- **LONG crossover signal:** `seasonal_price[0] > seasonal_SMA[0]` AND `seasonal_price[1] <= seasonal_SMA[1]` (seasonal pseudo-price crossed above its SMA from below).
- **SHORT crossover signal:** mirror.

### Step 3: Stochastic Confirmation Gate
- Fast Stochastic %K(5,3): `iStochastic(NULL, PERIOD_D1, 5, 3, 3, MODE_SMA, 0, MODE_MAIN, 0)`.
- **LONG gate:** `%K < 25` at time of crossover signal.
- **SHORT gate:** `%K > 75`.
- Both seasonal crossover AND stochastic gate must fire on the same bar.

### Step 4: Entry
- On confirmation: place **STOP order** 1 tick above `High[0]` (long) or below `Low[0]` (short).
- Stop valid for 3 D1 bars; cancel if unfilled.
- Rationale: stop confirms market price is moving in the expected seasonal direction before fill.

## Exit (SES — Katz Standard Exit Strategy)
- **Money-management stop:** entry -(long) `1.0 × ATR(50, D1)`.
- **Profit target:** entry +(long) `4.0 × ATR(50, D1)`.
- **Time exit:** close on close of bar 10 after entry.

## Risk
RISK_FIXED backtest / RISK_PERCENT live; 1.0% per trade. Warm-up: minimum 6 years of D1 history in the tester (start date must be at least 2012-01-01 for a 2018+ test start).

## Falsification
A/B vs same setup WITHOUT the stochastic confirmation gate (seasonal crossover only, no %K filter). If the stochastic gate does not improve performance, its incremental value is zero — the seasonal series alone drives the edge.

## Implementation Warning for Codex
This is the most complex EA in the library-mining queue. The seasonal series construction (Step 1) requires precomputing `N_years × all_bars` historical lookups in OnInit. For a 20-year D1 history and 10 years of reference data, this is ~5,000 bars × 10 years × ~250 lookups = compute-intensive. Recommended approach: precompute the entire seasonal series in `OnInit` and store in a buffer; do not recompute on each bar. Alternative: use a simplified seasonal series based on day-of-year average momentum (one-dimensional lookup table), which is faster and close enough for initial testing.
