# QM5_34003_triple-timeframe-williams-r-champion - Strategy Spec

**EA ID:** QM5_34003
**Slug:** 	riple-timeframe-williams-r-champion
**Source:** 	riple-timeframe-williams-r-champion-official-source (see strategy-seeds/sources/triple-timeframe-williams-r-champion-official-source/)
**Author of this spec:** Development
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
rtifacts/cards_approved/QM5_34003_triple-timeframe-williams-r-champion.md. See that card body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five Strategy_* hooks in
QM5_34003_triple-timeframe-williams-r-champion.mq5. Framework wiring (risk, magic, news, Friday close)
is inherited from QM_Common.mqh and is not redocumented here.

- Multi-timeframe trend alignment: H4 macro trend, H1 intermediate trend, M15 entry timing.
- Indicator: Williams %R (14) across H4, H1, M15.
- Long Entry: H4 WPR >= -35.0 AND H1 WPR >= -50.0 AND M15 WPR <= -80.0.
- Short Entry: H4 WPR <= -65.0 AND H1 WPR <= -50.0 AND M15 WPR >= -20.0.
- Stop Loss: 1.5 * ATR(14, M15)[1].
- Take Profit: 2.5 * SL_Distance (1:2.5 R:R).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_wpr_period | 14 | 10 - 28 | Williams %R calculation lookback period |
| strategy_h4_trend_long | -35.0 | -45.0 - -25.0 | H4 macro trend threshold for Long |
| strategy_h4_trend_short | -65.0 | -75.0 - -55.0 | H4 macro trend threshold for Short |
| strategy_h1_trend_mid | -50.0 | -60.0 - -40.0 | H1 intermediate trend threshold |
| strategy_m15_pullback_long | -80.0 | -90.0 - -70.0 | M15 pullback extreme for Long |
| strategy_m15_pullback_short | -20.0 | -30.0 - -10.0 | M15 pullback extreme for Short |
| strategy_atr_period | 14 | 10 - 20 | ATR period for stop loss sizing |
| strategy_sl_atr_mult | 1.5 | 1.0 - 2.5 | Initial SL in ATR multiples |
| strategy_tp_rr_mult | 2.5 | 1.5 - 3.5 | Take Profit risk:reward multiplier |
| strategy_spread_atr_period | 14 | 10 - 20 | Spread filter ATR period |
| strategy_spread_atr_mult | 1.8 | 1.2 - 2.5 | Spread filter threshold |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - registered in magic_numbers.csv for this EA (slot 0)
- GBPUSD.DWX - registered in magic_numbers.csv for this EA (slot 1)
- USDCHF.DWX - registered in magic_numbers.csv for this EA (slot 2)

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the QM_SymbolGuard framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | H4, H1, M15 |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_M15) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Cadence note | 80-160 high-conviction trades per year |
| Typical hold time | Intraday to multi-day swing |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Trending with pullback |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 	riple-timeframe-williams-r-champion-official-source
**Pointer:** strategy-seeds/sources/triple-timeframe-williams-r-champion-official-source/
**R1-R4 verdict (Q00):** all PASS - see
rtifacts/cards_approved/QM5_34003_triple-timeframe-williams-r-champion.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | ,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by QM_FrameworkInit (EA_INPUT_RISK_MODE_MISMATCH).
