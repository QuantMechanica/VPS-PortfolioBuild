# QM5_10752_tv-nq-vwap-orb - Strategy Spec

**EA ID:** QM5_10752
**Slug:** `tv-nq-vwap-orb`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA builds an opening range from the first configured minutes after the broker-time equivalent of the New York 09:30 open. After that range is locked, it buys when a closed bar finishes above the opening-range high and above session VWAP, and sells when a closed bar finishes below the opening-range low and below session VWAP. The stop is ATR(14) multiplied by 1.5 by default, and the take profit is set at 2.0R. The EA enforces one submitted trade per session by default and exits any open trade at the configured end-of-session time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_or_minutes` | 15 | 1+ minutes | Opening-range duration after the session open. |
| `strategy_session_open_hour` | 15 | 0-23 | Broker-time hour for the US cash-session open. |
| `strategy_session_open_minute` | 30 | 0-59 | Broker-time minute for the US cash-session open. |
| `strategy_session_close_hour` | 21 | 0-23 | Broker-time hour for the end-of-session flat rule. |
| `strategy_session_close_minute` | 55 | 0-59 | Broker-time minute for the end-of-session flat rule. |
| `strategy_atr_period` | 14 | 1+ bars | ATR period for bracket stop and optional trailing. |
| `strategy_atr_stop_mult` | 1.5 | >0 | ATR multiple used for the initial stop. |
| `strategy_target_r` | 2.0 | >0 | Take-profit distance in initial-risk multiples. |
| `strategy_use_vwap_filter` | true | true/false | Require long closes above VWAP and short closes below VWAP. |
| `strategy_use_volume_filter` | false | true/false | Enable tick-volume confirmation. |
| `strategy_volume_lookback` | 20 | 1-256 bars | Rolling tick-volume average length. |
| `strategy_volume_mult` | 1.25 | >0 | Required multiple of rolling tick volume when enabled. |
| `strategy_max_daily_trades` | 1 | 0+ | Maximum submitted entries per session, with 0 meaning no cap. |
| `strategy_max_spread_points` | 0 | 0+ points | Optional spread ceiling; 0 disables the ceiling. |
| `strategy_max_hold_minutes` | 0 | 0+ minutes | Optional time stop; 0 disables it. |
| `strategy_use_atr_trailing` | false | true/false | Optional ATR trailing after the trigger threshold. |
| `strategy_trail_trigger_r` | 1.0 | >0 | R-multiple profit required before ATR trailing starts. |
| `strategy_trail_atr_mult` | 1.0 | >0 | ATR multiple for optional trailing. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - primary Nasdaq 100 proxy for the NQ-focused source script.
- `WS30.DWX` - liquid US index basket member from the card's R3 list.
- `GDAXI.DWX` - available DAX custom symbol used as the matrix-verified equivalent of card-stated GER40.
- `XAUUSD.DWX` - matrix-verified liquid symbol included in the card's R3 basket.
- `EURUSD.DWX` - matrix-verified liquid FX symbol included in the card's R3 basket.
- `GBPUSD.DWX` - matrix-verified liquid FX symbol included in the card's R3 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is registered instead.
- `SP500.DWX` - card marks it optional and backtest-only, not part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | intraday, short-term scalping holds |
| Expected drawdown profile | scalping-sensitive and exposed to spread/slippage during US open volatility |
| Regime preference | breakout / volatility expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** `https://www.tradingview.com/script/b7IJ7mmW-NQ-Scalping-ORB-VWAP-Bias-ATR-Brackets/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10752_tv-nq-vwap-orb.md`

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
| v1 | 2026-06-14 | Initial build from card | 3664b2e9-ad3d-45be-b5bb-69f82bcd2aa7 |
| v2 | 2026-07-23 | Q02 FX infrastructure recovery | Existing positions are managed before entry-only session/news filters; historical news evaluation runs once per new M5 bar instead of every tick. Strategy mechanics and parameters are unchanged. |
