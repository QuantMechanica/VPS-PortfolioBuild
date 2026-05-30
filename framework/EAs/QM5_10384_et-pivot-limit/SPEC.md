# QM5_10384_et-pivot-limit - Strategy Spec

**EA ID:** QM5_10384
**Slug:** `et-pivot-limit`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

On each completed M15 bar, the EA computes typical price as `(close + high + low) / 3` and an EMA of the recent high-low range. It places a long limit below typical price and a short limit above typical price by `strategy_offset_mult * EMA(range)`, both expiring after one bar. If a position remains open after one completed M15 bar, or the instrument enters the final session-edge window, the EA closes it. A protective stop is placed at `strategy_atr_sl_mult * ATR(20)` from the entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_ema_length` | 3 | 1-50 | EMA length applied to completed-bar high-low range. |
| `strategy_offset_mult` | 0.50 | 0.10-2.00 | Multiplier applied to EMA(range) to place the buy/sell limit bands. |
| `strategy_atr_period` | 20 | 2-100 | ATR lookback for the protective stop. |
| `strategy_atr_sl_mult` | 1.00 | 0.25-5.00 | ATR multiple used for the protective stop distance. |
| `strategy_pending_expiry_bars` | 1 | 1-4 | Number of base timeframe bars before unfilled limits expire. |
| `strategy_min_stop_spread_mult` | 4 | 1-20 | Minimum stop distance in current spread multiples. |
| `strategy_session_edge_minutes` | 15 | 0-120 | Minutes after session open and before session close where new entries are blocked and open trades are closed. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 large-cap index exposure from the card's R3 basket; backtest-only per DWX symbol discipline.
- `NDX.DWX` - Nasdaq 100 liquid US index exposure from the card's R3 basket.
- `WS30.DWX` - Dow 30 liquid US index exposure from the card's R3 basket.
- `GDAXI.DWX` - Verified DWX DAX symbol used for the card's `GER40.DWX` target.
- `EURUSD.DWX` - Major FX pair from the card's R3 basket.
- `XAUUSD.DWX` - Gold/metals exposure from the card's R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical DWX S&P 500 symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | one completed M15 bar |
| Expected drawdown profile | High-turnover intraday mean reversion with cost and adverse-selection sensitivity. |
| Regime preference | intraday mean-revert / volatility-band |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/example-that-works.26440/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10384_et-pivot-limit.md`

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
| v1 | 2026-05-25 | Initial build from card | 3a6e1e97-7d84-4a4d-a537-757820eb6cc2 |
