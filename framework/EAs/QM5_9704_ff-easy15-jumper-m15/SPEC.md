# QM5_9704 — ForexFactory Easy 15 London-Open Jumper M15

**EA ID:** QM5_9704
**Slug:** ff-easy15-jumper-m15
**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Built:** 2026-06-11

---

## 1. Strategy Logic

London-open momentum jumper on M15. Each day, the EA monitors M15 bars from
broker hour 10 (GMT+2, outside US DST; adjust to 11 if DST active) for four
hours. The first candle that closes across EMApredictive (implemented as EMA 2)
becomes the *jumper* candle. On the immediately following candle, the EA enters
if that candle breaks above/below the jumper high/low AND the Traders Dynamic
Index (TDI) and EMA 200 confirm trend direction.

TDI: RSI Price Line = EMA(2) of RSI(13), Market Base Line = EMA(7) of RSI(13).
Long: Price Line above Base Line. Short: Price Line below Base Line. EMA(200)
trend filter: close above EMA(200) for longs, below for shorts.

ATR session filter: skip the session if ATR(14,M15) at London open is below 60%
of the 20-day mean ATR sampled at the same daily time stride.

One trade per session maximum. Positions managed per-tick for:
- Breakeven shift: after +10 pips in favour.
- Time stop: forced close after 16 M15 bars (~4 hours).
- TDI cross exit: on each new closed bar, exit if TDI Price Line crosses back
  across TDI Base Line (reversal signal).
- TP = 1.2R relative to SL distance (SL = wider of 20-pip floor or
  jumper-anchor ± 0.20 × ATR(14, M15)).

## 2. Parameters

| Input | Default | Notes |
|---|---|---|
| `strategy_sl_pips` | 20 | Minimum SL in pips (symbol-normalised) |
| `strategy_sl_atr_mult` | 0.20 | ATR multiplier for jumper-anchor SL extension |
| `strategy_tp_r_mult` | 1.2 | TP = R × multiplier |
| `strategy_be_trigger_pips` | 10 | Pips in profit before BE shift |
| `strategy_time_stop_bars` | 16 | Max bars before forced close |
| `strategy_ema_fast_period` | 2 | EMApredictive approximation (EMA 2 of close) |
| `strategy_ema_trend_period` | 200 | Trend filter EMA on M15 |
| `strategy_rsi_period` | 13 | TDI RSI period |
| `strategy_tdi_green_period` | 2 | TDI RSI Price Line EMA period |
| `strategy_tdi_yellow_period` | 7 | TDI Market Base Line EMA period |
| `strategy_atr_period` | 14 | ATR period for SL and volatility filter |
| `strategy_atr_filter_ratio` | 0.60 | ATR filter: skip if ATR < ratio × 20-day mean |
| `strategy_london_open_hour` | 10 | London open broker hour (GMT+2 standard) |
| `strategy_london_duration_hours` | 4 | Trading window in hours |

## 3. Symbol Universe

- EURUSD.DWX (slot 0, magic 97040000)
- GBPUSD.DWX (slot 1, magic 97040001)
- USDJPY.DWX (slot 2, magic 97040002)
- XAUUSD.DWX (slot 3, magic 97040003)

All four confirmed present in `framework/registry/dwx_symbol_matrix.csv`.

## 4. Timeframe

M15 (15-minute bars). Entry and indicator computation on M15 only.
No cross-timeframe reads.

## 5. Expected Behaviour

- Expected trades: ~55 per symbol per year (card estimate).
- Frequency class: intraday, London session.
- The session state machine resets each broker day; at most one entry per
  symbol per session.
- In backtests, the ATR filter will reduce entries on low-volatility days.
- Low-volatility consolidation periods produce fewer trades; this is intentional.
- Q02 smoke: expect trades on EURUSD.DWX 2024 year backtest with PF ≥ 1.0.

## 6. Source Citation

- Strategy card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_9704_ff-easy15-jumper-m15.md`
- G0 source ID: 6e967762-b26d-59a3-b076-35c17f2e7c36
- Original public reference: ForexFactory "Easy 15" thread (R1 community crowd-source).
- TDI indicator reference: Dean Malone, Traders Dynamic Index.
- EMApredictive 2.1 approximated as EMA(2) of close — closest deterministic
  equivalent with no look-ahead.

## 7. Risk Model

- Backtest: `RISK_FIXED = 1000` (fixed USD per trade), `RISK_PERCENT = 0`.
- Live: `RISK_FIXED = 0`, `RISK_PERCENT = 0.5` (0.5% of account equity).
- SL distance feeds `QM_LotsForRisk` for lot sizing (framework-computed).
- `PORTFOLIO_WEIGHT = 1.0` default; adjust at portfolio-construction gate (Q11).
- Magic schema: `ea_id × 10000 + symbol_slot` (Hard Rule HR5).
