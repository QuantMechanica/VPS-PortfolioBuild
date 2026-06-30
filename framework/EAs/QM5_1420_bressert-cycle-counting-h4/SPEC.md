# QM5_1420_bressert-cycle-counting-h4 — Strategy Spec

**EA ID:** QM5_1420
**Slug:** bressert-cycle-counting-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

This EA trades long-only H4 Bressert trough entries. It scans the last 800 H4 bars for Williams 5-bar low pivots, keeps only pivots whose surrounding 41-bar high-to-pivot-low distance is at least 2.5 ATR(14), and requires at least 6 significant troughs.

It computes the median trough-to-trough cycle length and IQR ratio, then allows an entry only when the current closed H4 bar is inside the 0.75x to 1.30x median-cycle trough-projection window. The entry also requires a 1.5 ATR pullback, a 38.2% to 78.6% retracement into the projected trough band, the lowest low over the last 20% of the median cycle, a bullish reversal bar, and a non-downsloping D1 SMA(100) macro filter.

The EA buys at the next bar's market open with an SL at the signal low minus 0.5 ATR(14), capped to a maximum 2.5 ATR risk distance. TP is 80% of the prior cycle amplitude. It closes half at 50% of the TP move and moves the stop to breakeven; remaining exits are TP, SL, Friday close, or the earlier of 1.5 median cycles and 60 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_cycle_window_bars` | 800 | 100+ | H4 bars scanned for significant low-pivot history. |
| `strategy_atr_period` | 14 | 2+ | ATR period used for pivot significance, pullback, SL, and macro filter. |
| `strategy_pivot_side_bars` | 2 | fixed 2 | Williams 5-bar low-pivot side length. |
| `strategy_pivot_swing_window` | 20 | 2+ | Bars on each side of a pivot used to measure pivot significance. |
| `strategy_pivot_atr_mult` | 2.5 | >0 | Minimum surrounding high minus pivot low in ATR units. |
| `strategy_min_pivots` | 6 | 3+ | Minimum significant low pivots required for cycle statistics. |
| `strategy_iqr_max_ratio` | 0.40 | 0-1 | Maximum IQR / median cycle dispersion. |
| `strategy_cycle_min_bars` | 20 | 1+ | Minimum median cycle length in H4 bars. |
| `strategy_cycle_max_bars` | 120 | >min | Maximum median cycle length in H4 bars. |
| `strategy_projection_min_mult` | 0.75 | >0 | Lower bound for bars since last trough divided by median cycle. |
| `strategy_projection_max_mult` | 1.30 | >min | Upper bound for bars since last trough divided by median cycle. |
| `strategy_pullback_atr_mult` | 1.5 | >0 | Minimum pullback from post-trough high in ATR units. |
| `strategy_retrace_min` | 0.382 | 0-1 | Minimum pullback retracement fraction. |
| `strategy_retrace_max` | 0.786 | 0-1 | Maximum pullback retracement fraction. |
| `strategy_local_low_cycle_frac` | 0.20 | 0-1 | Recent-bar window, as fraction of median cycle, for local-low confirmation. |
| `strategy_tp_amplitude_mult` | 0.80 | >0 | Prior-cycle amplitude fraction projected as TP distance. |
| `strategy_partial_close_fraction` | 0.50 | 0-1 | Position fraction to close at partial target. |
| `strategy_partial_move_fraction` | 0.50 | 0-1 | Fraction of TP move that triggers partial close and breakeven. |
| `strategy_time_exit_cycle_mult` | 1.50 | >0 | Median-cycle multiplier for time exit. |
| `strategy_time_exit_max_bars` | 60 | 1+ | Maximum H4 bars held. |
| `strategy_failure_first_bars` | 8 | 1+ | First bars where failure-level hard exit is active. |
| `strategy_sl_atr_mult` | 0.5 | >0 | ATR buffer below the signal low for initial SL. |
| `strategy_sl_max_atr_mult` | 2.5 | >0 | Maximum initial risk distance in ATR units. |
| `strategy_spread_atr_mult` | 0.25 | >=0 | Entry blocked only when positive spread exceeds this ATR fraction. |
| `strategy_macro_sma_period` | 100 | 2+ | D1 SMA period for macro-bias filter. |
| `strategy_macro_slope_bars` | 20 | 1+ | D1 bars used to measure SMA slope. |
| `strategy_macro_slope_atr_mult` | 0.03 | >=0 | Allowed negative D1 SMA slope per bar in ATR units. |
| `strategy_news_blackout_h4_bars` | 2 | >=0 | High-impact news blackout on both sides, in H4 bars. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`; only strategy-specific inputs are listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — FX major with native H4 DWX OHLC.
- `GBPUSD.DWX` — FX major with native H4 DWX OHLC.
- `USDJPY.DWX` — FX major with native H4 DWX OHLC.
- `AUDUSD.DWX` — FX major with native H4 DWX OHLC.
- `USDCAD.DWX` — FX major with native H4 DWX OHLC.
- `USDCHF.DWX` — FX major with native H4 DWX OHLC.
- `NZDUSD.DWX` — FX major with native H4 DWX OHLC.
- `XAUUSD.DWX` — gold CFD named in the card's R3 portable basket.
- `XTIUSD.DWX` — oil CFD named in the card's R3 portable basket.
- `NDX.DWX` — Nasdaq 100 index CFD named in the card's R3 portable basket.
- `WS30.DWX` — Dow 30 index CFD named in the card's R3 portable basket.
- `GDAXI.DWX` — DAX index CFD named in the card's R3 portable basket.
- `UK100.DWX` — FTSE 100 index CFD named in the card's R3 portable basket.

**Explicitly NOT for:**
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` — unavailable or non-canonical S&P variants in the DWX matrix.
- Non-DWX symbols — registry and backtest artifacts must retain `.DWX` suffix discipline.
- Symbols without stable H4 OHLC history — the cycle-statistics gate needs at least 800 H4 bars plus warmup.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 SMA(100) slope and D1 ATR(14) for macro-bias filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to min(1.5 median cycles, 60 H4 bars), usually hours to several days |
| Expected drawdown profile | Mean-reversion pullback strategy with ATR-capped single-trade risk |
| Regime preference | Cycle mean-reversion after a pullback, filtered against strong daily downtrends |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** book / forum cluster
**Pointer:** Walter Bressert, *The Power of Oscillator/Cycle Combinations* (1991), Bressert + Jones, *The Power Cycle Trading Toolbox* (1995), and the approved card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1420_bressert-cycle-counting-h4.md`
**R1–R4 verdict (Q00):** all R1–R4 PASS per `artifacts/cards_approved/QM5_1420_bressert-cycle-counting-h4.md`

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
| v1 | 2026-06-30 | Initial build from card | 49efb87c-ac1e-4232-ab19-eeb012918f64 |
