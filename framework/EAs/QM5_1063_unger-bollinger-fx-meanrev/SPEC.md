# QM5_1063_unger-bollinger-fx-meanrev - Strategy Spec

**EA ID:** QM5_1063
**Slug:** `unger-bollinger-fx-meanrev`
**Source:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9`
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades a Bollinger Band fade on H1 forex majors. On each closed H1 bar it buys when the close is below the lower Bollinger Band and sells when the close is above the upper Bollinger Band, but only when ADX(14) is below the lower of 20 and the 100-bar median ADX. Positions exit when the H1 close crosses back through the Bollinger middle band or when the 12-bar maximum hold time is reached. The initial stop is set at 1.5 x ATR(14) from the entry price.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | H1 fixed by card | Signal and exit timeframe. |
| `strategy_bb_period` | `20` | P3: 14, 20, 30 | Bollinger Band moving-average period. |
| `strategy_bb_deviation` | `2.0` | P3: 1.8, 2.0, 2.5 | Bollinger Band standard-deviation multiplier. |
| `strategy_adx_period` | `14` | fixed by card | ADX trend-filter period. |
| `strategy_adx_median_bars` | `100` | fixed by card | Lookback used for the median ADX baseline. |
| `strategy_adx_gate` | `20.0` | P3: 15, 20, 25 | Absolute ADX cap before applying the median cap. |
| `strategy_atr_period` | `14` | fixed by card | ATR period for the hard stop. |
| `strategy_sl_atr_mult` | `1.5` | P3: 1.0, 1.5, 2.0, 2.5 | ATR multiplier for the initial stop. |
| `strategy_max_hold_bars` | `12` | fixed by card | Maximum H1 bars to hold before a time-stop exit. |
| `strategy_spread_median_days` | `20` | fixed by card | D1 history length for median spread baseline. |
| `strategy_spread_mult` | `2.0` | fixed by card | Blocks new entries when current spread exceeds this multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-approved live-tradable EUR/USD forex major.
- `GBPUSD.DWX` - card-approved live-tradable GBP/USD forex major.

**Explicitly NOT for:**
- Equity indices and commodities - the card defines this as a forex-major Bollinger fade and does not authorize cross-asset expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entries; fixed closed H1 bar reads for signal and exit checks |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | Up to 12 H1 bars, usually shorter if price returns to the middle band |
| Expected drawdown profile | Mean-reversion drawdowns during persistent directional trends, bounded by ATR stop and time cap |
| Regime preference | Mean-revert, non-trending FX regimes |
| Win rate target (qualitative) | medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `eb97a148-0af9-5b9c-878c-25fb5dfa34f9`
**Source type:** book and video
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1063_unger-bollinger-fx-meanrev.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1063_unger-bollinger-fx-meanrev.md`

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
| v1 | 2026-06-13 | Initial build from card | e7559a4f-b246-4cb6-bb89-f646b4bdc2f1 |
