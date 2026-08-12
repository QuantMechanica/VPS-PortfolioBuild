# QM5_11389_munzer-d1-ema34-sma150-double-cci — Strategy Spec

**EA ID:** QM5_11389
**Slug:** `munzer-d1-ema34-sma150-double-cci`
**Source:** `dfd32799-2055-5ef8-b99b-dcbfa51daba0`
**Author of this spec:** Codex
**Last revised:** 2026-08-07

---

## 1. Strategy Logic

On each newly opened D1 bar, the EA evaluates the preceding closed candle. A
long setup requires EMA(34) above SMA(150), the close above EMA(34), both
CCI(50) and CCI(14) above zero, and Stochastic %K(5,3,3) below 80; a short setup
uses the exact mirror conditions and requires Stochastic %K above 20. A close
between EMA(34) and SMA(150) is a no-trade zone.

For a valid long setup, the EA places a buy stop 10 pips above the signal
candle high; for a short setup, it places a sell stop 10 pips below the signal
candle low. The pending order is bounded to the following D1 interval. The stop
is 10 pips beyond the opposite signal-candle extreme, capped to 60 pips from
entry; the target is 2 × ATR(14), and the stop moves to entry after a 1 × ATR
favourable move. Unfilled stops are removed when the next D1 signal evaluation
begins, and positions otherwise exit through SL, TP, breakeven, or the framework
Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 34 | 21 or 34 | Fast exponential trend average; 21 is the card's Q03 alternative |
| `strategy_sma_period` | 150 | fixed by card | Slow simple trend average |
| `strategy_cci_slow_period` | 50 | 50 or 100 | Slow CCI sign filter; 100 is the card's Q03 alternative |
| `strategy_cci_fast_period` | 14 | 14 or 20 | Fast CCI sign filter; 20 is the card's Q03 alternative |
| `strategy_stoch_k` | 5 | 5 or 14 | Stochastic %K period; 14 is the card's Q03 alternative |
| `strategy_stoch_d` | 3 | fixed by card | Stochastic %D period |
| `strategy_stoch_slowing` | 3 | fixed by card | Stochastic slowing period |
| `strategy_stoch_overbought` | 80.0 | fixed by card | Long entries require %K below this level |
| `strategy_stoch_oversold` | 20.0 | fixed by card | Short entries require %K above this level |
| `strategy_entry_offset_pips` | 10 | fixed by card | Pending-stop distance beyond the signal-candle extreme |
| `strategy_sl_buffer_pips` | 10 | fixed by card | Stop buffer beyond the opposite signal-candle extreme |
| `strategy_sl_cap_pips` | 60 | fixed by card | Maximum entry-to-stop distance |
| `strategy_atr_period` | 14 | fixed by card | ATR period for target and breakeven distance |
| `strategy_tp_atr_mult` | 2.0 | fixed by card | Target distance in ATR multiples |
| `strategy_breakeven_atr_mult` | 1.0 | fixed by card | Favourable ATR move required before moving SL to entry |
| `strategy_spread_cap_pips` | 30 | fixed by card | Blocks only a genuinely positive spread above 30 pips |
| `strategy_pending_expiration_seconds` | 86400 | one D1 interval | Broker-side lifetime for an unfilled pending stop |

Framework inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are
not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — card-listed liquid major with complete D1 DWX history.
- `GBPUSD.DWX` — card-listed liquid major with complete D1 DWX history.
- `USDJPY.DWX` — card-listed liquid major; framework pip conversion handles its
  three-digit quote scale.

**Explicitly NOT for:**

- Other `.DWX` symbols — the approved R3 universe names only the three forex
  majors above, so no unapproved symbol expansion is included.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` in the canonical skeleton; strategy reads are fixed to closed `PERIOD_D1` shift 1 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Expected trade frequency | `approximately 2.5 per month`, derived arithmetically from 30/year |
| Typical hold time | Card does not quantify it; D1 swing held until SL, TP, breakeven exit, or Friday close |
| Expected drawdown profile | Card does not quantify it; every trade uses fixed-risk sizing and a 60-pip stop-distance cap |
| Regime preference | `trend`, as stated by the card's trend-following concept and MA structure |
| Win rate target (qualitative) | Not specified in the approved card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `dfd32799-2055-5ef8-b99b-dcbfa51daba0`
**Source type:** PDF compilation / named-author trading system
**Pointer:** Mohammed Munzer, “Complex Trading System #7,” in the
forex-strategies-revealed.com compilation; local archive
`C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\pdfcoffee.com_forex-strategy-7-pdf-free.pdf`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per
`artifacts/cards_approved/QM5_11389_munzer-d1-ema34-sma150-double-cci.md`.

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
| v1 | 2026-08-07 | Initial build from card | bf147105-5ef4-4df5-992c-e4dac77272b9 |
