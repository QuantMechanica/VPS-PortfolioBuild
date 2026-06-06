# QM5_10845_tv-ls-short-3r - Strategy Spec

**EA ID:** QM5_10845
**Slug:** tv-ls-short-3r
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades short after a failed push above the broker-day high on the active chart timeframe. The setup requires the candle before the sweep candle to be bullish and already at the broker-day high, then the next candle must trade above that high and close back below the prior candle open. The EA enters short on the next bar, places the stop above the sweep high plus the larger of 0.10 ATR(14) or two spreads, and places take profit at 3.0R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_atr_period | 14 | >=1 | ATR period used for the stop buffer and maximum stop-distance filter. |
| strategy_stop_buffer_atr_mult | 0.10 | >=0.0 | ATR fraction added above the sweep high, compared with two spreads. |
| strategy_rr_target | 3.0 | >0.0 | Reward-to-risk multiple used for fixed take profit. |
| strategy_min_stop_spread_mult | 3.0 | >0.0 | Minimum stop distance as a multiple of current spread. |
| strategy_max_stop_atr_mult | 2.5 | >0.0 | Maximum stop distance as a multiple of ATR(14). |
| strategy_fx_session_start_min | 840 | 0-1439 | Broker-time minute when the FX/metals liquid-session gate opens. |
| strategy_fx_session_end_min | 1080 | 0-1439 | Broker-time minute when the FX/metals liquid-session gate closes. |
| strategy_index_session_start_min | 570 | 0-1439 | Broker-time minute when the index cash-open gate opens. |
| strategy_index_session_end_min | 1080 | 0-1439 | Broker-time minute when the index cash-open gate closes. |
| strategy_day_high_scan_bars | 288 | >=2 | Maximum M5-equivalent bars scanned backward within the broker day. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid DWX FX major suitable for intraday London/NY liquidity sweeps.
- GBPUSD.DWX - liquid DWX FX major suitable for intraday London/NY liquidity sweeps.
- XAUUSD.DWX - liquid DWX metal with intraday sweep/reclaim behavior.
- GDAXI.DWX - canonical DWX DAX symbol in the matrix, used as the available port for the card's GER40.DWX target.
- NDX.DWX - liquid DWX index CFD suitable for cash-open sweep tests.

**Explicitly NOT for:**
- GER40.DWX - card-stated DAX name, but not present in the canonical DWX symbol matrix for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday; card does not specify a fixed time stop. |
| Expected drawdown profile | Short-only intraday reversal with bounded fixed-risk SL and 3R TP. |
| Regime preference | Mean-reversion after failed liquidity sweeps. |
| Win rate target (qualitative) | Low to medium because payoff target is 3R. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script "5 Min Liquidity Sweep Short 1:3 RR" by parthaborah022, cited in the approved card.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10845_tv-ls-short-3r.md`

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
| v1 | 2026-06-06 | Initial build from card | fa47fad8-b79d-4e4f-bcdf-9e322be04fce |
