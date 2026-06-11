# QM5_11400_davey-big-range-momentum-d1 — Strategy Spec

**EA ID:** QM5_11400
**Slug:** `davey-big-range-momentum-d1`
**Source:** `fcee8d26-0910-56f3-a0f4-7a0d0a1dfdc9`
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each new closed D1 bar, the EA computes the mean and standard deviation of the last 20 bars' high-low ranges. If the signal bar's range exceeds `2 × StdDev + avg`, the market has printed a statistically exceptional momentum candle. The EA then checks close direction: if close is above the close from 5 bars ago, it enters long at the next bar's open; if below, it enters short. Stop loss is set at 1.5 × ATR(14) from entry; take profit at 2.0 × ATR(14). A breakeven move triggers once the position gains 1.0 × ATR(14) in the trade's favour.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_xr` | 20 | 5–50 | Range-StdDev lookback in D1 bars |
| `strategy_daysback` | 5 | 1–20 | Momentum reference bar shift |
| `strategy_range_mult` | 2.0 | 1.5–3.0 | Threshold multiplier: mult×StdDev + avg |
| `strategy_atr_period` | 14 | 7–21 | ATR period for SL / TP / BE |
| `strategy_sl_atr_mult` | 1.5 | 1.0–3.0 | SL distance as ATR multiple |
| `strategy_tp_atr_mult` | 2.0 | 1.5–4.0 | TP distance as ATR multiple |
| `strategy_be_atr_mult` | 1.0 | 0.5–2.0 | Breakeven trigger as ATR multiple |
| `strategy_spread_cap_pips` | 25.0 | 5–50 | Maximum allowed spread in pips |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep liquidity, clean daily bar ranges, target of original Davey research
- `GBPUSD.DWX` — high daily range volatility, strong momentum candles common
- `USDJPY.DWX` — structurally similar D1 range behaviour; correlates diversification
- `AUDUSD.DWX` — commodity-driven momentum aligns with range-outlier concept

**Explicitly NOT for:**
- Indices — range-outlier thresholds calibrated for forex pip ranges, not index point ranges
- Metals/commodities — require different range normalisations

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
| Trades / year / symbol | ~12 |
| Typical hold time | 1–5 days |
| Expected drawdown profile | ATR-scaled; SL at 1.5×ATR limits per-trade DD |
| Regime preference | volatility-expansion / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `fcee8d26-0910-56f3-a0f4-7a0d0a1dfdc9`
**Source type:** video/PDF
**Pointer:** Kevin J. Davey, "My 5 Favorite Entries", Entry #1: Momentum and Big Range (kjtradingsystems.com webinar; local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\### Forex to read\374755020-My-5-Favorite-Entries.pdf`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11400_davey-big-range-momentum-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | ae37c429-6786-4617-9a10-cfe46e925a8f |
