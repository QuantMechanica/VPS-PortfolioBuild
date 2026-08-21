# QM5_36005_nnfx-coral-trendlord-woodies-harvester — Strategy Spec

**EA ID:** QM5_36005
**Slug:** `nnfx-coral-trendlord-woodies-harvester`
**Source:** `nnfx-coral-trendlord-woodies-harvester-official-source` (see `strategy-seeds/sources/nnfx-coral-trendlord-woodies-harvester/`)
**Author of this spec:** Development (Gemini)
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card `artifacts/cards_approved/QM5_36005_nnfx-coral-trendlord-woodies-harvester.md`. See that card's body for the full entry/exit/stop/sizing rules; this SPEC summarises the implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in `QM5_36005_nnfx-coral-trendlord-woodies-harvester.mq5`. Framework wiring (risk, magic, news, Friday close) is inherited from `QM_Common.mqh` and is not redocumented here.

The official NNFX trend-following momentum algorithm on D1 combines Coral (Baseline), Trend Lord (C1 Trigger), Woodies CCI (C2 Confirmation), and Waddah Attar Explosion (Volume):
- Baseline: Coral Trend Indicator(20, 0.40) evaluated on completed D1 bars (Shift=1).
- C1 Trigger: Trend Lord(50) directional slope color (Green for Long, Red for Short).
- C2 Confirmation: Woodies CCI(14) (> 0 for Long, < 0 for Short).
- Volume Gate: Waddah Attar Explosion (MACD(12,26,9) momentum exceeding Bollinger Bands(20,2.0) explosion threshold or deadzone).
- Long Entry: Close[1] > Coral[1] AND TrendLord[1] == GREEN (+1) AND Woodies_CCI[1] > 0 AND WAE > ExplosionLine.
- Short Entry: Close[1] < Coral[1] AND TrendLord[1] == RED (-1) AND Woodies_CCI[1] < 0 AND WAE > ExplosionLine.
- Stop Loss: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Take Profit: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Break-Even: Move SL to Entry + 1.0 pip when open profit reaches +1.0R (1.0x ATR).
- Indicator Exit: Close position when Trend Lord flips color (RED for Long, GREEN for Short) or Woodies CCI crosses 0 against the trade.
- No-Trade Filter: Dynamic spread filter (Spread > 1.8 * ATR(14, D1)[1]) and rollover blackout 23:55–00:05 GMT.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_coral_period` | 20 | 14 - 30 | Coral SMMA/T3 smoothing period |
| `strategy_coral_coeff` | 0.40 | 0.20 - 0.80 | Coral smoothing coefficient |
| `strategy_coral_warmup_bars` | 100 | 50 - 200 | Closed-bar lookback warmup depth for Coral |
| `strategy_trendlord_period` | 50 | 20 - 70 | Trend Lord lookback period |
| `strategy_woodies_cci_period` | 14 | 10 - 20 | Woodies CCI period |
| `strategy_wae_fast` | 12 | 8 - 16 | WAE MACD fast EMA period |
| `strategy_wae_slow` | 26 | 20 - 32 | WAE MACD slow EMA period |
| `strategy_wae_signal` | 9 | 5 - 12 | WAE MACD signal SMA period |
| `strategy_wae_bb_period` | 20 | 14 - 26 | WAE Bollinger Bands period |
| `strategy_wae_bb_deviation` | 2.0 | 1.5 - 2.5 | WAE Bollinger Bands deviation |
| `strategy_wae_sensitivity` | 150 | 100 - 200 | WAE sensitivity multiplier |
| `strategy_wae_deadzone_pts` | 150 | 100 - 200 | WAE deadzone in points |
| `strategy_atr_period` | 14 | 10 - 20 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 1.00 | 0.8 - 1.5 | Stop loss distance as ATR multiplier |
| `strategy_tp_atr_mult` | 1.00 | 0.8 - 1.5 | Take profit distance as ATR multiplier |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 2.5 | Spread filter ATR multiplier |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` — registered in magic_numbers.csv for this EA (slot 0)
- `EURJPY.DWX` — registered in magic_numbers.csv for this EA (slot 1)
- `AUDNZD.DWX` — registered in magic_numbers.csv for this EA (slot 2)

**Explicitly NOT for:** any symbol not in the list above (no implicit universe expansion at runtime; the `QM_SymbolGuard` framework helper rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Cadence note | "80-160 high-conviction trades per year across 3 pairs" |
| Typical hold time | Daily swing (several D1 bars, up to 1-3 weeks) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Multi-indicator trend consensus with confirmed volume expansion |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-coral-trendlord-woodies-harvester-official-source`
**Pointer:** `strategy-seeds/sources/nnfx-coral-trendlord-woodies-harvester/`
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_36005_nnfx-coral-trendlord-woodies-harvester.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---
