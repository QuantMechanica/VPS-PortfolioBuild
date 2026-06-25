# QM5_1067_carver-carry-fx — Strategy Spec

**EA ID:** QM5_1067
**Slug:** `carver-carry-fx`
**Source:** `2a380bee-1ec4-50d1-a348-b10fac642c7a`
**Author of this spec:** Claude
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

On each closed D1 bar the EA computes an EWMA variance of daily close-change returns (span 25), annualises it by √256, and divides the annualised carry by that vol to get a raw carry ratio. Carry input is broker swap when non-zero; otherwise a per-symbol fallback in basis points (strategy_carry_fallback_bps, set in the setfile) is used — this makes the strategy testable in the DWX tester where broker swap = 0. The ratio is multiplied by scalar 30 and capped at ±20 to get the forecast. If forecast > +2 the EA goes long; if forecast < −2 it goes short. The position closes when the forecast crosses zero or the opposite threshold; a 2.5×ATR(20,D1) emergency stop is placed at entry. One position per symbol/magic at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_entry_forecast` | 2.0 | > 0 | Forecast threshold required to open a new position. |
| `strategy_vol_span_days` | 25 | >= 2 | EWMA span (bars) for daily close-change volatility. Carver default = 25. |
| `strategy_forecast_scalar` | 30.0 | > 0 | Scalar applied to carry / annualised vol to get forecast. |
| `strategy_forecast_cap` | 20.0 | > 0 | Absolute cap applied to the signed forecast. |
| `strategy_atr_period` | 20 | >= 1 | D1 ATR period for the emergency stop. |
| `strategy_atr_stop_mult` | 2.5 | > 0 | ATR multiple for the emergency stop. |
| `strategy_swap_days_per_year` | 256.0 | > 0 | Annualisation factor for swap and volatility. |
| `strategy_carry_fallback_bps` | 150.0 | any | Fallback annual carry in bps when broker swap = 0 (DWX tester). Positive = long base earns; negative = short base earns; 0 = no trades. Set per-symbol in the setfile. |
| `strategy_spread_cap_pips` | 5 | >= 0 | Max spread in pips for new entry. DWX tester spread = 0 always passes through. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDJPY.DWX` — AUD/JPY carry pair: AUD typically high-yielding vs JPY low-yielding
- `NZDJPY.DWX` — NZD/JPY carry pair: similar carry profile to AUD/JPY
- `AUDUSD.DWX` — AUD/USD: moderate carry when AUD rates exceed USD
- `NZDUSD.DWX` — NZD/USD: NZD occasionally higher-yielding
- `USDJPY.DWX` — USD/JPY: USD vs near-zero JPY rates = reliable carry
- `GBPJPY.DWX` — GBP/JPY: GBP rates vs JPY; significant carry in high-rate regimes
- `EURUSD.DWX` — EUR/USD: smaller carry differential, diversifies the basket
- `USDCAD.DWX` — USD/CAD: USD vs CAD rate differential

**Explicitly NOT for:**
- Index or commodity DWX symbols — no interest-rate carry concept applies

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (EWMA uses PERIOD_D1 shifted closes) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~2 |
| Typical hold time | weeks to months |
| Expected drawdown profile | slow-moving, drawdowns during carry unwind events |
| Regime preference | trending / carry (persistent interest-rate differential) |
| Win rate target (qualitative) | medium (carry strategies have moderate hit rate, high RR) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2a380bee-1ec4-50d1-a348-b10fac642c7a`
**Source type:** blog / book (Rob Carver, Systematic Trading ch.7)
**Pointer:** https://qoppac.blogspot.com/2015/09/python-code-for-two-trading-rules-in.html
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1067_carver-carry-fx.md`

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
| v1 | 2026-06-14 | Initial build from card | 1d91729a-96ea-4175-abf0-284731ba90f3 |
| v2 | 2026-06-25 | Zero-trade fix: replaced median-spread-count=0 early-exit and swap=0 early-exit with DWX-invariant-compliant spread cap + carry fallback bps | 649b99a9-4264-408d-b27c-74c343bc97b0 |
