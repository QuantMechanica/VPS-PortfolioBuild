# QM5_11178_zip-rsi-ls — Strategy Spec

**EA ID:** QM5_11178
**Slug:** `zip-rsi-ls`
**Source:** `260fe030-5ad9-5466-91f8-61ef5e23f334` (Quantopian Zipline momentum_pipeline.py)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Cross-sectional RSI long/short basket on D1. Once per completed D1 bar the EA
computes RSI(14) on the last closed bar for every symbol in a fixed 10-symbol
DWX basket and ranks them by RSI value, highest first. RSI is used as a
cross-sectional RANK (a state), not as an overbought/oversold threshold and not
as a fresh-cross event. The EA runs one instance per host chart symbol: it longs
the chart symbol when that symbol is among the top `n_select` names by RSI
(strongest), and shorts it when the symbol is among the bottom `n_select`
(weakest). Entry fires the moment the chart symbol enters its band — there is no
double-cross requirement. At each daily rebalance the position is closed when the
chart symbol leaves its band; a flip to the opposite band closes here and allows
the opposite entry only on the next eligible bar (never both on the same bar). An
emergency time stop closes any position after 20 D1 bars. The safety stop is
2.5 × ATR(20) on D1 from entry; one position per symbol/magic, fixed-risk sizing.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 7-21 | RSI lookback (Zipline default 14) used for the cross-sectional rank |
| `strategy_n_select` | 3 | 2-4 | Number of names traded long (top N) and short (bottom N) |
| `strategy_min_active_symbols` | 6 | 4-10 | Skip the rebalance if fewer than this many symbols have valid RSI |
| `strategy_time_stop_d1_bars` | 20 | 10-40 | Emergency time stop: close after this many D1 bars |
| `strategy_atr_period` | 20 | 10-30 | D1 ATR period for the safety stop |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | Safety stop distance = mult × D1 ATR(period) |
| `strategy_spread_atr_cap` | 0.50 | 0.1-1.0 | Skip entry if quoted spread / D1 ATR exceeds this (fail-open on .DWX zero spread) |

---

## 3. Symbol Universe

The EA is a basket ranker: every registered symbol participates in the RSI rank,
and each runs as its own host-chart instance trading one position per symbol/magic.

**Designed for:**
- `SP500.DWX` — S&P 500 (backtest-only Custom Symbol); US large-cap leg of the card basket.
- `NDX.DWX` — Nasdaq 100; US large-cap growth leg.
- `WS30.DWX` — Dow 30; US large-cap value leg.
- `GDAXI.DWX` — DAX 40; card listed `GER40` (not in the matrix) — ported to GDAXI.DWX, the nearest DAX symbol.
- `EURUSD.DWX` — major FX, card basket leg.
- `GBPUSD.DWX` — major FX, card basket leg.
- `USDJPY.DWX` — major FX, card basket leg.
- `XAUUSD.DWX` — gold; card listed `XAUUSD` — matrix name carries the `.DWX` suffix.
- `XAGUSD.DWX` — silver; card listed `XAGUSD` — matrix name carries the `.DWX` suffix.
- `XTIUSD.DWX` — WTI crude; card listed `XTIUSD` — matrix name carries the `.DWX` suffix.

**Explicitly NOT for:**
- `SPX500.DWX` / `SPY.DWX` — not the canonical S&P Custom Symbol; `SP500.DWX` is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (all RSI/ATR reads on D1) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~80` |
| Typical hold time | `days (1-20 D1 bars)` |
| Expected drawdown profile | `correlation-spike / rank-instability driven; bounded by ATR safety stop` |
| Regime preference | `trend (cross-sectional momentum — hold strongest long, weakest short)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `260fe030-5ad9-5466-91f8-61ef5e23f334`
**Source type:** `forum / open-source backtester example`
**Pointer:** `https://github.com/quantopian/zipline/blob/master/zipline/examples/momentum_pipeline.py`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11178_zip-rsi-ls.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |
