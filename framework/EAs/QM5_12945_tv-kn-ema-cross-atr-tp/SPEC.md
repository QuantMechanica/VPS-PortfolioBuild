# QM5_12945_tv-kn-ema-cross-atr-tp — Strategy Spec

**EA ID:** QM5_12945
**Slug:** `tv-kn-ema-cross-atr-tp`
**Source:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5`
**Author of this spec:** Codex
**Last revised:** 2026-08-21

---

## 1. Strategy Logic

On each completed H1 bar, the EA buys when the 9-period EMA crosses above the
21-period EMA and sells when the 9-period EMA crosses below the 21-period EMA.
Every entry receives a server-side stop 1.5 times ATR(14) from the entry price
and a full-position target 1.0 times ATR(14) from entry. An opposite EMA cross
closes an existing position before the opposite entry is evaluated. The
framework enforces one position per magic and performs the mandatory news and
Friday-close checks.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | `PERIOD_H1` | M30–H4 | Timeframe used for the closed-bar signal and ATR. |
| `strategy_ema_fast_period` | 9 | 8–20 | Fast EMA period. |
| `strategy_ema_slow_period` | 21 | 21–50 | Slow EMA period. |
| `strategy_atr_period` | 14 | 7–28 | ATR lookback for the fixed entry bracket. |
| `strategy_atr_sl_mult` | 1.5 | 1.0–2.5 | Stop distance in ATR units. |
| `strategy_atr_tp_mult` | 1.0 | 1.0–3.0 | Full-position target in ATR units; 1.0 is the approved baseline. |

Framework-level risk, news, stress, magic, and Friday-close inputs remain as
defined in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

The approved card names EURUSD, GBPUSD, USDJPY, and XAUUSD as its default Q02
shortlist. The governed registry also allocates the following portable `.DWX`
discovery surface so Q02 can test whether the simple normalized signal travels:

**Designed for:**

- `GDAXI.DWX` — liquid equity-index trend surface.
- `NDX.DWX` — liquid equity-index trend surface.
- `SP500.DWX` — liquid equity-index trend surface.
- `UK100.DWX` — liquid equity-index trend surface.
- `WS30.DWX` — liquid equity-index trend surface.
- `XAUUSD.DWX` — card-listed metal with ATR-normalized prices.
- `EURUSD.DWX` — card-listed primary FX pair.
- `GBPUSD.DWX` — card-listed FX pair.
- `USDJPY.DWX` — card-listed FX pair.
- `USDCHF.DWX` — portable liquid FX discovery pair.
- `AUDUSD.DWX` — portable liquid FX discovery pair.
- `USDCAD.DWX` — portable liquid FX discovery pair.
- `NZDUSD.DWX` — portable liquid FX discovery pair.

**Explicitly NOT for:**

- Non-`.DWX` research symbols — Q01–Q10 preserve the governed `.DWX` naming boundary.
- Sub-minute/tick execution — the strategy is a closed-bar H1 system, not HFT.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Not asserted by the card; measured deterministically at Q02. |
| Typical hold time | Hours to days, consistent with an H1 EMA cross and fixed ATR bracket. |
| Expected drawdown profile | Per-trade loss is bounded by the 1.5 ATR server-side stop; framework loss caps remain binding. |
| Regime preference | Trend. |
| Win rate target (qualitative) | Not asserted by the card; Q02 evidence is authoritative. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c84ae47e-8ea0-56f1-8b25-4436b6dda5b5`
**Source type:** TradingView Pine script
**Pointer:** https://www.tradingview.com/script/Xmti9o4w-KN-Smart-TP-SL-Signals/
**R1–R4 verdict (Q00):** all PASS; see
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12945_tv-kn-ema-cross-atr-tp.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent, only after all required approvals |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by the approved portfolio contract |

Backtest setfiles must keep `RISK_FIXED > 0` and `RISK_PERCENT = 0`. No live
authorization is created by this build.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-21 | Initial build from approved card | Router task `e3e1d19f-afc3-47be-93f1-9b4008808f20` |
