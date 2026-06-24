# QM5_11386_4h-macd513-ema-cascade-zero-cross — Strategy Spec

**EA ID:** QM5_11386
**Slug:** `4h-macd513-ema-cascade-zero-cross`
**Source:** `be088e52-82be-5132-9057-cf081d189aa3` (anonymous "4 Hour MACD Forex Strategy" PDF)
**Author of this spec:** Codex
**Last revised:** 2026-06-24

---

## 1. Strategy Logic

On the close of each H4 bar the EA reads a trend STATE and a single trigger EVENT.
The trend STATE is the EMA(365) filter: long requires EMA(365) sloping up over the
last 5 bars (EMA(365) at shift 1 above EMA(365) at shift 6) and the last close above
EMA(365); short is the mirror. The single EVENT is the MACD(5,13,1) histogram crossing
the zero line: long when the histogram was at or below zero on the prior bar and above
zero on the last closed bar; short when it was at or above zero and is now below. The
MACD histogram legitimately runs negative, so its sign is never used as a data-validity
guard. A long fires only when the up-trend STATE and the zero-cross-up EVENT coincide
(short: down-trend STATE plus zero-cross-down EVENT). Stop is ATR(14) x 1.5 from entry,
capped at 40 pips for P2. The EA partially closes 50% at the EMA(21) target zone and
25% at the EMA(200) target zone, using ATR minimum distances when those EMA levels are
too close to entry. The final tranche is managed by breakeven at +1 x ATR and an
ATR(14) x 1.0 trailing stop. One position per symbol/magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 5 | 3-12 | MACD fast EMA period |
| `strategy_macd_slow` | 13 | 8-26 | MACD slow EMA period |
| `strategy_macd_signal` | 1 | 1-9 | MACD signal period (1 = MODE_MAIN is the histogram value) |
| `strategy_ema_trend_period` | 365 | 100-400 | EMA trend filter / cascade anchor |
| `strategy_ema_slope_bars` | 5 | 3-10 | Bars back used to measure the EMA(365) slope |
| `strategy_atr_period` | 14 | 7-28 | ATR period for stop / target / breakeven |
| `strategy_sl_atr_mult` | 1.5 | 0.5-3.0 | Stop distance = mult x ATR |
| `strategy_sl_cap_pips` | 40 | 10-80 | Maximum P2 stop distance in pips |
| `strategy_tp1_min_atr_mult` | 1.5 | 0.5-3.0 | Minimum TP1 distance when EMA(21) is too close |
| `strategy_tp2_min_atr_mult` | 3.0 | 1.0-6.0 | Minimum TP2 distance when EMA(200) is too close |
| `strategy_be_trigger_atr` | 1.0 | 0.5-2.0 | Move SL to breakeven at +mult x ATR |
| `strategy_trail_atr_mult` | 1.0 | 0.5-3.0 | ATR trailing stop distance for the final tranche |
| `strategy_spread_pct_of_stop` | 15.0 | 5-50 | Block only if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — major liquid FX pair, card R3 PASS primary
- `GBPUSD.DWX` — major liquid FX pair, card R3 PASS
- `USDJPY.DWX` — major liquid FX pair, card R3 PASS

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the card mechanises an H4 major-FX MACD trend
  system; index gap/session structure is out of scope.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~50` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `moderate; trend-following with fixed ATR stop` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `be088e52-82be-5132-9057-cf081d189aa3`
**Source type:** `paper` (anonymous PDF, contact prbain@tradingsmart.com)
**Pointer:** `136212376-4-Hour-MACD-Forex-Strategy.pdf` (Dropbox forex PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11386_4h-macd513-ema-cascade-zero-cross.md`

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
| v1 | 2026-06-24 | Initial build from card | 3909b3e7-844a-4e81-a7a3-1846ffac1b2a |
