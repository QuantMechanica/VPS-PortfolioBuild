# QM5_1642_aa-xasset-xmom-third — Strategy Spec

**EA ID:** QM5_1642
**Slug:** `aa-xasset-xmom-third`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On the first trading day of each new month the EA ranks all 12 universe symbols by their
12-2 rate-of-change: `ROC = Close(3 months ago) / Close(13 months ago) - 1`. Symbols are
sorted descending; the top third enter long, the bottom third enter short, and the middle
third are kept flat. Each position is a D1 market order with an initial stop-loss of
3 × ATR(20, D1). Positions are reviewed at every monthly boundary: if a symbol leaves its
top/bottom-third rank, its position is closed; if it changes direction, the old position
is closed and a new one is opened on the same bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_roc_idx_recent` | 2 | 1-6 | Ring-buffer index for ROC numerator (card: Close(3) = index 2) |
| `strategy_roc_idx_old` | 12 | 6-15 | Ring-buffer index for ROC denominator (card: Close(13) = index 12) |
| `strategy_atr_period` | 20 | 10-50 | D1 ATR period for initial stop-loss distance |
| `strategy_atr_sl_mult` | 3.0 | 1.0-6.0 | SL = mult × ATR(D1) |
| `strategy_max_long_slots` | 5 | 1-6 | Max simultaneous long positions in portfolio |
| `strategy_max_short_slots` | 5 | 1-6 | Max simultaneous short positions in portfolio |
| `strategy_spread_mult` | 2.5 | 1.0-5.0 | Entry blocked if current spread > mult × 20-bar avg spread |
| `strategy_min_monthly_bars` | 14 | 3-24 | Minimum complete monthly closes before first trade |

---

## 3. Symbol Universe

This EA implements cross-sectional ranking across all registered symbols simultaneously.
Every instance runs on one symbol and participates in the shared ranking computation.

**Designed for:**
- `SP500.DWX` — US large-cap equity (backtest-only; live promote to NDX/WS30)
- `NDX.DWX` — US technology/growth equity; high momentum sensitivity
- `WS30.DWX` — US blue-chip equity; diversifies from NDX
- `UK100.DWX` — EU/UK equity; reduces US-concentration
- `GDAXI.DWX` — German DAX equity; EU industrial exposure
- `EURUSD.DWX` — Major FX; liquid, low-correlation to equities
- `GBPUSD.DWX` — Major FX; UK macro exposure
- `AUDUSD.DWX` — Commodity-currency FX; AUD/risk-on proxy
- `USDJPY.DWX` — Safe-haven FX; regime-diversifying
- `USDCHF.DWX` — Safe-haven FX; diversifies from USDJPY
- `XAUUSD.DWX` — Gold; hard-asset / crisis hedge
- `XTIUSD.DWX` — WTI Oil; commodity / inflation proxy

**Explicitly NOT for:**
- Any symbol not in the 12-symbol universe above — the cross-sectional ranking is calibrated to this set; adding or removing symbols changes the top/bottom-third cut-offs

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `PERIOD_D1` (all universe symbols read via QM_SMA) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

Note: The card specifies MN1 evaluation. MN1 is untestable in MT5 tester for DWX custom
symbols (0 bars/ticks generated). This EA uses D1 as the execution timeframe and detects
month boundaries via `TimeCurrent()` comparison, recording bar[1] close via
`QM_SMA(sym, PERIOD_D1, 1, 1)` as the monthly close proxy.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (monthly rebalance; some months flat) |
| Typical hold time | ~1 month (to next rebalance) |
| Expected drawdown profile | Moderate; 3×ATR(20,D1) initial SL; no partial close |
| Regime preference | Trend / cross-sectional momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** paper / blog
**Pointer:** Jack Vogel PhD, "The World's Longest Multi-Asset Momentum Investing Backtest!", Alpha Architect blog 2018-04-24
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1642_aa-xasset-xmom-third.md`

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
| v1 | 2026-06-10 | Initial build from card | 3d0fe399-28a9-4e51-a843-7b7bbc30387a |
