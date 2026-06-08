# QM5_11205_ft-adx-smas - Strategy Spec

**EA ID:** QM5_11205
**Slug:** ft-adx-smas
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long on H1 closed bars when SMA(3) crosses above SMA(6) and ADX(14) is above 25. The order is sent at the next bar as a market buy, with an ATR(14) x 2.5 initial stop and a 10 percent price target. It exits early when ADX(14) falls below 25 and SMA(6) crosses back above SMA(3). Framework news and Friday-close controls remain active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| sma_fast | 3 | 3, 5, 8 | Fast SMA period used for the bullish crossover. |
| sma_slow | 6 | 6, 10, 14 | Slow SMA period used for entry and exit crossover checks. |
| adx_period | 14 | fixed baseline | ADX lookback period from the source rule. |
| adx_threshold | 25.0 | 20, 25, 30 | Minimum ADX for entry and maximum ADX for source exit. |
| atr_stop_period | 14 | fixed baseline | ATR lookback used for the MT5 baseline stop. |
| atr_stop_mult | 2.5 | 2.0, 2.5, 3.0 | ATR multiplier used for the initial stop. |
| roi_target_pct | 10.0 | fixed baseline | Source ROI target as percent above long entry price. |
| max_spread_stop_fraction | 0.10 | fixed baseline | Maximum spread as a fraction of planned stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card R3 primary FX basket member with H1 OHLC coverage.
- GBPUSD.DWX - Card R3 primary FX basket member with H1 OHLC coverage.
- USDJPY.DWX - Card R3 primary FX basket member with H1 OHLC coverage.
- XAUUSD.DWX - Card R3 primary metals basket member with H1 OHLC coverage.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtest registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | H1 crossover hold; hours to days |
| Expected drawdown profile | Medium risk trend-following drawdown profile |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** Gert Wohlgemuth, `AdxSmas.py`, freqtrade-strategies, `user_data/strategies/berlinguyinca/AdxSmas.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11205_ft-adx-smas.md`

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
| v1 | 2026-06-08 | Initial build from card | 090cdc98-ea8f-47a7-8b4e-19d85f2c1a9e |
