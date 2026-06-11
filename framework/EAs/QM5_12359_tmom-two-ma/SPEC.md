# QM5_12359_tmom-two-ma - Strategy Spec

**EA ID:** QM5_12359
**Slug:** tmom-two-ma
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see approved card citation)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates completed D1 bars after an 80-bar warmup. It computes SMA(10) and SMA(50) on the D1 close. It opens long when SMA(10) crosses from at or below SMA(50) to above SMA(50), and opens short when SMA(10) crosses from at or above SMA(50) to below SMA(50). Open positions are closed on the opposite D1 crossover, while the broker stop is a hard stop placed 2.0 * ATR(14) from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_short_ma_period | 10 | 1 to strategy_long_ma_period - 1 | Short D1 SMA period used for crossover detection. |
| strategy_long_ma_period | 50 | strategy_short_ma_period + 1 and above | Long D1 SMA period used for crossover detection. |
| strategy_atr_period | 14 | 1 and above | D1 ATR period used for the hard stop distance. |
| strategy_atr_sl_mult | 2.0 | > 0.0 | ATR multiplier for the initial hard stop. |
| strategy_warmup_bars | 80 | >= strategy_long_ma_period | Minimum D1 history gate before entries are allowed. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 includes DWX FX majors and the rule uses portable close-derived moving averages.
- GBPUSD.DWX - card R3 includes DWX FX majors and the rule uses portable close-derived moving averages.
- USDJPY.DWX - card R3 includes DWX FX majors and the rule uses portable close-derived moving averages.
- XAUUSD.DWX - card R3 includes metals and the rule uses portable close-derived moving averages.
- GDAXI.DWX - canonical DAX custom symbol in the DWX matrix; used for the card's GER40.DWX DAX leg.
- NDX.DWX - card R3 includes Nasdaq 100 index exposure and the rule uses portable close-derived moving averages.
- WS30.DWX - card R3 includes Dow 30 index exposure and the rule uses portable close-derived moving averages.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to GDAXI.DWX.
- SP500.DWX - optional in the card only, not part of the primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | Days to weeks; exits on opposite D1 crossover or ATR hard stop. |
| Expected drawdown profile | Sideways-market whipsaw is the main drawdown source. |
| Regime preference | Trend-following / moving-average crossover. |
| Win rate target (qualitative) | Medium to low, with winners expected to come from persistent trends. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository strategy file
**Pointer:** ThewindMom/151-trading-strategies, `src/strategies/stocks/two_ma.py`, https://github.com/ThewindMom/151-trading-strategies/blob/main/src/strategies/stocks/two_ma.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12359_tmom-two-ma.md`

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
| v1 | 2026-06-11 | Initial build from card | 78f3a7e2-6adf-4843-a500-6394c0e213c6 |
