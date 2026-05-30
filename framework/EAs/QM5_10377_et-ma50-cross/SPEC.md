# QM5_10377_et-ma50-cross - Strategy Spec

**EA ID:** QM5_10377
**Slug:** et-ma50-cross
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA evaluates completed H4 bars and compares the last two closes to SMA(50) of close. It opens long when the previous close was below SMA(50) and the latest completed close is above SMA(50). The symmetric variant opens short when the previous close was above SMA(50) and the latest completed close is below SMA(50). Open positions close when the opposite cross appears, with an ATR(14) protective stop placed at entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 50 | 20-200 | Close-price SMA period used for entry and reversal exit. |
| `strategy_atr_period` | 14 | 1-100 | ATR period used for the protective stop. |
| `strategy_stop_atr_mult` | 1.5 | 1.0-3.0 | ATR multiple used to place the protective stop. |
| `strategy_symmetric_shorts` | true | true/false | Enables the V5 symmetric short variant of the source long rule. |
| `strategy_use_d1_sma200` | false | true/false | Optional D1 SMA(200) trend filter from the card. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with complete DWX coverage.
- `GBPUSD.DWX` - card-listed FX major with complete DWX coverage.
- `XAUUSD.DWX` - card-listed metal symbol already canonical in DWX.
- `GDAXI.DWX` - DWX canonical DAX equivalent for the card's GER40 target.
- `SP500.DWX` - card-listed S&P 500 custom symbol; valid for backtest registration.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX` - not the canonical S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | Optional D1 SMA(200) trend filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | Several H4 bars to multiple days, until opposite SMA(50) cross or stop |
| Expected drawdown profile | Whipsaw risk in sideways regimes, bounded by ATR stop |
| Regime preference | Trend-following |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/tradestation-9-5-strange-strategy-execution.351193/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10377_et-ma50-cross.md`

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
| v1 | 2026-05-25 | Initial build from card | ea68ca67-2137-4314-ad6e-7c81b1dd8610 |
