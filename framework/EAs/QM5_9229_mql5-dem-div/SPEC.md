# QM5_9229_mql5-dem-div — Strategy Spec

**EA ID:** QM5_9229
**Slug:** `mql5-dem-div`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA trades DeMarker(14) one-bar price/indicator divergence on the H1 timeframe. A bullish divergence is detected when the current H1 bar closes with a lower low than the previous bar while the DeMarker(14) reading is higher than the previous bar's reading; the EA enters long at the next bar's open. A bearish divergence is detected when the current H1 bar closes with a higher high while the DeMarker(14) reading is lower; the EA enters short at the next bar's open. Stop loss is placed at the structure extreme (lower of the two lows for longs, higher of the two highs for shorts) plus 0.5 × ATR(14). Take profit targets 1.8R. Exit rules: close long when DeMarker reaches 0.70 or an opposite bearish divergence prints; close short when DeMarker reaches 0.30 or an opposite bullish divergence prints; failsafe time exit after 30 H1 bars. A volatility filter (ATR(14) >= 0.5 × ATR(100)) prevents entries in unusually quiet regimes.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_dem_period` | 14 | 5–50 | DeMarker indicator lookback period |
| `strategy_atr_period` | 14 | 5–50 | ATR period used for SL distance calculation |
| `strategy_atr_vol_period` | 100 | 50–200 | ATR period for long-run volatility filter baseline |
| `strategy_atr_sl_mult` | 0.5 | 0.2–2.0 | SL offset from structure = ATR × this multiplier |
| `strategy_tp_r_mult` | 1.8 | 1.0–5.0 | TP distance expressed as multiples of 1R (SL distance) |
| `strategy_dem_exit_hi` | 0.70 | 0.55–0.90 | Long exit when DeMarker(14) closes at or above this level |
| `strategy_dem_exit_lo` | 0.30 | 0.10–0.45 | Short exit when DeMarker(14) closes at or below this level |
| `strategy_max_bars_hold` | 30 | 10–100 | Failsafe maximum hold in H1 bars |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major liquid forex pair; tight spread; DeMarker divergence well-suited to mean-reverting intraday structure
- `GBPUSD.DWX` — similar characteristics to EURUSD; correlated price structure validates cross-symbol deployment
- `XAUUSD.DWX` — gold; volatile enough to pass ATR volatility filter; exhibits divergence patterns documented in source article

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/GDAXI) — not listed in card's target_symbols; P3 may expand if divergence edge is confirmed across asset classes

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
| Trades / year / symbol | ~60 |
| Typical hold time | 2–30 hours (median ~8 hours) |
| Expected drawdown profile | Moderate; diversified across 3 uncorrelated symbols |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** forum/article
**Pointer:** https://www.mql5.com/en/articles/11394 — Mohamed Abdelmaaboud, "Learn how to design a trading system by DeMarker", MQL5 Articles, 2022-09-08, Strategy Three: DeMarker Divergence
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9229_mql5-dem-div.md`

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
| v1 | 2026-06-10 | Initial build from card | 78a51b56-99fa-4954-b29c-5b15bd932e35 |
