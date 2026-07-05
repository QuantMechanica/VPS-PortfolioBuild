# QM5_10209_tv-atr-ema-session — Strategy Spec

**EA ID:** QM5_10209
**Slug:** `tv-atr-ema-session`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/tradingview-popular-pine-scripts/`)
**Author of this spec:** Claude
**Last revised:** 2026-07-05

---

## 1. Strategy Logic

The EA operates on M15 or M30 bars (set via setfile) inside a per-symbol liquid-hours session window expressed in broker time. It computes ATR(25) and EMA(50) on the signal timeframe. Long entries are triggered when price crosses above EMA(50) on a closed bar AND the current ATR, normalised to broker price points, is below the long threshold (low-volatility regime allows longs). Short entries are triggered when price crosses below EMA(50) AND ATR in points is above the short threshold (high-volatility regime allows shorts). The EMA cross is the single trigger event; the ATR regime is a concurrent state filter. Each position exits on the first of: take profit at 5x ATR, stop loss at 10x ATR (both broker-managed), or session end (force-flat at the session close time). Daily entry count is capped at 3 per source default.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_CURRENT` | M15/M30 | Signal timeframe; resolves from chart TF if PERIOD_CURRENT |
| `strategy_atr_period` | 25 | 5-100 | ATR lookback period |
| `strategy_ema_period` | 50 | 5-200 | EMA lookback period |
| `strategy_long_atr_points_max` | 20.0 | >0 | Max ATR-in-points for long entry permission (low-vol regime) |
| `strategy_short_atr_points_min` | 25.0 | >0 | Min ATR-in-points for short entry permission (high-vol regime) |
| `strategy_sl_atr_mult` | 10.0 | >0 | Stop loss distance as ATR multiple |
| `strategy_tp_atr_mult` | 5.0 | >0 | Take profit distance as ATR multiple |
| `strategy_max_daily_trades` | 3 | >=1 | Maximum entries per broker day |
| `strategy_spread_atr_fraction` | 0.10 | >=0 | Max spread as fraction of ATR stop distance; 0 = disabled |
| `strategy_session_start_hour` | -1 | -1 to 23 | Session start hour in broker time; -1 = use per-symbol default |
| `strategy_session_start_min` | -1 | -1 to 59 | Session start minute in broker time; -1 = use per-symbol default |
| `strategy_session_end_hour` | -1 | -1 to 23 | Session end hour in broker time; -1 = use per-symbol default |
| `strategy_session_end_min` | -1 | -1 to 59 | Session end minute in broker time; -1 = use per-symbol default |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — Card target; DAX 40 index CFD; broker session window: 10:00-18:30 broker time (DAX cash 09:00-17:30 CET).
- `NDX.DWX` — Card target; Nasdaq 100 index CFD; broker session: 16:30-23:00 (US cash open 09:30 ET).
- `WS30.DWX` — Card target; Dow 30 index CFD; same US cash session as NDX.
- `XAUUSD.DWX` — Card target; spot gold CFD; London/NY liquid hours: 09:00-17:30 broker time.
- `EURUSD.DWX` — Card target; major FX pair; London/NY liquid hours: 09:00-17:30 broker time.

**Explicitly NOT for:**
- Symbols with session dynamics that don't fit intraday EMA/ATR momentum (e.g. thin Asian-only instruments).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` (primary per card); `M30` also supported via setfile override |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~120 |
| Typical hold time | Intraday; flat by session end |
| Expected drawdown profile | Moderate; 10x ATR stop, 5x ATR target (2:1 RR inverse) |
| Regime preference | Intraday momentum with volatility-regime switch |
| Win rate target (qualitative) | Medium; asymmetric ATR thresholds for long/short |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/uKRleT8B-ATR-EMA-Strategy/ (author: whitebear28, published 2026-04-13)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10209_tv-atr-ema-session.md`

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
| v1 | 2026-05-24 | Initial build from card | prior session |
| v2 | 2026-07-05 | OnTick ordering fix (2026-07-02 audit); SPEC.md rewritten to validator format; M15 setfiles added | 90a99219-7aef-4392-828b-9be553c73c0a |
