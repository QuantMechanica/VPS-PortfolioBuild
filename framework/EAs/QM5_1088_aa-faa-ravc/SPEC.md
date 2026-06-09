# QM5_1088_aa-faa-ravc - Strategy Spec

**EA ID:** QM5_1088
**Slug:** aa-faa-ravc
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7 (see `sources/alpha-architect-blog`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA evaluates a seven-symbol DWX proxy universe once per new monthly bar. For each symbol it computes four-month relative momentum, four-month realized volatility, and average four-month correlation to the rest of the universe. It ranks symbols by composite score: relative momentum rank plus half volatility rank plus half correlation rank, with lower volatility and lower correlation ranked better. A symbol is bought only when it is in the top three composite ranks and its absolute four-month momentum is positive; open positions are closed when the cached monthly rebalance selection no longer includes the symbol.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rebalance_timeframe` | `PERIOD_MN1` | MT5 timeframe enum | Timeframe used for monthly ranking and closed-bar entry cadence. |
| `strategy_lookback_months` | `4` | `2-12` | Number of closed monthly bars used for momentum, volatility, and correlation. |
| `strategy_top_n` | `3` | `1-7` | Number of composite-ranked eligible assets selected each rebalance. |
| `strategy_atr_period` | `4` | `1-24` | ATR period for the per-leg protective stop. |
| `strategy_atr_sl_mult` | `4.0` | `0.5-10.0` | ATR multiple for the per-leg protective stop. |
| `strategy_rebalance_day_max` | `7` | `1-10` | Latest calendar day in the new month where a rebalance entry may fire. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 proxy from the card's R3 DWX basket.
- `NDX.DWX` - Nasdaq 100 proxy from the card's R3 DWX basket.
- `GDAXI.DWX` - DAX proxy from the card's R3 DWX basket.
- `XAUUSD.DWX` - Gold proxy from the card's R3 DWX basket.
- `XTIUSD.DWX` - Crude oil proxy from the card's R3 DWX basket.
- `EURUSD.DWX` - Euro-dollar FX proxy from the card's R3 DWX basket.
- `USDJPY.DWX` - Dollar-yen FX proxy from the card's R3 DWX basket.

**Explicitly NOT for:**
- Unregistered symbols - the ranking logic uses the fixed seven-symbol card universe and registered magic slots only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `MN1` ranking and rebalance logic; lower chart periods may be used by the tester to provide tick generation while monthly closed bars remain the signal source. |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | about one month, until next rebalance |
| Expected drawdown profile | moderate tactical allocation drawdown, bounded by ATR leg stops and portfolio hard stop |
| Regime preference | relative momentum with risk-regime/correlation diversification preference |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Source type:** blog
**Pointer:** Wesley Gray, PhD, "Flexible Asset Allocation: Dethroning Moving Average Rules?", Alpha Architect, 2014-09-18
**R1-R4 verdict (Q00):** all R1, R2, and R4 PASS; R3 mapped to the approved DWX proxy basket per `artifacts/cards_approved/QM5_1088_aa-faa-ravc.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | 887fd34f-13d1-48a5-ac13-8e99c8d94adb |
