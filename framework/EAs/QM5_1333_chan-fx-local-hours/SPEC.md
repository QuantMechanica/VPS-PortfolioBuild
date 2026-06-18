# QM5_1333_chan-fx-local-hours — Strategy Spec

**EA ID:** QM5_1333
**Slug:** `chan-fx-local-hours`
**Source:** `fce67611-4e0f-5dce-8cff-c8b9dd84dd49` (Ernest Chan blog, "Time-of-day effects in FX trading", 2011-05-10)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Ernie Chan's "local-hours" effect: a currency tends to depreciate during its own
domestic trading hours. The EA shorts the base currency at the start of that
currency's local session and flattens at the end of the same session, with no
overnight hold. On each closed bar the current broker time is converted to UTC
via the framework's DST-aware `QM_BrokerToUTC`, and the UTC hour is tested against
a per-currency local-session window (EUR/GBP = London 07:00–16:00 UTC, JPY = Tokyo
00:00–09:00, AUD = Sydney/Tokyo overlap 22:00–07:00, USD/CAD = New York 12:00–21:00).
Entry fires exactly once per UTC session-day on the first bar inside the window (the
trigger EVENT); the window itself is a STATE that drives the time exit. A catastrophic
stop of `strategy_atr_sl_mult × ATR(14, H1)` protects the position; there is no fixed
take-profit — the trade is closed when the UTC hour leaves the session window. A
warmup gate requires at least 90 prior observed local sessions before trading.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_start_utc` | -1 | -1, 0-23 | Local-session open hour (UTC); -1 = auto-pick from base currency |
| `strategy_session_end_utc` | -1 | -1, 0-24 | Local-session close hour (UTC); -1 = auto-pick from base currency |
| `strategy_base_direction` | -1 | -1 / +1 | -1 = short base currency during local hours (card default), +1 = long base |
| `strategy_atr_period` | 14 | 5-50 | ATR period (H1) for the catastrophic stop |
| `strategy_atr_sl_mult` | 1.5 | 0.5-4.0 | Catastrophic stop = mult × ATR(period, H1) from entry (card baseline) |
| `strategy_min_sessions` | 90 | 0-500 | Require ≥ this many observed local sessions before trading |
| `strategy_max_spread_atr_frac` | 0.30 | 0.05-1.0 | Fail-OPEN wide-spread cap as a fraction of ATR(H1) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — base EUR, London/Europe local window 07:00–16:00 UTC
- `GBPUSD.DWX` — base GBP, London/Europe local window 07:00–16:00 UTC
- `USDJPY.DWX` — base USD, New York window 12:00–21:00 UTC (USD local pressure)
- `AUDUSD.DWX` — base AUD, Sydney/Tokyo overlap proxy 22:00–07:00 UTC (wraps midnight)
- `USDCAD.DWX` — base USD, New York window 12:00–21:00 UTC

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the local-hours FX-session edge has no analog there.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `ATR(14)` read on `PERIOD_H1` for the stop |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~250 (one entry per trading day inside the local window) |
| Typical hold time | Intraday, hours (single local session, no overnight) |
| Expected drawdown profile | Shallow per-trade (ATR-capped stop), seasonality-driven |
| Regime preference | Intraday time-of-day / FX-seasonality drift |
| Win rate target (qualitative) | Low-to-medium (small directional edge, no fixed TP) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fce67611-4e0f-5dce-8cff-c8b9dd84dd49`
**Source type:** forum/blog
**Pointer:** https://epchan.blogspot.com/2011/05/time-of-day-effects-in-fx-trading.html
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1333_chan-fx-local-hours.md`

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
| v1 | 2026-06-18 | Initial build from card | broker→UTC DST-aware local-session EA |
