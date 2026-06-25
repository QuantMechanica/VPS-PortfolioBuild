# QM5_10095_gh-ict-orderblk - Strategy Spec

**EA ID:** QM5_10095
**Slug:** gh-ict-orderblk
**Source:** 3b3ec48a-0755-5187-9331-afb36e174175
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades H1 order-block reversals in the direction of a weekly-open bias. A buy can open when price is above the current week's Monday open, the previous H1 candle is a bearish order-block candle, its close is the lowest close across the shifted lookback window, price has traded back above that candle's open, and SMA(5) has stayed above SMA(30) for the lookback. A sell mirrors the rule below the weekly open with a bullish order-block candle, highest shifted close, price back below the candle open, and SMA(5) below SMA(30). The EA blocks oversized H1 candles when the previous H1 range exceeds 80% of the five-day average D1 body, opens at market with the previous H1 low/high as stop, sets 3R or 4R take profit from the average daily body threshold, and moves the stop one initial-risk distance beyond entry after price reaches 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_order_block_threshold_pct | 10 | >0 | Minimum previous-candle body as percent of total H1 range. |
| strategy_lookback | 24 | >=1 | Shifted H1 close window and SMA trend-state window. |
| strategy_fast_sma | 5 | >=1 | Fast H1 SMA period. |
| strategy_slow_sma | 30 | >=1 | Slow H1 SMA period. |
| strategy_daily_body_days | 5 | >=1 | Number of closed D1 bars used for average absolute open-close body. |
| strategy_h1_range_to_d1_body_max | 0.80 | >0 | Blocks entries when previous H1 range is greater than this fraction of average D1 body. |
| strategy_tp_body_threshold | 10.0 | >=0 | Raw source-unit average D1 body threshold for selecting 4R instead of 3R. |
| strategy_tp_rr_low_body | 3.0 | >0 | Take-profit R multiple when average D1 body is below the threshold. |
| strategy_tp_rr_high_body | 4.0 | >0 | Take-profit R multiple when average D1 body is at or above the threshold. |
| strategy_weekly_open_lookback_bars | 240 | >=30 recommended | H1 bars searched to find the current week's first Monday/broker-week open. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed DWX forex target using H1/D1 OHLC and SMA only.
- XAUUSD.DWX - card-listed DWX metals target using the same OHLC/SMA mechanics.
- GDAXI.DWX - DWX matrix DAX equivalent for the card's GDAXI.DWX target.

**Explicitly NOT for:**
- GDAXI.DWX - card-stated name is not present in `framework/registry/dwx_symbol_matrix.csv`; registered as GDAXI.DWX instead.
- Non-DWX symbols - V5 research and backtest registry requires `.DWX` symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | D1 average absolute open-close body over 5 closed bars |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Not specified in card; expected H1 intraday to multi-day until SL, TP, 2R stop move, or Friday close |
| Expected drawdown profile | Not specified in card; fixed-risk single-position reversal profile |
| Regime preference | Weekly-open directional bias with H1 order-block reversal and SMA trend-state confirmation |
| Win rate target (qualitative) | Not specified in card; 3R/4R target implies medium-to-low win rate tolerance |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3b3ec48a-0755-5187-9331-afb36e174175
**Source type:** GitHub repository
**Pointer:** https://github.com/darula-hpp/ict-ea, file `ICT_EA.mq5`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10095_gh-ict-orderblk.md`

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
| v1 | 2026-06-20 | Initial build from card | 7322e316-c498-475e-975f-49d16bdfbe3d |
