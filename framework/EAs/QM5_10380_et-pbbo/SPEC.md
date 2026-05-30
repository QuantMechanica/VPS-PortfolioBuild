# QM5_10380_et-pbbo - Strategy Spec

**EA ID:** QM5_10380
**Slug:** et-pbbo
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades a previous-bar breakout. On each new bar, if flat, it places a buy stop one tick above the most recent completed bar high and a sell stop one tick below that bar low. Once one side fills, the other pending stop is cancelled. The stop loss follows the most recent completed bar opposite extreme, capped by a catastrophic 1.5 x ATR(20) distance when the bar stop is wider or unavailable.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_entry_offset_ticks | 1 | 1-3 | Stop-entry offset beyond the completed bar high or low. |
| strategy_atr_period | 20 | 5-100 | ATR period used by the range filter and catastrophic stop cap. |
| strategy_catastrophic_atr_mult | 1.50 | 0.5-5.0 | Maximum stop distance as a multiple of ATR. |
| strategy_range_max_atr_mult | 1.25 | 1.0-1.5 | Maximum allowed previous-bar range as a multiple of ATR. |
| strategy_min_range_spread_mult | 4.00 | 1.0-10.0 | Minimum previous-bar range as a multiple of current spread. |
| strategy_session_start_hour | 8 | 0-23 | Broker-hour start of the liquid regular-session window. |
| strategy_session_end_hour | 21 | 0-24 | Broker-hour end of the liquid regular-session window. |
| strategy_pending_expiry_bars | 1 | 1-4 | Number of current-chart bars before unfilled stop entries expire. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol named in the card's R3 basket.
- NDX.DWX - Nasdaq 100 index exposure named in the card's R3 basket.
- WS30.DWX - Dow 30 index exposure named in the card's R3 basket.
- GDAXI.DWX - canonical DAX custom symbol in the DWX matrix, used for the card's GER40.DWX intent.
- EURUSD.DWX - canonical DWX-suffixed form of the card's EURUSD FX target.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is the registered DAX equivalent.
- EURUSD - no `.DWX` suffix; backtest registry and setfiles use EURUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M2 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 220 |
| Typical hold time | minutes to a few bars |
| Expected drawdown profile | High-turnover micro-breakout with whipsaw and cost sensitivity. |
| Regime preference | Volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** https://www.elitetrader.com/et/threads/would-anyone-wish-to-share-a-1-minute-chart-strategy.74882/page-3
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10380_et-pbbo.md`

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
| v1 | 2026-05-25 | Initial build from card | 8fac2011-2ac8-4eb8-9462-07ba0e1bb7f0 |
