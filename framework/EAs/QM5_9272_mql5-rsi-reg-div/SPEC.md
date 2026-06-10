# QM5_9272_mql5-rsi-reg-div — Strategy Spec

**EA ID:** QM5_9272
**Slug:** `mql5-rsi-reg-div`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA detects regular RSI divergence on the H1 chart. A bullish signal fires when
price makes a lower swing low while RSI simultaneously makes a higher swing low over
the same two confirmed swing points (5-50 bars apart, with swing strength 5). A bearish
signal fires on the inverse pattern (higher price high, lower RSI high). Entry is a
market order at the open of the bar following the second swing's confirmation. The stop
is placed below/above the second swing extreme by the larger of 0.5×ATR(14) and 20
points. The initial target is 2×R or the previous opposite swing level, whichever is
closer. Positions exit early on an opposite regular RSI divergence signal or after 48 H1
bars (time stop).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 7-21 | RSI lookback period |
| `strategy_swing_strength` | 5 | 3-8 | Bars each side needed to confirm a swing high/low |
| `strategy_min_sep` | 5 | 3-15 | Minimum bar separation between the two divergence swings |
| `strategy_max_sep` | 50 | 20-100 | Maximum bar separation between the two divergence swings |
| `strategy_atr_period` | 14 | 7-21 | ATR period used for SL buffer calculation |
| `strategy_sl_atr_mult` | 0.5 | 0.3-1.0 | ATR multiplier for SL buffer beyond swing extreme |
| `strategy_sl_min_pts` | 20 | 10-50 | Minimum SL buffer in points |
| `strategy_tp_r_mult` | 2.0 | 1.5-3.0 | TP target expressed as R multiple |
| `strategy_rsi_div_tol` | 0.1 | 0.0-1.0 | RSI divergence line cleanliness tolerance (RSI units) |
| `strategy_time_exit_bars` | 48 | 24-96 | Max H1 bars before forced time exit |
| `strategy_rsi_mid_lo` | 45 | 35-50 | Lower RSI midzone bound for momentum filter |
| `strategy_rsi_mid_hi` | 55 | 50-65 | Upper RSI midzone bound for momentum filter |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major liquid FX pair; clean swing structure on H1
- `GBPUSD.DWX` — major liquid FX pair; historical divergence frequency matches expected range
- `USDJPY.DWX` — major liquid FX pair; RSI divergence well-documented on JPY pairs
- `XAUUSD.DWX` — liquid metals market; H1 divergence patterns consistent with momentum exhaustion thesis

**Explicitly NOT for:**
- Index symbols (NDX/WS30/SP500) — not in card target universe; divergence characteristics differ from FX/metals H1
- Exotic FX pairs — insufficient liquidity for clean swing structure

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
| Trades / year / symbol | ~50 |
| Typical hold time | 2–48 hours (median ~12h based on H1 RSI divergence patterns) |
| Expected drawdown profile | Moderate; mean-reversion entries with fixed 2R target |
| Regime preference | Mean-reversion / momentum-exhaustion |
| Win rate target (qualitative) | Medium (~45–55% expected for 2R target divergence plays) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** article
**Pointer:** Allan Munene Mutiiria, "Automating Trading Strategies in MQL5 (Part 37): Regular RSI Divergence Convergence with Visual Indicators", MQL5 Articles, 2025-10-29
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9272_mql5-rsi-reg-div.md`

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
| v1 | 2026-06-10 | Initial build from card | 1b4110df-3c43-42ae-bb20-9e82c46fd62f |
