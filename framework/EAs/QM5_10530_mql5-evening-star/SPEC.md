# QM5_10530_mql5-evening-star - Strategy Spec

**EA ID:** QM5_10530
**Slug:** `mql5-evening-star`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates completed H1 bars and looks for a bearish Evening Star over the last three closed candles. Candle 3 must be a bullish wide-body candle, candle 2 must be smaller and optionally gap above candle 3's body, and candle 1 must be bearish and close back inside candle 3's body. When the pattern is present and no same-symbol magic position is open, the EA sells at market on the new bar. The stop is placed beyond the pattern high plus spread buffer or 1.0 ATR(14), whichever is farther; take profit is 1.5R, with a time stop after 8 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR lookback used for the normalized stop distance. |
| `strategy_atr_sl_mult` | 1.0 | 0.1-5.0 | ATR multiplier for the volatility stop floor. |
| `strategy_tp_rr` | 1.5 | 0.5-5.0 | Take-profit multiple of initial risk. |
| `strategy_time_stop_bars` | 8 | 1-48 | Maximum H1 bars to hold before strategy close. |
| `strategy_require_gap` | true | true/false | Require candle 2 to gap above candle 3's body. |
| `strategy_require_candle_size` | true | true/false | Enable source-style candle body size checks. |
| `strategy_middle_body_max_ratio` | 0.50 | 0.1-1.0 | Maximum candle 2 body as a fraction of candle 3 body. |
| `strategy_wide_body_min_ratio` | 1.50 | 1.0-5.0 | Minimum candle 3 body relative to candle 2 body. |
| `strategy_min_body_range_fraction` | 0.50 | 0.1-1.0 | Minimum wide candle body as a fraction of its full range. |
| `strategy_max_spread_points` | 0 | 0-1000 | Optional no-trade spread ceiling; 0 disables the strategy-level ceiling. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Primary liquid FX major from the card's P2 basket.
- `GBPUSD.DWX` - Liquid FX major from the card's P2 basket.
- `USDJPY.DWX` - Liquid FX major from the card's P2 basket.
- `XAUUSD.DWX` - Liquid metal symbol from the card's P2 basket.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - not available for DWX backtesting.
- Equity index symbols - not part of the approved card basket for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | Up to 8 H1 bars |
| Expected drawdown profile | Reversal-pattern losses are bounded by pattern/ATR stop and fixed-risk sizing. |
| Regime preference | Candlestick reversal after short-term bullish exhaustion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase strategy
**Pointer:** `https://www.mql5.com/en/code/18507`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10530_mql5-evening-star.md`

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
| v1 | 2026-05-29 | Initial build from card | fe23b303-cb95-4b1a-a42c-3ab735de5cf3 |
