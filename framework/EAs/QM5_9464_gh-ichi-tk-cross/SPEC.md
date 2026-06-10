# QM5_9464_gh-ichi-tk-cross — Strategy Spec

**EA ID:** QM5_9464
**Slug:** `gh-ichi-tk-cross`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Long entry fires on the H1 bar where Tenkan-sen (9-period midline) has crossed above Kijun-sen (26-period midline): the just-closed bar has Tenkan > Kijun and the bar before it had Tenkan ≤ Kijun. Short entry fires on the mirror cross (Tenkan crosses below Kijun). The position is closed when the opposite state holds: Tenkan ≤ Kijun for a long, Tenkan ≥ Kijun for a short. Stop loss is placed at ATR(14) × 2.0 from the market entry price. No take-profit; the strategy rides the trend until the Ichimoku lines revert. One position per symbol per magic at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tenkan_period` | 9 | 5–20 | Lookback for Tenkan-sen midline (highest high + lowest low) / 2 |
| `strategy_kijun_period` | 26 | 10–52 | Lookback for Kijun-sen midline (highest high + lowest low) / 2 |
| `strategy_atr_period` | 14 | 7–20 | ATR lookback for stop-loss sizing |
| `strategy_atr_sl_mult` | 2.0 | 1.0–4.0 | ATR multiplier applied to stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair, sufficient H1 bar count, Ichimoku cross has documented edge on trending FX
- `GBPUSD.DWX` — liquid major FX pair, trending characteristics similar to EURUSD
- `XAUUSD.DWX` — trending commodity with sufficient H1 volatility for ATR-sized stops
- `GDAXI.DWX` — DAX 40 index (card specified GER40.DWX; ported to GDAXI.DWX which is the canonical DWX name for DAX; see open_questions)

**Explicitly NOT for:**
- `GER40.DWX` — not present in dwx_symbol_matrix.csv; ported to GDAXI.DWX

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
| Trades / year / symbol | ~50 (25–80 range per card) |
| Typical hold time | Hours to days (until reverse cross on H1) |
| Expected drawdown profile | Moderate trend-following drawdowns; ATR 2× stop limits per-trade risk |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** forum / GitHub
**Pointer:** https://github.com/pipbolt/experts/blob/master/experts/Ichimoku-Kinko-Hyo-EA.mq5
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9464_gh-ichi-tk-cross.md`

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
| v1 | 2026-06-11 | Initial build from card | 9f0321b1-a570-4915-98b0-15b150541831 |
