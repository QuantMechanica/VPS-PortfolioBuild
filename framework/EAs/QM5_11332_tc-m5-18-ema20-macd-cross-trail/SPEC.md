# QM5_11332_tc-m5-18-ema20-macd-cross-trail - Strategy Spec

**EA ID:** QM5_11332
**Slug:** tc-m5-18-ema20-macd-cross-trail
**Source:** e78a9f1f-4e6a-563c-a080-915133d6ed28
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades the Thomas Carter M5 System #18 mechanically. On each new M5 bar it looks for the last closed bar to cross EMA(20), then requires the MACD(12,26,9) main line to have crossed the zero line in the same direction within the last five closed bars. A long signal places a buy stop 10 pips above EMA(20), or enters at market if price is already beyond that trigger on the next bar; shorts mirror this 10 pips below EMA(20). The initial stop is the conservative EMA(20) +/- 20 pip stop capped to 1.5 ATR(14), half the position is closed at 1R, the remaining stop moves to breakeven, and the remainder trails by EMA(20) +/- 15 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 20 | 2-200 | EMA period for price cross, entry trigger, and trailing stop. |
| `strategy_macd_fast` | 12 | 1-100 | Fast EMA period for MACD main line. |
| `strategy_macd_slow` | 26 | fast+1-200 | Slow EMA period for MACD main line. |
| `strategy_macd_signal` | 9 | 1-100 | MACD signal period used by the standard MACD handle. |
| `strategy_macd_lookback` | 5 | 1-20 | Number of closed bars scanned for a same-direction MACD zero cross. |
| `strategy_entry_offset_pips` | 10.0 | 1.0-50.0 | Stop-entry offset above or below EMA(20). |
| `strategy_stop_ema_pips` | 20.0 | 1.0-100.0 | Conservative stop distance from EMA(20) before ATR cap. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the stop-distance cap. |
| `strategy_atr_cap_mult` | 1.5 | 0.1-10.0 | Maximum stop distance as a multiple of ATR(14). |
| `strategy_trail_ema_pips` | 15.0 | 1.0-100.0 | EMA(20) trailing offset for the remainder after the 1R partial. |
| `strategy_partial_pct` | 50.0 | 1.0-100.0 | Percent of the open position to close at 1R. |
| `strategy_spread_cap_pips` | 12.0 | 0.1-50.0 | Maximum allowed spread in pips before blocking entries. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major for M5 EMA/MACD testing.
- `GBPUSD.DWX` - card-listed liquid FX major for M5 EMA/MACD testing.
- `USDJPY.DWX` - card-listed liquid FX major for M5 EMA/MACD testing.

**Explicitly NOT for:**
- Non-FX index, metal, and energy `.DWX` symbols - the approved card specifies only the three FX instruments above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 130 |
| Typical hold time | minutes to hours, until 1R partial and EMA20 trailing stop complete |
| Expected drawdown profile | fixed-risk intraday trend-following with capped EMA stop and partial exit |
| Regime preference | trend-following / momentum continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** e78a9f1f-4e6a-563c-a080-915133d6ed28
**Source type:** book / PDF
**Pointer:** Thomas Carter, 20 Forex Trading Strategies (5 Minute Time Frame), 5 Min Trading System #18, local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11332_tc-m5-18-ema20-macd-cross-trail.md`

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
| v1 | 2026-06-08 | Initial build from card | a7d1bad5-9e94-4e73-ac97-b08cf6bb96d8 |
