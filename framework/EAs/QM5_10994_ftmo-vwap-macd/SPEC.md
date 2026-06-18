# QM5_10994_ftmo-vwap-macd — Strategy Spec

**EA ID:** QM5_10994
**Slug:** `ftmo-vwap-macd`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (FTMO, "Technical Indicators in Trading Strategies")
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Intraday session-VWAP bias with MACD momentum confirmation on M15. A session VWAP
is computed from the symbol's OWN bars (typical price (H+L+C)/3 weighted by tick
volume) and is reset at the London session anchor each day; the anchor is derived
in UTC via `QM_BrokerToUTC(bar_open_time)` so the daily reset stays DST-correct.
No external VWAP feed is used.

Long: price is above VWAP, the last closed M15 bar dipped to/below VWAP (low ≤ VWAP)
but closed back above it, and MACD(12,26,9) printed a fresh bullish histogram flip
(macd − signal turned positive) within the last `strategy_macd_lookback` bars. The
stop is the pullback swing low minus `strategy_sl_atr_buffer × ATR(14)`; the target
is `strategy_tp_rr × R`. Short is the mirror. A flat-VWAP filter skips when the VWAP
slope over the last 8 bars is within `strategy_slope_atr_frac × ATR(14)`. Trading is
restricted to the broker-time London+NY liquid window. Exits: a closed bar on the
opposite side of VWAP, leaving the liquid window (session end), or a
`strategy_max_hold_bars` M15-bar time stop — whichever comes first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 6-20 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 18-40 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5-15 | MACD signal SMA period |
| `strategy_macd_lookback` | 3 | 1-6 | Bars back to detect the MACD histogram flip trigger |
| `strategy_vwap_anchor_utc_h` | 7 | 0-23 | UTC hour of the London-open VWAP session reset anchor |
| `strategy_session_start_broker_h` | 9 | 0-23 | Trade window start hour (broker time, inclusive) |
| `strategy_session_end_broker_h` | 23 | 0-23 | Trade window end hour (broker time, exclusive) |
| `strategy_atr_period` | 14 | 7-28 | ATR period (slope filter + stop buffer) |
| `strategy_slope_atr_frac` | 0.05 | 0.0-0.5 | Flat-VWAP zone as a fraction of ATR over 8 bars |
| `strategy_swing_lookback` | 8 | 3-20 | Pullback swing-extreme lookback in closed bars |
| `strategy_sl_atr_buffer` | 0.25 | 0.0-1.0 | Stop buffer beyond the swing = mult × ATR |
| `strategy_tp_rr` | 1.8 | 1.0-3.0 | Take-profit as a multiple of risk (R) |
| `strategy_max_hold_bars` | 32 | 8-96 | Time-stop in M15 bars |
| `strategy_spread_lookback` | 20 | 5-50 | Closed-bar lookback used for the median spread baseline |
| `strategy_spread_median_mult` | 1.5 | 1.0-5.0 | Skip if current spread exceeds this multiple of the median spread baseline; zero spread passes |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid London/NY FX pair with clean intraday VWAP structure.
- `GBPUSD.DWX` — liquid London-centric FX pair; strong session momentum.
- `GDAXI.DWX` — canonical DWX DAX 40 proxy for the card's `GER40.DWX` target; pronounced European-session intraday trends.
- `NDX.DWX` — Nasdaq 100 index CFD; momentum-rich US-session VWAP behaviour.

**Explicitly NOT for:**
- Low-liquidity / exotic symbols — VWAP tick-volume proxy and session structure
  become unreliable outside the major FX pairs and liquid index CFDs above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~70` |
| Typical hold time | `minutes to a few hours (≤ 32 M15 bars = 8h cap)` |
| Expected drawdown profile | `moderate; intraday risk capped at one R per trade, flat overnight` |
| Regime preference | `intraday trend / momentum continuation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `forum` (FTMO educational blog)
**Pointer:** `https://ftmo.com/en/technical-indicators-in-trading-strategies/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10994_ftmo-vwap-macd.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-18 | Initial build from card | d73ad468-b2ad-49d9-81f0-f17549ae0cb3 |
