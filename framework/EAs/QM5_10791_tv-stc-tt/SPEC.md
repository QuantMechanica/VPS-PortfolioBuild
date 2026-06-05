# QM5_10791_tv-stc-tt — Strategy Spec

**EA ID:** QM5_10791
**Slug:** `tv-stc-tt`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView `Trend trader + STC [CHFIF] - CV`)
**Author of this spec:** Claude
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

Trend-following with momentum confirmation. Two indicators agree before an entry:
the Schaff Trend Cycle (STC), a fast momentum oscillator (MACD passed through a
double stochastic + factor smoothing), and an Andrew-Abraham Trend Trader (TT)
line, an ATR-trailing trend line that flips between a volatility floor (uptrend)
and ceiling (downtrend).

Go **long** when, on the last closed bar, STC crosses upward through its buy level
(25) while rising, the TT line is in an uptrend, and the close is above the TT
line. Go **short** on the mirror: STC crosses downward through its sell level (75)
while falling, the TT line is in a downtrend, and the close is below it. Only one
position per symbol (no pyramiding).

Exit on the opposite STC signal or when price closes through the TT line (long:
STC sell or close below TT; short: STC buy or close above TT). A protective
bracket also applies: stop at 2×ATR(14), target at 3×ATR(14) (≈1.5R). Friday
close and the news filter are handled by the framework.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `stc_fast_length` | 23 | 5-50 | MACD fast EMA length feeding STC |
| `stc_slow_length` | 50 | 20-100 | MACD slow EMA length feeding STC |
| `stc_cycle_length` | 10 | 5-30 | STC stochastic cycle length |
| `stc_factor` | 0.5 | 0.1-0.9 | STC smoothing factor |
| `stc_buy_level` | 25.0 | 10-40 | Upward cross of this level = STC buy |
| `stc_sell_level` | 75.0 | 60-90 | Downward cross of this level = STC sell |
| `tt_atr_period` | 14 | 7-30 | ATR period for the TT trend line |
| `tt_atr_mult` | 3.0 | 1.5-5.0 | ATR multiple (TT line sensitivity) |
| `sl_atr_period` | 14 | 7-30 | ATR period for SL/TP brackets |
| `sl_atr_mult` | 2.0 | 1.5-2.5 | Stop = mult × ATR |
| `tp_atr_mult` | 3.0 | 1.0-4.0 | Target = mult × ATR |
| `use_ema_filter` | false | bool | Optional directional EMA side filter (P3) |
| `ema_filter_period` | 200 | 50-300 | EMA length for side filter |
| `use_adx_filter` | false | bool | Optional ADX strength gate (P3) |
| `adx_period` | 14 | 7-30 | ADX period |
| `adx_min` | 25.0 | 15-35 | Minimum ADX to allow entries |
| `max_spread_points` | 0.0 | 0-100 | No-trade spread guard (0 = off) |

---

## 3. Symbol Universe

**Designed for** (card R3 portable basket, all in `dwx_symbol_matrix.csv`):
- `EURUSD.DWX` — major FX, deep liquidity, clean trend/momentum behaviour
- `GBPUSD.DWX` — major FX, trends well, supports the STC+TT confirmation edge
- `USDJPY.DWX` — major FX, persistent trends suit a trend-following filter
- `XAUUSD.DWX` — gold; strong trending instrument (card wrote `XAUUSD`, registered as `.DWX`)
- `GDAXI.DWX` — DAX 40 index; card said `GER40.DWX` (not in matrix) → ported to the DAX symbol `GDAXI.DWX`
- `NDX.DWX` — Nasdaq 100; trending equity index, live-tradable
- `WS30.DWX` — Dow 30; trending equity index, live-tradable

**Explicitly NOT for:**
- `SP500.DWX` — not requested by the card; and backtest-only (not broker-routable for live)

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` (card baseline is M15/H1; H1 chosen as the P2 base) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~110` (card `expected_trades_per_year_per_symbol`) |
| Typical hold time | `hours to a few days` (H1 trend swings) |
| Expected drawdown profile | `moderate; trend-following with ATR brackets + opposite-signal exit` |
| Regime preference | `trend` (with momentum confirmation) |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** `forum` (TradingView protected-source script `Trend trader + STC [CHFIF] - CV`, author `Chfif`)
**Pointer:** TradingView script page (see card `source_citation`); `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10791_tv-stc-tt.md`

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
| v1 | 2026-06-05 | Initial build from card | c4bf56de-656d-4344-adb4-5e7360e2f4f5 |
