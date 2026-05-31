# QM5_10681_tv-sd-engulf - Strategy Spec

**EA ID:** QM5_10681
**Slug:** `tv-sd-engulf`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA aggregates closed candles into fixed-size groups and marks demand after bullish continuation groups and supply after bearish continuation groups. A long entry is allowed when the latest closed candle is a bullish engulfing candle that trades back into an active demand zone; a short entry mirrors this at an active supply zone. Stops are placed beyond the engulfed candle with a 0.1 ATR buffer and targets are set at a fixed 2.0R. Open positions close at SL, TP, framework Friday close, or after at least three bars if an opposite zone-engulfing signal appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trade_mode` | 0 | -1, 0, 1 | Short only, both directions, or long only. |
| `strategy_aggregation_factor` | 3 | 1-20 | Number of closed candles in each supply/demand structure group. |
| `strategy_zone_lookback_groups` | 40 | 2-80 | Number of historical aggregated groups scanned for active zones. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for zone-width filtering and stop buffer. |
| `strategy_max_zone_atr_mult` | 3.0 | 0.1-10.0 | Maximum zone width as an ATR multiple. |
| `strategy_stop_atr_buffer_mult` | 0.10 | 0.0-2.0 | ATR buffer added beyond the engulfed candle stop. |
| `strategy_take_profit_rr` | 2.0 | 0.1-10.0 | Fixed reward-to-risk multiple for take profit. |
| `strategy_min_exit_bars` | 3 | 0-100 | Minimum bars in trade before opposite-signal exit can close. |
| `strategy_session_filter_enabled` | true | true/false | Enables the London/New York session hour gate. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker hour at which entries are allowed. |
| `strategy_session_end_hour` | 21 | 0-24 | Broker hour at which entries stop being allowed. |
| `strategy_start_date` | 1970-01-01 00:00 | datetime | Inclusive first date allowed by the configurable date filter. |
| `strategy_end_date` | 2099-12-31 23:59 | datetime | Inclusive last date allowed by the configurable date filter. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Major FX pair with liquid OHLC data for supply/demand retests.
- `GBPUSD.DWX` - Major FX pair from the card's P2 basket.
- `XAUUSD.DWX` - Canonical DWX gold symbol for the card's XAUUSD target.
- `NDX.DWX` - Liquid index CFD from the card's P2 basket.
- `GDAXI.DWX` - Matrix-valid DAX symbol used for the card's GER40.DWX target.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `XAUUSD` - Missing the required `.DWX` suffix for backtest registry use.

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
| Trades / year / symbol | 90 |
| Typical hold time | Intraday to multi-session, depending on 2R target, SL, or opposite signal after 3 bars |
| Expected drawdown profile | Fixed-risk mean-reversion entries with full-loss events when zone retests fail |
| Regime preference | Mean-reversion after supply/demand retests |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `TradingView open-source script`
**Pointer:** `https://www.tradingview.com/script/KszHWOSg-Supply-Demand-Zones-Engulfment-based-Execution/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10681_tv-sd-engulf.md`

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
| v1 | 2026-05-31 | Initial build from card | ce1e561b-a402-44d3-8d27-5400c568b364 |
