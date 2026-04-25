---
title: Seasonality, Trend-following, and Mean Reversion — Bitcoin adaptation to XAUUSD + indices
slug: seasonality-trend-mr-bitcoin
source_url: https://paperswithbacktest.com/strategies/seasonality-trend-following-and-mean-reversion-in-bitcoin
source_paper_url: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4081000
source_paper_title: Seasonality, Trend-following, and Mean reversion in Bitcoin
source_paper_authors: Padysak M., Vojtko R.
source_paper_year: 2022
asset_class: commodity+index
timeframe: D1
suitability: GO
sm_id_assigned:
pipeline_status: research
---

## 1. Economic Thesis

Padysak & Vojtko (2022) document three coexisting anomalies in Bitcoin that our adaptation hypothesises to generalise to liquid risk assets traded against USD — XAUUSD and major equity indices (GDAXI, NDX, WS30):

1. **Session-close seasonality.** Returns cluster in a narrow window around the NYSE close. In BTC the effect is extractable by holding only 21:00–23:00 UTC; in TradFi the analogous bucket is the late-session / post-close drift on the US cash day.
2. **Trend persistence at local maxima.** When price prints a new local N-day high it tends to continue higher for a handful of days. This is a short-horizon momentum/breakout effect, not a long-horizon trend-follow.
3. **Mean reversion at local minima.** Conversely, when price prints a new local N-day low it tends to bounce (post-drawdown rebound).

The three effects are *orthogonal in time*: a price cannot simultaneously be a 10-day MAX and a 10-day MIN, and the seasonal window is a time-of-day gate independent of price level. The authors therefore combine them additively.

**Why this edge might survive on XAUUSD / indices:**

- The NYSE-close clustering is documented across multiple risk-asset classes (index futures end-of-day drift, gold London-fix-to-NY-close behaviour). BTC inherits it via correlation to risk sentiment after 2020; gold and indices have it mechanically.
- N-day high/low continuation-vs-reversion asymmetry is a known short-horizon microstructure effect (inventory/stop clustering). Well documented on SPX futures and gold.

## 2. Failure Hypothesis (Pipeline V2.1 G0 gate)

The edge breaks if any of the following become true:

- **Regime shift in intraday flow structure.** If NYSE-close rebalancing flows migrate to open or mid-session (e.g. more ETF flow concentration at 15:50 ET close vs 21:00 UTC 2h window), the session-seasonality leg loses its anchor. Monitored via: close-of-day return share vs rest-of-day return share; reject if ratio drifts outside ±30% of DEV window average.
- **Trend/MR asymmetry inversion.** If 10-day highs start reverting and 10-day lows start continuing (bear regime / forced-liquidation regime), the two price-gated legs flip sign simultaneously. Detectable via rolling 252-day win-rate on each leg; kill-switch if both legs fall below 48% for 60 consecutive trading days.
- **Vol crush.** Strategy depends on non-trivial daily range to produce the 2h close drift and N-day extremes. If realised D1 ATR falls below 30% of DEV-window median for 90 days, expected edge per trade shrinks below round-trip costs.
- **Bitcoin-only artefact.** The paper's thesis is BTC-specific (21:00 UTC coincides with BTC's pre-Asia liquidity gap; crypto never closes). On XAUUSD/indices the analogous window is the 30 min around cash close (20:30–21:00 UTC winter / 19:30–20:00 UTC summer). If the seasonal leg shows zero edge on the TradFi version, the thesis failed transfer and only the price-extreme legs remain — that is still a valid strategy but distinct from the source paper and must be re-baselined.

## 3. Entry Rules

Strategy is a composite of **three independent sub-signals** combined long-only (the paper is long-only — no short on the MAX/MIN legs). On D1, each bar evaluates:

### Sub-signal A — Session-close seasonality (D1 proxy)

On D1 timeframe the original 2h window is not directly addressable; we implement a D1-level proxy: **enter long on Bar-Open if yesterday's Close printed within the last 30 minutes of the NYSE cash session.** For MT5 this reduces to: on every D1 bar, enter long at bar-open if the previous D1 close was a valid US-cash-session close (weekday, not a US holiday placeholder).

Parameter: `EnableSeasonalityLeg` (bool, default `true`).

### Sub-signal B — Trend-follow at local maximum

On the current completed D1 bar `t`, compute `MAX_N = max(High[t-N+1 .. t])`.
**Long entry at Bar-Open[t+1] if `Close[t] == MAX_N` (i.e. today closed at or above the N-bar high).**

Parameter: `MaxLookback_N` (int, default `10`; search grid in P3: `{10, 15, 20, 30, 40, 50}` — paper found shortest best).

### Sub-signal C — Mean-revert at local minimum

Symmetric: `MIN_N = min(Low[t-N+1 .. t])`.
**Long entry at Bar-Open[t+1] if `Close[t] == MIN_N`.**

Parameter: `MinLookback_N` (int, default `10`; shared with `MaxLookback_N` unless P3 decouples them).

### Composition

If any of A / B / C fires on the same bar, a single long position is opened (not stacked). If a position is already open, the entry is suppressed but the hold-clock is **reset** to the longest remaining exit horizon across the currently-triggered signals.

## 4. Exit Rules

| Trigger | Rule |
|---|---|
| Time-stop (A) | Close at next D1 bar-open (1-day hold). |
| Time-stop (B) | Close `HoldDays_Max` bars after entry (default `5`). |
| Time-stop (C) | Close `HoldDays_Min` bars after entry (default `3`). |
| Hard SL | `ATR(14)[entry] * 3.0` below entry price (configurable `StopLossATRMult`, default `3.0`). |
| Hard TP | None (paper is time-stop-only; TP kills the MR bounce and the trend continuation). |
| Breakeven | None in V1. Optional V2 enhancement: move SL to break-even after `HoldDays/2`. |
| End-of-week flatten | `FlattenOnFriday` optional param (default `false`); if `true`, close any open position at Friday D1 bar-close to avoid weekend gap (indices/gold only — irrelevant for FX). |

Rationale: the source paper's exit is pure time-stop (hold N days). The ATR hard-stop is added for FTMO compliance (max DD per trade) per Hard Rule 6; it is wide enough (3×ATR) that it fires only on tail events.

## 5. Position Sizing

Per Hard Rule 6, every EA supports both:

- `RISK_PERCENT` — percent-of-equity risk per trade (live-deploy default 0.50%, configurable).
- `RISK_FIXED` — fixed $1,000 risk per trade (DEV baseline per `feedback_fixed_risk_methodology`).

Position size: `lots = RiskAmount / (StopLossDistance * TickValuePerLot)` where `StopLossDistance = ATR(14) * StopLossATRMult`. Lots rounded down to broker `lotStep`, clipped to `[minLot, maxLot]`. No pyramiding — one position per symbol.

Magic number: `SM_<id>*10000 + symbol_slot` per Hard Rule 8 / `feedback_deploy_magic_numbers`.

## 6. Required Indicators / Data

All MT5-native — no exotic data, Hard Rule 12 compliant:

| Indicator / data | MT5 source | Notes |
|---|---|---|
| N-bar High / Low | `iHigh` / `iLow` buffers over window `N` | Core signal. |
| Bar close time | Chart D1 bars (Darwinex server time ≈ EET) | For seasonality leg gate. |
| US holiday calendar | Static CSV in `Include/FTMO/us_holidays.csv` (or existing holiday module if present) | Only needed for Sub-signal A; skip entries when prior D1 close was a half-day/holiday. CTO to confirm availability in base framework. |
| ATR(14) | `iATR` D1 | Stop sizing. |
| Tick data | Darwinex native D1 (Model 4 Every Real Tick per Hard Rule 6 / `feedback_always_model4`) | No external API. |

**Universe (Darwinex .DWX tick-data symbols):**
- Commodity: `XAUUSD.DWX` (primary — highest a priori plausibility)
- Indices: `GDAXI.DWX`, `NDX.DWX`, `WS30.DWX` (US30 — Dow Jones, substitute for paper's SPX reference since SPX is not in Darwinex tick-data universe; `UK100.DWX` optional secondary)

Crypto **explicitly excluded** — Darwinex MT5 has no .DWX crypto symbols (Hard Rule 12).

## 7. Backtest Scope

- **DEV window:** 2017-01-01 → 2022-12-31 (Pipeline V2.1 standard).
- **HO window:** 2023-01-01 → present (walk-forward target).
- **Tester model:** Model 4 — Every Real Tick (Hard Rule 6).
- **Baseline gate targets (P2):** PF > 1.30, Trades > 200 over DEV, DD < 12%.
- **Primary symbols for P2 baseline scan:** XAUUSD, GDAXI, NDX, WS30 (each as separate EA+symbol entries in registry).
- **P3 sweep axes:** `MaxLookback_N` ∈ {10,15,20,30,40,50}, `HoldDays_Max` ∈ {3,5,7,10}, `HoldDays_Min` ∈ {2,3,5,7}, `StopLossATRMult` ∈ {2.0,2.5,3.0,4.0}, `EnableSeasonalityLeg` ∈ {true,false}. Full grid ≈ 6×4×4×4×2 = 768 configs → use bounded-sweep 48-config batches per `TERMINAL_SETUP_GUIDE §8`.

Trade-count note: on D1 with a 10-day MAX/MIN filter, expected trade density is ~20–40 trades/year per symbol per leg. Four symbols × ~30 trades/yr × 6yr DEV ≈ 720 trades aggregated. Single-symbol instances will be tight on the T>200 gate over DEV and may require multi-symbol aggregation or extended DEV window; flag this as a P2 risk.

## 8. Original Source

> "The results point to a simple seasonality strategy that is based on holding BTC only for two hours per day. More specifically, the strategy has a simple rule: buy Bitcoin at 21:00 (UTC +0) and sell it at 23:00 (UTC +0). […] The data suggests that BTC tends to trend when it is at its maximum and bounce back when at the minimum. […] After exploring 10-, 20-, 30-, 40- and 50-days periods, the shortest tend to work the best."

— Padysak, M., Vojtko, R. (2022). *Seasonality, Trend-following, and Mean reversion in Bitcoin.* SSRN: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4081000

Reported combined performance on BTC (2010–2022, per paperswithbacktest.com): Sharpe 1.11, annual return 53.59%, annual vol 49.47%, max DD 74.39%. These numbers reflect un-levered BTC on a volatile asset; they do **not** forecast XAUUSD/indices performance, which will be much lower-vol and correspondingly lower-return.

Catalog row: R1 #135 / R2 GO-rank #1 (`papers_with_backtest_suitability.md` row 37, combined 9/10, plausibility 4, impl. ease 5).

## 9. Implementation Notes (CTO)

- **Inherit** `Include/FTMO/FTMO_Strategy_Base.mqh` per Hard Rule 6; enum for `RISK_MODE ∈ {RISK_PERCENT, RISK_FIXED}` must be parameter-exposed per `feedback_fixed_risk_methodology`.
- **SM-ID:** allocate next free via `Company/data/ea_registry.json` auto-bump; register one logical EA (not one per symbol — count unique EAs per Hard Rule 11).
- **Magic number:** `SM_<id>*10000 + symbol_slot` (Hard Rule 8). Slot map defined in `Company/Agents/DevOps/slot_map.json` if present, otherwise CTO assigns deterministically.
- **Separability of legs:** expose `EnableSeasonalityLeg`, `EnableMaxLeg`, `EnableMinLeg` as three bools so P3 sweeps can ablate each leg independently. This also enables the Sub-signal A failure hypothesis test (run with seasonality leg off — if Max+Min alone still passes P2 on gold/indices the core anomaly transferred even if the session leg did not).
- **Hold-clock reset on overlap:** document the single-position / hold-clock-reset rule clearly in the MQL5 source; a naive implementation that stacks or double-exits will distort P2 numbers.
- **No pyramiding, no hedging.** One long position per symbol at any time. Short direction is intentionally out of scope for V1 — the paper makes no short claim.
- **Smoke test:** deterministic-seed P1 smoke on XAUUSD D1 2017-01 → 2018-12 should produce a repeatable trade log (identical timestamps, identical lot sizes) across two runs.
- **Symbol suffix:** `.DWX` inside EA as documented in `TERMINAL_SETUP_GUIDE §7 / L-013`; suffix strip only on VPS deploy packaging (Hard Rule 7).
- **D1 bar-open execution:** entries fire at `Open[t+1]`, not `Close[t]`, to avoid lookahead on signal bar. Exits can be at `Open[t+HoldDays]` or `Close[t+HoldDays-1]` — CTO's choice but must be documented and consistent.

### Open design questions for CTO (answer before D1 merge)

1. D1 seasonality proxy (Sub-signal A) — is a prior-close-time gate meaningful on D1 given broker server time ≈ EET? If not, Sub-signal A may collapse to a no-op; decision: either drop it from V1 with documented rationale, or promote the EA to H1 timeframe for this single leg (hybrid timeframe adds complexity — recommend dropping in V1 and testing H1 variant as a separate SM-ID later).
2. Are `MaxLookback_N` and `MinLookback_N` tied or independent? Paper implies the same `N` for both but doesn't prove optimality; recommend expose independently for P3 search.
3. End-of-week flatten on indices — should this be default-on for indices (gap risk) and default-off for XAUUSD (24h metal)? CTO decision at D1 time.

## 10. Pipeline Results

*Empty at spec time. Auto-populated post P2 / P3 by Controlling agent.*

| Phase | Symbol | PF | Trades | DD | Verdict | Date | Report |
|---|---|---|---|---|---|---|---|
| P2 | — | — | — | — | — | — | — |
| P3 | — | — | — | — | — | — | — |
| P3.5 | — | — | — | — | — | — | — |
| P4 | — | — | — | — | — | — | — |
