# QM5_10165_tv-postopen-bb-atr - Strategy Spec

**EA ID:** QM5_10165
**Slug:** `tv-postopen-bb-atr`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

This EA trades long-only post-open resistance breakouts on intraday bars. It only considers entries during the 08:00-12:00 or 15:30-19:00 post-open windows, requires the setup to be near the Bollinger basis after lateralization, then buys when the latest closed bar breaks above the 20-bar resistance zone. The breakout must also close above EMA(10) and EMA(200), with RSI(7) above 30 and ADX(7) above 10. A fixed ATR bracket is placed at entry: stop loss 2.0 x ATR(14) below entry and take profit 4.0 x ATR(14) above entry; any remaining position is closed when the post-open window ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 14 | 5-50 | Bollinger Bands lookback for lateralization |
| `strategy_bb_deviation` | 1.5 | 0.5-4.0 | Bollinger standard-deviation multiplier |
| `strategy_bb_near_basis_frac` | 0.50 | 0.0-1.0 | Maximum setup-candle distance from Bollinger basis as a fraction of half-band width |
| `strategy_ema_fast_period` | 10 | 2-50 | Fast EMA filter period |
| `strategy_ema_slow_period` | 200 | 50-400 | Slow EMA trend filter period |
| `strategy_rsi_period` | 7 | 2-50 | RSI filter period |
| `strategy_rsi_min` | 30.0 | 0.0-100.0 | Minimum RSI value allowed for long entries |
| `strategy_adx_period` | 7 | 2-50 | ADX trend-strength period |
| `strategy_adx_min` | 10.0 | 0.0-100.0 | Minimum ADX value allowed for long entries |
| `strategy_resistance_bars` | 20 | 5-100 | Closed bars used to identify resistance |
| `strategy_resistance_touches` | 2 | 1-10 | Minimum highs near resistance required |
| `strategy_touch_tolerance_atr` | 0.20 | 0.0-1.0 | Resistance touch tolerance as a fraction of ATR |
| `strategy_atr_period` | 14 | 2-100 | ATR period for spread, stop, and target distances |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | Stop-loss distance in ATR multiples |
| `strategy_atr_tp_mult` | 4.0 | 0.1-20.0 | Take-profit distance in ATR multiples |
| `strategy_max_spread_sl_frac` | 0.15 | 0.0-1.0 | Maximum spread as a fraction of ATR stop distance |
| `strategy_de_open_start_hhmm` | 800 | 0-2359 | German post-open window start in broker HHMM |
| `strategy_de_open_end_hhmm` | 1200 | 0-2359 | German post-open window end in broker HHMM |
| `strategy_us_open_start_hhmm` | 1530 | 0-2359 | US post-open window start in broker HHMM |
| `strategy_us_open_end_hhmm` | 1900 | 0-2359 | US post-open window end in broker HHMM |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index exposure fits the card's post-open breakout premise.
- `WS30.DWX` - Dow 30 index exposure fits the card's US post-open breakout premise.
- `GDAXI.DWX` - Canonical DWX DAX symbol; used as the available port for the card's GER40 baseline.
- `XAUUSD.DWX` - Gold is explicitly listed by the card as a portable DWX baseline market.
- `EURUSD.DWX` - Major FX pair explicitly listed by the card as a portable DWX baseline market.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- Any symbol not registered above - magic resolution blocks unregistered symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` or `M15` per card; Q01 smoke uses `M5` to exercise the higher-frequency card variant |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | intraday, no overnight holding |
| Expected drawdown profile | bounded fixed-risk breakout drawdown under framework risk controls |
| Regime preference | volatility-expansion breakout after post-open compression |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView script`
**Pointer:** `https://www.tradingview.com/script/wApzruR3/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10165_tv-postopen-bb-atr.md`

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
| v1 | 2026-05-25 | Initial build from card | 74fe4c97-4c5e-4ad6-8782-e7a2fc06f41c |
| v2 | 2026-06-04 | Q01 rework: evaluate BB lateralization on setup candle and use highest two-touch resistance level | b1747809-4fa1-4ee9-b336-f5893e4bcd27 |
