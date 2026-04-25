---
title: ATH Breakout + ATR Trailing Stop (Trend Following, adapted from Blackstar 2005)
slug: ath-breakout-atr-trail
source_url: https://paperswithbacktest.com/strategies/does-trend-following-work-on-stocks
source_paper_url: https://paperswithbacktest.com/api/paper/does-trend-following-work-on-stocks/pdf
source_paper_title: Does Trend Following Work on Stocks?
source_paper_authors: Cole Wilcox, Eric Crittenden
source_paper_year: 2005
asset_class: multi
timeframe: D1
suitability: GO
sm_id_assigned:
pipeline_status: research
---

## 1. Economic Thesis

Wilcox & Crittenden (Blackstar Funds, 2005) studied U.S. single-stock trend-following from 1983-2004 and showed that a simple rule — buy on a breakout above the all-time-high close, exit on a wide volatility-scaled trailing stop — produced a long-term positive-expectancy distribution with heavy positive skew. The study's central insight is not that the method is accurate (it isn't — most trades lose), but that the **return distribution is non-normal**: a small number of very large winners in stocks that went on multi-year trends (Apple, Microsoft, etc.) paid for a majority of small, capped losers. The edge lives in the tails, not in the hit rate.

The equity thesis rests on three drivers that translate only partially to FX/indices/gold:

1. **Cross-sectional dispersion and survivorship bias.** On stocks, the universe is large (thousands of names), individual firms can compound 50-100× over decades, and the cross-section has a structural right-tail from winners-take-most industry dynamics. This driver is **absent** in single-symbol FX / single-index / single-commodity directional — there is no "survivor" vs "dead" dispersion within one ticker.
2. **Trend persistence in macro assets.** Multi-month-to-multi-year directional runs in gold, the U.S. dollar index, equity indices, and oil have been empirically documented (Hurst-exponent and time-series-momentum literature: Moskowitz et al. 2012; Hamill et al. 2016). This driver **does** transfer — it is what we rely on.
3. **All-time-high breakout as a non-overfit regime filter.** Unlike rolling N-day donchian breakouts, the ATH trigger fires rarely and only in genuinely persistent uptrends, so the method is naturally selective. This **transfers** — it is a lookback-length argument, not an equity-specific argument.

**Translation to our adaptation (FX / indices / gold on Darwinex D1):**

- Drop driver (1). We run single-symbol directional, no cross-sectional selection.
- Keep driver (2) as the primary thesis: liquid macro assets exhibit trend persistence long enough that a very wide trailing stop can ride multi-month runs without being shaken out by noise.
- Keep driver (3) as the trigger: breakouts at multi-year highs/lows carry information that has no analogue in rolling N-day donchians — fewer, cleaner signals.
- **Drop long-only.** Blackstar is long-only because equities have a secular upward drift. FX (cross-rate) has no drift; gold, indices, and oil have partial drifts but regularly spend years in drawdown. We must support a symmetric short leg and ablate in P3 whether the short side pays.

The residual thesis we carry to pipeline: **in liquid Darwinex D1 universes that exhibit secular or multi-year regime trends (XAUUSD, GDAXI, NDX, WS30, XTIUSD, major-USD FX pairs), an N-period-high breakout entry paired with a very wide ATR trailing stop produces a positive-expectancy, heavily-right-skewed trade distribution at P2 gate levels (PF > 1.30, DD < 12%) after costs — on a subset of the tested symbols. On flat / mean-reverting FX crosses (EURGBP, AUDNZD) it should fail, which is a diagnostic not a problem.**

## 2. Failure Hypothesis (Pipeline V2.1 G0 gate)

The edge breaks if any of the following become true:

- **Cross-sectional driver absence dominates.** If PF across the full symbol universe is <1.0 on DEV, the thesis that the ATH-trigger + wide-ATR-trail transfers to single-symbol macro was wrong, and no parameter search will recover it. Reject the family rather than overfit N or ATR multiplier.
- **Trailing stop too wide for fixed-risk accounts.** A 10×ATR(42) trailing stop on D1 can imply per-trade risk of 5-8% of entry price on volatile symbols. Converted to Hard-Rule-6 fixed-risk sizing, position sizes become microscopic (lots below broker minLot). If >30% of signals fail to size above minLot on DEV, the strategy is uninvestable at DarwinexZero risk caps. Flag P2 risk; must be caught before P3.
- **Trend persistence is already priced out of liquid macro.** TSMOM research post-2012 has made time-series-momentum a crowded factor; CTA capacity is large, and mean-reversion in 1-3 month windows has increased in FX majors. If the DEV-window hit-rate on ATH breakouts falls below 25% AND the average winner's R-multiple falls below 3R, the heavy-tail payoff structure is gone and the method cannot survive 10×ATR stop costs. Detectable at P2.
- **ATH is undefined or degenerate on FX.** Cross-rates do not have "all-time highs" in the equity sense — EURUSD 2008 high of 1.60 is a 20-year high that may never recur, while USDJPY can revisit the same 145 level across 30 years. If we use a fixed in-series ATH, most FX symbols never trigger in DEV. The N-period high (default N=252) is the pragmatic substitute; if it degenerates into a standard donchian and produces the same signals as QUAA-238 (Turtle), the spec has no incremental value. Must ablate in P3.5 against Turtle-55 on the same symbols.
- **Wide-stop slippage amplifies losses.** The Blackstar 10×ATR trail is designed assuming equity markets with narrow overnight gaps. D1 gaps on indices (weekend), oil (rollover), and gold (central-bank-news) can blow through a single-point trailing stop by 2-5 ATR. If average stop-exit slippage >2×ATR on DEV, realised edge collapses vs backtest-assumed edge. Monitor in P5b.
- **Inverse correlation within portfolio.** By construction, this EA will hold concurrent long positions in highly correlated trending assets (e.g. XAUUSD + EURUSD + NDX all long in a USD-weakness regime). P9 family-cap logic must treat ATH-breakout as its own family; otherwise portfolio-heat becomes unsafe. Flag as P9 risk; not strictly a G0 kill, but a deploy-gate kill if ignored.

## 3. Entry Rules

Strategy is a **single-direction N-period-extreme breakout**, long and short legs gated independently.

### Long entry

On the close of the completed D1 bar `t`, both conditions must hold:

1. **ATH trigger:** `Close[t] >= max(Close[t-EntryATH_N .. t-1])` — the closing price of bar `t` is greater than or equal to the highest close in the prior `EntryATH_N` bars (bar `t` excluded from the lookback to prevent self-referential lookahead).
2. No position currently open on this symbol (no pyramiding).

If both hold, **enter long at Open[t+1]**.

### Short entry

Symmetric:

1. `Close[t] <= min(Close[t-EntryATH_N .. t-1])`.
2. No position currently open on this symbol.

Enter short at Open[t+1].

### Parameters

| Parameter | Default | P3 sweep grid | Notes |
|---|---|---|---|
| `EntryATH_N` | 252 | {126, 252, 504, 1260} | 252 = ~1Y D1; 504 = ~2Y; 1260 = ~5Y. Blackstar original uses full in-series history; 252 is our pragmatic D1 default per issue spec. `126` tests the mid-term breakout variant. |
| `TrailATR_Mult` | 10.0 | {5.0, 7.5, 10.0, 12.5, 15.0} | Blackstar original 10×ATR trailing stop. Sweep around it to check plateau stability. |
| `TrailATR_Period` | 42 | {14, 20, 42, 60} | Blackstar original uses ATR(42). 14 is MT5 default; kept as an axis. |
| `EnableLongs` | true | {true, false} | Leg ablation. |
| `EnableShorts` | true | {true, false} | Equity bias is long-only; FX symmetry demands short leg — must ablate. |
| `HardStopATRMult` | 15.0 | {12.0, 15.0, 20.0, 0 = off} | Safety cap at 1.5× the trail multiplier. Prevents runaway losses if the trail fails to update (e.g. gap-through). 0 = disabled. |

Rule constraint: `HardStopATRMult > TrailATR_Mult`. Enforced as compile-time assert; EA refuses to start if violated.

**Close-vs-High trigger choice.** Blackstar uses close-based breakouts (today's close >= all-time-high-close); we keep this. An alternative intrabar-high trigger (`High[t] >= max(High[t-N .. t-1])`) produces more signals but fills on wicks and degrades into classic donchian. Keep close-based as default; flag for P3 consideration only if PF is marginal.

## 4. Exit Rules

| Trigger | Rule |
|---|---|
| ATR trailing stop (primary) | Long: maintain `trail = max(trail, High_since_entry - ATR(TrailATR_Period)_at_current_bar * TrailATR_Mult)`; close at Open[t+1] if `Low[t] <= trail`. Short: `trail = min(trail, Low_since_entry + ATR * TrailATR_Mult)`; close at Open[t+1] if `High[t] >= trail`. Trail tightens (long: rises) with price; never loosens. ATR is **recomputed each bar** (unlike Turtle which freezes ATR at entry) — this is deliberately Blackstar-faithful, because the wide multiplier is supposed to auto-scale with regime volatility. |
| Hard ATR stop (safety) | Long: `entry_price - ATR(TrailATR_Period)[entry] * HardStopATRMult`. Short: symmetric. ATR frozen at entry. This is the catastrophic backstop for gap-throughs; set wider than the trail so it only fires when the trail has demonstrably failed to update. |
| Hard TP | None. Core method is trail-only — any TP destroys the heavy-tail winners that justify the entire approach per Blackstar finding. |
| Breakeven | None in V1. V2 optional (pre-registered per `feedback_enhancement_doctrine`, exit-only = allowed): move hard stop to entry after `+TrailATR_Mult * 0.5 * ATR` favourable move. Not the trail itself — trail always governs. |
| Time-stop | None. Trend-following method; time-stops contradict the thesis. |
| News / session | Deferred to P8 News Impact gate (OFF / PAUSE / SKIP_DAY selection per standard pipeline). |

**Design note on ATR recomputation.** This is the critical deviation from QUAA-238 (Turtle, ATR frozen at entry). Blackstar's wide trail is explicitly designed to breathe with regime volatility — if volatility contracts post-entry the stop tightens automatically; if it expands the stop loosens (up to the monotone-tightening rule on the trail itself). This is load-bearing for the method and should not be "simplified" in CTO implementation.

## 5. Position Sizing

Per Hard Rule 6, every EA supports both modes:

- `RISK_PERCENT` — percent-of-equity risk per trade (live-deploy default 0.50%, configurable per deploy-set).
- `RISK_FIXED` — fixed $1,000 risk per trade (DEV baseline per `feedback_fixed_risk_methodology`).

Position size: `lots = RiskAmount / (StopLossDistance * TickValuePerLot)` where `StopLossDistance = ATR(TrailATR_Period)[entry] * TrailATR_Mult` (the **initial trail distance at entry**, not the hard-stop distance — because the trail is the realistic worst-case on most trades; the hard stop is a backstop, not the expected loss). Lots rounded down to broker `lotStep`, clipped to `[minLot, maxLot]`.

**Sizing sanity check in P1 smoke.** With `TrailATR_Mult=10` and `TrailATR_Period=42`, risk-per-trade implies very small lot sizes. If on EURUSD with $1,000 risk the computed lot falls below `minLot`, the EA must log the skip, not silently size up. Report fraction-of-signals-unsized in the P1 smoke artefact — this is a P2-preview for the "too wide to size" failure mode in Section 2.

**No pyramiding.** One position per symbol. If a new ATH breakout fires while a position is open, log-skip and continue.

Magic number: `SM_<id>*10000 + symbol_slot` per Hard Rule 8 / `feedback_deploy_magic_numbers`.

## 6. Required Indicators / Data

All MT5-native — no exotic data, Hard Rule 12 compliant:

| Indicator / data | MT5 source | Notes |
|---|---|---|
| N-period max / min close | `iClose` over window `[t-N, t-1]` via `CopyClose` + ArrayMaximum / ArrayMinimum | Core entry signal. Bar `t` strictly excluded from lookback — standard non-lookahead convention. |
| ATR(`TrailATR_Period`) | `iATR` on D1 timeframe | Trail stop distance. Recomputed each bar for the trail; frozen at entry for the hard safety stop. |
| Tick data | Darwinex native D1 (Model 4 Every Real Tick per Hard Rule 6 / `feedback_always_model4`) | No external market API. |

**Universe (Darwinex .DWX tick-data symbols, D1):**

- **Tier 1 (primary, secular-trend assets):** `XAUUSD.DWX`, `GDAXI.DWX`, `NDX.DWX`, `WS30.DWX`, `XTIUSD.DWX` — these exhibit the multi-year regime trends the method is designed for.
- **Tier 2 (macro-FX majors, partial trend transfer):** `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX` — USD-bloc pairs can trend for 1-2 years during Fed-cycle regimes but revert on longer horizons.
- **Tier 3 (optional, likely fail):** `XAGUSD.DWX`, `XBRUSD.DWX`, `UK100.DWX`, `JPN225.DWX` — include for universe completeness; expect P2 to reject most.
- **Explicitly excluded:** FX cross-rates without secular drift (`EURGBP.DWX`, `AUDNZD.DWX`, `EURCHF.DWX`). By construction the method should fail on these; exclude to keep P2 trade-count honest rather than padding the universe with known-NO_GOs.
- **Crypto excluded** per Hard Rule 12 (no .DWX crypto tick data on Darwinex).

## 7. Backtest Scope

- **DEV window:** 2017-01-01 → 2022-12-31 (Pipeline V2.1 standard).
- **HO window:** 2023-01-01 → present (walk-forward target).
- **Tester model:** Model 4 — Every Real Tick (Hard Rule 6).
- **Baseline gate targets (P2):** PF > 1.30, Trades > 200 over DEV, DD < 12%.
- **Primary symbols for P2 baseline scan:** Tier 1 (5 symbols) + Tier 2 (6 symbols) = 11 symbols. Tier 3 dropped from baseline to keep scan compute bounded; can be revived if P3.5 CSR needs more class members.
- **P3 sweep axes:** `EntryATH_N` × `TrailATR_Mult` × `TrailATR_Period` × `EnableLongs` × `EnableShorts` = 4×5×4×2×2 = 320 configs. Under the bounded 48-config batches convention (`TERMINAL_SETUP_GUIDE §8`), run 7 batches; rank by DEV Sharpe with trade-count floor.

**Trade-count warning.** With N=252 and close-based ATH trigger, expected annual signal rate on D1 is ~0-3 per symbol per direction per year (trending years: 2-3; flat years: 0). Over the 6-year DEV window, expect ~5-30 trades per single-symbol instance. **The T>200 P2 gate is almost certain to fail on every individual symbol.** This is a known structural constraint of ATH-style methods — not a bug.

**Proposed P2 evaluation strategy** (CTO + CEO to confirm before P2 run):

- **Option A (preferred):** aggregate the 11-symbol universe into a single "portfolio-baseline" run, count trades across the universe. Trade-count floor becomes T>200 aggregate, not per-symbol.
- **Option B:** run per-symbol P2 with relaxed `T>30` floor on a trade-count-waiver basis, justified by this spec. PF and DD gates unchanged.
- **Option C (rejected):** lower `EntryATH_N` to 126 or 63 to synthesise trades. This converges to a standard donchian and destroys the thesis — not an acceptable path.

CTO call required at P2 spawn time.

**P3.5 CSR classes:** Tier 1 (commodities+indices, secular-trend) vs Tier 2 (USD-FX majors, macro-trend). Two orthogonal macro regimes. CSR gate: PF > 1.0 on both, Sharpe drop <40% between classes.

## 8. Original Source

Primary source URL (paperswithbacktest.com editorial):

> https://paperswithbacktest.com/strategies/does-trend-following-work-on-stocks

R1 catalog summary (row #1): all-time-high breakout entry on stocks, 10-period ATR trailing stop exit, demonstrating trend-following works single-name equities.

R2 suitability (row #3 GO, combined 9/10, plausibility 4, implementation ease 5, GO_TRANSFER): "All-time-high breakout entry + 10×ATR trailing stop; single-symbol directional; transfers to FX/indices/gold."

**Underlying paper (primary source):**

- Wilcox, C., & Crittenden, E. (November 2005). *Does Trend Following Work on Stocks?* Blackstar Funds LLC. Available at https://paperswithbacktest.com/api/paper/does-trend-following-work-on-stocks/pdf
- Paper backtest scope: U.S. stocks 1983-2004; 24,000+ tickers including delisted; entry on break of all-time-high close; exit on 10-ATR(42) trailing stop.

**Reported source-page performance** (paperswithbacktest editorial, 1990-2026 synthesis on stocks):

| Metric | Value |
|---|---|
| Sharpe | 0.58 |
| CAGR | 10.24% |
| Annualised Vol | 20.64% |
| Max DD | 45.37% |
| PF | not reported |

These are **not applicable targets** for our FX/index/gold adaptation — different asset class, different universe, no cross-sectional driver. Pipeline P2 on our Darwinex D1 universe is authoritative.

## 9. Implementation Notes (CTO)

### Delta vs Blackstar original (what was kept, added, changed)

| Aspect | Blackstar 2005 original | This spec | Why |
|---|---|---|---|
| Universe | U.S. single stocks, 24k+ tickers, cross-sectional | Darwinex D1 FX / indices / metals / energy, single-symbol directional | Our data provider + Hard Rule 12; no cross-sectional stock selection infrastructure. |
| Entry trigger | All-time-high close (full in-series history) | **N-period-high close (default N=252)** | FX has no meaningful all-time-high; N=252 is pragmatic D1 default with `{126, 252, 504, 1260}` P3 sweep. |
| Direction | Long-only | **Symmetric long+short, each ablatable** | FX is symmetric; equity drift does not exist on cross-rates. P3 determines whether shorts pay per symbol. |
| Exit | 10×ATR(42) trailing stop | **Kept: 10×ATR(42) default** with P3 sweep `{5, 7.5, 10, 12.5, 15}` × `{14, 20, 42, 60}` | Core of the method; preserved. |
| ATR recomputation on trail | Recomputed each bar (not frozen) | **Kept: recomputed each bar** | Load-bearing — the wide multiplier is designed to auto-scale with regime vol. Explicitly different from Turtle (QUAA-238). |
| Safety hard stop | None (stock method — limited downside) | **Added: hard ATR stop at 15×ATR frozen at entry** | Gap-through safety in FX/indices; disabled if `HardStopATRMult=0`. |
| Position sizing | Full-capital equity position | **FTMO_Strategy_Base fixed-risk or percent-risk** (Hard Rule 6) | Matches our uniform EA framework. |
| Pyramiding | Not used | **Not used** | Same. |
| Cross-sectional selection | Buy any stock that triggers | **Single-symbol EA, P9 handles cross-symbol diversification** | Our pipeline architecture. |
| Execution | Signal-bar-close entry | **Next-bar-open entry** after the breakout bar closes | D1 Model 4 backtest convention; prevents lookahead. |

### CTO implementation checklist

- **Inherit** `Include/FTMO/FTMO_Strategy_Base.mqh` per Hard Rule 6.
- **SM-ID:** allocate next free via `Company/data/ea_registry.json` auto-bump; register one logical EA (count unique EAs per Hard Rule 11).
- **Magic number:** `SM_<id>*10000 + symbol_slot` (Hard Rule 8 / `feedback_deploy_magic_numbers`); slot map per `Company/Agents/DevOps/slot_map.json` if present.
- **N-period-high computation:** use `CopyClose(_Symbol, PERIOD_D1, 1, EntryATH_N, arr)` then `ArrayMaximum(arr)` — starts at shift=1, length=N, so the lookback is strictly `[t-N, t-1]`. Compare to `Close[0]` once the bar is closed (OnTick after bar-close detection, or OnTimer at D1 close). Never include the current bar.
- **ATR recomputation on trail:** the trail's ATR is per-bar, not frozen. The hard safety stop's ATR **is** frozen at entry. Do not collapse both to a single ATR variable — they are semantically different and both are load-bearing.
- **Trail monotonicity:** long trail never decreases bar-to-bar; short trail never increases. Implement as `trail = MathMax(trail_prev, price_high - atr_now * mult)` for longs. Initialise trail at entry (not at first bar after).
- **`HardStopATRMult > TrailATR_Mult` assert:** compile-time check (or OnInit check with explicit `INIT_PARAMETERS_INCORRECT` return). EA refuses to start if violated.
- **Leg ablation flags:** `EnableLongs`, `EnableShorts` exposed as inputs so P3 can ablate each direction independently.
- **Under-sized signal handling:** if computed lot < broker `minLot`, log-skip (category `SKIP_MIN_LOT`), do NOT silently round up to minLot. Report fraction-of-skipped-signals in the P1 smoke artefact — this directly feeds the Section-2 failure-hypothesis check.
- **No pyramiding, no hedging, no same-symbol stacking.** One position per symbol at any time. If a breakout fires while a position exists, log-skip and continue.
- **Symbol suffix:** `.DWX` inside EA as documented in `TERMINAL_SETUP_GUIDE §7 / L-013`; suffix strip only on VPS deploy packaging (Hard Rule 7).
- **Smoke test:** deterministic-seed P1 smoke on XAUUSD D1 2017-01 → 2019-12 must produce an identical trade log across two runs.

### ATR-trail implementation path (issue-required decision)

The issue acceptance requires documenting whether to implement the ATR trail via custom logic or the existing `CTrailingStops` helper library. Decision and rationale:

- **Decision: custom implementation, not `CTrailingStops`.**
- Rationale:
  1. **ATR-recomputation-per-bar** is the core mechanic; most off-the-shelf `CTrailingStops` variants (including the common MetaQuotes / community snippets) freeze ATR or use a fixed-point trail. Wiring the recomputation into a library designed for fixed-distance trails is more code than writing it directly.
  2. **Monotonicity + initial-trail anchoring at entry** must be explicit and auditable. Custom code in the EA's `OnTick` post-position-check is 20-30 lines and directly testable in P1 smoke.
  3. **Two separate stop concepts** (dynamic trail + frozen hard stop) coexist in this EA. A single library abstraction obscures that; explicit code does not.
  4. **Determinism**: custom code is easier to seed-audit for P1 determinism check and for P5b noise-injection reproducibility.
- Reference: existing EAs in `MQL5/Experts/EA_Testing/` that use custom ATR trails (e.g. SM_254 family, some of the FTMO_Strategy_Base-derived donchian EAs) — CTO to cross-reference one existing custom-trail EA as a pattern, rather than introducing `CTrailingStops` as a new dependency.

### Open design questions for CTO (answer before D1 merge)

1. **Hard-stop default value.** 15×ATR is proposed as 1.5× the trail multiplier. CTO to confirm this leaves enough headroom for gap-through events on GDAXI / NDX weekends (or propose a different gap-based floor — e.g. 3% of entry price as an absolute cap).
2. **Rollover handling on energy symbols** (`XTIUSD.DWX`, `XBRUSD.DWX`): same concern as QUAA-238 (Turtle). Confirm whether `FTMO_Strategy_Base.mqh` already neutralises rollover jumps for the ATH-close and the trail update. If not, the EA should skip ATH-close comparisons across rollover boundaries.
3. **Entry-gap policy on indices**: on Monday opens GDAXI / NDX can gap 2-3 ATR beyond the Friday breakout close. V1 behaviour should be: enter anyway, log the gap, flag for P5b slippage calibration. V2 can add a max-entry-gap input.
4. **Close vs adjusted-close for equities-legacy comparison**: not applicable to FX / indices on Darwinex (no corporate actions) — confirm `iClose` is the correct source and no dividend-adjustment gymnastics are needed.

## 10. Pipeline Results

*Empty at spec time. Auto-populated post P2 / P3 by Controlling agent.*

| Phase | Symbol | PF | Trades | DD | Verdict | Date | Report |
|---|---|---|---|---|---|---|---|
| P2 | — | — | — | — | — | — | — |
| P3 | — | — | — | — | — | — | — |
| P3.5 | — | — | — | — | — | — | — |
| P4 | — | — | — | — | — | — | — |
