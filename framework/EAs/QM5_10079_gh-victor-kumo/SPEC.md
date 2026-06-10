<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_10079_gh-victor-kumo — Strategy Spec

**EA ID:** QM5_10079
**Slug:** `gh-victor-kumo`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades D1 Ichimoku Kumo breakouts on forex and metals. It computes Tenkan-sen (9-period HL midpoint), Kijun-sen (26-period HL midpoint), and Senkou Span B (52-period HL midpoint); Senkou Span A is (Tenkan + Kijun) / 2, projected 26 bars forward as the cloud. A long entry fires when the cloud is bullish on both bar[-1] and bar[-2] and price transitions from inside or below the cloud upper boundary to fully above it (bar[-2] low below upper, bar[-1] low above upper). A short entry fires on the mirror condition with a bearish cloud. The position is closed intraday if the developing bar low (long) or high (short) crosses back through the opposite cloud boundary. Initial stop is placed at 3% below/above the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tenkan_period` | 9 | 5–20 | Tenkan-sen (conversion line) lookback bars |
| `strategy_kijun_period` | 26 | 15–52 | Kijun-sen (base line) lookback bars; also controls cloud projection offset |
| `strategy_senkou_b_period` | 52 | 26–104 | Senkou Span B lookback bars |
| `strategy_stop_percent` | 3.0 | 1.0–6.0 | Initial stop distance as % of entry price |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major forex pair; high liquidity, classic Ichimoku trend vehicle
- `GBPUSD.DWX` — major forex pair; correlated but independent momentum to EURUSD
- `USDJPY.DWX` — major forex pair; risk-on/off dynamics complement EUR/GBP breakouts
- `XAUUSD.DWX` — gold; trend-following profile fits Ichimoku cloud breakouts on D1

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500) — card specifies forex + metals universe only

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~20 |
| Typical hold time | days to weeks |
| Expected drawdown profile | trend-following; moderate drawdown during ranging markets |
| Regime preference | breakout / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub open-source EA
**Pointer:** Victor Algo, Ichimoku Kumo Break Out EA, https://github.com/victor-algo/channel/blob/main/LIVE%20BOT%20-%20Cr%C3%A9ation%20de%20trading%20bot%20from%20scratch/Ichimoku%20Kumo%20Break%20Out/Expert/IchimokuKumoBO.mq5
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_10079_gh-victor-kumo.md`

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
| v1 | 2026-06-10 | Initial build from card | 20e81c41-fae2-44c9-bd90-7d8d8d150646 |
