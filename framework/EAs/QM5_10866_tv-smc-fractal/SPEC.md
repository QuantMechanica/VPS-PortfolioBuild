# QM5_10866_tv-smc-fractal — Strategy Spec

**EA ID:** QM5_10866
**Slug:** tv-smc-fractal
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA confirms swing highs and swing lows with a symmetric fractal window on closed bars. It opens long when the most recent closed candle closes above the latest confirmed fractal high, and opens short when it closes below the latest confirmed fractal low. Long stops sit below the latest confirmed fractal low with an ATR buffer; short stops sit above the latest confirmed fractal high with the same buffer. Profit target is a fixed R multiple, and an open trade is closed when an opposite confirmed break of structure appears before TP or SL.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fractal_side_bars` | 2 | 1-10 | Bars required on each side of the pivot to confirm a fractal. |
| `strategy_fractal_scan_bars` | 80 | 20-300 | Closed-bar OHLC window used to find the latest confirmed fractal high and low. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the stop buffer and optional volatility filter. |
| `strategy_atr_buffer_mult` | 0.25 | 0.0-2.0 | ATR multiple added beyond the opposite fractal for the stop. |
| `strategy_min_stop_atr_mult` | 0.80 | 0.1-5.0 | Minimum stop distance as a multiple of ATR. |
| `strategy_target_r` | 1.50 | 0.5-5.0 | Fixed reward-to-risk target multiple. |
| `strategy_cooldown_bars` | 3 | 0-20 | Bars to wait after an exit before allowing another entry. |
| `strategy_spread_stop_max_frac` | 0.15 | 0.0-1.0 | Maximum spread as a fraction of planned stop distance. |
| `strategy_use_atr_median_filter` | false | true/false | Enables the optional ATR-above-median dead-range filter from the card. |
| `strategy_atr_median_bars` | 50 | 5-200 | ATR samples used by the optional median filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid DWX forex major with OHLC and ATR history for fractal BOS tests.
- `GBPUSD.DWX` — liquid DWX forex major with structure-break behaviour suitable for the card.
- `XAUUSD.DWX` — liquid DWX metal where ATR-buffered fractal stops are mechanically testable.
- `NDX.DWX` — liquid DWX US index CFD for the card's index-CFD portability claim.
- `GDAXI.DWX` — DWX DAX canonical symbol used as the available matrix port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SPX500.DWX` — not a canonical DWX symbol; S&P 500 exposure would use `SP500.DWX` only if separately requested.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | intraday to multi-session, governed by fixed R target, fractal stop, or opposite BOS |
| Expected drawdown profile | whipsaw-sensitive in choppy local structure |
| Regime preference | breakout / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `SMC Fractal Strategy Jamol v3`, author `JAMOL91`, https://www.tradingview.com/script/97G0VL40-SMC-Fractal-Strategy-Jamol-v3/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10866_tv-smc-fractal.md`

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
| v1 | 2026-06-06 | Initial build from card | 88fec293-b77d-4984-a04b-637f85ced8a9 |
