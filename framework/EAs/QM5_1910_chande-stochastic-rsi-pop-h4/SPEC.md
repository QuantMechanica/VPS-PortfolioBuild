# QM5_1910_chande-stochastic-rsi-pop-h4 - Strategy Spec

**EA ID:** QM5_1910
**Slug:** chande-stochastic-rsi-pop-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades Chande and Kroll's Stochastic RSI on H4 bars. It buys when StochRSI has spent two closed H4 bars below 20, then exits above 20 while above its 3-bar signal line and the latest closed H4 price is above the D1 EMA(50). It sells on the mirrored overbought failure below 80 while price is below the D1 EMA(50). Positions use a 2.5 x ATR(20, H4) initial stop, start a 2.0 x ATR trailing stop after a 1.5 x ATR favorable move, and close on StochRSI midline cross, opposite-zone touch, or a 24-H4-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 5-50 | Wilder RSI period used as the StochRSI input buffer. |
| `strategy_stoch_rsi_period` | 14 | 5-50 | Rolling RSI min/max window for StochRSI normalization. |
| `strategy_signal_period` | 3 | 1-20 | SMA period applied to StochRSI for signal-line confirmation. |
| `strategy_oversold_level` | 20.0 | 1-49 | Oversold recovery threshold for long entries and short completion exits. |
| `strategy_overbought_level` | 80.0 | 51-99 | Overbought failure threshold for short entries and long completion exits. |
| `strategy_midline_level` | 50.0 | 20-80 | StochRSI mean-reversion midline used for signal exits. |
| `strategy_d1_ema_period` | 50 | 10-200 | D1 EMA macro-regime filter period. |
| `strategy_atr_period` | 20 | 5-80 | ATR period for stop placement, trailing, spread cap, and D1 slope threshold. |
| `strategy_initial_sl_atr_mult` | 2.5 | 0.5-8.0 | Initial protective stop distance as a multiple of H4 ATR. |
| `strategy_trail_atr_mult` | 2.0 | 0.5-8.0 | Trailing stop distance after the favorable-move trigger. |
| `strategy_trail_start_atr_mult` | 1.5 | 0.5-5.0 | Favorable move in ATRs required before ATR trailing begins. |
| `strategy_spread_atr_mult` | 0.35 | 0.05-1.00 | Entry is blocked only when modeled spread exceeds this share of H4 ATR. |
| `strategy_time_stop_h4_bars` | 24 | 4-80 | Maximum holding period in H4 bars before time-stop exit. |
| `strategy_ema_slope_lookback_d1` | 5 | 1-20 | D1 bars used to measure EMA slope for trend-strength gating. |
| `strategy_ema_slope_atr_mult` | 0.5 | 0.0-3.0 | D1 ATR multiple defining a strongly adverse EMA slope. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - Chande's canonical S&P futures example is testable on the approved S&P 500 custom symbol.
- `NDX.DWX` - US large-cap index proxy included in the card's portable index universe.
- `WS30.DWX` - Dow 30 index proxy included in the card's portable index universe.
- `GDAXI.DWX` - DAX 40 global index proxy available in the DWX matrix.
- `UK100.DWX` - FTSE 100 global index proxy available in the DWX matrix.
- `EURUSD.DWX` - standard FX major matching the card's instrument-relative FX portability statement.
- `GBPUSD.DWX` - standard FX major matching the card's instrument-relative FX portability statement.
- `USDJPY.DWX` - standard FX major matching the card's instrument-relative FX portability statement.
- `USDCHF.DWX` - standard FX major matching the card's instrument-relative FX portability statement.
- `USDCAD.DWX` - standard FX major matching the card's instrument-relative FX portability statement.
- `AUDUSD.DWX` - standard FX major matching the card's instrument-relative FX portability statement.
- `NZDUSD.DWX` - standard FX major matching the card's instrument-relative FX portability statement.
- `XAUUSD.DWX` - gold exposure listed in the card's R3 portability section.
- `XTIUSD.DWX` - crude-oil exposure listed in the card's R3 portability section.

**Explicitly NOT for:**
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable aliases; the canonical S&P 500 custom symbol is `SP500.DWX`.
- Non-DWX broker symbols - research and backtest artifacts must keep the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 EMA(50) regime filter and D1 ATR(20) EMA-slope threshold |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Up to 24 H4 bars, about 4 days |
| Expected drawdown profile | Mean-reversion drawdowns controlled by ATR stop, ATR trailing after confirmation, and time stop. |
| Regime preference | Mean-reversion entries aligned with the D1 EMA regime. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** book, journal, forum
**Pointer:** Tushar S. Chande and Stanley Kroll, *The New Technical Trader* (1994), chapter 4; ForexFactory Stochastic RSI threads referenced by the approved card.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1910_chande-stochastic-rsi-pop-h4.md`

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
| v1 | 2026-07-07 | Initial build from card | c97ee8fa-6763-4bb1-b1be-5ca65e2748ef |
