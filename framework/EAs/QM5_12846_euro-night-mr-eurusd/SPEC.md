# QM5_12846_euro-night-mr-eurusd - Strategy Spec

**EA ID:** QM5_12846
**Slug:** `euro-night-mr-eurusd`
**Source:** `davey-euro-night-mr-20260630`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

---

## 1. Strategy Logic

This EA trades EURUSD.DWX H1 overnight mean reversion with pending limit orders. On each new H1 bar inside the broker-time entry window, it computes the average high and average low over the last `strategy_lookback_bars`, then places both symmetric limits when valid: a buy limit at average high minus `strategy_atr_mult` times ATR and a sell limit at average low plus `strategy_atr_mult` times ATR. The entry window maps Davey's 18:00-01:00 ET session to 01:00-08:00 broker time under the DXZ ET+7 convention; the hard exit maps 07:00 ET to 14:00 broker. Open trades use ATR-scaled hard stops, ATR or fixed-percent targets, OCO pending cleanup after a fill, and a hard broker-hour time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_bars` | 20 | 2-200 | Rolling H1 high/low mean window. |
| `strategy_atr_mult` | 2.0 | 1.5-3.0 sweep | Cost lever: deeper limits reduce frequency and improve net-of-cost viability. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for entry offset, SL, and ATR TP. |
| `strategy_sl_atr_mult` | 2.0 | 0.5-5.0 | Hard stop distance in ATR units. |
| `strategy_tp_mode` | `QM12846_TP_FIXED_ATR` | enum | Fixed ATR target by default; fixed percent mode is available for Davey WFA. |
| `strategy_tp_atr_mult` | 1.5 | 0.5-5.0 | ATR target distance when `strategy_tp_mode` is fixed ATR. |
| `strategy_tp_fixed_pct` | 0.20 | 0.05-2.00 | Percent target distance when `strategy_tp_mode` is fixed percent. |
| `strategy_entry_start_hour` | 1 | 0-23 broker | Start of overnight entry window; 18:00 ET = 01:00 broker under DXZ ET+7. |
| `strategy_entry_end_hour` | 8 | 0-23 broker | End of new-entry window; 01:00 ET = 08:00 broker under DXZ ET+7. |
| `strategy_exit_hour` | 14 | 0-23 broker | Hard flatten hour; 07:00 ET = 14:00 broker under DXZ ET+7. |
| `strategy_max_spread_points` | 50 | 0-500 | Skip new paired-limit placement when spread exceeds this point cap; 0 disables the guard. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the card's explicit EURUSD overnight FX mean-reversion instrument with H1 history on T1-T5.

**Explicitly NOT for:**
- `XAUUSD.DWX` - different session liquidity and cost profile than the EURUSD overnight card.
- `NDX.DWX` - index overnight behavior is not the Davey Euro Night FX thesis.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80-120 after the wider `strategy_atr_mult` cost filter |
| Typical hold time | Hours, bounded by the same-session `strategy_exit_hour` |
| Expected drawdown profile | Medium FX mean-reversion drawdown, card expectation about 7 percent |
| Regime preference | Overnight mean-reversion after low-liquidity extremes |
| Win rate target (qualitative) | Medium to high with small-to-moderate average wins |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `davey-euro-night-mr-20260630`
**Source type:** video synthesis / OWNER slate
**Pointer:** `docs/research/YOUTUBE_STRATEGY_SYNTHESIS_2026-06-30.md`
**R1-R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12846_euro-night-mr-eurusd.md`

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
| v1 | 2026-07-01 | Initial build from card | adefef89-0159-40fa-a854-7a4b20e71149 |
| v2 | 2026-07-02 | Correct ET->broker session mapping and paired-limit mechanics | entry 1-8 broker, exit 14 broker, max-spread guard, symmetric buy/sell limits |
