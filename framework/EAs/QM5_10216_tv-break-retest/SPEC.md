# QM5_10216_tv-break-retest — Strategy Spec

**EA ID:** QM5_10216
**Slug:** `tv-break-retest`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728`
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA builds H1 support and resistance from bounded pivot highs and lows.
After a closed-bar breakout above resistance, it waits for a later closed bar
to retest that level and close back above it before opening long. After a
closed-bar breakout below support, it waits for a later closed bar to retest
that level and close back below it before opening short. Exits are handled by
the initial stop, the activated percentage trailing stop, framework Friday
close, and opposite confirmed breakout-retest signals.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pivot_left` | 5 | 1+ | Bars to the left of a candidate pivot that must not exceed the pivot high or undercut the pivot low. |
| `strategy_pivot_right` | 5 | 1+ | Bars to the right of a candidate pivot that confirm the pivot level. |
| `strategy_pivot_lookback` | 40 | 12+ recommended | Maximum closed H1 bars scanned for the latest support and resistance pivots. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for spread and FX stop normalization. |
| `strategy_direction_mode` | 2 | 0, 1, 2 | Direction filter: 0 long only, 1 short only, 2 both. |
| `strategy_stop_percent` | 1.0 | >0 | Initial stop distance as a percent of entry for indices and gold. |
| `strategy_fx_stop_atr_mult` | 2.0 | >0 | ATR multiple used as the FX initial stop normalization. |
| `strategy_profit_threshold_pct` | 1.0 | >=0 | Profit percent required before the trailing stop starts. |
| `strategy_trailing_stop_pct` | 1.0 | >0 | Trailing stop distance as a percent of current favorable price. |
| `strategy_min_retest_atr_mult` | 0.25 | >=0 | Minimum retest penetration beyond spread, expressed as ATR multiple. |
| `strategy_max_spread_atr_mult` | 0.20 | >=0 | No-trade spread ceiling expressed as ATR multiple. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major FX pair with H1 liquidity and pivot/retest structure.
- `GBPUSD.DWX` — major FX pair with H1 liquidity and pivot/retest structure.
- `XAUUSD.DWX` — liquid gold CFD named in the card's portable basket.
- `NDX.DWX` — liquid Nasdaq 100 index CFD named in the card's portable basket.
- `GDAXI.DWX` — available DWX DAX custom symbol used for the card's GER40/DAX target.

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | hours to days, until stop, trailing stop, Friday close, or opposite signal |
| Expected drawdown profile | stop-defined continuation trades, one position per magic number |
| Regime preference | breakout / volatility expansion with successful retests |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView Pine script page
**Pointer:** `https://www.tradingview.com/script/800ndgbX-Breaks-and-Retests-Free990/`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10216_tv-break-retest.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | 62af7233-1112-4754-85ab-2e1afc215565 |
