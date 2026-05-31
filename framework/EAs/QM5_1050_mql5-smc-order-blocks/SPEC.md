# QM5_1050_mql5-smc-order-blocks - Strategy Spec

**EA ID:** QM5_1050
**Slug:** mql5-smc-order-blocks
**Source:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA scans closed bars for the last opposite candle before an ATR-sized impulse and stores it as a bullish or bearish order block. It confirms direction with a break of recent structure on the trading timeframe and a higher-timeframe HH/HL or LH/LL trend read on H4 by default. A long entry is opened when the prior closed bar was inside a bullish order block and the latest closed bar closes above that block; shorts mirror this rule below a bearish block. Exits are handled by fixed stop loss and a 4R take profit, with an optional move to break even after price reaches 1R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_trend_tf` | `PERIOD_H4` | MT5 timeframe | Higher timeframe used for HH/HL or LH/LL trend context |
| `strategy_ob_lookback` | `20` | `3+` | Closed bars scanned for the latest qualifying order block |
| `strategy_bos_lookback` | `10` | `3+` | Closed bars used for break-of-structure and trend windows |
| `strategy_atr_period` | `14` | `1+` | ATR period used to qualify impulse candles |
| `strategy_impulse_atr_mult` | `1.5` | `>0` | Minimum impulse range as ATR multiple |
| `strategy_sl_offset_points` | `10` | `0+` | Stop offset beyond the order-block low or high |
| `strategy_rr` | `4.0` | `>0` | Take-profit multiple of stop distance |
| `strategy_session_start_hour` | `7` | `0-23` | Broker-hour start of London and NY overlap window |
| `strategy_session_end_hour` | `17` | `0-23` | Broker-hour end of London and NY overlap window |
| `strategy_max_spread_points` | `20` | `0+` | Maximum allowed spread in points |
| `strategy_require_inducement` | `false` | `true/false` | If true, requires the cached liquidity-grab condition before retest entry |
| `strategy_move_be_after_1r` | `true` | `true/false` | Move stop to near break even after price moves 1R in favor |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major Forex pair and primary fit for the SMC article style.
- `GBPUSD.DWX` - major Forex pair with liquid London and NY overlap behavior.
- `USDJPY.DWX` - major Forex pair with liquid overlap-session structure.
- `AUDUSD.DWX` - major Forex pair included by the card's P2 saturation basket.
- `USDCAD.DWX` - major Forex pair included by the card's P2 saturation basket.

**Explicitly NOT for:**
- Non-DWX symbols - pipeline data discipline requires registered `.DWX` symbols only.
- Non-liquid synthetic or unavailable symbols - the order-block retest logic assumes continuous liquid intraday bars.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `PERIOD_H4` trend context |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `500` |
| Typical hold time | Intraday to multi-session; exits are SL, 4R TP, break-even management, or Friday close |
| Expected drawdown profile | Price-action breakout profile with clustered losses during choppy structure |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Low to medium due to 4R fixed target |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb
**Source type:** MQL5 article
**Pointer:** https://www.mql5.com/en/articles/22078
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1050_mql5-smc-order-blocks.md`

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
| v1 | 2026-05-28 | Initial build from card | d144646e-ad34-47c2-a7ce-8ed2b9a8054b |
