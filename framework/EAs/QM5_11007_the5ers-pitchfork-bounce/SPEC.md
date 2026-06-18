# QM5_11007_the5ers-pitchfork-bounce — Strategy Spec

**EA ID:** QM5_11007
**Slug:** `the5ers-pitchfork-bounce`
**Source:** `1d445184-7c47-57da-9856-a123682a932d` (The5ers blog: "All You Need to Know About Andrews Pitchforks Strategy")
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Mean-reversion bounce off the outer lines of an Andrews Pitchfork. On each closed
H4 bar the EA finds three confirmed fractal pivots (3-left/3-right) and builds a
deterministic pitchfork: the median line runs from the first pivot (P0) through the
midpoint of the next two pivots (P1, P2), and two parallel outer lines run through
P1 and P2. A bullish pitchfork is a low-high-low triplet with the second low above
the first; a bearish pitchfork is a high-low-high triplet with the second high
below the first.

Long when the just-closed bar's low touches the lower pitchfork line within
0.25·ATR(14), the bar rejects the line (close above it with a lower wick ≥ 50% of
the bar range), and RSI(14) < 35. Short is the mirror at the upper line with
RSI(14) > 65. Stop = touch extreme ± 0.5·ATR. Take-profit = the median line at the
current bar, capped at 2.5R, and the trade is skipped if the median target is less
than 1.0R away. Trades also exit if price closes beyond the touched outer line by
0.25·ATR, or after 24 closed H4 bars (time stop). One position per magic; line
spacing must be ≥ 2·ATR and P0 must be ≥ 30 bars / ≤ 120 bars old.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fractal_width` | 3 | 2-5 | Bars left/right required to confirm a swing pivot |
| `strategy_scan_bars` | 200 | 100-400 | Bounded closed-bar window scanned for pivots |
| `strategy_rsi_period` | 14 | 7-21 | RSI lookback period |
| `strategy_rsi_long_max` | 35.0 | 30-40 | Long requires RSI[1] below this |
| `strategy_rsi_short_min` | 65.0 | 60-70 | Short requires RSI[1] above this |
| `strategy_atr_period` | 14 | 7-21 | ATR period for tolerance / stop / spacing |
| `strategy_touch_atr_mult` | 0.25 | 0.15-0.40 | Touch tolerance and signal-exit overshoot, in ATR |
| `strategy_sl_atr_mult` | 0.5 | 0.3-1.0 | Stop buffer beyond the touch extreme, in ATR |
| `strategy_wick_frac_min` | 0.50 | 0.3-0.7 | Rejection wick must be ≥ this fraction of bar range |
| `strategy_min_spacing_atr` | 2.0 | 1.0-3.0 | Min upper-lower line spacing at entry, in ATR |
| `strategy_min_target_rr` | 1.0 | 0.5-1.5 | Skip if median target < this × R |
| `strategy_tp_cap_rr` | 2.5 | 1.5-3.5 | Cap the median target at this × R |
| `strategy_min_anchor_bars` | 30 | 20-60 | Min bars between P0 and the entry bar |
| `strategy_max_age_bars` | 120 | 60-200 | Expire a pitchfork this many bars after P2 |
| `strategy_time_stop_bars` | 24 | 12-48 | Close after this many closed bars |
| `strategy_spread_pct_of_stop` | 25.0 | 10-50 | Skip if spread > this % of stop distance (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep liquidity, clean H4 swing structure for pitchfork geometry.
- `GBPUSD.DWX` — liquid major with frequent measured retracements.
- `AUDUSD.DWX` — commodity-linked major; respects channel support/resistance.
- `EURJPY.DWX` — cross with strong trending legs and clear median-line behaviour.
- `XAUUSD.DWX` — metal with persistent channel structure; the source cites metals.

**Explicitly NOT for:**
- Index CFDs (`NDX.DWX`, `WS30.DWX`, etc.) — card targets FX/metals only; index
  microstructure and gaps were not part of the source's pitchfork examples.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~24` (card: conservative 12-30) |
| Typical hold time | `hours to a few days (≤ 24 H4 bars ≈ 4 days)` |
| Expected drawdown profile | `shallow, bounded by 0.5·ATR structural stop per trade` |
| Regime preference | `mean-revert (channel support/resistance bounces)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1d445184-7c47-57da-9856-a123682a932d`
**Source type:** `forum` (broker/educational blog — The5ers Team)
**Pointer:** `https://the5ers.com/andrews-pitchfork-strategy/` (Updated July 25, 2021)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11007_the5ers-pitchfork-bounce.md`

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
| v1 | 2026-06-18 | Initial build from card | 2988a363-6fa3-44d7-abe5-7fd4f5f86ad1 |
