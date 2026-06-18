# QM5_11016_the5ers-fib-breaker — Strategy Spec

**EA ID:** QM5_11016
**Slug:** `the5ers-fib-breaker`
**Source:** `1d445184-7c47-57da-9856-a123682a932d` (The5ers blog interview, Billy A.)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

H1 trend-continuation entries filtered by a Daily (D1) directional bias, traded
only during the London session. The D1 bias is bullish when the last closed D1
bar closes above EMA(D1, 50) and the latest confirmed D1 swing high and swing
low are both higher than their previous counterparts (mirror for bearish). On
H1, the latest impulse leg in the bias direction is anchored to the two most
recent confirmed opposing fractal swing pivots, and a Fibonacci retracement is
drawn over that leg. A long fires when price has retraced into the 50.0%–61.8%
zone, the signal bar (last closed H1) closes above the high of the last bearish
candle inside the zone (a bullish "breaker"), and that signal bar is bullish and
closes in the top 40% of its range; shorts are the mirror. The stop sits 0.5×
ATR(H1, 14) beyond the retracement swing extreme; the take-profit is a fixed
2.0R bracket. Discretionary exits: H1 closes beyond the 61.8% line against the
position (signal failure) or 30 H1 bars elapse (time stop).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_bias_period` | 50 | 20-100 | D1 EMA period for the directional bias |
| `strategy_d1_fractal_k` | 2 | 1-4 | D1 swing-pivot fractal half-width (bars each side) |
| `strategy_swing_fractal_k` | 2 | 1-4 | H1 swing-pivot fractal half-width |
| `strategy_swing_scan_bars` | 90 | 40-200 | H1 bars scanned for confirmed pivots |
| `strategy_fib_lo` | 50.0 | 38.2-61.8 | Retracement zone lower bound (% of impulse) |
| `strategy_fib_hi` | 61.8 | 50.0-78.6 | Retracement zone upper bound (% of impulse) |
| `strategy_min_impulse_atr` | 2.0 | 1.0-4.0 | Skip impulse smaller than mult×ATR(H1) |
| `strategy_max_retrace_bars` | 24 | 6-48 | Skip retracements older than N H1 bars |
| `strategy_atr_period` | 14 | 7-28 | ATR(H1) period for the stop buffer |
| `strategy_sl_atr_mult` | 0.5 | 0.25-1.5 | Stop buffer = mult×ATR beyond the swing |
| `strategy_rr_target` | 2.0 | 1.0-3.0 | Take-profit as N×R |
| `strategy_time_stop_bars` | 30 | 10-60 | Close the position after N H1 bars |
| `strategy_signal_close_frac` | 0.60 | 0.5-0.8 | Signal bar must close in top/bottom (1-frac) of range |
| `strategy_london_start_uk` | 8 | 6-10 | London session start, UK local hour |
| `strategy_london_end_uk` | 16 | 14-18 | London session end, UK local hour |
| `strategy_spread_pct_of_stop` | 20.0 | 5-50 | Skip if spread > this % of the stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity London-session major; clean swing structure.
- `GBPUSD.DWX` — London-centric major with strong intraday impulse legs.
- `USDJPY.DWX` — major with consistent trend persistence for D1-bias filtering.
- `XAUUSD.DWX` — high-volatility metal; impulse/retracement structure is pronounced.
- `GDAXI.DWX` — DAX 40 index; ported from the card's `GER40.DWX` (GER40 is not in
  `dwx_symbol_matrix.csv`; GDAXI.DWX is the canonical DAX symbol). London-overlap
  European cash index, fits the London-session bias filter well.

**Explicitly NOT for:**
- `SP500.DWX` / US-only indices — the edge is London-session-anchored; US cash
  session falls outside the trading window.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` (bias: EMA + swing structure) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~60` |
| Typical hold time | `hours to a few days (intraday-to-swing, ≤30 H1 bars)` |
| Expected drawdown profile | `moderate; structural stop ~0.5 ATR beyond swing, 2R target` |
| Regime preference | `trend (continuation pullback)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1d445184-7c47-57da-9856-a123682a932d`
**Source type:** `forum` (broker blog / trader interview)
**Pointer:** `https://the5ers.com/most-important-thing-in-forex/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11016_the5ers-fib-breaker.md`

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
| v1 | 2026-06-18 | Initial build from card | deb6a030-da5c-4ebd-963c-8277a29ac811 |
