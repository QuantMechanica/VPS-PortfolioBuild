# QM5_10670_tv-ls-bos-retest - Strategy Spec

**EA ID:** QM5_10670
**Slug:** tv-ls-bos-retest
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA looks for a confirmed swing low or swing high, then waits for a closed bar to sweep that level and reclaim it. After a sweep, it requires a strong displacement candle to break the opposite confirmed swing level, then waits for a retest of that BOS level. A long trade opens when the retest bar touches the BOS level and closes bullish back above it; a short trade opens when the retest bar touches the BOS level and closes bearish back below it. The stop is placed beyond the swept liquidity extreme with a 0.1 ATR buffer and the target is fixed at 2R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_pivot_left | 3 | >=1 | Older bars required to confirm a swing pivot. |
| strategy_pivot_right | 3 | >=1 | Newer closed bars required to confirm a swing pivot. |
| strategy_pivot_lookback | 48 | >=8 | Closed-bar search depth for recent pivots. |
| strategy_setup_timeout_bars | 16 | >=1 | Bars allowed between sweep, BOS, and retest before reset. |
| strategy_displacement_body_min | 0.55 | 0.0-1.0 | Minimum body share of the BOS candle range. |
| strategy_displacement_edge_max | 0.30 | 0.0-1.0 | Maximum close distance from the BOS candle edge. |
| strategy_retest_edge_max | 0.35 | 0.0-1.0 | Maximum close distance from the retest candle edge. |
| strategy_atr_period | 14 | >=1 | ATR period for the swept-liquidity stop buffer. |
| strategy_atr_stop_buffer_mult | 0.10 | >=0.0 | ATR buffer beyond the swept high or low. |
| strategy_max_stop_atr | 2.50 | >0.0 | Reject entries whose stop distance is larger than this ATR multiple. |
| strategy_rr_target | 2.00 | >0.0 | Fixed reward-to-risk target. |
| strategy_session_filter_enabled | true | true/false | Enables the NY Open broker-time session filter. |
| strategy_session_start_minute | 990 | 0-1439 | Session start minute of broker day, default 16:30. |
| strategy_session_end_minute | 1080 | 0-1439 | Session end minute of broker day, default 18:00. |
| strategy_max_spread_points | 200 | >=0 | Maximum allowed spread in points; zero disables the spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - liquid DWX index CFD from the card's P2 basket.
- GDAXI.DWX - available DWX DAX custom symbol used as the GER40.DWX port.
- WS30.DWX - liquid DWX index CFD from the card's P2 basket.
- XAUUSD.DWX - DWX metal symbol from the card's P2 basket.
- EURUSD.DWX - major DWX FX pair from the card's P2 basket.

**Explicitly NOT for:**
- GER40.DWX - card-stated name is not present in the DWX symbol matrix; GDAXI.DWX is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | intraday, minutes to hours |
| Expected drawdown profile | stop-defined reversal/retest losses with fixed 2R winners |
| Regime preference | volatility-expansion reversal after liquidity sweep |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/AWa1tWoJ-Liquidity-Sweep-BOS-Retest-System-Prop-Firm-Edition/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10670_tv-ls-bos-retest.md`

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
| v1 | 2026-05-31 | Initial build from card | 5da6fe9f-affa-46fd-b42c-89fec5bbe68d |
