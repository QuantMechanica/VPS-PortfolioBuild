# QM5_11736_rfs-cutting-points-bb-rsi-adx-m5 - Strategy Spec

**EA ID:** QM5_11736
**Slug:** rfs-cutting-points-bb-rsi-adx-m5
**Source:** b5a932a2-40b6-5628-840b-d5069ac35c4a
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades a Bollinger Band mean-reversion scalp on M5. A long setup requires the previous setup bar to close at or below the lower BB(20,2), RSI(7) below 30, ADX(14) below 30, and the next closed bar to return above the lower band; the EA then buys at the following bar open. A short setup mirrors the logic at the upper band with RSI above 70 and a return-close below the upper band. The stop is placed three pips beyond the signal-side outer band, and the take-profit is the BB middle line, updated while the trade is open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | `> 1` | Bollinger Band moving-average period. |
| `strategy_bb_deviation` | 2.0 | `> 0` | Bollinger Band standard-deviation multiplier. |
| `strategy_rsi_period` | 7 | `> 1` | RSI period used to confirm overbought or oversold extremes. |
| `strategy_rsi_oversold` | 30.0 | `> 0` and `< overbought` | Long-side RSI threshold. |
| `strategy_rsi_overbought` | 70.0 | `> oversold` | Short-side RSI threshold. |
| `strategy_adx_period` | 14 | `> 1` | ADX period used to require non-trending conditions. |
| `strategy_adx_max` | 30.0 | `> 0` | Maximum ADX allowed for entry. |
| `strategy_sl_buffer_pips` | 3 | `> 0` | Stop distance beyond the entry-side Bollinger outer band, in pips. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target and liquid DWX M5 major FX pair.
- `GBPUSD.DWX` - card target and liquid DWX M5 major FX pair.
- `AUDUSD.DWX` - card target and liquid DWX M5 major FX pair.
- `USDCAD.DWX` - card target and liquid DWX M5 major FX pair.

**Explicitly NOT for:**
- Index, metal, energy, and non-target FX `.DWX` symbols - the approved card names only these four FX pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | Intraday M5 scalp, usually minutes to hours. |
| Expected drawdown profile | Frequent small losses from mean-reversion failures, bounded by fixed pip-buffer stops. |
| Regime preference | Mean-revert, sideways or calm markets with ADX below 30. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b5a932a2-40b6-5628-840b-d5069ac35c4a
**Source type:** online compilation PDF
**Pointer:** Anonymous, "Cutting Points", Robo-forex Strategy Compilation, robofx.com, pages 17-18.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11736_rfs-cutting-points-bb-rsi-adx-m5.md`.

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
| v1 | 2026-06-20 | Initial build from card | 5588e487-9a3e-4a4c-93f6-faa35fd5dc16 |
