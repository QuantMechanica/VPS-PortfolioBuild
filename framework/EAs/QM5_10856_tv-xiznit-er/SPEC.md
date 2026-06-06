# QM5_10856_tv-xiznit-er - Strategy Spec

**EA ID:** QM5_10856
**Slug:** tv-xiznit-er
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView Xiznit Advanced Scalper card)
**Author of this spec:** Claude
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

A regime-gated intraday trend scalper. On each closed bar the EA computes the
Kaufman Efficiency Ratio (ER) over the last `er_length` bars, a session-anchored
VWAP, and a fast/slow EMA pair. The market is classified "uptrend" when ER is at
or above `er_trend_threshold` AND the fast EMA is above the slow EMA AND both EMAs
and the bar close are above VWAP; "downtrend" is the mirror; otherwise
"non-trending". A long fires on the first bar that transitions from non-trending
into a fully-aligned uptrend, provided the prior bar already had fast>slow MA
alignment, both EMAs are sloping up, the signal candle body is at least
`min_body_atr_frac * ATR`, and the candle closes beyond the prior bar's high
(short is the mirror with prior-bar low). A fixed ATR bracket is attached at
entry (stop = `atr_sl_mult * ATR`, target = `atr_tp_mult * ATR`). The position is
closed immediately when the ER regime shifts away from the trade direction, at
the broker-time EOD flatten (23:58, = 15:58 CST), and otherwise by its SL/TP. New
entries are blocked during the first 20 minutes of the NY session, the CST lunch
hour, and after the EOD flatten time. A spread guard skips entries whose spread
exceeds 15% of the stop distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `er_length` | 20 | 10-30 | Kaufman Efficiency Ratio lookback (bars) |
| `er_trend_threshold` | 0.30 | 0.0-1.0 | ER at/above this = trending regime |
| `fast_ma_period` | 9 | 5-20 | Fast EMA period |
| `slow_ma_period` | 21 | 15-60 | Slow EMA period |
| `strat_atr_period` | 14 | 5-30 | ATR period for the bracket |
| `atr_sl_mult` | 1.0 | 0.5-2.0 | Stop distance = mult * ATR |
| `atr_tp_mult` | 1.0 | 0.5-2.0 | Target distance = mult * ATR |
| `min_body_atr_frac` | 0.10 | 0.0-1.0 | Min signal-candle body as fraction of ATR |
| `spread_guard_frac` | 0.15 | 0.0-1.0 | Skip entry if spread > frac * stop distance |
| `ny_open_hour_broker` | 16 | 0-23 | NY RTH open hour, broker time (08:30 CST) |
| `ny_open_min_broker` | 30 | 0-59 | NY RTH open minute, broker time |
| `ny_open_block_minutes` | 20 | 0-120 | Block first N min of NY session |
| `lunch_start_hour_broker` | 20 | 0-23 | CST lunch start (12:00 CST), broker time |
| `lunch_end_hour_broker` | 21 | 0-23 | CST lunch end (13:00 CST), broker time |
| `eod_flat_hour_broker` | 23 | 0-23 | EOD flatten hour (15:58 CST), broker time |
| `eod_flat_min_broker` | 58 | 0-59 | EOD flatten minute, broker time |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are
> documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Nasdaq 100; high-cadence trending index, primary P2/live symbol.
- `WS30.DWX` — Dow 30; liquid US large-cap index, live-tradable.
- `GDAXI.DWX` — DAX 40; the card's "GER40" maps to the matrix name GDAXI.DWX.
- `XAUUSD.DWX` — Gold; the card's metals leg, strong intraday trends.
- `XAGUSD.DWX` — Silver; second metals leg, complements gold.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (not broker-routable); not in this card's R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` (card baseline M2/M5; M5 chosen for the P2 baseline) |
| Multi-timeframe refs | `none` (all reads on the chart timeframe) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~120` |
| Typical hold time | `minutes to a few hours (intraday, EOD-flat)` |
| Expected drawdown profile | `frequent small fixed-bracket losses; trend runners` |
| Regime preference | `trend (ER-gated trend continuation)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `forum` (TradingView open-source community strategy)
**Pointer:** `https://www.tradingview.com/script/qP7M4QtD-Xiznit-Advanced-Scalper/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10856_tv-xiznit-er.md`

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
| v1 | 2026-06-06 | Initial build from card | 69a6b57e-316a-4590-8134-b8e7d0feffac |
