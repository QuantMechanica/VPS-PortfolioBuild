# QM5_11148_hpetf-3hl-d1 — Strategy Spec

**EA ID:** QM5_11148
**Slug:** `hpetf-3hl-d1`
**Source:** `c8ce2dc9-0ffe-50e2-841b-62a0ec11d758` (see `strategy-seeds/sources/c8ce2dc9-0ffe-50e2-841b-62a0ec11d758/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Trend-aligned ETF mean reversion on D1 index CFDs (Connors/Alvarez "High
Probability ETF Trading"). Long when the last closed bar's close is above its
200-day SMA (trend up) but below its 5-day SMA (short-term exhaustion) AND the
last three closed bars each printed a lower high and a lower low than the bar
before them (a three-day lower-high/lower-low pullback). The short side is the
exact mirror: close below SMA(200), close above SMA(5), and three consecutive
higher-high/higher-low bars. Entry is a market order at the next D1 open.
Exit when the close crosses back through the 5-day SMA (long: close > SMA(5);
short: close < SMA(5)), or after a 10-bar time-stop, whichever fires first.
A hard protective stop sits at 3 × ATR(14) from entry (the source has no stop;
this is the QM5 bounded-risk adaptation).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_trend_period` | 200 | 100-250 | Long-term trend-gate SMA period |
| `strategy_sma_exit_period` | 5 | 3-10 | Short-term SMA for entry setup and exit |
| `strategy_atr_period` | 14 | 7-21 | ATR period for the protective stop |
| `strategy_sl_atr_mult` | 3.0 | 1.5-5.0 | Stop distance as a multiple of ATR |
| `strategy_time_stop_bars` | 10 | 5-20 | Exit after this many closed D1 bars in trade |
| `strategy_spread_pct_of_atr` | 25.0 | 5-50 | Skip if spread > this % of ATR (card: 0.25*ATR) |
| `strategy_allow_long` | true | bool | Enable the above-200 long mean reversion |
| `strategy_allow_short` | true | bool | Enable the below-200 short mirror |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500, the canonical Connors HPETF (SPY) proxy; backtest-only Custom Symbol.
- `NDX.DWX` — Nasdaq 100 (QQQ equivalent), live-tradable index CFD for parallel validation.
- `WS30.DWX` — Dow 30 (DIA equivalent), live-tradable index CFD.
- `GDAXI.DWX` — DAX 40, a liquid non-US index to diversify the mean-reversion basket.

**Explicitly NOT for:**
- Single-stock or thin-liquidity symbols — the HPETF edge is calibrated to broad, liquid index ETFs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~4` |
| Typical hold time | `a few days (SMA(5) revert or 10-bar time-stop)` |
| Expected drawdown profile | `shallow per-trade (3×ATR stop), occasional trend-fight losses` |
| Regime preference | `mean-revert (counter short-term move, with the major trend)` |
| Win rate target (qualitative) | `high` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c8ce2dc9-0ffe-50e2-841b-62a0ec11d758`
**Source type:** `book`
**Pointer:** Larry Connors & Cesar Alvarez, *High Probability ETF Trading*, TradingMarkets / Connors Research, 2009 (`strategy-seeds/sources/c8ce2dc9-0ffe-50e2-841b-62a0ec11d758/`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11148_hpetf-3hl-d1.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor worktree |
