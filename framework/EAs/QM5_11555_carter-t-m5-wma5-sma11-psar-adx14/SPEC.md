# QM5_11555_carter-t-m5-wma5-sma11-psar-adx14 - Strategy Spec

**EA ID:** QM5_11555
**Slug:** carter-t-m5-wma5-sma11-psar-adx14
**Source:** 42530cb3-0265-534a-89cc-150f80733ff5 (see `sources/carter-thomas-20-forex-strategies-5min`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades the M5 trend state from the Carter System #16 card. A long entry is allowed when WMA(5) is above SMA(11), Parabolic SAR(0.01, 0.1) is below the last closed bar, and ADX(14) +DI is above -DI. A short entry uses the mirrored conditions. Positions exit when PSAR flips to the opposite side of price; initial stop loss is the prior 5-bar swing stop capped at 25 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_M5` | M5 expected | Signal timeframe from the card. |
| `strategy_wma_period` | `5` | `1+` | Fast weighted moving average period. |
| `strategy_sma_period` | `11` | `1+` | Slow simple moving average period. |
| `strategy_psar_step` | `0.01` | `>0` | Parabolic SAR step; card resolves invalid source note to 0.01. |
| `strategy_psar_max` | `0.10` | `>0` | Parabolic SAR maximum; card resolves invalid source note to 0.10. |
| `strategy_adx_period` | `14` | `1+` | ADX DI filter period. |
| `strategy_sl_lookback_bars` | `5` | `1+` | Swing high/low lookback for structure stop. |
| `strategy_sl_cap_pips` | `25` | `1+` | Maximum stop distance in pips. |
| `strategy_spread_cap_pips` | `5` | `0+` | Entry-blocking spread cap in pips. |
| `strategy_no_friday_entry` | `true` | `true/false` | Blocks new entries on Friday as specified by the card. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - listed by the card and present in the DWX matrix.
- `GBPUSD.DWX` - listed by the card and present in the DWX matrix.
- `AUDUSD.DWX` - listed by the card and present in the DWX matrix.
- `USDCHF.DWX` - listed by the card and present in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX or unavailable symbols - the build registers only the card's available DWX forex basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `250` |
| Typical hold time | Until M5 PSAR flips; card does not state a fixed duration |
| Expected drawdown profile | Trend-following pullbacks; controlled by 5-bar swing stop capped at 25 pips |
| Regime preference | Trend / directional momentum |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 42530cb3-0265-534a-89cc-150f80733ff5
**Source type:** book
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", self-published 2014, System #16
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11555_carter-t-m5-wma5-sma11-psar-adx14.md`

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
| v1 | 2026-06-11 | Initial build from card | ffb3905c-7b55-4211-823d-46dd58ba1f4b |
