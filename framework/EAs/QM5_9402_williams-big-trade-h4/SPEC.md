# QM5_9402_williams-big-trade-h4 - Strategy Spec

**EA ID:** QM5_9402
**Slug:** williams-big-trade-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

This EA trades Larry Williams' Big-Trade key-reversal pattern on H4 by aggregating the last six closed H4 bars into a rolling compound-D1 bar. A long entry is opened when the compound bar undercuts the prior compound-D1 low, closes above the prior compound-D1 close, closes green, and has a lower tail of at least 0.6 ATR(14,H4). A short entry mirrors the rule with a higher high, lower close, red compound bar, and an upper tail of at least 0.6 ATR. SL is placed 0.3 ATR beyond the compound-D1 extreme, TP projects one compound-D1 range beyond the opposite extreme, and positions time out after 18 closed H4 bars if neither SL nor TP fires.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_compound_bars | 6 | 2-24 | Number of closed H4 bars aggregated into the compound-D1 signal bar. |
| strategy_atr_period | 14 | 2-100 | H4 ATR period used for tail validation, spread filter, and stop buffer. |
| strategy_tail_atr_mult | 0.6 | 0.1-5.0 | Minimum reversal tail as a multiple of ATR(14,H4). |
| strategy_stop_atr_mult | 0.3 | 0.0-5.0 | SL buffer beyond the compound-D1 high or low. |
| strategy_target_range_mult | 1.0 | 0.1-10.0 | TP projection multiple of the compound-D1 high-low range. |
| strategy_spread_atr_mult | 0.20 | 0.0-2.0 | Maximum live spread as a fraction of ATR(14,H4). |
| strategy_time_stop_bars | 18 | 1-200 | Maximum holding period in closed H4 bars. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major listed by the approved card and present in the DWX matrix.
- GBPUSD.DWX - FX major listed by the approved card and present in the DWX matrix.
- USDJPY.DWX - FX major listed by the approved card and present in the DWX matrix.
- AUDUSD.DWX - FX major listed by the approved card and present in the DWX matrix.
- USDCAD.DWX - FX major listed by the approved card and present in the DWX matrix.
- USDCHF.DWX - FX major listed by the approved card and present in the DWX matrix.
- NZDUSD.DWX - FX major listed by the approved card and present in the DWX matrix.
- XAUUSD.DWX - metal CFD listed by the approved card and present in the DWX matrix.
- XTIUSD.DWX - energy CFD listed by the approved card and present in the DWX matrix.
- GDAXI.DWX - DAX index CFD listed by the approved card and present in the DWX matrix.
- NDX.DWX - US index CFD listed by the approved card and present in the DWX matrix.
- WS30.DWX - US index CFD listed by the approved card and present in the DWX matrix.
- UK100.DWX - UK index CFD listed by the approved card and present in the DWX matrix.

**Explicitly NOT for:**
- FRA40.DWX - listed by the approved card but absent from `framework/registry/dwx_symbol_matrix.csv` at build time.
- JP225.DWX - listed by the approved card but absent from `framework/registry/dwx_symbol_matrix.csv` at build time.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 22 |
| Typical hold time | Up to 18 H4 bars, about 3 trading days |
| Expected drawdown profile | Fixed 1R event risk with reversal-pattern losses clustered in persistent trends |
| Regime preference | mean-reversion after compound-D1 key reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum plus book attribution
**Pointer:** https://www.forexfactory.com/thread/post/14001500 and Larry Williams, Long-Term Secrets to Short-Term Trading, ch. 9
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_9402_williams-big-trade-h4.md`

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
| v1 | 2026-06-26 | Initial build from card | dbf902ae-428b-48a5-b403-a79dd0337714 |
