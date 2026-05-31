# QM5_10738_tv-yd-range - Strategy Spec

**EA ID:** QM5_10738
**Slug:** `tv-yd-range`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

At the start of each broker day, the EA reads the current D1 open and the prior confirmed D1 high-low range. It places one long buy-stop for the session at `today_open + yesterday_range * multiplier`, with default multiplier 0.25. If the stop fills, the position is closed at the configured session close; if it does not fill, the pending buy-stop is cancelled at that same session close. The source had no stop, so the implementation uses the card's V5 safety stop of `1.5 * ATR(14)` below entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_multiplier` | 0.25 | > 0 | Fraction of yesterday's D1 range added to today's D1 open for the buy-stop price. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used for the safety stop. |
| `strategy_atr_sl_mult` | 1.5 | > 0 | ATR multiple subtracted from entry for the safety stop. |
| `strategy_session_close_hour` | 23 | 0-23 | Broker-time hour used for session-close exit and pending-order cancellation. |
| `strategy_session_close_minute` | 45 | 0-59 | Broker-time minute used for session-close exit and pending-order cancellation. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - liquid index CFD suitable for prior-day range stop mechanics.
- `XAUUSD.DWX` - liquid metal CFD suitable for prior-day range stop mechanics.
- `EURUSD.DWX` - liquid FX pair suitable for prior-day range stop mechanics.
- `GBPUSD.DWX` - liquid FX pair suitable for prior-day range stop mechanics.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX custom-symbol data path.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_D1` for today open and yesterday high-low range |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Intraday, from buy-stop fill until broker session close |
| Expected drawdown profile | Safety-stop controlled intraday breakout drawdowns |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source script`
**Pointer:** `https://www.tradingview.com/script/tYnk6xgJ-Simple-BTC-trading-strategy-based-on-yesterday-s-trading-range/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10738_tv-yd-range.md`

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
| v1 | 2026-05-31 | Initial build from card | ef0ee66e-2e2a-4d0c-9a01-e189d168b326 |
