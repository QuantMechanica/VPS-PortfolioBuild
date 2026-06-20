# QM5_11274_iaf-rsi-ema — Strategy Spec

**EA ID:** QM5_11274
**Slug:** `iaf-rsi-ema`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

Long-only RSI + EMA-crossover confirmation strategy ported from the
`investing-algorithm-framework` `RSIEMACrossoverStrategy` example. The EA opens
a long when, on a closed H2 bar, RSI(14) is below 30 and a bullish EMA(12) >
EMA(26) crossover occurred at any point within the last 10 closed bars. It
exits the long when RSI(14) is at or above 70 and a bearish EMA(12) < EMA(26)
crossunder occurred within the last 10 closed bars. Risk is bounded by an
ATR(14)-scaled stop (2x ATR) as the V5 fixed-risk translation of the source's
percent stop, with a take-profit at 2x the stop distance. Friday-close and news
guards are framework-supplied.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 12 | 5-50 | Fast EMA period (source EMA12) |
| `strategy_ema_slow_period` | 26 | 10-100 | Slow EMA period (source EMA26) |
| `strategy_ema_lookback` | 10 | 1-30 | Bars to look back for the EMA cross STATE |
| `strategy_rsi_period` | 14 | 5-30 | RSI lookback period |
| `strategy_rsi_oversold` | 30.0 | 10-45 | Entry trigger: RSI cross DOWN through this level |
| `strategy_rsi_overbought` | 70.0 | 55-90 | Exit gate: RSI at/above this level |
| `strategy_atr_period` | 14 | 5-30 | ATR period for stop sizing |
| `strategy_sl_atr_mult` | 2.0 | 0.5-5.0 | Stop distance = mult x ATR |
| `strategy_tp_rr` | 2.0 | 0.5-5.0 | Take-profit = tp_rr x stop distance (RR) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX; card primary target; clean RSI/EMA close-derived signal.
- `XAUUSD.DWX` — trending metal; card target; ATR-scaled stop ports across the higher price level.
- `GDAXI.DWX` — DAX 40; ported from card-stated `GER40.DWX` (not in `dwx_symbol_matrix.csv`); GDAXI is the canonical DAX DWX symbol.

**Explicitly NOT for:**
- `GER40.DWX` — not a canonical DWX symbol; the broker provides no tick data for it. Use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H2` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~35` |
| Typical hold time | `hours to a few days (H2 swing)` |
| Expected drawdown profile | `moderate; ATR-bounded per-trade risk, one position per magic` |
| Regime preference | `momentum-reversal (oversold dip inside an established uptrend)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** `forum` (GitHub open-source repo / docs example)
**Pointer:** `https://github.com/coding-kitties/investing-algorithm-framework/blob/main/docusaurus/docs/Getting%20Started/simple-example.md` (class `RSIEMACrossoverStrategy`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11274_iaf-rsi-ema.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | 6bead079-d4fa-43bb-8c43-80a872e4e063 |
