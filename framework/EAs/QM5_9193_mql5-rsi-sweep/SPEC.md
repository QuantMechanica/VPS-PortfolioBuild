# QM5_9193_mql5-rsi-sweep — Strategy Spec

**EA ID:** QM5_9193
**Slug:** `mql5-rsi-sweep`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

When RSI(14) drops below 30 on any M15 bar, the EA records that bar's low as the liquidity reference level. Once RSI recovers above 30, the EA watches for price to sweep (break below) that level. On the first M15 bar that closes back above the swept level (bullish confirmation), a long position is entered. The stop is placed below the swept level by ATR(14)×0.25; the take-profit is set at 2R. A break-even shift moves the stop to entry+2pips after a +1R favourable move. The short mirror fires when RSI exceeds 70 and price sweeps above the corresponding candle high before a bearish close confirms below it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 5–50 | RSI lookback period |
| `strategy_rsi_oversold` | 30.0 | 10–45 | RSI threshold for long extreme |
| `strategy_rsi_overbought` | 70.0 | 55–90 | RSI threshold for short extreme |
| `strategy_extreme_valid_bars` | 20 | 3–50 | Bars after RSI recovers before setup expires |
| `strategy_atr_period` | 14 | 5–50 | ATR period for stop buffer |
| `strategy_sl_atr_mult` | 0.25 | 0.1–1.0 | Multiplier for ATR stop buffer |
| `strategy_rr` | 2.0 | 1.0–4.0 | Risk-reward ratio for TP |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair with clean RSI swings and reliable liquidity sweeps
- `GBPUSD.DWX` — volatile major with frequent RSI extremes suitable for sweep reversals
- `XAUUSD.DWX` — gold frequently forms RSI extremes around liquidity pockets; M15 sweep setups are reliable

**Explicitly NOT for:**
- Illiquid or thin-spread instruments where sweep signals are noisy

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~24 |
| Typical hold time | hours to 1–2 days |
| Expected drawdown profile | moderate; many small losses offset by 2R winners |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** forum/article
**Pointer:** Israel Pelumi Abioye, "Introduction to MQL5 (Part 10): A Beginner's Guide to Working with Built-in Indicators in MQL5", MQL5 Articles, 2024-12-04, https://www.mql5.com/en/articles/16514
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9193_mql5-rsi-sweep.md`

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
| v1 | 2026-06-10 | Initial build from card | 03cc94b3-c0fc-4d05-8fea-6d6091dc4529 |
