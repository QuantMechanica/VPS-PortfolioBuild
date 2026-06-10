# QM5_9124_aa-abg-velocity — Strategy Spec

**EA ID:** QM5_9124
**Slug:** `aa-abg-velocity`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Applies a third-order alpha-beta-gamma tracking filter (fixed constants alpha=0.3289, beta=0.0654, gamma=0.0065) to the daily close price. The velocity term of the filter is an estimate of the linear trend. A long is opened when velocity crosses from non-positive to positive on a completed D1 bar; a short is opened when velocity crosses from non-negative to negative. Positions are closed when velocity crosses back through zero (long closed when vel ≤ 0; short closed when vel ≥ 0). An initial stop loss is placed at 2.5 × ATR(20,D1) from entry. New entries are blocked if current spread exceeds 2.5 × 20-day median spread. Filter requires 120 completed D1 bars of warmup before trading.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | 5–50 | D1 ATR lookback period for initial SL computation |
| `strategy_sl_atr_mult` | 2.5 | 1.0–5.0 | Multiplier applied to ATR to set initial SL distance |
| `strategy_spread_max_mult` | 2.5 | 1.0–10.0 | Entry blocked when spread exceeds this multiple of the 20-day median spread |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 daily trend; original paper used SPX daily closes; backtest-only (broker does not route SP500 orders)
- `NDX.DWX` — Nasdaq 100; strong daily trend-following characteristics similar to S&P 500
- `WS30.DWX` — Dow Jones 30; US large-cap daily trend
- `GDAXI.DWX` — DAX 40; European index daily trend
- `XAUUSD.DWX` — Gold; persistent multi-day trends, strong signal-to-noise for a velocity filter
- `XTIUSD.DWX` — WTI Crude Oil; ported from card's USOIL.DWX (USOIL.DWX not in DWX matrix; XTIUSD.DWX is the canonical WTI custom symbol)
- `EURUSD.DWX` — EUR/USD; highest-liquidity FX pair, suitable for D1 trend filter
- `GBPUSD.DWX` — GBP/USD; liquid major FX pair with measurable daily trends
- `USDJPY.DWX` — USD/JPY; liquid major FX pair included in baseline card basket

**Explicitly NOT for:**
- Intraday timeframes — the ABG filter is calibrated on D1 closes only

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
| Trades / year / symbol | ~100 |
| Typical hold time | days to weeks |
| Expected drawdown profile | moderate, trend-following with ATR-based hard stop |
| Regime preference | trend |
| Win rate target (qualitative) | low-medium (trend-following) |

---

## 6. Source Citation

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog / paper
**Pointer:** Henry Stern, "Trend-Following Filters - Part 2/2", Alpha Architect, 2021-01-21
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9124_aa-abg-velocity.md`

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
| v1 | 2026-06-10 | Initial build from card | 2e699f68-18b1-4a83-af5f-5f858fe47a8b |
