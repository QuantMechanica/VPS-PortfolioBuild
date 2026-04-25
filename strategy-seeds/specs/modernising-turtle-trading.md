---
title: Modernising the Turtle Trading Strategy
slug: modernising-turtle-trading
source_url: https://paperswithbacktest.com/strategies/turtle-trading-strategy
source_paper_url: n/a
source_paper_title: n/a
source_paper_authors: n/a (paperswithbacktest.com editorial page)
source_paper_year: n/a
asset_class: multi
timeframe: D1
suitability: GO
sm_id_assigned:
pipeline_status: research
---

## 1. Economic Thesis

The Turtle system (Dennis & Eckhardt, 1983; popularised by Faith, 2007) is the archetypal donchian-breakout trend-follower: enter on N-day price extremes, ride the trend with a volatility-scaled stop, exit on the opposite M-day extreme. The core edge is the **persistence of trend regimes** in liquid futures/FX/indices/commodities: once price clears a multi-week range boundary, dealer hedging, CTA momentum flows, and stop clustering beyond the breakout level tend to extend the move for weeks to months.

The "modernised" variant keeps the donchian skeleton but addresses two well-documented weaknesses of the classic rules:

1. **Whipsaw during mean-reverting regimes.** Classic Turtle takes every breakout and accepts that ~60-65% of trades lose. A **long-term trend filter** (e.g. Close vs SMA(200)) suppresses breakouts that fire against the dominant regime — which empirically removes the worst cluster of whipsaws without sacrificing the heavy-tail winners.
2. **Unit-based pyramiding is impractical for fixed-risk / prop-firm accounts.** Classic Turtle adds up to 4 units at 0.5N intervals, with a max-12-unit portfolio-heat cap. This is incompatible with FTMO / Darwinex-Zero single-trade risk budgets. The modern implementation uses **one full-risk position per signal** (no pyramiding) and delegates diversification to multi-symbol portfolio construction (our P9 phase).

The residual thesis we take to pipeline: **in liquid Darwinex MT5 D1 universes (FX majors, metals, indices, energy), N-day donchian breakouts filtered by a long-term trend proxy continue to produce a positive-expectancy, positively-skewed trade distribution at P2 gate levels (PF > 1.30, DD < 12%) — after costs and slippage — across at least a subset of the tested symbols.**

## 2. Failure Hypothesis (Pipeline V2.1 G0 gate)

The edge breaks if any of the following become true:

- **Regime compression / "death of trend".** Multi-year regimes of low realised D1 volatility and narrow ranges (e.g. FX majors 2019, gold 2013-2015) produce false breakouts that reverse inside the ATR stop. Detectable via rolling 252-day breakout-hit-rate on each symbol; kill-signal if hit-rate falls below 30% and the average hold is shorter than `TrailDonchian_M`.
- **Filter destroys the tails.** The SMA(200) filter might suppress the very breakouts that become the best-performing outliers (early-regime-turn signals that fire before the long-term MA has rolled). If removing the filter raises PF materially on DEV but the filtered version loses to buy-and-hold, the filter is over-fit; must be ablated in P3.
- **Donchian is fully priced in.** Turtle logic has been public since 1983 and in retail books since 2007. If cross-symbol aggregate PF on the full universe of Darwinex D1 symbols is <1.0 on the DEV window, the edge is simply gone on this data universe and no parameter search will recover it — reject the family rather than search harder.
- **Slippage / cost break-even.** Breakouts on D1 cross-hour gaps (weekend open on indices, rollover on metals/oil) can fill 3-5 ATR-ticks worse than the trigger level. If realised average slippage >1% of ATR(14), expected edge per trade collapses. Monitor via tick-level fill simulation in P5b.
- **Stop-distance too tight for the horizon.** The original 2N stop is specifically matched to a 10-day exit window. If P3 optimisation drifts toward stops <1.5N, trades get cut before the edge materialises; if >3.5N, losers become catastrophic. Either extreme invalidates the original thesis and must be flagged as "no longer a Turtle".

## 3. Entry Rules

Strategy is a **single-direction donchian breakout with a long-term MA trend filter**, long-only and short-only each gated independently.

### Long entry

On the close of the completed D1 bar `t`, all three conditions must hold:

1. `High[t] >= Donchian_High_N` where `Donchian_High_N = max(High[t-N .. t-1])` (strictly the prior N bars, bar `t` excluded from the lookback so the signal is non-lookahead).
2. **Trend filter:** `Close[t] > SMA(TrendMA_L)[t]` (long-only filter).
3. No position currently open on this symbol (no pyramiding).

If all three hold, **enter long at Open[t+1]**.

### Short entry

Symmetric:

1. `Low[t] <= Donchian_Low_N` where `Donchian_Low_N = min(Low[t-N .. t-1])`.
2. **Trend filter:** `Close[t] < SMA(TrendMA_L)[t]`.
3. No position currently open on this symbol.

Enter short at Open[t+1].

### Parameters

| Parameter | Default | P3 sweep grid | Notes |
|---|---|---|---|
| `EntryDonchian_N` | 55 | {20, 40, 55, 80, 100} | Classic System 2 uses 55; System 1 uses 20. 55 is the modernisation default (fewer trades, cleaner signals). |
| `TrailDonchian_M` | 20 | {10, 15, 20, 30} | Exit donchian window. Classic System 2 pairs 55/20. |
| `TrendMA_L` | 200 | {100, 150, 200, 250} | SMA for trend filter. 200 is industry standard. |
| `EnableLongs` | true | {true, false} | Leg ablation. |
| `EnableShorts` | true | {true, false} | Leg ablation. |
| `StopLossATRMult` | 2.0 | {1.5, 2.0, 2.5, 3.0} | Classic 2N stop. |

Rule constraint: `TrailDonchian_M < EntryDonchian_N` (otherwise the trail can never fire an exit independent of the entry). Enforced as a compile-time assert in the EA.

## 4. Exit Rules

| Trigger | Rule |
|---|---|
| Trailing Donchian (primary) | Long: close at Open[t+1] if `Low[t] <= min(Low[t-M .. t-1])`. Short: close at Open[t+1] if `High[t] >= max(High[t-M .. t-1])`. |
| Hard SL | Long: `entry_price - ATR(14)[entry] * StopLossATRMult`. Short: `entry_price + ATR(14)[entry] * StopLossATRMult`. ATR frozen at entry bar. |
| Hard TP | None. Classic Turtle is trail-only; any TP destroys the heavy-tail winners that make the EV positive. |
| Breakeven | None in V1. V2 optional: move stop to entry after `+2 * ATR` favourable move (pre-registered as enhancement per `feedback_enhancement_doctrine`, exit-only = allowed). |
| Time-stop | None. Donchian trail is the only time-related exit. |
| News / session | Deferred to P8 News Impact gate (OFF / PAUSE / SKIP_DAY selection per standard pipeline). |

Rationale: the 2N / M-day-opposite-extreme combination is the classical Turtle exit pair. The ATR stop caps tail-loss per Hard Rule 6 / FTMO compliance; the donchian trail captures trend reversal before the ATR stop would normally fire in a gradual roll-over.

## 5. Position Sizing

Per Hard Rule 6, every EA supports both modes:

- `RISK_PERCENT` — percent-of-equity risk per trade (live-deploy default 0.50%, configurable per deploy-set).
- `RISK_FIXED` — fixed $1,000 risk per trade (DEV baseline per `feedback_fixed_risk_methodology`).

Position size: `lots = RiskAmount / (StopLossDistance * TickValuePerLot)` where `StopLossDistance = ATR(14) * StopLossATRMult`. Lots rounded down to broker `lotStep`, clipped to `[minLot, maxLot]`.

**No pyramiding.** Classic Turtle stacks up to 4 units at 0.5N intervals; modern variant deliberately drops this. Rationale: (a) incompatible with FTMO / Darwinex-Zero single-trade risk caps; (b) diversification is handled at portfolio level in P9 (family cap 3 / symbol cap 2 per `pipeline-v2-1.md`), not within a single instance.

Magic number: `SM_<id>*10000 + symbol_slot` per Hard Rule 8 / `feedback_deploy_magic_numbers`.

## 6. Required Indicators / Data

All MT5-native — no exotic data, Hard Rule 12 compliant:

| Indicator / data | MT5 source | Notes |
|---|---|---|
| Donchian High / Low over `N` | `iHigh` / `iLow` buffers, shifted 1 bar | Core entry signal. Strictly prior-N lookback; exclude current bar to avoid lookahead. |
| Donchian High / Low over `M` | Same, window `M` | Trailing exit. |
| SMA(TrendMA_L) | `iMA(..., MODE_SMA, PRICE_CLOSE)` | Trend filter. Default length 200. |
| ATR(14) | `iATR` D1 | Stop sizing and normalisation. ATR value frozen at entry bar (not recomputed live) so stop level is deterministic. |
| Tick data | Darwinex native D1 (Model 4 Every Real Tick per Hard Rule 6 / `feedback_always_model4`) | No external market API. |

**Universe (Darwinex .DWX tick-data symbols, D1):**

- FX majors: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `NZDUSD.DWX`
- FX crosses (optional): `EURJPY.DWX`, `GBPJPY.DWX`, `EURGBP.DWX`, `AUDJPY.DWX`
- Metals: `XAUUSD.DWX`, `XAGUSD.DWX`
- Indices: `GDAXI.DWX`, `NDX.DWX`, `WS30.DWX`, `SPX500.DWX` (if available), `UK100.DWX`, `JPN225.DWX`
- Energy: `XTIUSD.DWX` (WTI), `XBRUSD.DWX` (Brent) — rollover-sensitive, flag for P3 rollover handling

Crypto **explicitly excluded** — Darwinex MT5 has no .DWX crypto tick data (Hard Rule 12). The paperswithbacktest editorial mentions crypto under classic Turtle's universe; we scope it out.

## 7. Backtest Scope

- **DEV window:** 2017-01-01 → 2022-12-31 (Pipeline V2.1 standard).
- **HO window:** 2023-01-01 → present (walk-forward target).
- **Tester model:** Model 4 — Every Real Tick (Hard Rule 6).
- **Baseline gate targets (P2):** PF > 1.30, Trades > 200 over DEV, DD < 12%.
- **Primary symbols for P2 baseline scan:** EURUSD, GBPUSD, AUDUSD, USDJPY, XAUUSD, GDAXI, NDX, WS30, XTIUSD (9 symbols — the core liquid-trend universe).
- **P3 sweep axes:** `EntryDonchian_N` × `TrailDonchian_M` × `TrendMA_L` × `StopLossATRMult` × `EnableLongs` × `EnableShorts` = 5×4×4×4×2×2 = 1,280 full grid → use bounded 48-config batches per `TERMINAL_SETUP_GUIDE §8`. Sweep rank by DEV Sharpe, then walk-forward the top 30 into P4.

**Trade-count note:** on D1 with a 55-day donchian entry and SMA(200) filter, expected trade density is ~6-10 entries/year per symbol per direction on trending pairs, ~2-4/year on rangebound pairs. Over the 6-year DEV window, expect ~50-120 trades per single-symbol instance. The T>200 P2 gate **will be tight on many symbols** and likely requires either: (a) multi-symbol aggregation in the baseline run, (b) the shorter `EntryDonchian_N=20` sweep cell, or (c) acceptance that some instances fail P2 on trade-count alone despite being economically sound. Flag as P2 risk — this is consistent with the known Turtle property of producing few high-quality trades.

**P3.5 CSR classes:** FX-majors vs metals+indices (two orthogonal macro regimes); or alternative: trending-pairs (AUDUSD, NZDUSD, JPY-crosses) vs mean-reverting-pairs (EURUSD, EURGBP). CTO / Research agree the class split at P3.5 time.

## 8. Original Source

Source URL (paperswithbacktest.com editorial — no underlying academic paper, site synthesises the original Turtle rules with common modernisations):

> https://paperswithbacktest.com/strategies/turtle-trading-strategy

Catalog summary (R1 row #153): "Buy on N-day high breakouts above trend-confirming moving average, exit on M-day low with volatility-adjusted position sizing."

R2 suitability (row #2 GO, combined 9/10): plausibility 4, implementation ease 5, rationale "N-day high BO + MA filter + vol-adjusted sizing; classic robust trend — low novelty but clean and implementable".

**Provenance of the classic rules** (not the editorial page, but the underlying method the page modernises):

- Dennis, R., & Eckhardt, W. (1983). *The Original Turtle Trading Rules* (private training material, later published in public form).
- Faith, C. M. (2007). *Way of the Turtle: The Secret Methods That Turned Ordinary People into Legendary Traders*. McGraw-Hill. ISBN 978-0-07-148664-4.
- Covel, M. W. (2007). *The Complete TurtleTrader*. Collins Business.

No reported aggregate Sharpe / PF / DD on the editorial page — performance numbers on paperswithbacktest are per-asset and mix stocks/crypto/commodities, so we do not transcribe them. Pipeline P2 is authoritative on our D1 universe.

## 9. Implementation Notes (CTO)

### Delta vs classic Turtle (what was added, kept, removed)

| Aspect | Classic Turtle (Dennis 1983 / Faith 2007) | Modern variant (this spec) | Why |
|---|---|---|---|
| Systems | Two parallel: S1 (20/10) + S2 (55/20) | **Single system (55/20 default)**, S1 window accessible via P3 sweep of `EntryDonchian_N=20` | Running both simultaneously doubles complexity with minimal evidence of outperformance on modern data; P3 determines which window survives per symbol. |
| Trend filter | **None** in classic | **SMA(200) filter added** (longs only if Close > SMA(200); symmetric for shorts) | Suppresses whipsaws against the dominant regime. Must be ablated in P3 to confirm it helps rather than overfits. |
| Skip-after-winner rule | S1 skipped new entries if prior S1 trade was profitable (anti-trending heuristic) | **Removed** | Modern backtests find it insignificant; adds complexity, obscures the base edge. |
| Pyramiding | Up to 4 units at +0.5N intervals | **None — one full-risk unit per signal** | Incompatible with FTMO / Darwinex-Zero single-trade caps. Diversification handled at P9 portfolio level. |
| Position sizing | "1 Unit" = 1% account / N, with portfolio-heat caps | **FTMO_Strategy_Base fixed-risk or percent-risk** (Hard Rule 6) | Matches our uniform EA framework; portfolio-heat analogue lives at P9 (family/symbol caps). |
| Stop loss | 2N from entry | **Kept: 2N default** (sweepable 1.5N-3N) | This is the Turtle-specific stop and we preserve it as the default. |
| Exit | M-day opposite donchian (10 for S1, 20 for S2) | **Kept: M-day opposite donchian** (20 default) | Core of the method. |
| Markets | All liquid futures (bonds, commodities, FX, metals) | **Darwinex D1 universe: FX + metals + indices + WTI/Brent** (no crypto, Hard Rule 12; no bonds, not on Darwinex retail) | Constrained by our data provider. |
| Execution | Stop-order entry at exact breakout level (intrabar) | **Next-bar-open entry** after the breakout bar closes | D1 Model 4 backtest convention; prevents lookahead. Live-trading slippage simulation in P5b should capture the intrabar-vs-bar-open divergence. |

### CTO implementation checklist

- **Inherit** `Include/FTMO/FTMO_Strategy_Base.mqh` per Hard Rule 6.
- **SM-ID:** allocate next free via `Company/data/ea_registry.json` auto-bump; register one logical EA (count unique EAs per Hard Rule 11).
- **Magic number:** `SM_<id>*10000 + symbol_slot` (Hard Rule 8 / `feedback_deploy_magic_numbers`); slot map per `Company/Agents/DevOps/slot_map.json` if present.
- **Donchian computation:** exclude the current bar from the lookback window. Entry on bar `t` uses `max(High[t-N .. t-1])` — a common bug is to include `High[t]` and get self-referential lookahead at the signal bar.
- **ATR freezing:** capture `ATR(14)[entry]` at entry tick and use it for the full trade life. Do NOT recompute ATR per tick for the hard stop — this causes non-deterministic stops and breaks P5b reproducibility.
- **`TrailDonchian_M < EntryDonchian_N` assert:** compile-time check; block EA start if violated.
- **Leg ablation flags:** `EnableLongs`, `EnableShorts` exposed as inputs so P3 can ablate each direction independently (relevant for metals / indices which have secular long bias).
- **No pyramiding, no hedging, no same-symbol stacking.** One position per symbol at any time. If a breakout fires while a position exists, log-skip and continue.
- **Symbol suffix:** `.DWX` inside EA as documented in `TERMINAL_SETUP_GUIDE §7 / L-013`; suffix strip only on VPS deploy packaging (Hard Rule 7).
- **Smoke test:** deterministic-seed P1 smoke on EURUSD D1 2017-01 → 2018-12 must produce an identical trade log across two runs.

### Open design questions for CTO (answer before D1 merge)

1. **Rollover handling on energy symbols** (`XTIUSD.DWX`, `XBRUSD.DWX`): Darwinex rolls futures contracts with a price adjustment — does the current baseline framework already neutralise rollover jumps for donchian calculations, or does the EA need to skip breakout signals on rollover bars? CTO to verify existing handling in `FTMO_Strategy_Base.mqh` and document.
2. **Signal-bar vs next-bar execution for indices with weekend gaps**: on GDAXI / NDX / WS30 the Monday open can gap 2-3N beyond the Friday breakout level. Should the EA skip entries when the next-bar-open is already beyond `entry + 1*ATR`? Recommend: log-and-enter in V1 (document the slippage honestly in P5b), consider a max-slippage gate in V2.
3. **`SPX500.DWX` availability**: confirm Darwinex has SPX500 as a .DWX tick-data symbol. If not, drop it from the universe and use WS30 + NDX as the US-equity proxy.
4. **MA filter type**: SMA(200) is the default. Should EMA(200) be an alternative to test in P3? Recommend: expose `TrendMA_Type` ∈ {SMA, EMA} as a P3 axis only (default SMA), not a user-exposed live input.

## 10. Pipeline Results

*Empty at spec time. Auto-populated post P2 / P3 by Controlling agent.*

| Phase | Symbol | PF | Trades | DD | Verdict | Date | Report |
|---|---|---|---|---|---|---|---|
| P2 | — | — | — | — | — | — | — |
| P3 | — | — | — | — | — | — | — |
| P3.5 | — | — | — | — | — | — | — |
| P4 | — | — | — | — | — | — | — |
