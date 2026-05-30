# QM5_10385_et-3bar-filter - Strategy Spec

**EA ID:** QM5_10385
**Slug:** et-3bar-filter
**Source:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA runs on M15 index data and looks for three consecutive closed candles in the same direction during the source intraday windows. A long setup requires three up candles, the latest close below its high, the latest close above EMA(200), a three-bar range below 0.35 * ATR(20), and the previous candle body to exceed 65% of its range; the short setup mirrors those rules below EMA(200). It places a stop order at the three-bar extreme, uses one setup range as the stop distance subject to the V5 four-spread minimum, targets 0.5 setup range, expires unfilled orders at the end of the active source window, and exits any open position at the afternoon session close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 200 | 150-250 in P3 | Trend filter EMA length on M15 close. |
| `strategy_atr_period` | 20 | 20 fixed by card | ATR period used to port the source range threshold. |
| `strategy_range_atr_mult` | 0.35 | 0.25-0.50 in P3 | Maximum three-bar range as a multiple of ATR(20). |
| `strategy_body_range_min` | 0.65 | 0.55-0.75 in P3 | Minimum previous-bar absolute body divided by previous-bar range. |
| `strategy_target_rg_mult` | 0.50 | 0.50-1.00 in P3 | Take-profit distance as a multiple of setup range. |
| `strategy_morning_start` | 1000 | source window variants in P3 | Morning entry window start in broker/exchange HHMM. |
| `strategy_morning_end` | 1200 | source window variants in P3 | Morning entry window end in broker/exchange HHMM. |
| `strategy_afternoon_start` | 1330 | source window variants in P3 | Afternoon entry window start in broker/exchange HHMM. |
| `strategy_afternoon_end` | 1500 | source window variants in P3 | Afternoon entry window end and latest new-order time in broker/exchange HHMM. |
| `strategy_session_close` | 1500 | source close | Intraday session-close exit time in broker/exchange HHMM. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index exposure named by the card; valid backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 large-cap US index analogue from the card's R3 basket.
- `WS30.DWX` - Dow 30 large-cap US index analogue from the card's R3 basket.
- `GDAXI.DWX` - DAX index proxy for card-stated `GER40.DWX`, which is not present in `dwx_symbol_matrix.csv`.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not in the DWX matrix; registered as `GDAXI.DWX` instead.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; the canonical custom symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Intraday; stop/target or 15:00 source session close |
| Expected drawdown profile | Transaction-cost and volatility-regime sensitive due to asymmetric 0.5R target versus 1R stop. |
| Regime preference | Intraday breakout after range compression with EMA trend filter |
| Win rate target (qualitative) | Medium-to-high required by the asymmetric reward-to-risk profile |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
**Source type:** forum
**Pointer:** acrary, working system, needs improvement, Elite Trader, 2003-02-16, https://www.elitetrader.com/et/threads/working-system-needs-improvement.14001/page-4
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10385_et-3bar-filter.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-25 | Initial build from card | 17817666-75ae-4d03-8957-629bc308b076 |
