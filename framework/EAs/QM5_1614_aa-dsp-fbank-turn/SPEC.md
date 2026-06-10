# QM5_1614_aa-dsp-fbank-turn — Strategy Spec

**EA ID:** QM5_1614
**Slug:** `aa-dsp-fbank-turn`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA applies a six-band analysis-synthesis IIR filter bank to daily close prices. Each band uses a second-order bandpass filter with centre periods 15, 88, 513, 2990, 17427, and 101572 samples respectively, with synthesis gain 0.886. The per-band outputs are summed to produce Y(t), which oscillates around zero. A completed local trough in Y below zero (Y(t-2) > Y(t-1), Y(t) > Y(t-1), Y(t-1) < 0) triggers a long entry at market; a completed local crest above zero triggers a short entry. Positions are closed on the opposite signal (trough for short, crest for long) or after 40 completed D1 bars, with an initial stop of 2 × ATR(20). A minimum of 300 D1 bars of warmup is required before any signal can fire, and entries are skipped when the current bid-ask spread exceeds 2.5 × its 20-day median.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 20 | 5-50 | ATR period for initial stop calculation |
| `strategy_atr_sl_mult` | 2.0 | 1.0-4.0 | SL = mult × ATR(period) distance from entry |
| `strategy_max_hold_bars` | 40 | 10-120 | Maximum D1 bars to hold a position (time stop) |
| `strategy_warmup_bars` | 300 | 200-500 | Minimum historical D1 bars to seed IIR filters |
| `strategy_spread_mult` | 2.5 | 1.5-5.0 | Block entry if spread > mult × 20-day median spread |
| `strategy_spread_lookback` | 20 | 5-60 | Bars used to compute median spread |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — US large-cap tech index; high liquidity, clear trend cycles
- `SP500.DWX` — US broad market index (backtest-only; broker does not route live orders)
- `WS30.DWX` — US blue-chip index; complementary cycle to NDX
- `GDAXI.DWX` — German DAX 40; European index with distinct cycle behaviour
- `XAUUSD.DWX` — Gold; responds to macro/risk cycles captured by longer filter bands
- `XTIUSD.DWX` — WTI crude oil (ported from USOIL.DWX which is not in DWX matrix)
- `EURUSD.DWX` — Major FX pair; smooth close series suitable for IIR filter signal
- `GBPUSD.DWX` — Major FX pair; adequate liquidity
- `USDJPY.DWX` — Major FX pair; risk-on/off cycle proxy

**Explicitly NOT for:**
- `USOIL.DWX` — not a valid DWX symbol; ported to XTIUSD.DWX
- `SP500.DWX` live promotion — backtest only per board advisory T6-gate note

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` via framework `QM_IsNewBar()` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~100 |
| Typical hold time | 5-40 days |
| Expected drawdown profile | moderate swing drawdown; ATR-based stop limits per-trade risk |
| Regime preference | trend-following / cycle-turn |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog / paper
**Pointer:** Henry Stern, "Trend-Following Filters - Part 3", Alpha Architect 2021-04-08, https://alphaarchitect.com/trend-following-filters-part-3/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_1614_aa-dsp-fbank-turn.md`

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
| v1 | 2026-06-10 | Initial build from card | 66e54b2d-321b-4ba0-9a45-54f194a9ca35 |
