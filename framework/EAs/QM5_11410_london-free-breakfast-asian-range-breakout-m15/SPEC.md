# QM5_11410_london-free-breakfast-asian-range-breakout-m15 - Strategy Spec

**EA ID:** QM5_11410
**Slug:** london-free-breakfast-asian-range-breakout-m15
**Source:** 8b4188d8-fda3-5633-965f-da707fcb5b4b (see `strategy-seeds/sources/8b4188d8-fda3-5633-965f-da707fcb5b4b/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA marks the broker-time Asian session from 01:00 through 09:00 on M15 bars and stores the wick high and wick low for that same trading day. During the London open window, a long entry fires when the most recently closed M15 bar closes above the Asian high and the prior closed bar had not already closed above it. A short entry mirrors this rule below the Asian low. The stop is the breakout candle low for longs or high for shorts, capped at 40 pips, and the take-profit is fixed at 40 pips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_asian_start_hour_broker` | 1 | 0-23 | Broker-time hour where the Asian range begins. |
| `strategy_asian_end_hour_broker` | 9 | 1-24 | Broker-time hour where the Asian range ends, exclusive. |
| `strategy_london_start_hour_broker` | 9 | 0-23 | Broker-time hour where breakout entries may begin. |
| `strategy_london_end_hour_broker` | 10 | 1-24 | Broker-time hour where breakout-bar eligibility ends, exclusive. |
| `strategy_range_scan_bars` | 80 | 36-160 | Closed M15 bars scanned to recover the current day's Asian range. |
| `strategy_min_asian_bars` | 24 | 16-32 | Minimum valid M15 bars required in the Asian range. |
| `strategy_tp_pips` | 40 | 25-55 | Fixed take-profit in pips. |
| `strategy_sl_cap_pips` | 40 | 20-60 | Maximum stop distance in pips from market entry. |
| `strategy_spread_cap_pips` | 20 | 1-50 | Maximum modeled spread before entry is blocked. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - Primary card instrument for London-session FX breakout behavior.
- `EURUSD.DWX` - Liquid European-major FX pair with DWX M15 history.
- `USDJPY.DWX` - Liquid major FX pair listed by the card as portable.
- `AUDUSD.DWX` - Liquid major FX pair listed by the card as portable.

**Explicitly NOT for:**
- `SP500.DWX` - Index symbol, not part of the card's FX London-breakout basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | 1-2 hours, bounded by fixed SL/TP and Friday close |
| Expected drawdown profile | Breakout false-start losses clustered in low-volatility London opens |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 8b4188d8-fda3-5633-965f-da707fcb5b4b
**Source type:** local PDF / anonymous strategy note
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\423041768-London-Free-Breakfast-Forex-Trading-Strategy-1.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11410_london-free-breakfast-asian-range-breakout-m15.md`

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
| v1 | 2026-06-23 | Initial build from card | 48c8b531-fe93-4c46-9740-89b70d67fb62 |
