# QM5_11690_strat-ma-trend - Strategy Spec

**EA ID:** QM5_11690
**Slug:** strat-ma-trend
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA reads the completed H1 close and compares it with one moving average on close. It enters long when the completed close is above the moving average and enters short when the completed close is below it. It closes an open long when the completed close is below or equal to the moving average, and closes an open short when the completed close is above or equal to the moving average. The source has no protective stop, so the implementation adds the V5 ATR catastrophic stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_use_ema` | `false` | `false` or `true` | `false` uses the card seed SMA; `true` enables the static EMA axis for later P3 testing. |
| `strategy_ma_period` | `50` | `2+` | Period of the single moving average on close. |
| `strategy_atr_period` | `14` | `1+` | ATR period used only for the V5 catastrophic stop. |
| `strategy_sl_atr_mult` | `2.0` | `> 0` | Stop distance in ATR multiples. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card target; liquid DWX forex symbol with close-derived MA data.
- `XAUUSD.DWX` - Card target; liquid DWX metal CFD with close-derived MA data.
- `GDAXI.DWX` - Matrix-backed DAX custom symbol used as the available port for the card's `GER40.DWX` target.

**Explicitly NOT for:**
- `GER40.DWX` - Named in the card but not present in `framework/registry/dwx_symbol_matrix.csv`; not registered.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Card does not specify; positions hold until the completed close changes side versus the MA, the ATR catastrophic stop is hit, or framework Friday close runs. |
| Expected drawdown profile | Trend-following whipsaw risk in sideways regimes; single-trade loss capped by ATR catastrophic stop. |
| Regime preference | Trend-following. |
| Win rate target (qualitative) | Not specified by card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository source file
**Pointer:** https://github.com/diogomatoschaves/stratestic/blob/main/stratestic/strategies/moving_average/ma.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11690_strat-ma-trend.md`

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
| v1 | 2026-07-07 | Initial build from card | 424d246b-e219-4337-b3cc-8b3104809bc3 |
