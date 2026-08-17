# QM5_35008_short-term-bollinger-reversion-system — Strategy Spec

**EA ID:** QM5_35008
**Slug:** `short-term-bollinger-reversion-system`
**Source:** `short-term-bollinger-reversion-system-official-source` (see `strategy-seeds/sources/short-term-bollinger-reversion-system/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_35008_short-term-bollinger-reversion-system.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_35008_short-term-bollinger-reversion-system.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

The Short-Term Bollinger Reversion System fades extreme 2.5-sigma Bollinger Band probes during quiet evening hours (18:00 to 22:00 GMT) when RSI(14) exhibits oversold/overbought divergence, targeting reversion to the 20 SMA midline.
- Long Entry: Completed bar within 18:00–22:00 GMT, Low[1] <= LowerBB(20, 2.5)[1], Close[1] > Open[1] (bullish bounce candle), and RSI(14)[1] <= 30.0.
- Short Entry: Completed bar within 18:00–22:00 GMT, High[1] >= UpperBB(20, 2.5)[1], Close[1] < Open[1] (bearish bounce candle), and RSI(14)[1] >= 70.0.
- Stop Loss: Placed at entry - 1.5 * ATR(14)[1] for Long, entry + 1.5 * ATR(14)[1] for Short.
- Take Profit: Target at the 20-period SMA middle band (fallback 1.5x SL distance if middle band is too close).
- Time Exit: Close open positions at 23:00 GMT before rollover.
- Break-Even / Trailing: Move SL to Entry + 1.0 pip when open profit reaches +1.0R.
- No-Trade Filter: Dynamic spread filter (Spread > 1.8 * ATR(14)[1]) and rollover blackout 23:55–00:05 GMT.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 14 - 30 | Bollinger Bands moving average period |
| `strategy_bb_dev` | 2.50 | 2.0 - 3.0 | Standard deviation for outer Bollinger bands |
| `strategy_rsi_period` | 14 | 7 - 21 | RSI oscillator period |
| `strategy_rsi_oversold` | 30.0 | 20.0 - 35.0 | RSI oversold boundary for long entry |
| `strategy_rsi_overbought` | 70.0 | 65.0 - 80.0 | RSI overbought boundary for short entry |
| `strategy_atr_period` | 14 | 10 - 20 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 1.50 | 1.0 - 2.5 | Stop loss distance as ATR multiplier |
| `strategy_entry_start_hhmm` | 1800 | 1600 - 2000 | Session entry window start in GMT (hhmm) |
| `strategy_entry_end_hhmm` | 2200 | 2000 - 2230 | Session entry window end in GMT (hhmm) |
| `strategy_exit_hhmm` | 2300 | 2230 - 2330 | Time exit cutoff before rollover in GMT (hhmm) |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 2.5 | Spread filter ATR multiplier |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA (slot 0)
- `USDCAD.DWX` — registered in magic_numbers.csv for this EA (slot 1)
- `EURCHF.DWX` — registered in magic_numbers.csv for this EA (slot 2)

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

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
| Trades / year / symbol | 110 |
| Cadence note | "80-160 high-conviction trades per year" |
| Typical hold time | Intraday (1 to 5 hours, exit by 23:00 GMT) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Mean-reverting evening ranges with low volatility |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `short-term-bollinger-reversion-system-official-source`
**Pointer:** `strategy-seeds/sources/short-term-bollinger-reversion-system/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_35008_short-term-bollinger-reversion-system.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---
