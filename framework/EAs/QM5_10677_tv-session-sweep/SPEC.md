# QM5_10677_tv-session-sweep - Strategy Spec

**EA ID:** QM5_10677
**Slug:** tv-session-sweep
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `artifacts/cards_approved/QM5_10677_tv-session-sweep.md`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades only inside the configured liquid session window. On each closed bar, it compares the signal candle with the previous 20-bar range: a long requires the candle low to sweep below that prior low, the candle close to reclaim above that prior low, and the close to be above EMA(50). A short requires the candle high to sweep above the prior high, the candle close to return below that prior high, and the close to be below EMA(50). Entries use an ATR(14) stop at 1.5 ATR and a fixed 2.5R take profit, with any open position closed after the session ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_liquidity_lookback` | 20 | 1+ bars | Number of prior closed bars used for the sweep high/low. |
| `strategy_ema_period` | 50 | 1+ bars | EMA trend filter period on the chart timeframe. |
| `strategy_atr_period` | 14 | 1+ bars | ATR period for stop distance. |
| `strategy_atr_stop_mult` | 1.5 | >0 | ATR multiple used for the stop loss. |
| `strategy_reward_risk` | 2.5 | >0 | Take-profit distance as a multiple of initial risk. |
| `strategy_index_session_start_hour` | 16 | 0-23 | Broker-hour start for index CFD session. |
| `strategy_index_session_start_min` | 30 | 0-59 | Broker-minute start for index CFD session. |
| `strategy_index_session_end_hour` | 18 | 0-23 | Broker-hour end for index CFD session. |
| `strategy_index_session_end_min` | 0 | 0-59 | Broker-minute end for index CFD session. |
| `strategy_fx_session_start_hour` | 15 | 0-23 | Broker-hour start for FX/metals London/New York overlap. |
| `strategy_fx_session_start_min` | 0 | 0-59 | Broker-minute start for FX/metals session. |
| `strategy_fx_session_end_hour` | 19 | 0-23 | Broker-hour end for FX/metals London/New York overlap. |
| `strategy_fx_session_end_min` | 0 | 0-59 | Broker-minute end for FX/metals session. |
| `strategy_entry_cutoff_minutes` | 10 | 0+ minutes | Blocks new entries in the final minutes of the session. |
| `strategy_max_spread_points` | 0 | 0+ points | Optional spread gate; 0 disables the gate. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 index CFD in the card's primary P2 basket.
- `GDAXI.DWX` - canonical local DAX symbol used for the card's `GER40.DWX` basket item.
- `WS30.DWX` - Dow 30 index CFD in the card's primary P2 basket.
- `XAUUSD.DWX` - gold/metals session-sweep target from the card's primary P2 basket.
- `GBPUSD.DWX` - FX session-sweep target from the card's primary P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; not part of the card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 and M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday; usually minutes to one configured session |
| Expected drawdown profile | Fixed-risk session scalping with ATR-defined loss per trade |
| Regime preference | Liquidity sweep with trend confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** AIScripts, `Session Liquidity Sweep + Trend Confirmation`, 2026-01-19, https://www.tradingview.com/script/o6iMtsld-Session-Liquidity-Sweep-Trend-Confirmation/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10677_tv-session-sweep.md`

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
| v1 | 2026-05-31 | Initial build from card | d24bb013-5286-4902-b92d-ee505e560196 |
