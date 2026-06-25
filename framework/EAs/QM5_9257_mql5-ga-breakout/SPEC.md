# QM5_9257_mql5-ga-breakout - Strategy Spec

**EA ID:** QM5_9257
**Slug:** mql5-ga-breakout
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA scans closed H1 bars for Bill Williams-style fractal swing points and requires three consecutive alternating swings to define an internal consolidation range. A setup locks only when the range height is ATR-bounded, the latest swing is near the active boundary, recent price has touched that boundary, and at least two geometric asymmetry votes pass: distance expansion, slope expansion, and time compression. A locked bullish setup enters when the next closed bar breaks above the range high; a locked bearish setup enters when the next closed bar breaks below the range low. The stop is placed outside the opposite side of the locked range by 0.5 ATR, the take profit is the closer of 2.5R and one projected range height, and an open trade closes if a later closed bar returns inside the locked range.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_fractal_strength | 2 | >= 1 | Left/right closed bars required for a fractal swing. |
| strategy_lookback_bars | 160 | >= 24 | Bounded H1 bar window used for the fractal/range scan. |
| strategy_min_structure_bars | 8 | >= 1 | Minimum span from oldest to latest swing in the three-swing structure. |
| strategy_atr_period | 14 | >= 1 | ATR period for range qualification and stops. |
| strategy_min_range_atr | 0.60 | > 0 | Minimum locked range height as ATR multiple. |
| strategy_max_range_atr | 3.00 | > min | Maximum locked range height as ATR multiple. |
| strategy_distance_ratio | 1.20 | >= 1 | Latest swing leg must exceed prior leg by this ratio for the distance vote. |
| strategy_slope_ratio | 1.20 | >= 1 | Latest swing slope must exceed prior swing slope by this ratio for the slope vote. |
| strategy_time_compression_ratio | 0.80 | 0-1 | Latest swing duration must be within this fraction of prior duration for the compression vote. |
| strategy_min_geometry_votes | 2 | 1-3 | Minimum directional geometry votes needed to lock a setup. |
| strategy_boundary_atr_mult | 0.25 | >= 0 | ATR distance used for final-swing and recent-boundary-touch proximity. |
| strategy_boundary_touch_bars | 6 | >= 1 | Recent closed bars checked for range-boundary interaction. |
| strategy_max_lock_bars | 12 | >= 1 | Bars after which an untriggered locked setup expires. |
| strategy_min_bars_between_signals | 6 | >= 0 | Cooldown after an entry before locking another setup. |
| strategy_stop_atr_mult | 0.50 | > 0 | ATR buffer outside the locked range for stop placement. |
| strategy_take_profit_rr | 2.50 | > 0 | R-multiple candidate for the take-profit cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed forex major with DWX OHLC and ATR history available.
- GBPJPY.DWX - card-listed forex cross with DWX OHLC and ATR history available.
- NDX.DWX - DWX alias for the card's NAS100/Nasdaq 100 target.

**Explicitly NOT for:**
- NAS100.DWX - not present in `dwx_symbol_matrix.csv`; mapped to NDX.DWX for build registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Hours to a few days, bounded by range-breakout SL/TP or return-inside-range close |
| Expected drawdown profile | Breakout system with clustered losses during failed consolidation breaks |
| Regime preference | Volatility-expansion breakout after fractal consolidation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** article
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 59): Using Geometric Asymmetry to Identify Precision Breakouts from Fractal Consolidation", MQL5 Articles, 2026-02-09, https://www.mql5.com/en/articles/21197
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9257_mql5-ga-breakout.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-25 | Initial build from card | 29057df6-055f-4a88-9d58-26eaf34da91b |
