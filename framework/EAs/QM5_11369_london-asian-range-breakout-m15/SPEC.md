# QM5_11369_london-asian-range-breakout-m15 - Strategy Spec

**EA ID:** QM5_11369
**Slug:** london-asian-range-breakout-m15
**Source:** 53af8381-7fd2-50f1-add6-a90e0a866868 (see `strategy-seeds/sources/53af8381-7fd2-50f1-add6-a90e0a866868/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA builds an Asian-session box from M15 bars between 22:00 and 07:00 broker time. After 07:00 broker time, it takes the first closed M15 candle that closes strictly above the box high as a long breakout, or strictly below the box low as a short breakout. The stop is the low or high of the breakout candle, capped at 25 pips by default, and the take-profit is a fixed 40 pips. Any remaining position is closed at or after 12:00 broker time, Monday entries are skipped, and only the first clean breakout per day can trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_asian_start_hour` | 22 | 0-23 | Broker-hour start of the Asian range window, inclusive. |
| `strategy_asian_start_minute` | 0 | 0-59 | Broker minute for the Asian range start. |
| `strategy_asian_end_hour` | 7 | 0-23 | Broker-hour end of the Asian range and London-open watch start, exclusive. |
| `strategy_asian_end_minute` | 0 | 0-59 | Broker minute for the Asian range end and London-open watch start. |
| `strategy_london_close_hour` | 12 | 0-23 | Broker hour for the discretionary time exit. |
| `strategy_london_close_minute` | 0 | 0-59 | Broker minute for the discretionary time exit. |
| `strategy_tp_pips` | 40.0 | 25-55 for P3 sweep | Fixed take-profit distance in pips. |
| `strategy_sl_cap_pips` | 25.0 | 20-35 for P3 sweep | Maximum allowed breakout-candle stop distance in pips. |
| `strategy_skip_monday` | true | true/false | Skip Monday entries because the weekend gap can distort the Asian range. |
| `strategy_spread_cap_pips` | 20.0 | 0-50 | Maximum modeled spread in pips; zero spread in `.DWX` tester data is allowed. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - primary GBP/USD instrument from the source and card.
- `EURUSD.DWX` - card-listed forex extension with London-session liquidity.
- `GBPJPY.DWX` - card-listed forex extension with London-session GBP volatility.

**Explicitly NOT for:**
- `SP500.DWX` - the card is a forex London-open range breakout, not an index strategy.
- `XAUUSD.DWX` - not listed in the card's target or extension set.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 220 |
| Typical hold time | Intraday, maximum about 5 hours from 07:00 to 12:00 broker time |
| Expected drawdown profile | Breakout whipsaws around London open; fixed 25-pip maximum initial stop cap |
| Regime preference | London-open volatility expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 53af8381-7fd2-50f1-add6-a90e0a866868
**Source type:** local PDF
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\### Forex to read\423041768-London-Free-Breakfast-Forex-Trading-Strategy-1.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11369_london-asian-range-breakout-m15.md`

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
| v1 | 2026-06-20 | Initial build from card | 51c675a9-2eeb-44aa-bbd6-188296204e52 |
