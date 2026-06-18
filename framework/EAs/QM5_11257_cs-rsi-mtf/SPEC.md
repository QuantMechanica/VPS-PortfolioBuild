# QM5_11257_cs-rsi-mtf — Strategy Spec

**EA ID:** QM5_11257
**Slug:** `cs-rsi-mtf`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Long-only multi-timeframe RSI mean-reversion mechanised from the CryptoSignal
`docs/config.md` RSI example (1d RSI + 1h RSI, `hot: 30` / `cold: 70`). Two
timeframes of the SAME symbol are combined: the daily (D1) RSI defines an
oversold regime STATE and the hourly (H1) RSI cross is the single entry EVENT.

Entry (on a closed H1 bar): go long when D1 RSI(21) is below 30 (oversold
context, a STATE) AND H1 RSI(50) crosses DOWN through 30 on this bar
(`RSI@2 >= 30 AND RSI@1 < 30`, the EVENT). Making the D1 leg a state and only
the H1 cross an event avoids the two-fresh-crosses-on-one-bar zero-trade trap.

Exit: close the long when H1 RSI(50) rises above 70 (reversion complete), or
force-close when D1 RSI(21) rises above 70, or after a 10 H1-bar time stop if
neither RSI exit fires. A hard stop sits at entry − 2.0 × ATR(14); once price
advances +1R the stop is moved to breakeven. A spread guard skips a bar only
when ATR(14) is below 10 × the live spread (fails open on the .DWX zero
modeled spread). Friday-close and the central news filter apply by framework
default.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_d1_rsi_period` | 21 | 14-28 | D1 RSI period (higher-TF oversold state) |
| `strategy_d1_hot` | 30.0 | 25-40 | D1 RSI oversold threshold (long context) |
| `strategy_d1_cold` | 70.0 | 65-75 | D1 RSI overbought threshold (force-close exit) |
| `strategy_h1_rsi_period` | 50 | 21-50 | H1 RSI period (entry-TF cross / exit) |
| `strategy_h1_hot` | 30.0 | 25-35 | H1 RSI oversold cross-down entry threshold |
| `strategy_h1_cold` | 70.0 | 65-75 | H1 RSI overbought exit threshold |
| `strategy_atr_period` | 14 | 10-21 | ATR period for the hard stop |
| `strategy_sl_atr_mult` | 2.0 | 1.5-2.5 | Hard stop distance = mult × ATR |
| `strategy_time_stop_bars` | 10 | 5-20 | Close after N H1 bars if no RSI exit fired |
| `strategy_spread_atr_mult` | 10.0 | 5-15 | Skip bar if ATR < this × live spread (fail-open on 0 spread) |

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for.

**Designed for:**
- `EURUSD.DWX` — deep, liquid major FX; clean RSI mean-reversion behaviour.
- `GBPUSD.DWX` — liquid major FX; RSI reversion edge with adequate volatility.
- `XAUUSD.DWX` — gold; strong oscillatory swings suit oversold RSI reversion.
- `NDX.DWX` — Nasdaq 100 index CFD; live-tradable, frequent RSI dips to fade.
- `GDAXI.DWX` — DAX 40 index CFD; ported from the card's `GER40.DWX` (see
  Section 6 note); the canonical DWX DAX symbol per `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `dwx_symbol_matrix.csv`; the broker provides no
  tick data under that name. Ported to `GDAXI.DWX` (same underlying, DAX 40).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` RSI(21) read off the same symbol (no basket) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~30 (card range 20-45) |
| Typical hold time | hours to a few days (≤10 H1 bars time-stop cap) |
| Expected drawdown profile | mean-reversion entries can cluster in persistent trends; MTF agreement lowers cadence |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** forum / open-source repository
**Pointer:** CryptoSignal/Crypto-Signal `docs/config.md` RSI example, https://github.com/CryptoSignal/Crypto-Signal/blob/master/docs/config.md
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11257_cs-rsi-mtf.md`

> Symbol port note: the card's R3 basket lists `GER40.DWX`, which is not in
> `framework/registry/dwx_symbol_matrix.csv`. Per build-prompt DWX symbol
> discipline (DAX → `GDAXI.DWX`), `GER40.DWX` was ported to `GDAXI.DWX`
> (same underlying, DAX 40). Flagged in the build_result `flags`.

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
